import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class ParametrePenalite {
  final String id;
  final String typeVehicule;
  final String typeCalcul;
  final double montantFixe;
  final double pourcentage;
  final int seuilJours;
  final double? plafond;
  final bool actif;

  ParametrePenalite({
    required this.id,
    required this.typeVehicule,
    required this.typeCalcul,
    required this.montantFixe,
    required this.pourcentage,
    required this.seuilJours,
    this.plafond,
    required this.actif,
  });

  factory ParametrePenalite.fromJson(Map<String, dynamic> json) {
    return ParametrePenalite(
      id: json['id'] as String,
      typeVehicule: json['type_vehicule'] as String,
      typeCalcul: json['type_calcul'] as String,
      montantFixe: (json['montant_fixe'] as num?)?.toDouble() ?? 0,
      pourcentage: (json['pourcentage'] as num?)?.toDouble() ?? 0,
      seuilJours: (json['seuil_jours'] as num?)?.toInt() ?? 1,
      plafond: json['plafond'] != null ? (json['plafond'] as num).toDouble() : null,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'type_calcul': typeCalcul,
    'montant_fixe': montantFixe,
    'pourcentage': pourcentage,
    'seuil_jours': seuilJours,
    'plafond': plafond,
    'actif': actif,
  };
}

class Penalite {
  final String id;
  final String vehiculeId;
  final String chauffeurId;
  final String datePenalite;
  final double montant;
  final String motif;
  final String statut;
  final String? immatriculation;
  final String? chauffeurNom;
  final DateTime? payeLe;
  final String? motifAnnulation;

  Penalite({
    required this.id,
    required this.vehiculeId,
    required this.chauffeurId,
    required this.datePenalite,
    required this.montant,
    required this.motif,
    required this.statut,
    this.immatriculation,
    this.chauffeurNom,
    this.payeLe,
    this.motifAnnulation,
  });

  factory Penalite.fromJson(Map<String, dynamic> json) {
    return Penalite(
      id: json['id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      chauffeurId: json['chauffeur_id'] as String,
      datePenalite: json['date_penalite'] as String,
      montant: (json['montant'] as num).toDouble(),
      motif: json['motif'] as String? ?? 'Retard de paiement',
      statut: json['statut'] as String,
      immatriculation: json['immatriculation'] as String?,
      chauffeurNom: json['chauffeur_nom'] as String?,
      payeLe: json['paye_le'] != null ? DateTime.parse(json['paye_le'] as String) : null,
      motifAnnulation: json['motif_annulation'] as String?,
    );
  }
}

class TotalPenalites {
  final double totalActif;
  final double totalPaye;
  final double totalAnnule;

  TotalPenalites({
    required this.totalActif,
    required this.totalPaye,
    required this.totalAnnule,
  });

  factory TotalPenalites.fromJson(Map<String, dynamic> json) {
    return TotalPenalites(
      totalActif: (json['total_actif'] as num?)?.toDouble() ?? 0,
      totalPaye: (json['total_paye'] as num?)?.toDouble() ?? 0,
      totalAnnule: (json['total_annule'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExemptionPenalite {
  final String id;
  final String? vehiculeId;
  final String? chauffeurId;
  final String? immatriculation;
  final String? chauffeurNom;
  final String motif;
  final String dateDebut;
  final String? dateFin;
  final bool actif;

  ExemptionPenalite({
    required this.id,
    this.vehiculeId,
    this.chauffeurId,
    this.immatriculation,
    this.chauffeurNom,
    required this.motif,
    required this.dateDebut,
    this.dateFin,
    required this.actif,
  });

  factory ExemptionPenalite.fromJson(Map<String, dynamic> json) {
    return ExemptionPenalite(
      id: json['id'] as String,
      vehiculeId: json['vehicule_id'] as String?,
      chauffeurId: json['chauffeur_id'] as String?,
      immatriculation: json['immatriculation'] as String?,
      chauffeurNom: json['chauffeur_nom'] as String?,
      motif: json['motif'] as String,
      dateDebut: json['date_debut'] as String,
      dateFin: json['date_fin'] as String?,
      actif: json['actif'] as bool? ?? true,
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

class PenalitesState {
  final List<ParametrePenalite> parametres;
  final List<Penalite> penalites;
  final List<ExemptionPenalite> exemptions;
  final Map<String, TotalPenalites> totauxParVehicule;
  final bool isLoading;
  final String? error;

  PenalitesState({
    this.parametres = const [],
    this.penalites = const [],
    this.exemptions = const [],
    this.totauxParVehicule = const {},
    this.isLoading = false,
    this.error,
  });

  PenalitesState copyWith({
    List<ParametrePenalite>? parametres,
    List<Penalite>? penalites,
    List<ExemptionPenalite>? exemptions,
    Map<String, TotalPenalites>? totauxParVehicule,
    bool? isLoading,
    String? error,
  }) {
    return PenalitesState(
      parametres: parametres ?? this.parametres,
      penalites: penalites ?? this.penalites,
      exemptions: exemptions ?? this.exemptions,
      totauxParVehicule: totauxParVehicule ?? this.totauxParVehicule,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PenalitesNotifier extends StateNotifier<PenalitesState> {
  PenalitesNotifier(this._ref) : super(PenalitesState());

  final Ref _ref;

  Future<void> chargerParametres() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _ref.read(apiClientProvider).get('/penalites/parametres');
      final data = response.data as Map<String, dynamic>;
      final list = (data['parametres'] as List)
          .map((e) => ParametrePenalite.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(parametres: list, isLoading: false);
    } catch (e) {
      AppLogger.e('Erreur chargement paramètres pénalités', error: e);
      state = state.copyWith(isLoading: false, error: 'Erreur chargement paramètres');
    }
  }

  Future<bool> updateParametre(String typeVehicule, ParametrePenalite parametre) async {
    try {
      await _ref.read(apiClientProvider).put(
        '/penalites/parametres/$typeVehicule',
        data: parametre.toJson(),
      );
      await chargerParametres();
      return true;
    } catch (e) {
      AppLogger.e('Erreur update paramètre pénalité', error: e);
      return false;
    }
  }

  Future<void> chargerPenalites({String? vehiculeId, String? chauffeurId, String? statut}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final queryParams = <String, dynamic>{};
      if (vehiculeId != null) queryParams['vehicule_id'] = vehiculeId;
      if (chauffeurId != null) queryParams['chauffeur_id'] = chauffeurId;
      if (statut != null) queryParams['statut'] = statut;

      final response = await _ref.read(apiClientProvider).get(
        '/penalites',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['penalites'] as List)
          .map((e) => Penalite.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(penalites: list, isLoading: false);
    } catch (e) {
      AppLogger.e('Erreur chargement pénalités', error: e);
      state = state.copyWith(isLoading: false, error: 'Erreur chargement pénalités');
    }
  }

  Future<TotalPenalites?> chargerTotalVehicule(String vehiculeId) async {
    try {
      final response = await _ref.read(apiClientProvider).get('/penalites/$vehiculeId/total');
      final data = response.data as Map<String, dynamic>;
      final total = TotalPenalites.fromJson(data);
      final newTotaux = Map<String, TotalPenalites>.from(state.totauxParVehicule);
      newTotaux[vehiculeId] = total;
      state = state.copyWith(totauxParVehicule: newTotaux);
      return total;
    } catch (e) {
      AppLogger.e('Erreur chargement total pénalités', error: e);
      return null;
    }
  }

  Future<bool> annulerPenalite(String penaliteId, String motif) async {
    try {
      await _ref.read(apiClientProvider).post(
        '/penalites/$penaliteId/annuler',
        data: {'motif': motif},
      );
      await chargerPenalites();
      return true;
    } catch (e) {
      AppLogger.e('Erreur annulation pénalité', error: e);
      return false;
    }
  }

  Future<void> chargerExemptions() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/penalites/exemptions');
      final data = response.data as Map<String, dynamic>;
      final list = (data['exemptions'] as List)
          .map((e) => ExemptionPenalite.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(exemptions: list);
    } catch (e) {
      AppLogger.e('Erreur chargement exemptions', error: e);
    }
  }

  Future<bool> ajouterExemption({
    String? vehiculeId,
    String? chauffeurId,
    required String motif,
    required String dateDebut,
    String? dateFin,
  }) async {
    try {
      await _ref.read(apiClientProvider).post(
        '/penalites/exemptions',
        data: {
          'vehicule_id': vehiculeId,
          'chauffeur_id': chauffeurId,
          'motif': motif,
          'date_debut': dateDebut,
          'date_fin': dateFin,
        },
      );
      await chargerExemptions();
      return true;
    } catch (e) {
      AppLogger.e('Erreur ajout exemption', error: e);
      return false;
    }
  }

  Future<bool> supprimerExemption(String exemptionId) async {
    try {
      await _ref.read(apiClientProvider).delete('/penalites/exemptions/$exemptionId');
      await chargerExemptions();
      return true;
    } catch (e) {
      AppLogger.e('Erreur suppression exemption', error: e);
      return false;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final penalitesProvider = StateNotifierProvider<PenalitesNotifier, PenalitesState>((ref) {
  return PenalitesNotifier(ref);
});
