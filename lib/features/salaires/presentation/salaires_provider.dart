import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class Salaire {
  final String id;
  final String profil; // 'proprietaire' | 'employe'
  final String mois; // 'YYYY-MM'
  final double montant;
  final double revenuEncaisse;
  final int vehiculesActifs;
  final double pctApplique;
  final String statut; // 'calcule' | 'valide' | 'verse' | 'annule'
  final DateTime? dateVersement;
  final String? note;

  const Salaire({
    required this.id,
    required this.profil,
    required this.mois,
    required this.montant,
    this.revenuEncaisse = 0,
    this.vehiculesActifs = 0,
    this.pctApplique = 0,
    required this.statut,
    this.dateVersement,
    this.note,
  });

  factory Salaire.fromJson(Map<String, dynamic> json) {
    return Salaire(
      id: json['id'] as String,
      profil: json['profil'] as String,
      mois: json['mois'] as String,
      montant: double.tryParse(json['montant']?.toString() ?? '0') ?? 0,
      revenuEncaisse: double.tryParse(json['revenu_encaisse']?.toString() ?? '0') ?? 0,
      vehiculesActifs: json['vehicules_actifs'] as int? ?? 0,
      pctApplique: double.tryParse(json['pct_applique']?.toString() ?? '0') ?? 0,
      statut: json['statut'] as String? ?? 'calcule',
      dateVersement: json['date_versement'] != null
          ? DateTime.tryParse(json['date_versement'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  String get labelStatut {
    switch (statut) {
      case 'calcule': return 'Calculé';
      case 'valide': return 'Validé';
      case 'verse': return 'Versé';
      case 'annule': return 'Annulé';
      default: return statut;
    }
  }
}

class ParametresSalaire {
  final double pctProprietaire;
  final double pctEmploye;
  final int seuilVehicules;
  final bool actif;

  const ParametresSalaire({
    required this.pctProprietaire,
    required this.pctEmploye,
    required this.seuilVehicules,
    required this.actif,
  });

  factory ParametresSalaire.fromJson(Map<String, dynamic> json) {
    return ParametresSalaire(
      pctProprietaire: double.tryParse(json['pctProprietaire']?.toString() ?? '8') ?? 8,
      pctEmploye: double.tryParse(json['pctEmploye']?.toString() ?? '4') ?? 4,
      seuilVehicules: json['seuilVehicules'] as int? ?? 5,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'pctProprietaire': pctProprietaire,
    'pctEmploye': pctEmploye,
    'seuilVehicules': seuilVehicules,
    'actif': actif,
  };
}

class CumulsSalaire {
  final Map<String, ProfilCumul> parProfil;

  const CumulsSalaire({this.parProfil = const {}});

  factory CumulsSalaire.fromJson(Map<String, dynamic> json) {
    final map = <String, ProfilCumul>{};
    for (final entry in json.entries) {
      map[entry.key] = ProfilCumul.fromJson(Map<String, dynamic>.from(entry.value as Map));
    }
    return CumulsSalaire(parProfil: map);
  }
}

class ProfilCumul {
  final int nbMois;
  final double totalCalcule;
  final double totalVerse;
  final double moyenneMensuelle;

  const ProfilCumul({
    required this.nbMois,
    required this.totalCalcule,
    required this.totalVerse,
    required this.moyenneMensuelle,
  });

  factory ProfilCumul.fromJson(Map<String, dynamic> json) {
    return ProfilCumul(
      nbMois: json['nbMois'] as int? ?? 0,
      totalCalcule: double.tryParse(json['totalCalcule']?.toString() ?? '0') ?? 0,
      totalVerse: double.tryParse(json['totalVerse']?.toString() ?? '0') ?? 0,
      moyenneMensuelle: double.tryParse(json['moyenneMensuelle']?.toString() ?? '0') ?? 0,
    );
  }
}

class SimulationMois {
  final String mois;
  final int vehiculesActifs;
  final double revenuEncaisse;
  final double salaireProprietaire;
  final double salaireEmploye;
  final double cashApresSalaires;
  final bool seuilAtteint;

  const SimulationMois({
    required this.mois,
    required this.vehiculesActifs,
    required this.revenuEncaisse,
    required this.salaireProprietaire,
    required this.salaireEmploye,
    required this.cashApresSalaires,
    required this.seuilAtteint,
  });

  factory SimulationMois.fromJson(Map<String, dynamic> json) {
    return SimulationMois(
      mois: json['mois'] as String,
      vehiculesActifs: json['vehiculesActifs'] as int? ?? 0,
      revenuEncaisse: double.tryParse(json['revenuEncaisse']?.toString() ?? '0') ?? 0,
      salaireProprietaire: double.tryParse(json['salaireProprietaire']?.toString() ?? '0') ?? 0,
      salaireEmploye: double.tryParse(json['salaireEmploye']?.toString() ?? '0') ?? 0,
      cashApresSalaires: double.tryParse(json['cashApresSalaires']?.toString() ?? '0') ?? 0,
      seuilAtteint: json['seuilAtteint'] as bool? ?? false,
    );
  }
}

class SimulationResultat {
  final List<SimulationMois> scenarios;
  final double totalSalairesProprietaire;
  final double totalSalairesEmploye;
  final double totalVerse;
  final String? moisDefaillance;

  const SimulationResultat({
    required this.scenarios,
    required this.totalSalairesProprietaire,
    required this.totalSalairesEmploye,
    required this.totalVerse,
    this.moisDefaillance,
  });

  factory SimulationResultat.fromJson(Map<String, dynamic> json) {
    return SimulationResultat(
      scenarios: (json['scenarios'] as List?)
          ?.map((e) => SimulationMois.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? [],
      totalSalairesProprietaire: double.tryParse(json['totalSalairesProprietaire']?.toString() ?? '0') ?? 0,
      totalSalairesEmploye: double.tryParse(json['totalSalairesEmploye']?.toString() ?? '0') ?? 0,
      totalVerse: double.tryParse(json['totalVerse']?.toString() ?? '0') ?? 0,
      moisDefaillance: json['moisDefaillance'] as String?,
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

class SalairesState {
  final List<Salaire> salaires;
  final ParametresSalaire? parametres;
  final CumulsSalaire? cumuls;
  final SimulationResultat? simulation;
  final bool isLoading;
  final bool isCalculating;
  final String? error;

  const SalairesState({
    this.salaires = const [],
    this.parametres,
    this.cumuls,
    this.simulation,
    this.isLoading = false,
    this.isCalculating = false,
    this.error,
  });

  SalairesState copyWith({
    List<Salaire>? salaires,
    ParametresSalaire? parametres,
    CumulsSalaire? cumuls,
    SimulationResultat? simulation,
    bool? isLoading,
    bool? isCalculating,
    String? error,
    bool clearError = false,
    bool clearSimulation = false,
  }) {
    return SalairesState(
      salaires: salaires ?? this.salaires,
      parametres: parametres ?? this.parametres,
      cumuls: cumuls ?? this.cumuls,
      simulation: clearSimulation ? null : (simulation ?? this.simulation),
      isLoading: isLoading ?? this.isLoading,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class SalairesNotifier extends StateNotifier<SalairesState> {
  final Ref _ref;

  SalairesNotifier(this._ref) : super(const SalairesState());

  Future<void> chargerSalaires({String? profil, String? statut}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final params = <String, dynamic>{};
      if (profil != null) params['profil'] = profil;
      if (statut != null) params['statut'] = statut;

      final response = await _ref.read(apiClientProvider).get('/salaires', queryParameters: params);
      final data = response.data['data'] as List?;
      final salaires = data?.map((e) => Salaire.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
      state = state.copyWith(salaires: salaires, isLoading: false);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur chargement: $e');
      state = state.copyWith(isLoading: false, error: 'Erreur de chargement');
    }
  }

  Future<void> chargerParametres() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/salaires/parametres');
      final params = ParametresSalaire.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(parametres: params);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur paramètres: $e');
    }
  }

  Future<void> chargerCumuls() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/salaires/cumuls');
      final cumuls = CumulsSalaire.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(cumuls: cumuls);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur cumuls: $e');
    }
  }

  Future<void> updateParametres(ParametresSalaire params) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).put('/salaires/parametres', data: params.toJson());
      final updated = ParametresSalaire.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(parametres: updated, isLoading: false);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur update: $e');
      state = state.copyWith(isLoading: false, error: 'Erreur de mise à jour');
    }
  }

  Future<void> calculerMois(String mois) async {
    state = state.copyWith(isCalculating: true, clearError: true);
    try {
      await _ref.read(apiClientProvider).post('/salaires/calculer', data: {'mois': mois});
      await chargerSalaires();
      await chargerCumuls();
      state = state.copyWith(isCalculating: false);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur calcul: $e');
      state = state.copyWith(isCalculating: false, error: 'Erreur de calcul');
    }
  }

  Future<void> validerSalaire(String id) async {
    try {
      await _ref.read(apiClientProvider).post('/salaires/$id/valider');
      await chargerSalaires();
      await chargerCumuls();
    } catch (e) {
      AppLogger.e('[Salaires] Erreur validation: $e');
      state = state.copyWith(error: 'Erreur de validation');
    }
  }

  Future<void> annulerSalaire(String id) async {
    try {
      await _ref.read(apiClientProvider).post('/salaires/$id/annuler');
      await chargerSalaires();
      await chargerCumuls();
    } catch (e) {
      AppLogger.e('[Salaires] Erreur annulation: $e');
      state = state.copyWith(error: 'Erreur d\'annulation');
    }
  }

  Future<void> simuler({
    double? pctProprietaire,
    double? pctEmploye,
    int? seuilVehicules,
    int? nbMois,
  }) async {
    state = state.copyWith(isCalculating: true, clearError: true, clearSimulation: true);
    try {
      final data = <String, dynamic>{};
      if (pctProprietaire != null) data['pctProprietaire'] = pctProprietaire;
      if (pctEmploye != null) data['pctEmploye'] = pctEmploye;
      if (seuilVehicules != null) data['seuilVehicules'] = seuilVehicules;
      if (nbMois != null) data['nbMois'] = nbMois;

      final response = await _ref.read(apiClientProvider).post('/salaires/simuler', data: data);
      final result = SimulationResultat.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(simulation: result, isCalculating: false);
    } catch (e) {
      AppLogger.e('[Salaires] Erreur simulation: $e');
      state = state.copyWith(isCalculating: false, error: 'Erreur de simulation');
    }
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final salairesProvider = StateNotifierProvider<SalairesNotifier, SalairesState>((ref) {
  return SalairesNotifier(ref);
});
