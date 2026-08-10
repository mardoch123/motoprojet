import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/api_client.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/features/ia/presentation/gps_tracking_service.dart';

// ─── Modèles de données ──────────────────────────────────────────────────────

class IaRecommandation {
  final String id;
  final String recommandation;
  final bool objectifAtteint;
  final String modeleUtilise;
  final double revenuJour;
  final double objectifJour;
  final double ecart;
  final double kmJour;
  final double km7j;
  final List<String> zonesFrequentees;
  final int joursTravailles7j;
  final int joursObjectifAtteint7j;
  final DateTime date;

  const IaRecommandation({
    required this.id,
    required this.recommandation,
    required this.objectifAtteint,
    required this.modeleUtilise,
    required this.revenuJour,
    required this.objectifJour,
    required this.ecart,
    required this.kmJour,
    required this.km7j,
    required this.zonesFrequentees,
    required this.joursTravailles7j,
    required this.joursObjectifAtteint7j,
    required this.date,
  });

  factory IaRecommandation.fromJson(Map<String, dynamic> json) {
    final contexte = json['contexte'] as Map<String, dynamic>;
    return IaRecommandation(
      id: json['id'] as String,
      recommandation: json['recommandation'] as String,
      objectifAtteint: json['objectif_atteint'] as bool,
      modeleUtilise: json['modele_utilise'] as String,
      revenuJour: (contexte['revenu_jour'] as num?)?.toDouble() ?? 0,
      objectifJour: (contexte['objectif_jour'] as num?)?.toDouble() ?? 0,
      ecart: (contexte['ecart'] as num?)?.toDouble() ?? 0,
      kmJour: (contexte['km_jour'] as num?)?.toDouble() ?? 0,
      km7j: (contexte['km_7j'] as num?)?.toDouble() ?? 0,
      zonesFrequentees: contexte['zones_frequentees'] is List
          ? List<String>.from(contexte['zones_frequentees'] as List)
          : [],
      joursTravailles7j: contexte['jours_travailles_7j'] as int? ?? 0,
      joursObjectifAtteint7j: contexte['jours_objectif_atteint_7j'] as int? ?? 0,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class HistoriquePerformance {
  final List<IaRecommandation> recommandations;
  final int totalJours;
  final int joursObjectifAtteint;
  final int tauxReussite;

  const HistoriquePerformance({
    required this.recommandations,
    required this.totalJours,
    required this.joursObjectifAtteint,
    required this.tauxReussite,
  });
}

// ─── États ────────────────────────────────────────────────────────────────────

enum IaStatus { initial, loading, success, error }

class IaState {
  final IaStatus status;
  final IaRecommandation? derniereRecommandation;
  final HistoriquePerformance? historique;
  final String? errorMessage;
  final double objectifJournalier;
  final bool gpsActif;
  final double kmParcourus;
  final Set<String> zonesVisitees;

  const IaState({
    this.status = IaStatus.initial,
    this.derniereRecommandation,
    this.historique,
    this.errorMessage,
    this.objectifJournalier = 10000,
    this.gpsActif = false,
    this.kmParcourus = 0,
    this.zonesVisitees = const {},
  });

  IaState copyWith({
    IaStatus? status,
    IaRecommandation? derniereRecommandation,
    HistoriquePerformance? historique,
    String? errorMessage,
    double? objectifJournalier,
    bool? gpsActif,
    double? kmParcourus,
    Set<String>? zonesVisitees,
  }) {
    return IaState(
      status: status ?? this.status,
      derniereRecommandation: derniereRecommandation ?? this.derniereRecommandation,
      historique: historique ?? this.historique,
      errorMessage: errorMessage ?? this.errorMessage,
      objectifJournalier: objectifJournalier ?? this.objectifJournalier,
      gpsActif: gpsActif ?? this.gpsActif,
      kmParcourus: kmParcourus ?? this.kmParcourus,
      zonesVisitees: zonesVisitees ?? this.zonesVisitees,
    );
  }
}

// ─── Provider du service GPS ──────────────────────────────────────────────────

final gpsTrackingProvider = Provider<GpsTrackingService>((ref) {
  final service = GpsTrackingService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Provider principal IA ────────────────────────────────────────────────────

final iaProvider = StateNotifierProvider<IaNotifier, IaState>((ref) {
  return IaNotifier(ref);
});

class IaNotifier extends StateNotifier<IaState> {
  final Ref _ref;
  late final GpsTrackingService _gps;

  IaNotifier(this._ref) : super(const IaState()) {
    _gps = _ref.read(gpsTrackingProvider);
  }

  // ─── Démarrer le GPS ──────────────────────────────────────────────────────
  Future<bool> demarrerGps({int startHour = 6, int endHour = 22}) async {
    final success = await _gps.startTracking(startHour: startHour, endHour: endHour);
    state = state.copyWith(gpsActif: success);
    return success;
  }

  // ─── Arrêter le GPS ───────────────────────────────────────────────────────
  void arreterGps() {
    _gps.stopTracking();
    state = state.copyWith(gpsActif: false);
  }

  // ─── Mettre à jour l'objectif ─────────────────────────────────────────────
  Future<void> updateObjectif(double nouvelObjectif) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.put('/ia/objectif', data: {'objectif_journalier': nouvelObjectif});
      state = state.copyWith(objectifJournalier: nouvelObjectif);
      AppLogger.i('[IA] Objectif mis à jour : $nouvelObjectif FCFA');
    } catch (e) {
      AppLogger.e('[IA] Erreur update objectif: $e');
    }
  }

  // ─── Demander une recommandation IA ───────────────────────────────────────
  Future<void> demanderRecommandation({double? revenuJour}) async {
    state = state.copyWith(status: IaStatus.loading, errorMessage: null);

    try {
      final api = _ref.read(apiClientProvider);

      final body = {
        'revenu_jour': revenuJour ?? 0,
        'km_jour': _gps.dailyKm,
        'zones': _gps.zonesVisited.toList(),
      };

      final response = await api.post('/ia/recommandations', data: body);
      final data = response.data['data'] as Map<String, dynamic>;
      final reco = IaRecommandation.fromJson(data);

      state = state.copyWith(
        status: IaStatus.success,
        derniereRecommandation: reco,
        kmParcourus: _gps.dailyKm,
        zonesVisitees: _gps.zonesVisited,
      );

      AppLogger.i('[IA] Recommandation reçue (${reco.modeleUtilise})');
    } catch (e) {
      final message = e.toString().contains('SocketException')
          ? 'Connexion internet requise pour obtenir une recommandation.'
          : 'Erreur lors de l\'appel IA. Veuillez réessayer.';

      state = state.copyWith(
        status: IaStatus.error,
        errorMessage: message,
      );
      AppLogger.e('[IA] Erreur recommandation: $e');
    }
  }

  // ─── Charger l'historique ─────────────────────────────────────────────────
  Future<void> chargerHistorique({int limit = 14}) async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get('/ia/historique', queryParameters: {'limit': limit});
      final data = response.data['data'] as Map<String, dynamic>;
      final stats = data['stats'] as Map<String, dynamic>;

      final recommandations = (data['recommandations'] as List)
          .map((r) => IaRecommandation.fromJson(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        historique: HistoriquePerformance(
          recommandations: recommandations,
          totalJours: stats['total_jours_analyses'] as int,
          joursObjectifAtteint: stats['jours_objectif_atteint'] as int,
          tauxReussite: stats['taux_reussite'] as int,
        ),
      );
    } catch (e) {
      AppLogger.e('[IA] Erreur chargement historique: $e');
    }
  }

  // ─── Rafraîchir les données GPS depuis le service ─────────────────────────
  void refreshGpsData() {
    state = state.copyWith(
      kmParcourus: _gps.dailyKm,
      zonesVisitees: _gps.zonesVisited,
      gpsActif: _gps.isTracking,
    );
  }
}
