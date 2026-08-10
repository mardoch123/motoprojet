import crypto from 'node:crypto';
import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { writeAuditLog } from './audit.js';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface Contrat {
  id: string;
  numero: string;
  chauffeurId: string;
  vehiculeId: string;
  garantId: string | null;
  prixAchat: number;
  apportInitial: number;
  montantFinanc: number;
  frequencePaiement: string;
  montantEcheance: number;
  nombreEcheances: number | null;
  tauxInteret: number;
  datePremierPaiement: string | null;
  dateSignature: string | null;
  dateDebut: string;
  dateFinPrevue: string | null;
  dateFinReelle: string | null;
  statut: string;
  pdfUrl: string | null;
  pdfHash: string | null;
  creePar: string | null;
  creeLe: string;
  modifieLe: string;
  notes: string | null;
}

export interface Garant {
  id: string;
  userId: string | null;
  nom: string;
  prenom: string | null;
  dateNaissance: string | null;
  lieuNaissance: string | null;
  nationalite: string;
  profession: string | null;
  telephone: string;
  email: string | null;
  adresse: string | null;
  pieceIdentiteType: string | null;
  pieceIdentiteNumero: string | null;
  pieceIdentiteDelivreeLe: string | null;
  pieceIdentiteLieu: string | null;
  lienParente: string | null;
  situationFinanciere: string | null;
  employeur: string | null;
  revenuMensuel: number | null;
  photoUrl: string | null;
  actif: boolean;
  creeLe: string;
}

export interface SignatureContrat {
  id: string;
  contratId: string;
  signataireType: string;
  signataireId: string;
  signataireNom: string;
  signatureHash: string;
  signatureImageUrl: string | null;
  dateSignature: string;
  ipAddress: string | null;
  userAgent: string | null;
  statut: string;
  creeLe: string;
}

// ─── Numérotation ────────────────────────────────────────────────────────────

async function genererNumeroContrat(): Promise<string> {
  const { rows } = await pool.query(`SELECT valeur FROM parametres_contrats WHERE cle = 'prefixe_numero'`);
  const prefixe = rows[0]?.valeur ?? 'MP';
  
  const annee = new Date().getFullYear();
  const { rows: countRows } = await pool.query(
    `SELECT COUNT(*) FROM contrats WHERE numero LIKE $1`,
    [`${prefixe}-${annee}-%`],
  );
  const numero = parseInt(countRows[0].count, 10) + 1;
  return `${prefixe}-${annee}-${String(numero).padStart(4, '0')}`;
}

// ─── Garant ──────────────────────────────────────────────────────────────────

export async function creerGarant(data: {
  nom: string;
  prenom?: string;
  dateNaissance?: string;
  lieuNaissance?: string;
  nationalite?: string;
  profession?: string;
  telephone: string;
  email?: string;
  adresse?: string;
  pieceIdentiteType?: string;
  pieceIdentiteNumero?: string;
  pieceIdentiteDelivreeLe?: string;
  pieceIdentiteLieu?: string;
  lienParente?: string;
  situationFinanciere?: string;
  employeur?: string;
  revenuMensuel?: number;
  photoUrl?: string;
  userId?: string;
}): Promise<Garant> {
  const { rows } = await pool.query(`
    INSERT INTO garants (
      nom, prenom, date_naissance, lieu_naissance, nationalite, profession,
      telephone, email, adresse, piece_identite_type, piece_identite_numero,
      piece_identite_delivree_le, piece_identite_lieu, lien_parente,
      situation_financiere, employeur, revenu_mensuel, photo_url, user_id
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)
    RETURNING *
  `, [
    data.nom, data.prenom ?? null, data.dateNaissance ?? null,
    data.lieuNaissance ?? null, data.nationalite ?? 'Béninoise',
    data.profession ?? null, data.telephone, data.email ?? null,
    data.adresse ?? null, data.pieceIdentiteType ?? null,
    data.pieceIdentiteNumero ?? null, data.pieceIdentiteDelivreeLe ?? null,
    data.pieceIdentiteLieu ?? null, data.lienParente ?? null,
    data.situationFinanciere ?? null, data.employeur ?? null,
    data.revenuMensuel ?? null, data.photoUrl ?? null, data.userId ?? null,
  ]);

  return mapGarant(rows[0]);
}

export async function listerGarants(actifsOnly = true): Promise<Garant[]> {
  const query = actifsOnly
    ? `SELECT * FROM garants WHERE actif = true ORDER BY nom`
    : `SELECT * FROM garants ORDER BY nom`;
  const { rows } = await pool.query(query);
  return rows.map(mapGarant);
}

export async function getGarant(id: string): Promise<Garant | null> {
  const { rows } = await pool.query(`SELECT * FROM garants WHERE id = $1`, [id]);
  return rows.length > 0 ? mapGarant(rows[0]) : null;
}

export async function updateGarant(id: string, data: Record<string, unknown>): Promise<Garant | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let idx = 1;

  const mapping: Record<string, string> = {
    nom: 'nom', prenom: 'prenom', dateNaissance: 'date_naissance',
    lieuNaissance: 'lieu_naissance', nationalite: 'nationalite',
    profession: 'profession', telephone: 'telephone', email: 'email',
    adresse: 'adresse', pieceIdentiteType: 'piece_identite_type',
    pieceIdentiteNumero: 'piece_identite_numero',
    pieceIdentiteDelivreeLe: 'piece_identite_delivree_le',
    pieceIdentiteLieu: 'piece_identite_lieu', lienParente: 'lien_parente',
    situationFinanciere: 'situation_financiere', employeur: 'employeur',
    revenuMensuel: 'revenu_mensuel', photoUrl: 'photo_url', actif: 'actif',
  };

  for (const [key, col] of Object.entries(mapping)) {
    if (data[key] !== undefined) {
      fields.push(`${col} = $${idx}`);
      values.push(data[key]);
      idx++;
    }
  }

  if (fields.length === 0) return getGarant(id);
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE garants SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
    values,
  );
  return rows.length > 0 ? mapGarant(rows[0]) : null;
}

function mapGarant(r: Record<string, unknown>): Garant {
  return {
    id: r.id as string,
    userId: r.user_id as string | null,
    nom: r.nom as string,
    prenom: r.prenom as string | null,
    dateNaissance: r.date_naissance as string | null,
    lieuNaissance: r.lieu_naissance as string | null,
    nationalite: r.nationalite as string,
    profession: r.profession as string | null,
    telephone: r.telephone as string,
    email: r.email as string | null,
    adresse: r.adresse as string | null,
    pieceIdentiteType: r.piece_identite_type as string | null,
    pieceIdentiteNumero: r.piece_identite_numero as string | null,
    pieceIdentiteDelivreeLe: r.piece_identite_delivree_le as string | null,
    pieceIdentiteLieu: r.piece_identite_lieu as string | null,
    lienParente: r.lien_parente as string | null,
    situationFinanciere: r.situation_financiere as string | null,
    employeur: r.employeur as string | null,
    revenuMensuel: r.revenu_mensuel ? parseFloat(r.revenu_mensuel as string) : null,
    photoUrl: r.photo_url as string | null,
    actif: r.actif as boolean,
    creeLe: r.cree_le as string,
  };
}

// ─── Paramètres ──────────────────────────────────────────────────────────────

export async function listerParametres(): Promise<Array<{ cle: string; valeur: string; description: string | null }>> {
  const { rows } = await pool.query(`SELECT cle, valeur, description FROM parametres_contrats ORDER BY cle`);
  return rows.map((r: Record<string, unknown>) => ({
    cle: r.cle as string,
    valeur: r.valeur as string,
    description: r.description as string | null,
  }));
}

export async function updateParametre(cle: string, valeur: string, userId: string): Promise<void> {
  await pool.query(
    `UPDATE parametres_contrats SET valeur = $2, modifie_par = $3, modifie_le = NOW() WHERE cle = $1`,
    [cle, valeur, userId],
  );
}

// ─── Contrats ────────────────────────────────────────────────────────────────

export async function creerContrat(data: {
  chauffeurId: string;
  vehiculeId: string;
  garantId?: string;
  prixAchat: number;
  apportInitial?: number;
  frequencePaiement: string;
  montantEcheance: number;
  nombreEcheances?: number;
  tauxInteret?: number;
  datePremierPaiement?: string;
  dateDebut: string;
  dateFinPrevue?: string;
  notes?: string;
  userId: string;
}): Promise<Contrat> {
  const numero = await genererNumeroContrat();
  const montantFinanc = data.prixAchat - (data.apportInitial ?? 0);

  const { rows } = await pool.query(`
    INSERT INTO contrats (
      numero, chauffeur_id, vehicule_id, garant_id, prix_achat, apport_initial,
      montant_financ, frequence_paiement, montant_echeance, nombre_echeances,
      taux_interet, date_premier_paiement, date_debut, date_fin_prevue,
      statut, cree_par, notes
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'brouillon',$15,$16)
    RETURNING *
  `, [
    numero, data.chauffeurId, data.vehiculeId, data.garantId ?? null,
    data.prixAchat, data.apportInitial ?? 0, montantFinanc,
    data.frequencePaiement, data.montantEcheance, data.nombreEcheances ?? null,
    data.tauxInteret ?? 0, data.datePremierPaiement ?? null,
    data.dateDebut, data.dateFinPrevue ?? null, data.userId, data.notes ?? null,
  ]);

  logger.info('Contrat créé', { numero, chauffeurId: data.chauffeurId });
  return mapContrat(rows[0]);
}

export async function listerContrats(options?: {
  chauffeurId?: string;
  garantId?: string;
  statut?: string;
  vehiculeId?: string;
}): Promise<Contrat[]> {
  let query = `SELECT * FROM contrats`;
  const conditions: string[] = [];
  const params: unknown[] = [];
  let idx = 1;

  if (options?.chauffeurId) {
    conditions.push(`chauffeur_id = $${idx}`);
    params.push(options.chauffeurId);
    idx++;
  }
  if (options?.garantId) {
    conditions.push(`garant_id = $${idx}`);
    params.push(options.garantId);
    idx++;
  }
  if (options?.statut) {
    conditions.push(`statut = $${idx}`);
    params.push(options.statut);
    idx++;
  }
  if (options?.vehiculeId) {
    conditions.push(`vehicule_id = $${idx}`);
    params.push(options.vehiculeId);
    idx++;
  }

  if (conditions.length > 0) query += ' WHERE ' + conditions.join(' AND ');
  query += ' ORDER BY cree_le DESC';

  const { rows } = await pool.query(query, params);
  return rows.map(mapContrat);
}

export async function getContrat(id: string): Promise<Contrat | null> {
  const { rows } = await pool.query(`SELECT * FROM contrats WHERE id = $1`, [id]);
  return rows.length > 0 ? mapContrat(rows[0]) : null;
}

export async function getContratComplet(id: string): Promise<Record<string, unknown> | null> {
  const contrat = await getContrat(id);
  if (!contrat) return null;

  // Chauffeur + user
  const { rows: chauffeurRows } = await pool.query(`
    SELECT c.*, u.telephone, u.statut AS user_statut
    FROM chauffeurs c JOIN users u ON c.user_id = u.id
    WHERE c.id = $1
  `, [contrat.chauffeurId]);

  // Véhicule
  const { rows: vehiculeRows } = await pool.query(
    `SELECT * FROM vehicules WHERE id = $1`, [contrat.vehiculeId],
  );

  // Garant
  let garant = null;
  if (contrat.garantId) {
    garant = await getGarant(contrat.garantId);
  }

  // Signatures
  const { rows: signatureRows } = await pool.query(`
    SELECT * FROM signatures_contrats WHERE contrat_id = $1 ORDER BY date_signature
  `, [id]);

  // Paiements
  const { rows: paiementRows } = await pool.query(`
    SELECT * FROM paiements WHERE vehicule_id = $1 ORDER BY date DESC LIMIT 50
  `, [contrat.vehiculeId]);

  // Stats paiements
  const { rows: statsRows } = await pool.query(`
    SELECT COALESCE(SUM(montant), 0) AS total_verse, COUNT(*) AS nb_paiements
    FROM paiements WHERE vehicule_id = $1
  `, [contrat.vehiculeId]);

  return {
    ...contrat,
    chauffeur: chauffeurRows[0] ?? null,
    vehicule: vehiculeRows[0] ?? null,
    garant,
    signatures: signatureRows.map(mapSignature),
    paiements: paiementRows,
    stats: statsRows[0] ?? { total_verse: 0, nb_paiements: 0 },
  };
}

export async function updateContrat(id: string, data: Record<string, unknown>): Promise<Contrat | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let idx = 1;

  const mapping: Record<string, string> = {
    garantId: 'garant_id', prixAchat: 'prix_achat', apportInitial: 'apport_initial',
    frequencePaiement: 'frequence_paiement', montantEcheance: 'montant_echeance',
    nombreEcheances: 'nombre_echeances', tauxInteret: 'taux_interet',
    datePremierPaiement: 'date_premier_paiement', dateDebut: 'date_debut',
    dateFinPrevue: 'date_fin_prevue', statut: 'statut', notes: 'notes',
    pdfUrl: 'pdf_url', pdfHash: 'pdf_hash',
  };

  for (const [key, col] of Object.entries(mapping)) {
    if (data[key] !== undefined) {
      fields.push(`${col} = $${idx}`);
      values.push(data[key]);
      idx++;
    }
  }

  if (fields.length === 0) return getContrat(id);
  fields.push(`modifie_le = NOW()`);
  values.push(id);
  const { rows } = await pool.query(
    `UPDATE contrats SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
    values,
  );
  return rows.length > 0 ? mapContrat(rows[0]) : null;
}

function mapContrat(r: Record<string, unknown>): Contrat {
  return {
    id: r.id as string,
    numero: r.numero as string,
    chauffeurId: r.chauffeur_id as string,
    vehiculeId: r.vehicule_id as string,
    garantId: r.garant_id as string | null,
    prixAchat: parseFloat(r.prix_achat as string),
    apportInitial: parseFloat(r.apport_initial as string),
    montantFinanc: parseFloat(r.montant_financ as string),
    frequencePaiement: r.frequence_paiement as string,
    montantEcheance: parseFloat(r.montant_echeance as string),
    nombreEcheances: r.nombre_echeances ? parseInt(r.nombre_echeances as string, 10) : null,
    tauxInteret: parseFloat(r.taux_interet as string),
    datePremierPaiement: r.date_premier_paiement as string | null,
    dateSignature: r.date_signature as string | null,
    dateDebut: r.date_debut as string,
    dateFinPrevue: r.date_fin_prevue as string | null,
    dateFinReelle: r.date_fin_reelle as string | null,
    statut: r.statut as string,
    pdfUrl: r.pdf_url as string | null,
    pdfHash: r.pdf_hash as string | null,
    creePar: r.cree_par as string | null,
    creeLe: r.cree_le as string,
    modifieLe: r.modifie_le as string,
    notes: r.notes as string | null,
  };
}

// ─── Signatures ──────────────────────────────────────────────────────────────

export async function signerContrat(data: {
  contratId: string;
  signataireType: 'chauffeur' | 'garant' | 'admin';
  signataireId: string;
  signataireNom: string;
  signatureImageUrl?: string;
  ipAddress?: string;
  userAgent?: string;
}): Promise<SignatureContrat> {
  // Vérifier que le contrat existe et est signable
  const contrat = await getContrat(data.contratId);
  if (!contrat) throw new Error('Contrat introuvable');
  if (contrat.statut !== 'brouillon' && contrat.statut !== 'en_cours') {
    throw new Error(`Contrat non signable (statut: ${contrat.statut})`);
  }

  // Vérifier que ce signataire n'a pas déjà signé
  const { rows: existing } = await pool.query(`
    SELECT id FROM signatures_contrats
    WHERE contrat_id = $1 AND signataire_type = $2 AND statut = 'signe'
  `, [data.contratId, data.signataireType]);
  if (existing.length > 0) {
    throw new Error(`${data.signataireType} a déjà signé ce contrat`);
  }

  // Générer le hash de signature (intégrité)
  const timestamp = new Date().toISOString();
  const hashContent = `${data.contratId}|${data.signataireType}|${data.signataireId}|${timestamp}`;
  const signatureHash = crypto.createHash('sha256').update(hashContent).digest('hex');

  const { rows } = await pool.query(`
    INSERT INTO signatures_contrats (
      contrat_id, signataire_type, signataire_id, signataire_nom,
      signature_hash, signature_image_url, date_signature, ip_address, user_agent
    ) VALUES ($1,$2,$3,$4,$5,$6,NOW(),$7,$8)
    RETURNING *
  `, [
    data.contratId, data.signataireType, data.signataireId, data.signataireNom,
    signatureHash, data.signatureImageUrl ?? null,
    data.ipAddress ?? null, data.userAgent ?? null,
  ]);

  // Mettre à jour le statut du contrat
  await pool.query(
    `UPDATE contrats SET statut = 'en_cours', modifie_le = NOW() WHERE id = $1`,
    [data.contratId],
  );

  // Vérifier si toutes les signatures requises sont présentes
  await verifierSignaturesCompletes(data.contratId);

  logger.info('Contrat signé', {
    contratId: data.contratId,
    signataireType: data.signataireType,
    signataireNom: data.signataireNom,
  });

  await writeAuditLog(data.signataireId, 'SIGN_CONTRAT', data.contratId, {
    signataireType: data.signataireType,
    signatureHash,
  });

  return mapSignature(rows[0]);
}

async function verifierSignaturesCompletes(contratId: string): Promise<void> {
  const { rows: signatures } = await pool.query(`
    SELECT signataire_type FROM signatures_contrats
    WHERE contrat_id = $1 AND statut = 'signe'
  `, [contratId]);

  const typesSignes = signatures.map((s: Record<string, unknown>) => s.signataire_type);
  const contrat = await getContrat(contratId);
  if (!contrat) return;

  // Il faut au moins la signature du chauffeur
  const signaturesRequises = ['chauffeur'];
  if (contrat.garantId) signaturesRequises.push('garant');

  const toutesSignees = signaturesRequises.every(t => typesSignes.includes(t));
  if (toutesSignees) {
    await pool.query(`
      UPDATE contrats SET statut = 'signe', date_signature = CURRENT_DATE, modifie_le = NOW()
      WHERE id = $1
    `, [contratId]);
    logger.info('Contrat complètement signé', { contratId });
  }
}

export async function listerSignatures(contratId: string): Promise<SignatureContrat[]> {
  const { rows } = await pool.query(
    `SELECT * FROM signatures_contrats WHERE contrat_id = $1 ORDER BY date_signature`,
    [contratId],
  );
  return rows.map(mapSignature);
}

function mapSignature(r: Record<string, unknown>): SignatureContrat {
  return {
    id: r.id as string,
    contratId: r.contrat_id as string,
    signataireType: r.signataire_type as string,
    signataireId: r.signataire_id as string,
    signataireNom: r.signataire_nom as string,
    signatureHash: r.signature_hash as string,
    signatureImageUrl: r.signature_image_url as string | null,
    dateSignature: r.date_signature as string,
    ipAddress: r.ip_address as string | null,
    userAgent: r.user_agent as string | null,
    statut: r.statut as string,
    creeLe: r.cree_le as string,
  };
}

// ─── Génération contenu contrat ──────────────────────────────────────────────

export async function genererContenuContrat(contratId: string): Promise<Record<string, unknown>> {
  const data = await getContratComplet(contratId);
  if (!data) throw new Error('Contrat introuvable');

  const parametres = await listerParametres();
  const clauses: Record<string, string> = {};
  for (const p of parametres) {
    clauses[p.cle] = p.valeur;
  }

  const chauffeur = data.chauffeur as Record<string, unknown> | null;
  const vehicule = data.vehicule as Record<string, unknown> | null;
  const garant = data.garant as Garant | null;
  const contrat = data as unknown as Contrat;

  return {
    titre: clauses['titre_contrat'] ?? 'CONTRAT DE FINANCEMENT DE VÉHICULE',
    numero: contrat.numero,
    date: new Date().toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' }),
    lieu: 'Cotonou, Bénin',

    parties: {
      financeur: {
        raison_sociale: 'MotoProjet Bénin',
        adresse: 'Cotonou, Bénin',
        telephone: '+229 XX XX XX XX',
      },
      beneficiaire: {
        nom: chauffeur?.nom ?? '',
        date_naissance: chauffeur?.date_naissance ?? '',
        lieu_naissance: chauffeur?.lieu_naissance ?? '',
        nationalite: chauffeur?.nationalite ?? 'Béninoise',
        profession: chauffeur?.profession ?? '',
        telephone: chauffeur?.telephone ?? '',
        adresse: chauffeur?.adresse ?? '',
        piece_identite: chauffeur?.piece_identite ?? '',
        numero_cni: chauffeur?.numero_cni ?? '',
      },
      garant: garant ? {
        nom: garant.nom,
        prenom: garant.prenom ?? '',
        date_naissance: garant.dateNaissance ?? '',
        lieu_naissance: garant.lieuNaissance ?? '',
        nationalite: garant.nationalite,
        profession: garant.profession ?? '',
        telephone: garant.telephone,
        adresse: garant.adresse ?? '',
        piece_identite_type: garant.pieceIdentiteType ?? '',
        piece_identite_numero: garant.pieceIdentiteNumero ?? '',
        lien_parente: garant.lienParente ?? '',
        situation_financiere: garant.situationFinanciere ?? '',
        employeur: garant.employeur ?? '',
        revenu_mensuel: garant.revenuMensuel,
      } : null,
    },

    vehicule: {
      type: vehicule?.type ?? '',
      marque: vehicule?.marque ?? '',
      plaque: vehicule?.plaque ?? '',
      immatriculation: vehicule?.immatriculation ?? '',
      prix_achat: contrat.prixAchat,
    },

    conditions: {
      prix_achat: contrat.prixAchat,
      apport_initial: contrat.apportInitial,
      montant_financ: contrat.montantFinanc,
      frequence_paiement: contrat.frequencePaiement,
      montant_echeance: contrat.montantEcheance,
      nombre_echeances: contrat.nombreEcheances,
      taux_interet: contrat.tauxInteret,
      date_debut: contrat.dateDebut,
      date_fin_prevue: contrat.dateFinPrevue,
      date_premier_paiement: contrat.datePremierPaiement,
    },

    clauses: {
      objet: clauses['clause_objet'] ?? '',
      obligations_beneficiaire: clauses['clause_obligations_beneficiaire'] ?? '',
      obligations_financeur: clauses['clause_obligations_financeur'] ?? '',
      retard: clauses['clause_retard'] ?? '',
      resiliation: clauses['clause_resiliation'] ?? '',
      garant: clauses['clause_garant'] ?? '',
      juridiction: clauses['clause_juridiction'] ?? '',
    },

    signatures: data.signatures ?? [],
  };
}

// ─── Suppression ─────────────────────────────────────────────────────────────

export async function supprimerContrat(id: string): Promise<boolean> {
  const contrat = await getContrat(id);
  if (!contrat) return false;
  if (contrat.statut === 'signe') {
    throw new Error('Impossible de supprimer un contrat signé');
  }
  await pool.query(`DELETE FROM contrats WHERE id = $1`, [id]);
  return true;
}
