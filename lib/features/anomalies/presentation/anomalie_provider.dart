import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles de données ──────────────────────────────────────────────────────

class Anomalie {
  final String id;
  final String typeAnomalie;
  final String severite; // 'critique' | 'haute' | 'moyenne' | 'basse'
  final String titre;
  final String description;
  final String? causeProbable;
  final List<String> actionsSuggerees;
  final Map<String, dynamic> contexte;
  final String statut; // 'nouveau' | 'vu' | 'ignore' | 'traite'
  final bool notifEnvoyee;
  final DateTime dateDetection;

  const Anomalie({
    required this.id,
    required this.typeAnomalie,
    required this.severite,
    required this.titre,
    required this.description,
    this.causeProbable,
    required this.actionsSuggerees,
    required this.contexte,
    required this.statut,
    required this.notifEnvoyee,
    required this.dateDetection,
  });

  factory Anomalie.fromJson(Map<String, dynamic> json) {
    return Anomalie(
      id: json['id'] as String,
      typeAnomalie: json['type_anomalie'] as String,
      severite: json['severite'] as String? ?? 'moyenne',
      titre: json['titre'] as String,
      description: json['description'] as String,
      causeProbable: json['cause_probable'] as String?,
      actionsSuggerees: json['actions_suggerees'] is List
          ? List<String>.from(json['actions_suggerees'] as List)
          : [],
      contexte: json['contexte_json'] is Map
          ? Map<String, dynamic>.from(json['contexte_json'] as Map)
          : {},
      statut: json['statut'] as String? ?? 'nouveau',
      notifEnvoyee: json['notif_envoyee'] as bool? ?? false,
      dateDetection: DateTime.parse(json['date_detection'] as String),
    );
  }

  String get emojiSeverite {
    switch (severite) {
      case 'critique':
        return '🚨';
      case 'haute':
        return '⚠️';
      case 'moyenne':
        return '📊';
      case 'basse':
        return 'ℹ️';
      default:
        return '📋';
    }
  }

  String get labelType {
    switch (typeAnomalie) {
      case 'chute_recouvrement':
        return 'Chute recouvrement';
      case 'chauffeur_arret_paiement':
        return 'Arrêt paiement';
      case 'remboursements_simultanes':
        return 'Remboursements groupés';
      case 'incidents_multiples':
        return 'Incidents multiples';
      case 'cash_anormalement_bas':
        return 'Cash bas';
      case 'retards_ensemble':
        return 'Retards groupés';
      default:
        return 'Autre';
    }
  }
}

class AnomalieStats {
  final int total;
  final int nouveaux;
  final int critiquesNouveaux;
  final int derniers7j;

  const AnomalieStats({
    required this.total,
    required this.nouveaux,
    required this.critiquesNouveaux,
    required this.derniers7j,
  });

  factory AnomalieStats.fromJson(Map<String, dynamic> json) {
    return AnomalieStats(
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      nouveaux: int.tryParse(json['nouveaux']?.toString() ?? '0') ?? 0,
      critiquesNouveaux: int.tryParse(json['critiques_nouveaux']?.toString() ?? '0') ?? 0,
      derniers7j: int.tryParse(json['derniers_7j']?.toString() ?? '0') ?? 0,
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

class AnomalieState {
  final List<Anomalie> anomalies;
  final AnomalieStats? stats;
  final bool isLoading;
  final String? error;

  const AnomalieState({
    this.anomalies = const [],
    this.stats,
    this.isLoading = false,
    this.error,
  });

  AnomalieState copyWith({
    List<Anomalie>? anomalies,
    AnomalieStats? stats,
    bool? isLoading,
    String? error,
  }) {
    return AnomalieState(
      anomalies: anomalies ?? this.anomalies,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AnomalieNotifier extends StateNotifier<AnomalieState> {
  final Ref _ref;

  AnomalieNotifier(this._ref) : super(const AnomalieState());

  Future<void> chargerAnomalies({String? statut, String? severite}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiClientProvider);
      final params = <String, String>{};
      if (statut != null) params['statut'] = statut;
      if (severite != null) params['severite'] = severite;
      params['limit'] = '50';

      final response = await api.get('/anomalies', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final list = (data['anomalies'] as List)
          .map((e) => Anomalie.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(anomalies: list, isLoading: false);
    } catch (e) {
      AppLogger.e('[Anomalies] Erreur chargement: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> chargerStats() async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get('/anomalies/stats');
      final data = response.data as Map<String, dynamic>;
      final stats = AnomalieStats.fromJson(data['global'] as Map<String, dynamic>);
      state = state.copyWith(stats: stats);
    } catch (e) {
      AppLogger.e('[Anomalies] Erreur stats: $e');
    }
  }

  Future<void> changerStatut(String id, String statut) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.put('/anomalies/$id/statut', data: {'statut': statut});
      // Recharger la liste
      await chargerAnomalies();
      await chargerStats();
    } catch (e) {
      AppLogger.e('[Anomalies] Erreur changement statut: $e');
      rethrow;
    }
  }

  Future<void> forcerScan() async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.post('/anomalies/scan');
      await chargerAnomalies();
      await chargerStats();
    } catch (e) {
      AppLogger.e('[Anomalies] Erreur scan: $e');
      rethrow;
    }
  }

  int get nbNouveaux => state.anomalies.where((a) => a.statut == 'nouveau').length;
  int get nbCritiques => state.anomalies.where((a) => a.severite == 'critique' && a.statut == 'nouveau').length;
}

// ─── Providers ───────────────────────────────────────────────────────────────

final anomalieProvider = StateNotifierProvider<AnomalieNotifier, AnomalieState>((ref) {
  return AnomalieNotifier(ref);
});

final anomalieNotifierProvider = Provider<AnomalieNotifier>((ref) {
  return ref.watch(anomalieProvider.notifier);
});
