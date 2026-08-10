import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class Tresorerie {
  final double totalEncaisse;
  final double totalSalaires;
  final double totalDepenses;
  final double totalAchats;
  final double disponible;
  final int nbVehiculesAchetes;

  const Tresorerie({
    required this.totalEncaisse,
    required this.totalSalaires,
    required this.totalDepenses,
    required this.totalAchats,
    required this.disponible,
    required this.nbVehiculesAchetes,
  });

  factory Tresorerie.fromJson(Map<String, dynamic> j) => Tresorerie(
    totalEncaisse: _num(j['totalEncaisse']),
    totalSalaires: _num(j['totalSalaires']),
    totalDepenses: _num(j['totalDepenses']),
    totalAchats: _num(j['totalAchats']),
    disponible: _num(j['disponible']),
    nbVehiculesAchetes: j['nbVehiculesAchetes'] as int? ?? 0,
  );
}

class ProchainAchatVehicule {
  final double prix;
  final double cashAlloue;
  final double manque;
  final double pct;
  final int? joursRestants;
  final String? dateEstimee;
  final int rythmeJour;
  final int apportsJour;
  final int apports90j;

  const ProchainAchatVehicule({
    required this.prix,
    required this.cashAlloue,
    required this.manque,
    required this.pct,
    this.joursRestants,
    this.dateEstimee,
    required this.rythmeJour,
    this.apportsJour = 0,
    this.apports90j = 0,
  });

  factory ProchainAchatVehicule.fromJson(Map<String, dynamic> j) => ProchainAchatVehicule(
    prix: _num(j['prix']),
    cashAlloue: _num(j['cashAlloue']),
    manque: _num(j['manque']),
    pct: _num(j['pct']),
    joursRestants: j['joursRestants'] as int?,
    dateEstimee: j['dateEstimee'] as String?,
    rythmeJour: j['rythmeJour'] as int? ?? 0,
    apportsJour: j['apportsJour'] as int? ?? 0,
    apports90j: j['apports90j'] as int? ?? 0,
  );

  bool get achatPossible => manque <= 0;
}

class RythmeEncaissement {
  final int moyenneJournaliere;
  final int total30j;
  final int nbJoursActifs;
  final double partMoto;
  final double partVoiture;
  final String regle;

  const RythmeEncaissement({
    required this.moyenneJournaliere,
    required this.total30j,
    required this.nbJoursActifs,
    required this.partMoto,
    required this.partVoiture,
    required this.regle,
  });

  factory RythmeEncaissement.fromJson(Map<String, dynamic> j) => RythmeEncaissement(
    moyenneJournaliere: j['moyenneJournaliere'] as int? ?? 0,
    total30j: j['total30j'] as int? ?? 0,
    nbJoursActifs: j['nbJoursActifs'] as int? ?? 0,
    partMoto: _num(j['partMoto']),
    partVoiture: _num(j['partVoiture']),
    regle: j['regle'] as String? ?? 'tout_moto',
  );
}

class AchatHistorique {
  final String id;
  final String type;
  final String plaque;
  final String? marque;
  final double prix;
  final String? date;

  const AchatHistorique({
    required this.id,
    required this.type,
    required this.plaque,
    this.marque,
    required this.prix,
    this.date,
  });

  factory AchatHistorique.fromJson(Map<String, dynamic> j) => AchatHistorique(
    id: j['id'] as String,
    type: j['type'] as String,
    plaque: j['plaque'] as String,
    marque: j['marque'] as String?,
    prix: _num(j['prix']),
    date: j['date'] as String?,
  );
}

class ProchainAchatData {
  final Tresorerie tresorerie;
  final ProchainAchatVehicule moto;
  final ProchainAchatVehicule voiture;
  final RythmeEncaissement rythme;
  final List<AchatHistorique> historique;

  const ProchainAchatData({
    required this.tresorerie,
    required this.moto,
    required this.voiture,
    required this.rythme,
    this.historique = const [],
  });

  factory ProchainAchatData.fromJson(Map<String, dynamic> j) => ProchainAchatData(
    tresorerie: Tresorerie.fromJson(Map<String, dynamic>.from(j['tresorerie'] as Map)),
    moto: ProchainAchatVehicule.fromJson(Map<String, dynamic>.from(j['moto'] as Map)),
    voiture: ProchainAchatVehicule.fromJson(Map<String, dynamic>.from(j['voiture'] as Map)),
    rythme: RythmeEncaissement.fromJson(Map<String, dynamic>.from(j['rythme'] as Map)),
    historique: (j['historique'] as List? ?? [])
        .map((e) => AchatHistorique.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

// ─── État + Notifier ─────────────────────────────────────────────────────────

class ProchainAchatState {
  final ProchainAchatData? data;
  final bool isLoading;
  final String? error;

  const ProchainAchatState({this.data, this.isLoading = false, this.error});

  ProchainAchatState copyWith({
    ProchainAchatData? data,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => ProchainAchatState(
    data: data ?? this.data,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class ProchainAchatNotifier extends StateNotifier<ProchainAchatState> {
  final Ref _ref;
  ProchainAchatNotifier(this._ref) : super(const ProchainAchatState());

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).get('/dashboard/prochain-achat');
      final data = ProchainAchatData.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      AppLogger.e('[ProchainAchat] Erreur: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final prochainAchatProvider = StateNotifierProvider<ProchainAchatNotifier, ProchainAchatState>((ref) {
  return ProchainAchatNotifier(ref);
});
