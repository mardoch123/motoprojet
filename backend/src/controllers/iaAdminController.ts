import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';
import {
  getRapportAdmin,
  getChatAdmin,
  type AdminContexte,
  type AdminObjectif,
} from '../services/iaAdminService.js';
import { logger } from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * Agrège le contexte business complet pour l'IA admin.
 * Ne transmet AUCUNE donnée personnelle identifiable (pas de téléphone, adresse, etc.).
 */
async function buildAdminContexte(): Promise<AdminContexte> {
  // Exécuter toutes les requêtes d'agrégation en parallèle
  const [
    vehicules,
    paiements,
    recouvrement,
    chauffeurs,
    cashCumule,
    tendance,
    objectifs,
  ] = await Promise.all([
    // Véhicules
    pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE statut = 'en_remboursement') AS actifs,
        COUNT(*) FILTER (WHERE statut = 'rembourse') AS rembourses,
        COUNT(*) FILTER (WHERE type = 'moto' AND statut = 'en_remboursement') AS motos,
        COUNT(*) FILTER (WHERE type = 'voiture' AND statut = 'en_remboursement') AS voitures,
        COALESCE(AVG(prix_achat) FILTER (WHERE type = 'moto'), 450000) AS prix_moyen_moto,
        COALESCE(AVG(prix_achat) FILTER (WHERE type = 'voiture'), 3000000) AS prix_moyen_voiture,
        COALESCE(SUM(prix_achat), 0) AS valeur_totale
      FROM vehicules
    `),
    // Paiements (jour / semaine / mois)
    pool.query(`
      SELECT
        COALESCE(SUM(montant) FILTER (WHERE date = CURRENT_DATE), 0) AS jour,
        COALESCE(SUM(montant) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '7 days'), 0) AS semaine,
        COALESCE(SUM(montant) FILTER (WHERE date >= DATE_TRUNC('month', CURRENT_DATE)), 0) AS mois
      FROM paiements
    `),
    // Recouvrement (dernier snapshot)
    pool.query(`SELECT * FROM historique_taux_recouvrement ORDER BY date DESC LIMIT 1`),
    // Chauffeurs (comptages anonymisés)
    pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE statut = 'actif') AS actifs,
        COUNT(*) FILTER (WHERE statut = 'retard') AS retard,
        COUNT(*) FILTER (WHERE statut = 'defaut') AS defaut,
        COUNT(*) FILTER (WHERE statut IN ('actif') AND jours_impayes_cumules = 0) AS a_jour
      FROM chauffeurs
    `),
    // Cash cumulé
    pool.query(`SELECT * FROM vue_cash_cumule_disponible`),
    // Tendance 7 jours
    pool.query(`
      SELECT date::text AS date, COALESCE(SUM(montant), 0) AS montant
      FROM paiements
      WHERE date >= CURRENT_DATE - INTERVAL '7 days'
      GROUP BY date
      ORDER BY date ASC
    `),
    // Objectifs admin actifs
    pool.query(`SELECT * FROM ia_objectifs_admin WHERE actif = TRUE`),
  ]);

  const v = vehicules.rows[0];
  const p = paiements.rows[0];
  const r = recouvrement.rows[0] ?? {};
  const ch = chauffeurs.rows[0];
  const cash = cashCumule.rows[0] ?? {};
  const objectifsList: AdminObjectif[] = objectifs.rows.map((o: any) => ({
    libelle: o.libelle,
    valeur_cible: parseFloat(o.valeur_cible),
    unite: o.unite,
    delai_mois: o.delai_mois,
  }));

  // Calculer la trajectoire
  const nbVehiculesActifs = parseInt(v.actifs, 10);
  const objectifVehicules = objectifsList.find(o => o.unite === 'nb_vehicules');
  const objectifTaux = objectifsList.find(o => o.unite === 'taux_recouvrement');

  const vehiculesCible = objectifVehicules?.valeur_cible ?? 20;
  const delaiMois = objectifVehicules?.delai_mois ?? 12;
  const moisRestants = Math.max(1, delaiMois); // Simplifié
  const retardVehicules = Math.max(0, vehiculesCible - nbVehiculesActifs);
  const rythmeNecessaire = parseFloat((retardVehicules / moisRestants).toFixed(2));

  // Rythme réel : nb véhicules achetés les 3 derniers mois / 3
  const { rows: achatsRecents } = await pool.query(`
    SELECT COUNT(*) AS nb FROM vehicules
    WHERE date_achat >= CURRENT_DATE - INTERVAL '3 months'
  `);
  const rythmeReel = parseFloat(((parseInt(achatsRecents[0].nb, 10) || 0) / 3).toFixed(2));

  const tauxRecouvrementActuel = parseFloat(r.taux_recouvrement ?? '0');

  return {
    nb_vehicules_actifs: nbVehiculesActifs,
    nb_vehicules_rembourses: parseInt(v.rembourses, 10),
    nb_motos: parseInt(v.motos, 10),
    nb_voitures: parseInt(v.voitures, 10),
    prix_moyen_moto: parseFloat(v.prix_moyen_moto),
    prix_moyen_voiture: parseFloat(v.prix_moyen_voiture),
    valeur_totale_parc: parseFloat(v.valeur_totale),

    total_paiements_jour: parseFloat(p.jour),
    total_paiements_semaine: parseFloat(p.semaine),
    total_paiements_mois: parseFloat(p.mois),
    cash_cumule_total: parseFloat(cash.total_general ?? '0'),
    cash_disponible_achat: parseFloat(cash.total_general ?? '0'),

    taux_recouvrement: tauxRecouvrementActuel,
    montant_reel: parseFloat(r.montant_reel ?? '0'),
    montant_theorique: parseFloat(r.montant_theorique ?? '0'),

    nb_chauffeurs_actifs: parseInt(ch.actifs, 10),
    nb_chauffeurs_retard: parseInt(ch.retard, 10),
    nb_chauffeurs_defaut: parseInt(ch.defaut, 10),
    nb_chauffeurs_a_jour: parseInt(ch.a_jour, 10),
    montant_total_du: 0, // Calculé ci-dessous si nécessaire

    tendance_paiements: tendance.rows.map((t: any) => ({
      date: t.date,
      montant: parseFloat(t.montant),
    })),

    objectifs: objectifsList,

    trajectoire: {
      vehicules_cible: vehiculesCible,
      vehicules_actuels: nbVehiculesActifs,
      mois_restant: moisRestants,
      rythme_achat_necessaire: rythmeNecessaire,
      rythme_achat_reel: rythmeReel,
      taux_recouvrement_cible: objectifTaux?.valeur_cible ?? 90,
      taux_recouvrement_actuel: tauxRecouvrementActuel,
    },
  };
}

/**
 * GET /api/v1/ia/admin/rapport
 *
 * Génère (ou retourne le dernier) rapport IA hebdomadaire.
 * Si un rapport de moins de 24h existe, il est retourné sinon un nouveau est généré.
 */
export async function getRapport(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const forceRefresh = req.query.force === 'true';

    // Vérifier s'il existe un rapport récent (< 24h)
    if (!forceRefresh) {
      const { rows: rapportsRecents } = await pool.query(`
        SELECT id, rapport, actions_proposees, trajectoire, objectifs_snapshot, modele_utilise, date_creation
        FROM ia_rapports_admin
        WHERE type = 'hebdo' AND date_creation >= NOW() - INTERVAL '24 hours'
        ORDER BY date_creation DESC
        LIMIT 1
      `);

      if (rapportsRecents.length > 0) {
        const r = rapportsRecents[0];
        res.json({
          success: true,
          data: {
            id: r.id,
            rapport: r.rapport,
            actions_proposees: r.actions_proposees ?? [],
            trajectoire: r.trajectoire,
            objectifs: r.objectifs_snapshot ?? {},
            modele_utilise: r.modele_utilise,
            date: r.date_creation,
            frais: false,
          },
        });
        return;
      }
    }

    // Construire le contexte et appeler l'IA
    const contexte = await buildAdminContexte();
    const reponseIA = await getRapportAdmin(contexte);

    // Stocker le rapport
    const { rows: newRapport } = await pool.query(`
      INSERT INTO ia_rapports_admin
        (type, contexte_json, rapport, actions_proposees, trajectoire, objectifs_snapshot, modele_utilise, user_id)
      VALUES ('hebdo', $1, $2, $3, $4, $5, $6, $7)
      RETURNING id, date_creation
    `, [
      JSON.stringify({
        nb_vehicules: contexte.nb_vehicules_actifs,
        taux_recouvrement: contexte.taux_recouvrement,
        nb_chauffeurs: contexte.nb_chauffeurs_actifs,
        cash_disponible: contexte.cash_disponible_achat,
      }),
      reponseIA.rapport,
      JSON.stringify(reponseIA.actions_proposees),
      reponseIA.trajectoire,
      JSON.stringify(contexte.objectifs),
      reponseIA.modele_utilise,
      req.user?.sub,
    ]);

    res.json({
      success: true,
      data: {
        id: newRapport[0].id,
        rapport: reponseIA.rapport,
        actions_proposees: reponseIA.actions_proposees,
        trajectoire: reponseIA.trajectoire,
        objectifs: contexte.objectifs,
        modele_utilise: reponseIA.modele_utilise,
        date: newRapport[0].date_creation,
        frais: true,
      },
    });
  } catch (err) {
    logger.error('[IA-Admin] Erreur getRapport', { err });
    next(err);
  }
}

/**
 * POST /api/v1/ia/admin/chat
 *
 * Chat libre avec l'IA — le super admin pose une question en langage naturel.
 * Body : { question: string }
 */
export async function chat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { question } = req.body as { question: string };

    if (!question || question.trim().length < 3) {
      throw AppError.badRequest('La question doit contenir au moins 3 caractères');
    }

    const contexte = await buildAdminContexte();
    const reponseIA = await getChatAdmin(question.trim(), contexte);

    // Stocker la réponse chat
    const { rows: newChat } = await pool.query(`
      INSERT INTO ia_rapports_admin
        (type, contexte_json, rapport, actions_proposees, trajectoire, objectifs_snapshot, modele_utilise, user_id)
      VALUES ('chat', $1, $2, $3, $4, $5, $6, $7)
      RETURNING id, date_creation
    `, [
      JSON.stringify({ question: question.trim().substring(0, 200) }),
      reponseIA.rapport,
      JSON.stringify(reponseIA.actions_proposees),
      reponseIA.trajectoire,
      JSON.stringify({}),
      reponseIA.modele_utilise,
      req.user?.sub,
    ]);

    res.json({
      success: true,
      data: {
        id: newChat[0].id,
        reponse: reponseIA.rapport,
        actions: reponseIA.actions_proposees,
        modele_utilise: reponseIA.modele_utilise,
        date: newChat[0].date_creation,
      },
    });
  } catch (err) {
    logger.error('[IA-Admin] Erreur chat', { err });
    next(err);
  }
}

/**
 * GET /api/v1/ia/admin/historique
 *
 * Liste des rapports IA passés.
 * Query params : type (hebdo|chat|manuel), limit (défaut 20, max 100)
 */
export async function getHistorique(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const typeFilter = req.query.type as string;
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));

    let query = `
      SELECT id, type, rapport, actions_proposees, trajectoire, objectifs_snapshot, modele_utilise, date_creation
      FROM ia_rapports_admin
    `;
    const params: unknown[] = [];

    if (typeFilter && ['hebdo', 'chat', 'manuel'].includes(typeFilter)) {
      query += ` WHERE type = $1`;
      params.push(typeFilter);
    }

    query += ` ORDER BY date_creation DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const { rows } = await pool.query(query, params);

    // Stats globales
    const { rows: stats } = await pool.query(`
      SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE type = 'hebdo') AS hebdo,
        COUNT(*) FILTER (WHERE type = 'chat') AS chat,
        COUNT(*) FILTER (WHERE trajectoire = 'en_retard') AS en_retard,
        COUNT(*) FILTER (WHERE trajectoire = 'a_temps') AS a_temps,
        COUNT(*) FILTER (WHERE trajectoire = 'en_avance') AS en_avance
      FROM ia_rapports_admin
    `);

    res.json({
      success: true,
      data: {
        rapports: rows.map((r: any) => ({
          id: r.id,
          type: r.type,
          rapport: r.rapport,
          actions_proposees: r.actions_proposees ?? [],
          trajectoire: r.trajectoire,
          objectifs: r.objectifs_snapshot ?? {},
          modele_utilise: r.modele_utilise,
          date: r.date_creation,
        })),
        stats: {
          total: parseInt(stats[0].total, 10),
          rapports_hebdo: parseInt(stats[0].hebdo, 10),
          sessions_chat: parseInt(stats[0].chat, 10),
          trajectoires: {
            en_avance: parseInt(stats[0].en_avance, 10),
            a_temps: parseInt(stats[0].a_temps, 10),
            en_retard: parseInt(stats[0].en_retard, 10),
          },
        },
      },
    });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/ia/admin/objectif
 *
 * Définir ou modifier un objectif global.
 * Body : { libelle, valeur_cible, unite, delai_mois }
 */
export async function setObjectif(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { libelle, valeur_cible, unite, delai_mois } = req.body as {
      libelle: string;
      valeur_cible: number;
      unite: 'nb_vehicules' | 'taux_recouvrement' | 'revenu_mensuel' | 'delai_mois';
      delai_mois: number;
    };

    if (!libelle || !valeur_cible || !unite) {
      throw AppError.badRequest('libelle, valeur_cible et unite sont requis');
    }

    const validUnites = ['nb_vehicules', 'taux_recouvrement', 'revenu_mensuel', 'delai_mois'];
    if (!validUnites.includes(unite)) {
      throw AppError.badRequest(`Unité invalide. Valeurs acceptées : ${validUnites.join(', ')}`);
    }

    const { rows } = await pool.query(`
      INSERT INTO ia_objectifs_admin (libelle, valeur_cible, unite, delai_mois)
      VALUES ($1, $2, $3, $4)
      RETURNING id, libelle, valeur_cible, unite, delai_mois, actif, date_creation
    `, [libelle, valeur_cible, unite, delai_mois ?? 12]);

    res.json({
      success: true,
      data: {
        id: rows[0].id,
        libelle: rows[0].libelle,
        valeur_cible: parseFloat(rows[0].valeur_cible),
        unite: rows[0].unite,
        delai_mois: rows[0].delai_mois,
        actif: rows[0].actif,
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/ia/admin/objectifs
 *
 * Liste des objectifs admin actifs.
 */
export async function getObjectifs(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT id, libelle, valeur_cible, unite, delai_mois, actif, date_creation
      FROM ia_objectifs_admin
      WHERE actif = TRUE
      ORDER BY date_creation DESC
    `);

    res.json({
      success: true,
      data: rows.map((o: any) => ({
        id: o.id,
        libelle: o.libelle,
        valeur_cible: parseFloat(o.valeur_cible),
        unite: o.unite,
        delai_mois: o.delai_mois,
        actif: o.actif,
      })),
    });
  } catch (err) { next(err); }
}

/**
 * Génère le rapport hebdomadaire automatiquement (appelé par le scheduler).
 */
export async function generateRapportHebdo(): Promise<{ id: string; trajectoire: string }> {
  logger.info('[IA-Admin] Génération du rapport hebdomadaire automatique');

  const contexte = await buildAdminContexte();
  const reponseIA = await getRapportAdmin(contexte);

  const { rows } = await pool.query(`
    INSERT INTO ia_rapports_admin
      (type, contexte_json, rapport, actions_proposees, trajectoire, objectifs_snapshot, modele_utilise)
    VALUES ('hebdo', $1, $2, $3, $4, $5, $6)
    RETURNING id
  `, [
    JSON.stringify({
      nb_vehicules: contexte.nb_vehicules_actifs,
      taux_recouvrement: contexte.taux_recouvrement,
      generation: 'automatique',
    }),
    reponseIA.rapport,
    JSON.stringify(reponseIA.actions_proposees),
    reponseIA.trajectoire,
    JSON.stringify(contexte.objectifs),
    reponseIA.modele_utilise,
  ]);

  logger.info(`[IA-Admin] Rapport hebdo généré : ${rows[0].id} (${reponseIA.trajectoire})`);
  return { id: rows[0].id, trajectoire: reponseIA.trajectoire };
}
