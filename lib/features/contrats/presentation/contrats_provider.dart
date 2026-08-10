import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class Garant {
  final String id;
  final String nom;
  final String? prenom;
  final String? dateNaissance;
  final String? lieuNaissance;
  final String nationalite;
  final String? profession;
  final String telephone;
  final String? email;
  final String? adresse;
  final String? pieceIdentiteType;
  final String? pieceIdentiteNumero;
  final String? pieceIdentiteDelivreeLe;
  final String? pieceIdentiteLieu;
  final String? lienParente;
  final String? situationFinanciere;
  final String? employeur;
  final int? revenuMensuel;
  final String? photoUrl;
  final bool actif;

  const Garant({
    required this.id,
    required this.nom,
    this.prenom,
    this.dateNaissance,
    this.lieuNaissance,
    this.nationalite = 'Béninoise',
    this.profession,
    required this.telephone,
    this.email,
    this.adresse,
    this.pieceIdentiteType,
    this.pieceIdentiteNumero,
    this.pieceIdentiteDelivreeLe,
    this.pieceIdentiteLieu,
    this.lienParente,
    this.situationFinanciere,
    this.employeur,
    this.revenuMensuel,
    this.photoUrl,
    this.actif = true,
  });

  factory Garant.fromJson(Map<String, dynamic> j) => Garant(
    id: j['id'] as String,
    nom: j['nom'] as String,
    prenom: j['prenom'] as String?,
    dateNaissance: j['date_naissance'] as String?,
    lieuNaissance: j['lieu_naissance'] as String?,
    nationalite: j['nationalite'] as String? ?? 'Béninoise',
    profession: j['profession'] as String?,
    telephone: j['telephone'] as String,
    email: j['email'] as String?,
    adresse: j['adresse'] as String?,
    pieceIdentiteType: j['piece_identite_type'] as String?,
    pieceIdentiteNumero: j['piece_identite_numero'] as String?,
    pieceIdentiteDelivreeLe: j['piece_identite_delivree_le'] as String?,
    pieceIdentiteLieu: j['piece_identite_lieu'] as String?,
    lienParente: j['lien_parente'] as String?,
    situationFinanciere: j['situation_financiere'] as String?,
    employeur: j['employeur'] as String?,
    revenuMensuel: j['revenu_mensuel'] as int?,
    photoUrl: j['photo_url'] as String?,
    actif: j['actif'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'prenom': prenom,
    'dateNaissance': dateNaissance,
    'lieuNaissance': lieuNaissance,
    'nationalite': nationalite,
    'profession': profession,
    'telephone': telephone,
    'email': email,
    'adresse': adresse,
    'pieceIdentiteType': pieceIdentiteType,
    'pieceIdentiteNumero': pieceIdentiteNumero,
    'pieceIdentiteDelivreeLe': pieceIdentiteDelivreeLe,
    'pieceIdentiteLieu': pieceIdentiteLieu,
    'lienParente': lienParente,
    'situationFinanciere': situationFinanciere,
    'employeur': employeur,
    'revenuMensuel': revenuMensuel,
    'photoUrl': photoUrl,
  };

  String get nomComplet => [prenom, nom].where((s) => s != null && s.isNotEmpty).join(' ');
}

enum StatutContrat {
  brouillon,
  enCours,
  signe,
  resilie,
  termine;

  String get label {
    switch (this) {
      case StatutContrat.brouillon: return 'Brouillon';
      case StatutContrat.enCours: return 'En cours de signature';
      case StatutContrat.signe: return 'Signé';
      case StatutContrat.resilie: return 'Résilé';
      case StatutContrat.termine: return 'Terminé';
    }
  }

  static StatutContrat fromString(String s) {
    switch (s) {
      case 'en_cours': return StatutContrat.enCours;
      case 'signe': return StatutContrat.signe;
      case 'resilie': return StatutContrat.resilie;
      case 'termine': return StatutContrat.termine;
      default: return StatutContrat.brouillon;
    }
  }
}

enum FrequencePaiement {
  journalier,
  hebdomadaire,
  mensuel;

  String get label {
    switch (this) {
      case FrequencePaiement.journalier: return 'Journalier';
      case FrequencePaiement.hebdomadaire: return 'Hebdomadaire';
      case FrequencePaiement.mensuel: return 'Mensuel';
    }
  }

  static FrequencePaiement fromString(String s) {
    switch (s) {
      case 'hebdomadaire': return FrequencePaiement.hebdomadaire;
      case 'mensuel': return FrequencePaiement.mensuel;
      default: return FrequencePaiement.journalier;
    }
  }
}

class SignatureContrat {
  final String id;
  final String signataireType;
  final String signataireNom;
  final String dateSignature;
  final String signatureHash;
  final String? signatureImageUrl;
  final String statut;

  const SignatureContrat({
    required this.id,
    required this.signataireType,
    required this.signataireNom,
    required this.dateSignature,
    required this.signatureHash,
    this.signatureImageUrl,
    required this.statut,
  });

  factory SignatureContrat.fromJson(Map<String, dynamic> j) => SignatureContrat(
    id: j['id'] as String,
    signataireType: j['signataire_type'] as String,
    signataireNom: j['signataire_nom'] as String,
    dateSignature: j['date_signature'] as String,
    signatureHash: j['signature_hash'] as String,
    signatureImageUrl: j['signature_image_url'] as String?,
    statut: j['statut'] as String? ?? 'signe',
  );
}

class Contrat {
  final String id;
  final String numero;
  final String chauffeurId;
  final String vehiculeId;
  final String? garantId;
  final int prixAchat;
  final int apportInitial;
  final int montantFinanc;
  final FrequencePaiement frequencePaiement;
  final int montantEcheance;
  final int? nombreEcheances;
  final double tauxInteret;
  final String? datePremierPaiement;
  final String? dateSignature;
  final String dateDebut;
  final String? dateFinPrevue;
  final StatutContrat statut;
  final String? pdfUrl;
  final String? notes;
  final String creeLe;

  // Données complètes (optionnelles, chargées séparément)
  final Map<String, dynamic>? chauffeur;
  final Map<String, dynamic>? vehicule;
  final Garant? garant;
  final List<SignatureContrat> signatures;
  final int? totalVerse;
  final int? nbPaiements;

  const Contrat({
    required this.id,
    required this.numero,
    required this.chauffeurId,
    required this.vehiculeId,
    this.garantId,
    required this.prixAchat,
    required this.apportInitial,
    required this.montantFinanc,
    required this.frequencePaiement,
    required this.montantEcheance,
    this.nombreEcheances,
    required this.tauxInteret,
    this.datePremierPaiement,
    this.dateSignature,
    required this.dateDebut,
    this.dateFinPrevue,
    required this.statut,
    this.pdfUrl,
    this.notes,
    required this.creeLe,
    this.chauffeur,
    this.vehicule,
    this.garant,
    this.signatures = const [],
    this.totalVerse,
    this.nbPaiements,
  });

  factory Contrat.fromJson(Map<String, dynamic> j) => Contrat(
    id: j['id'] as String,
    numero: j['numero'] as String,
    chauffeurId: j['chauffeur_id'] as String,
    vehiculeId: j['vehicule_id'] as String,
    garantId: j['garant_id'] as String?,
    prixAchat: (j['prix_achat'] as num?)?.toInt() ?? 0,
    apportInitial: (j['apport_initial'] as num?)?.toInt() ?? 0,
    montantFinanc: (j['montant_financ'] as num?)?.toInt() ?? 0,
    frequencePaiement: FrequencePaiement.fromString(j['frequence_paiement'] as String? ?? 'journalier'),
    montantEcheance: (j['montant_echeance'] as num?)?.toInt() ?? 0,
    nombreEcheances: j['nombre_echeances'] as int?,
    tauxInteret: (j['taux_interet'] as num?)?.toDouble() ?? 0,
    datePremierPaiement: j['date_premier_paiement'] as String?,
    dateSignature: j['date_signature'] as String?,
    dateDebut: j['date_debut'] as String,
    dateFinPrevue: j['date_fin_prevue'] as String?,
    statut: StatutContrat.fromString(j['statut'] as String? ?? 'brouillon'),
    pdfUrl: j['pdf_url'] as String?,
    notes: j['notes'] as String?,
    creeLe: j['cree_le'] as String? ?? '',
    chauffeur: j['chauffeur'] as Map<String, dynamic>?,
    vehicule: j['vehicule'] as Map<String, dynamic>?,
    garant: j['garant'] != null ? Garant.fromJson(j['garant'] as Map<String, dynamic>) : null,
    signatures: (j['signatures'] as List?)
        ?.map((s) => SignatureContrat.fromJson(s as Map<String, dynamic>))
        .toList() ?? const [],
    totalVerse: (j['stats'] as Map<String, dynamic>?)?['total_verse'] != null
        ? ((j['stats'] as Map<String, dynamic>)['total_verse'] as num).toInt()
        : null,
    nbPaiements: (j['stats'] as Map<String, dynamic>?)?['nb_paiements'] != null
        ? ((j['stats'] as Map<String, dynamic>)['nb_paiements'] as num).toInt()
        : null,
  );

  bool get isSigne => statut == StatutContrat.signe;
  bool get isComplet => signatures.any((s) => s.signataireType == 'chauffeur') &&
      (garantId == null || signatures.any((s) => s.signataireType == 'garant'));
}

// ─── État ────────────────────────────────────────────────────────────────────

class ContratsState {
  final List<Contrat> contrats;
  final List<Garant> garants;
  final List<Map<String, String>> parametres;
  final bool isLoading;
  final String? error;
  final Contrat? contratSelectionne;

  const ContratsState({
    this.contrats = const [],
    this.garants = const [],
    this.parametres = const [],
    this.isLoading = false,
    this.error,
    this.contratSelectionne,
  });

  ContratsState copyWith({
    List<Contrat>? contrats,
    List<Garant>? garants,
    List<Map<String, String>>? parametres,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Contrat? contratSelectionne,
    bool clearContrat = false,
  }) => ContratsState(
    contrats: contrats ?? this.contrats,
    garants: garants ?? this.garants,
    parametres: parametres ?? this.parametres,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    contratSelectionne: clearContrat ? null : (contratSelectionne ?? this.contratSelectionne),
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ContratsNotifier extends StateNotifier<ContratsState> {
  final Ref _ref;
  ContratsNotifier(this._ref) : super(const ContratsState());

  Future<void> chargerContrats({String? statut}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final params = <String, dynamic>{};
      if (statut != null) params['statut'] = statut;
      final response = await _ref.read(apiClientProvider).get('/contrats', queryParameters: params);
      final contrats = (response.data['data'] as List)
          .map((e) => Contrat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(contrats: contrats, isLoading: false);
    } catch (e) {
      AppLogger.e('[Contrats] Erreur chargement: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> chargerContrat(String id) async {
    try {
      final response = await _ref.read(apiClientProvider).get('/contrats/$id');
      final contrat = Contrat.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(contratSelectionne: contrat);
    } catch (e) {
      AppLogger.e('[Contrats] Erreur chargement détail: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Contrat?> creerContrat(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).post('/contrats', data: data);
      final contrat = Contrat.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      await chargerContrats();
      state = state.copyWith(isLoading: false);
      return contrat;
    } catch (e) {
      AppLogger.e('[Contrats] Erreur création: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> updateContrat(String id, Map<String, dynamic> data) async {
    try {
      await _ref.read(apiClientProvider).put('/contrats/$id', data: data);
      await chargerContrats();
    } catch (e) {
      AppLogger.e('[Contrats] Erreur update: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> supprimerContrat(String id) async {
    try {
      await _ref.read(apiClientProvider).delete('/contrats/$id');
      await chargerContrats();
    } catch (e) {
      AppLogger.e('[Contrats] Erreur suppression: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> signerContrat({
    required String contratId,
    required String signataireType,
    required String signataireNom,
    String? signatureImageUrl,
  }) async {
    try {
      await _ref.read(apiClientProvider).post('/contrats/$contratId/signer', data: {
        'signataireType': signataireType,
        'signataireNom': signataireNom,
        'signatureImageUrl': signatureImageUrl,
      });
      await chargerContrat(contratId);
      await chargerContrats();
      return true;
    } catch (e) {
      AppLogger.e('[Contrats] Erreur signature: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> getContenuContrat(String id) async {
    try {
      final response = await _ref.read(apiClientProvider).get('/contrats/$id/contenu');
      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('[Contrats] Erreur contenu: $e');
      return null;
    }
  }

  // ─── Garants ─────────────────────────────────────────────────────────────

  Future<void> chargerGarants() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/contrats/garants');
      final garants = (response.data['data'] as List)
          .map((e) => Garant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(garants: garants);
    } catch (e) {
      AppLogger.e('[Contrats] Erreur chargement garants: $e');
    }
  }

  Future<Garant?> creerGarant(Map<String, dynamic> data) async {
    try {
      final response = await _ref.read(apiClientProvider).post('/contrats/garants', data: data);
      final garant = Garant.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      await chargerGarants();
      return garant;
    } catch (e) {
      AppLogger.e('[Contrats] Erreur création garant: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateGarant(String id, Map<String, dynamic> data) async {
    try {
      await _ref.read(apiClientProvider).put('/contrats/garants/$id', data: data);
      await chargerGarants();
    } catch (e) {
      AppLogger.e('[Contrats] Erreur update garant: $e');
    }
  }

  // ─── Paramètres ──────────────────────────────────────────────────────────

  Future<void> chargerParametres() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/contrats/parametres');
      final parametres = (response.data['data'] as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      state = state.copyWith(parametres: parametres);
    } catch (e) {
      AppLogger.e('[Contrats] Erreur chargement paramètres: $e');
    }
  }

  Future<void> updateParametre(String cle, String valeur) async {
    try {
      await _ref.read(apiClientProvider).put('/contrats/parametres/$cle', data: {'valeur': valeur});
      await chargerParametres();
    } catch (e) {
      AppLogger.e('[Contrats] Erreur update paramètre: $e');
    }
  }
}

final contratsProvider = StateNotifierProvider<ContratsNotifier, ContratsState>((ref) {
  return ContratsNotifier(ref);
});
