import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/features/simulation/core/simulation_engine.dart';

// ─── État ────────────────────────────────────────────────────────────────────

class ScenarioConfig {
  final String nom;
  final ParametresSimulation parametres;
  final ResultatSimulation? resultat;
  final bool actif; // visible sur le graphique

  const ScenarioConfig({
    required this.nom,
    required this.parametres,
    this.resultat,
    this.actif = true,
  });

  ScenarioConfig copyWith({
    String? nom,
    ParametresSimulation? parametres,
    ResultatSimulation? resultat,
    bool? actif,
    bool clearResultat = false,
  }) {
    return ScenarioConfig(
      nom: nom ?? this.nom,
      parametres: parametres ?? this.parametres,
      resultat: clearResultat ? null : (resultat ?? this.resultat),
      actif: actif ?? this.actif,
    );
  }
}

class SimulationState {
  final List<ScenarioConfig> scenarios;
  final bool isCalculating;
  final String? error;

  const SimulationState({
    this.scenarios = const [],
    this.isCalculating = false,
    this.error,
  });

  SimulationState copyWith({
    List<ScenarioConfig>? scenarios,
    bool? isCalculating,
    String? error,
    bool clearError = false,
  }) {
    return SimulationState(
      scenarios: scenarios ?? this.scenarios,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Paramètres par défaut ────────────────────────────────────────────────────

ParametresSimulation defaultParams() => const ParametresSimulation(
  prixMoto: 500000,
  prixVoiture: 3000000,
  remboursementJourMoto: 5000,
  remboursementJourVoiture: 15000,
  dureeRemboursementMois: 14,
  tauxRecouvrement: 0.90,
  regle: RegleReinvestissement.toutMoto,
  motosInitiales: 0,
  voituresInitiales: 0,
  cashInitial: 500000,
  dureeMois: 12,
  pas: PasSimulation.mois,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class SimulationNotifier extends StateNotifier<SimulationState> {
  SimulationNotifier() : super(SimulationState(
    scenarios: [
      ScenarioConfig(nom: 'Scénario 1', parametres: defaultParams()),
      ScenarioConfig(nom: 'Scénario 2', parametres: defaultParams().copyWith(
        regle: RegleReinvestissement.rythmeMixte,
        rythmeMotos: 3,
        rythmeVoitures: 1,
      )),
      ScenarioConfig(nom: 'Scénario 3', parametres: defaultParams().copyWith(
        regle: RegleReinvestissement.basculeDate,
        moisBascule: 6,
      )),
    ],
  ));

  /// Met à jour les paramètres d'un scénario
  void updateParametres(int index, ParametresSimulation params) {
    if (index < 0 || index >= state.scenarios.length) return;
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    scenarios[index] = scenarios[index].copyWith(parametres: params, clearResultat: true);
    state = state.copyWith(scenarios: scenarios);
  }

  /// Renomme un scénario
  void renommerScenario(int index, String nom) {
    if (index < 0 || index >= state.scenarios.length) return;
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    scenarios[index] = scenarios[index].copyWith(nom: nom);
    state = state.copyWith(scenarios: scenarios);
  }

  /// Active/désactive un scénario sur le graphique
  void toggleScenario(int index) {
    if (index < 0 || index >= state.scenarios.length) return;
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    scenarios[index] = scenarios[index].copyWith(actif: !scenarios[index].actif);
    state = state.copyWith(scenarios: scenarios);
  }

  /// Lance le calcul pour tous les scénarios
  void calculerTous() {
    state = state.copyWith(isCalculating: true, clearError: true);
    try {
      final scenarios = List<ScenarioConfig>.from(state.scenarios);
      for (int i = 0; i < scenarios.length; i++) {
        final resultat = MoteurSimulation.executer(scenarios[i].parametres);
        scenarios[i] = scenarios[i].copyWith(resultat: resultat);
      }
      state = state.copyWith(scenarios: scenarios, isCalculating: false);
      AppLogger.i('[Simulation] ${scenarios.length} scénarios calculés');
    } catch (e) {
      AppLogger.e('[Simulation] Erreur calcul: $e');
      state = state.copyWith(isCalculating: false, error: 'Erreur de calcul: $e');
    }
  }

  /// Lance le calcul pour un scénario spécifique
  void calculerScenario(int index) {
    if (index < 0 || index >= state.scenarios.length) return;
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    try {
      final resultat = MoteurSimulation.executer(scenarios[index].parametres);
      scenarios[index] = scenarios[index].copyWith(resultat: resultat);
      state = state.copyWith(scenarios: scenarios);
    } catch (e) {
      state = state.copyWith(error: 'Erreur calcul scénario ${index + 1}: $e');
    }
  }

  /// Duplique un scénario
  void dupliquerScenario(int index) {
    if (index < 0 || index >= state.scenarios.length) return;
    if (state.scenarios.length >= 3) return; // Max 3 scénarios
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    final original = scenarios[index];
    scenarios.add(ScenarioConfig(
      nom: '${original.nom} (copie)',
      parametres: original.parametres,
    ));
    state = state.copyWith(scenarios: scenarios);
  }

  /// Réinitialise un scénario aux valeurs par défaut
  void reinitialiserScenario(int index) {
    if (index < 0 || index >= state.scenarios.length) return;
    final scenarios = List<ScenarioConfig>.from(state.scenarios);
    scenarios[index] = ScenarioConfig(
      nom: scenarios[index].nom,
      parametres: defaultParams(),
    );
    state = state.copyWith(scenarios: scenarios);
  }
}

// ─── Extension pour copier les paramètres ─────────────────────────────────────

extension ParametresSimulationCopy on ParametresSimulation {
  ParametresSimulation copyWith({
    double? prixMoto,
    double? prixVoiture,
    double? remboursementJourMoto,
    double? remboursementJourVoiture,
    int? dureeRemboursementMois,
    double? tauxRecouvrement,
    RegleReinvestissement? regle,
    int? moisBascule,
    int? rythmeMotos,
    int? rythmeVoitures,
    int? motosInitiales,
    int? voituresInitiales,
    double? cashInitial,
    int? dureeMois,
    PasSimulation? pas,
    double? salaireMensuelMoto,
    double? salaireMensuelVoiture,
  }) {
    return ParametresSimulation(
      prixMoto: prixMoto ?? this.prixMoto,
      prixVoiture: prixVoiture ?? this.prixVoiture,
      remboursementJourMoto: remboursementJourMoto ?? this.remboursementJourMoto,
      remboursementJourVoiture: remboursementJourVoiture ?? this.remboursementJourVoiture,
      dureeRemboursementMois: dureeRemboursementMois ?? this.dureeRemboursementMois,
      tauxRecouvrement: tauxRecouvrement ?? this.tauxRecouvrement,
      regle: regle ?? this.regle,
      moisBascule: moisBascule ?? this.moisBascule,
      rythmeMotos: rythmeMotos ?? this.rythmeMotos,
      rythmeVoitures: rythmeVoitures ?? this.rythmeVoitures,
      motosInitiales: motosInitiales ?? this.motosInitiales,
      voituresInitiales: voituresInitiales ?? this.voituresInitiales,
      cashInitial: cashInitial ?? this.cashInitial,
      dureeMois: dureeMois ?? this.dureeMois,
      pas: pas ?? this.pas,
      salaireMensuelMoto: salaireMensuelMoto ?? this.salaireMensuelMoto,
      salaireMensuelVoiture: salaireMensuelVoiture ?? this.salaireMensuelVoiture,
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final simulationProvider = StateNotifierProvider<SimulationNotifier, SimulationState>((ref) {
  return SimulationNotifier();
});

final simulationNotifierProvider = Provider<SimulationNotifier>((ref) {
  return ref.watch(simulationProvider.notifier);
});
