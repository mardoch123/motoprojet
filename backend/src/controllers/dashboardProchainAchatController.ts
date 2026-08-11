import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';
import { calculerApportsPrevus } from '../services/financesService.js';

/**
 * GET /api/v1/dashboard/prochain-achat
 *
 * Calcule en temps réel :
 * - La trésorerie disponible pour achat (cash encaissé - salaires versés - dépenses)
 * - Le rythme d'encaissement moyen sur 30 jours (moyenne glissante)
 * - Les projections de date d'achat pour moto et voiture
 * - L'historique des achats précédents
 */
export async function getProchainAchat(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    // ── 1. Prix configurables ────────────────────────────────────────────────
    const { rows: prixRows } = await pool.query(`
      SELECT cle, valeur FROM parametres
      WHERE cle IN ('prix_moto_defaut', 'prix_voiture_defaut')
    `);
    const prixMap: Record<string, number> = {};
    for (const r of prixRows) prixMap[r.cle] = parseFloat(r.valeur);
    const prixMoto = prixMap['prix_moto_defaut'] ?? 500000;
    const prixVoiture = prixMap['prix_voiture_defaut'] ?? 2500000;

    // ── 2. Trésorerie disponible ─────────────────────────────────────────────
    // Total encaissé
    const { rows: cashRows } = await pool.query(`
      SELECT COALESCE(SUM(montant), 0)::float AS total
      FROM paiements
    `);
    const totalEncaisse = cashRows[0]?.total ?? 0;

    // Salaires versés
    const { rows: salaireRows } = await pool.query(`
      SELECT COALESCE(SUM(montant), 0)::float AS total
      FROM salaires
    `);
    const totalSalaires = salaireRows[0]?.total ?? 0;

    // Dépenses incidents (coûts de réparation)
    const { rows: incidentRows } = await pool.query(`
      SELECT COALESCE(SUM(cout), 0)::float AS total
      FROM incidents WHERE cout > 0
    `);
    const totalDepenses = incidentRows[0]?.total ?? 0;

    // Véhicules déjà achetés (somme des prix d'achat)
    const { rows: achatsRows } = await pool.query(`
      SELECT COALESCE(SUM(prix_achat), 0)::float AS total,
             COUNT(*)::int AS nb
      FROM vehicules
    `);
    const totalAchats = achatsRows[0]?.total ?? 0;
    const nbVehiculesAchetes = achatsRows[0]?.nb ?? 0;

    // Trésorerie nette disponible = encaissé - salaires - dépenses - achats
    const tresorerieDisponible = totalEncaisse - totalSalaires - totalDepenses - totalAchats;

    // ── 3. Répartition du cash (si mode mixte) ───────────────────────────────
    // Lire la règle de réinvestissement
    const { rows: regleRows } = await pool.query(`
      SELECT valeur FROM parametres WHERE cle = 'regle_reinvestissement'
    `);
    const regle = regleRows[0]?.valeur ?? 'tout_moto';

    // Si 100% moto → tout le cash va à la moto
    // Si 100% voiture → tout le cash va à la voiture
    // Si mixte → répartition 50/50 par défaut (ou selon rythme)
    let partMoto: number, partVoiture: number;
    switch (regle) {
      case 'tout_moto':
        partMoto = 1; partVoiture = 0; break;
      case 'tout_voiture':
        partMoto = 0; partVoiture = 1; break;
      case 'bascule':
        // Après la bascule, tout va en voiture
        const { rows: dateBascule } = await pool.query(
          `SELECT valeur FROM parametres WHERE cle = 'date_bascule_voiture'`
        );
        const basculeAtteinte = dateBascule.length > 0 && new Date() >= new Date(dateBascule[0].valeur);
        partMoto = basculeAtteinte ? 0 : 1;
        partVoiture = basculeAtteinte ? 1 : 0;
        break;
      default: // mixte → 50/50
        partMoto = 0.5; partVoiture = 0.5;
    }

    const cashAlloueMoto = tresorerieDisponible * partMoto;
    const cashAlloueVoiture = tresorerieDisponible * partVoiture;

    // ── 4. Rythme d'encaissement (30 derniers jours) ─────────────────────────
    const { rows: rythmeRows } = await pool.query(`
      SELECT
        COALESCE(SUM(montant), 0)::float AS total_30j,
        COUNT(DISTINCT DATE(date))::int AS nb_jours
      FROM paiements
      WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    `);
    const total30j = rythmeRows[0]?.total_30j ?? 0;
    const nbJours = rythmeRows[0]?.nb_jours ?? 1;
    const moyenneJournaliere = total30j / Math.max(nbJours, 1);

    // Rythme par type (proportionnel à la part allouée)
    const rythmeMotoParJour = moyenneJournaliere * partMoto;
    const rythmeVoitureParJour = moyenneJournaliere * partVoiture;

    // ── 4b. Apports personnels configurés ─────────────────────────────────
    // Calculer les apports prévus sur les 90 prochains jours pour moto et voiture
    const apportsMoto90j = await calculerApportsPrevus(90, 'moto');
    const apportsVoiture90j = await calculerApportsPrevus(90, 'voiture');
    const apportsMotoParJour = apportsMoto90j / 90;
    const apportsVoitureParJour = apportsVoiture90j / 90;

    // Rythme total (encaissement + apports)
    const rythmeTotalMotoParJour = rythmeMotoParJour + apportsMotoParJour;
    const rythmeTotalVoitureParJour = rythmeVoitureParJour + apportsVoitureParJour;

    // ── 5. Projections ───────────────────────────────────────────────────────
    const manqueMoto = Math.max(0, prixMoto - cashAlloueMoto);
    const manqueVoiture = Math.max(0, prixVoiture - cashAlloueVoiture);

    // Utiliser le rythme total (encaissement + apports) pour les projections
    const joursRestantsMoto = rythmeTotalMotoParJour > 0 ? Math.ceil(manqueMoto / rythmeTotalMotoParJour) : null;
    const joursRestantsVoiture = rythmeTotalVoitureParJour > 0 ? Math.ceil(manqueVoiture / rythmeTotalVoitureParJour) : null;

    const now = new Date();
    const dateMoto = joursRestantsMoto !== null ? new Date(now.getTime() + joursRestantsMoto * 86400000) : null;
    const dateVoiture = joursRestantsVoiture !== null ? new Date(now.getTime() + joursRestantsVoiture * 86400000) : null;

    const pctMoto = prixMoto > 0 ? Math.min(100, (cashAlloueMoto / prixMoto) * 100) : 0;
    const pctVoiture = prixVoiture > 0 ? Math.min(100, (cashAlloueVoiture / prixVoiture) * 100) : 0;

    // ── 6. Historique des achats ─────────────────────────────────────────────
    const { rows: historique } = await pool.query(`
      SELECT
        id, type, plaque, marque, prix_achat, date_achat,
        DATE(date_achat) AS date_achat_formatted
      FROM vehicules
      ORDER BY date_achat DESC
      LIMIT 20
    `);

    // ── 7. Récapitulatif ─────────────────────────────────────────────────────
    res.json({
      success: true,
      data: {
        tresorerie: {
          totalEncaisse,
          totalSalaires,
          totalDepenses,
          totalAchats,
          disponible: tresorerieDisponible,
          nbVehiculesAchetes,
        },
        moto: {
          prix: prixMoto,
          cashAlloue: Math.round(cashAlloueMoto),
          manque: Math.round(manqueMoto),
          pct: Math.round(pctMoto * 10) / 10,
          joursRestants: joursRestantsMoto,
          dateEstimee: dateMoto?.toISOString().split('T')[0] ?? null,
          rythmeJour: Math.round(rythmeMotoParJour),
          apportsJour: Math.round(apportsMotoParJour),
          apports90j: Math.round(apportsMoto90j),
        },
        voiture: {
          prix: prixVoiture,
          cashAlloue: Math.round(cashAlloueVoiture),
          manque: Math.round(manqueVoiture),
          pct: Math.round(pctVoiture * 10) / 10,
          joursRestants: joursRestantsVoiture,
          dateEstimee: dateVoiture?.toISOString().split('T')[0] ?? null,
          rythmeJour: Math.round(rythmeVoitureParJour),
          apportsJour: Math.round(apportsVoitureParJour),
          apports90j: Math.round(apportsVoiture90j),
        },
        rythme: {
          moyenneJournaliere: Math.round(moyenneJournaliere),
          total30j: Math.round(total30j),
          nbJoursActifs: nbJours,
          partMoto,
          partVoiture,
          regle,
        },
        historique: historique.map((h: any) => ({
          id: h.id,
          type: h.type,
          plaque: h.plaque,
          marque: h.marque,
          prix: parseFloat(h.prix_achat),
          date: h.date_achat,
        })),
      },
    });
  } catch (err) { next(err); }
}
