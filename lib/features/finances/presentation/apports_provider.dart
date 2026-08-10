import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

enum FrequenceApport {
  hebdomadaire,
  mensuel,
  trimestriel;

  String get label {
    switch (this) {
      case FrequenceApport.hebdomadaire:
        return 'Hebdomadaire';
      case FrequenceApport.mensuel:
        return 'Mensuel';
      case FrequenceApport.trimestriel:
        return 'Trimestriel';
    }
  }

  String get apiValue {
    switch (this) {
      case FrequenceApport.hebdomadaire:
        return 'hebdomadaire';
      case FrequenceApport.mensuel:
        return 'mensuel';
      case FrequenceApport.trimestriel:
        return 'trimestriel';
    }
  }

  static FrequenceApport fromString(String value) {
    switch (value) {
      case 'hebdomadaire':
        return FrequenceApport.hebdomadaire;
      case 'mensuel':
        return FrequenceApport.mensuel;
      case 'trimestriel':
        return FrequenceApport.trimestriel;
      default:
        return FrequenceApport.mensuel;
    }
  }
}

enum ObjectifApport {
  moto,
  voiture;

  String get label {
    switch (this) {
      case ObjectifApport.moto:
        return 'Moto';
      case ObjectifApport.voiture:
        return 'Voiture';
    }
  }

  static ObjectifApport fromString(String value) {
    switch (value) {
      case 'voiture':
        return ObjectifApport.voiture;
      default:
        return ObjectifApport.moto;
    }
  }
}

class ApportPersonnel {
  final String id;
  final String libelle;
  final int montant;
  final FrequenceApport frequence;
  final int? jourPrealable;
  final bool actif;
  final String dateDebut;
  final String? dateFin;
  final ObjectifApport objectif;
  final String? note;

  const ApportPersonnel({
    required this.id,
    required this.libelle,
    required this.montant,
    required this.frequence,
    this.jourPrealable,
    required this.actif,
    required this.dateDebut,
    this.dateFin,
    required this.objectif,
    this.note,
  });

  factory ApportPersonnel.fromJson(Map<String, dynamic> j) => ApportPersonnel(
    id: j['id'] as String,
    libelle: j['libelle'] as String,
    montant: j['montant'] as int? ?? 0,
    frequence: FrequenceApport.fromString(j['frequence'] as String),
    jourPrealable: j['jourPrealable'] as int?,
    actif: j['actif'] as bool? ?? true,
    dateDebut: j['dateDebut'] as String,
    dateFin: j['dateFin'] as String?,
    objectif: ObjectifApport.fromString(j['objectif'] as String? ?? 'moto'),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'libelle': libelle,
    'montant': montant,
    'frequence': frequence.apiValue,
    'jourPrealable': jourPrealable,
    'dateDebut': dateDebut,
    'dateFin': dateFin,
    'objectif': objectif.name,
    'note': note,
  };
}

class ApportVersement {
  final String id;
  final String apportId;
  final String dateVersement;
  final int montant;
  final String? note;
  final bool valide;
  final String? mode;
  final String? telephone;
  final String? statutPaiement;
  final String? kkiapayTransactionId;

  const ApportVersement({
    required this.id,
    required this.apportId,
    required this.dateVersement,
    required this.montant,
    this.note,
    required this.valide,
    this.mode,
    this.telephone,
    this.statutPaiement,
    this.kkiapayTransactionId,
  });

  factory ApportVersement.fromJson(Map<String, dynamic> j) => ApportVersement(
    id: j['id'] as String,
    apportId: j['apportId'] as String? ?? j['apport_id'] as String,
    dateVersement: j['dateVersement'] as String? ?? j['date_versement'] as String,
    montant: j['montant'] as int? ?? 0,
    note: j['note'] as String?,
    valide: j['valide'] as bool? ?? true,
    mode: j['mode'] as String?,
    telephone: j['telephone'] as String?,
    statutPaiement: j['statutPaiement'] as String? ?? j['statut_paiement'] as String?,
    kkiapayTransactionId: j['kkiapayTransactionId'] as String? ?? j['kkiapay_transaction_id'] as String?,
  );
}

// ─── État ────────────────────────────────────────────────────────────────────

/// Statut d'un paiement KKiaPay
enum StatutPaiementKKiaPay {
  idle,
  initiating,
  pending,
  confirmed,
  failed,
  expired;

  String get label {
    switch (this) {
      case StatutPaiementKKiaPay.idle:
        return '';
      case StatutPaiementKKiaPay.initiating:
        return 'Initiation...';
      case StatutPaiementKKiaPay.pending:
        return 'En attente de confirmation';
      case StatutPaiementKKiaPay.confirmed:
        return 'Paiement confirmé';
      case StatutPaiementKKiaPay.failed:
        return 'Paiement échoué';
      case StatutPaiementKKiaPay.expired:
        return 'Paiement expiré';
    }
  }

  bool get isTerminal => this == confirmed || this == failed || this == expired;
}

/// Résultat d'une transaction KKiaPay
class TransactionKKiaPay {
  final String transactionId;
  final String statut;
  final String? urlPaiement;
  final String message;

  const TransactionKKiaPay({
    required this.transactionId,
    required this.statut,
    this.urlPaiement,
    required this.message,
  });

  factory TransactionKKiaPay.fromJson(Map<String, dynamic> j) => TransactionKKiaPay(
    transactionId: j['transaction_id'] as String,
    statut: j['statut'] as String,
    urlPaiement: j['url_paiement'] as String?,
    message: j['message'] as String? ?? '',
  );
}

class ApportsState {
  final List<ApportPersonnel> apports;
  final List<ApportVersement> versements;
  final bool isLoading;
  final String? error;
  final StatutPaiementKKiaPay statutPaiement;
  final TransactionKKiaPay? transactionEnCours;

  const ApportsState({
    this.apports = const [],
    this.versements = const [],
    this.isLoading = false,
    this.error,
    this.statutPaiement = StatutPaiementKKiaPay.idle,
    this.transactionEnCours,
  });

  ApportsState copyWith({
    List<ApportPersonnel>? apports,
    List<ApportVersement>? versements,
    bool? isLoading,
    String? error,
    bool clearError = false,
    StatutPaiementKKiaPay? statutPaiement,
    TransactionKKiaPay? transactionEnCours,
    bool clearTransaction = false,
  }) => ApportsState(
    apports: apports ?? this.apports,
    versements: versements ?? this.versements,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    statutPaiement: statutPaiement ?? this.statutPaiement,
    transactionEnCours: clearTransaction ? null : (transactionEnCours ?? this.transactionEnCours),
  );

  /// Total mensuel des apports actifs pour un objectif
  int totalMensuelPour(ObjectifApport objectif) {
    int total = 0;
    for (final a in apports.where((a) => a.actif && a.objectif == objectif)) {
      switch (a.frequence) {
        case FrequenceApport.hebdomadaire:
          total += a.montant * 4; // ~4 semaines par mois
          break;
        case FrequenceApport.mensuel:
          total += a.montant;
          break;
        case FrequenceApport.trimestriel:
          total += a.montant ~/ 3; // ~1/3 par mois
          break;
      }
    }
    return total;
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ApportsNotifier extends StateNotifier<ApportsState> {
  final Ref _ref;
  ApportsNotifier(this._ref) : super(const ApportsState());

  Future<void> chargerApports({bool actifsOnly = true}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).get(
        '/finances/apports',
        queryParameters: {'actifs': actifsOnly.toString()},
      );
      final apports = (response.data['data'] as List)
          .map((e) => ApportPersonnel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(apports: apports, isLoading: false);
    } catch (e) {
      AppLogger.e('[Apports] Erreur chargement: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> creerApport({
    required String libelle,
    required int montant,
    required FrequenceApport frequence,
    int? jourPrealable,
    required String dateDebut,
    String? dateFin,
    required ObjectifApport objectif,
    String? note,
  }) async {
    try {
      await _ref.read(apiClientProvider).post('/finances/apports', data: {
        'libelle': libelle,
        'montant': montant,
        'frequence': frequence.apiValue,
        'jourPrealable': jourPrealable,
        'dateDebut': dateDebut,
        'dateFin': dateFin,
        'objectif': objectif.name,
        'note': note,
      });
      await chargerApports();
    } catch (e) {
      AppLogger.e('[Apports] Erreur création: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateApport(String id, Map<String, dynamic> updates) async {
    try {
      await _ref.read(apiClientProvider).put('/finances/apports/$id', data: updates);
      await chargerApports();
    } catch (e) {
      AppLogger.e('[Apports] Erreur update: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> supprimerApport(String id) async {
    try {
      await _ref.read(apiClientProvider).delete('/finances/apports/$id');
      await chargerApports();
    } catch (e) {
      AppLogger.e('[Apports] Erreur suppression: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Initie un versement via KKiaPay (mobile money)
  Future<TransactionKKiaPay?> initierVersementKKiaPay({
    required String apportId,
    required String dateVersement,
    required int montant,
    required String telephone,
    String? note,
  }) async {
    state = state.copyWith(
      statutPaiement: StatutPaiementKKiaPay.initiating,
      clearError: true,
      clearTransaction: true,
    );
    try {
      final response = await _ref.read(apiClientProvider).post(
        '/finances/apports/$apportId/versement',
        data: {
          'dateVersement': dateVersement,
          'montant': montant,
          'telephone': telephone,
          'note': note,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final transaction = TransactionKKiaPay.fromJson(data);
      state = state.copyWith(
        statutPaiement: StatutPaiementKKiaPay.pending,
        transactionEnCours: transaction,
      );
      AppLogger.i('[KKiaPay] Transaction initiée: ${transaction.transactionId}');
      return transaction;
    } catch (e) {
      AppLogger.e('[KKiaPay] Erreur initiation: $e');
      state = state.copyWith(
        statutPaiement: StatutPaiementKKiaPay.failed,
        error: 'Impossible d\'initier le paiement : $e',
      );
      return null;
    }
  }

  /// Vérifie le statut d'une transaction KKiaPay (polling)
  Future<StatutPaiementKKiaPay> verifierStatutTransaction(String transactionId) async {
    try {
      final response = await _ref.read(apiClientProvider).get(
        '/kkiapay/transaction/$transactionId/statut',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final statut = data['statut'] as String;

      StatutPaiementKKiaPay nouveauStatut;
      switch (statut) {
        case 'confirmed':
          nouveauStatut = StatutPaiementKKiaPay.confirmed;
        case 'failed':
          nouveauStatut = StatutPaiementKKiaPay.failed;
        case 'expired':
          nouveauStatut = StatutPaiementKKiaPay.expired;
        default:
          nouveauStatut = StatutPaiementKKiaPay.pending;
      }

      state = state.copyWith(statutPaiement: nouveauStatut);
      return nouveauStatut;
    } catch (e) {
      AppLogger.e('[KKiaPay] Erreur vérification statut: $e');
      return StatutPaiementKKiaPay.pending;
    }
  }

  /// Polling automatique jusqu'à confirmation ou expiration
  Future<void> attendreConfirmation(String transactionId, {int maxTentatives = 20, int intervalSecondes = 5}) async {
    for (int i = 0; i < maxTentatives; i++) {
      await Future.delayed(Duration(seconds: intervalSecondes));
      final statut = await verifierStatutTransaction(transactionId);
      if (statut.isTerminal) {
        if (statut == StatutPaiementKKiaPay.confirmed) {
          await chargerVersements();
        }
        return;
      }
    }
    // Timeout
    state = state.copyWith(statutPaiement: StatutPaiementKKiaPay.expired);
  }

  /// Réinitialise le statut de paiement
  void reinitialiserStatutPaiement() {
    state = state.copyWith(
      statutPaiement: StatutPaiementKKiaPay.idle,
      clearTransaction: true,
    );
  }

  Future<void> chargerVersements({String? apportId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apportId != null) queryParams['apportId'] = apportId;
      final response = await _ref.read(apiClientProvider).get(
        '/finances/apports/versements',
        queryParameters: queryParams,
      );
      final versements = (response.data['data'] as List)
          .map((e) => ApportVersement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(versements: versements);
    } catch (e) {
      AppLogger.e('[Apports] Erreur versements: $e');
    }
  }
}

final apportsProvider = StateNotifierProvider<ApportsNotifier, ApportsState>((ref) {
  return ApportsNotifier(ref);
});
