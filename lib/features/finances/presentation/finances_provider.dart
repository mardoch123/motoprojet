import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class PatrimoineData {
  final int cashEnCaisse;
  final int valeurVehiculesActifs;
  final int patrimoineTotal;
  final int nbVehiculesActifs;
  final int nbVehiculesRembourses;
  final List<VehiculeDetail> detail;

  const PatrimoineData({
    required this.cashEnCaisse,
    required this.valeurVehiculesActifs,
    required this.patrimoineTotal,
    required this.nbVehiculesActifs,
    required this.nbVehiculesRembourses,
    this.detail = const [],
  });

  factory PatrimoineData.fromJson(Map<String, dynamic> j) => PatrimoineData(
    cashEnCaisse: j['cashEnCaisse'] as int? ?? 0,
    valeurVehiculesActifs: j['valeurVehiculesActifs'] as int? ?? 0,
    patrimoineTotal: j['patrimoineTotal'] as int? ?? 0,
    nbVehiculesActifs: j['nbVehiculesActifs'] as int? ?? 0,
    nbVehiculesRembourses: j['nbVehiculesRembourses'] as int? ?? 0,
    detail: (j['detail'] as List? ?? [])
        .map((e) => VehiculeDetail.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class VehiculeDetail {
  final String id;
  final String type;
  final String plaque;
  final String? marque;
  final int prixAchat;
  final int valeurResiduelle;
  final String? dateAchat;

  const VehiculeDetail({
    required this.id,
    required this.type,
    required this.plaque,
    this.marque,
    required this.prixAchat,
    required this.valeurResiduelle,
    this.dateAchat,
  });

  factory VehiculeDetail.fromJson(Map<String, dynamic> j) => VehiculeDetail(
    id: j['id'] as String,
    type: j['type'] as String,
    plaque: j['plaque'] as String,
    marque: j['marque'] as String?,
    prixAchat: j['prixAchat'] as int? ?? 0,
    valeurResiduelle: j['valeurResiduelle'] as int? ?? 0,
    dateAchat: j['dateAchat'] as String?,
  );
}

class DepotBanque {
  final String id;
  final String dateDepot;
  final int montantTheorique;
  final int montantReel;
  final int ecart;
  final String? banque;
  final String? reference;
  final String? note;
  final bool rapproche;
  final String? rapprochePar;
  final String? rapprocheLe;

  const DepotBanque({
    required this.id,
    required this.dateDepot,
    required this.montantTheorique,
    required this.montantReel,
    required this.ecart,
    this.banque,
    this.reference,
    this.note,
    this.rapproche = false,
    this.rapprochePar,
    this.rapprocheLe,
  });

  factory DepotBanque.fromJson(Map<String, dynamic> j) => DepotBanque(
    id: j['id'] as String,
    dateDepot: j['dateDepot'] as String,
    montantTheorique: j['montantTheorique'] as int? ?? 0,
    montantReel: j['montantReel'] as int? ?? 0,
    ecart: j['ecart'] as int? ?? 0,
    banque: j['banque'] as String?,
    reference: j['reference'] as String?,
    note: j['note'] as String?,
    rapproche: j['rapproche'] as bool? ?? false,
    rapprochePar: j['rapprochePar'] as String?,
    rapprocheLe: j['rapprocheLe'] as String?,
  );
}

class ExportComptableData {
  final String periodeDebut;
  final String periodeFin;
  final int totalEncaisse;
  final int totalSalaires;
  final int totalDepenses;
  final int totalAchats;
  final int cashNet;
  final int nbPaiements;
  final int patrimoineFinal;
  final List<Map<String, dynamic>> paiements;
  final List<Map<String, dynamic>> salaires;
  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> depots;

  const ExportComptableData({
    required this.periodeDebut,
    required this.periodeFin,
    required this.totalEncaisse,
    required this.totalSalaires,
    required this.totalDepenses,
    required this.totalAchats,
    required this.cashNet,
    required this.nbPaiements,
    required this.patrimoineFinal,
    this.paiements = const [],
    this.salaires = const [],
    this.incidents = const [],
    this.depots = const [],
  });

  factory ExportComptableData.fromJson(Map<String, dynamic> j) {
    final resume = Map<String, dynamic>.from(j['resume'] as Map);
    final periode = Map<String, dynamic>.from(j['periode'] as Map);
    return ExportComptableData(
      periodeDebut: periode['debut'] as String,
      periodeFin: periode['fin'] as String,
      totalEncaisse: resume['totalEncaisse'] as int? ?? 0,
      totalSalaires: resume['totalSalaires'] as int? ?? 0,
      totalDepenses: resume['totalDepenses'] as int? ?? 0,
      totalAchats: resume['totalAchats'] as int? ?? 0,
      cashNet: resume['cashNet'] as int? ?? 0,
      nbPaiements: resume['nbPaiements'] as int? ?? 0,
      patrimoineFinal: resume['patrimoineFinal'] as int? ?? 0,
      paiements: (j['paiements'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      salaires: (j['salaires'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      incidents: (j['incidents'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      depots: (j['depots'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

class FinancesState {
  final PatrimoineData? patrimoine;
  final List<DepotBanque> depots;
  final ExportComptableData? exportData;
  final bool isLoadingPatrimoine;
  final bool isLoadingDepots;
  final bool isLoadingExport;
  final String? error;

  const FinancesState({
    this.patrimoine,
    this.depots = const [],
    this.exportData,
    this.isLoadingPatrimoine = false,
    this.isLoadingDepots = false,
    this.isLoadingExport = false,
    this.error,
  });

  FinancesState copyWith({
    PatrimoineData? patrimoine,
    List<DepotBanque>? depots,
    ExportComptableData? exportData,
    bool? isLoadingPatrimoine,
    bool? isLoadingDepots,
    bool? isLoadingExport,
    String? error,
    bool clearError = false,
  }) => FinancesState(
    patrimoine: patrimoine ?? this.patrimoine,
    depots: depots ?? this.depots,
    exportData: exportData ?? this.exportData,
    isLoadingPatrimoine: isLoadingPatrimoine ?? this.isLoadingPatrimoine,
    isLoadingDepots: isLoadingDepots ?? this.isLoadingDepots,
    isLoadingExport: isLoadingExport ?? this.isLoadingExport,
    error: clearError ? null : (error ?? this.error),
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class FinancesNotifier extends StateNotifier<FinancesState> {
  final Ref _ref;
  FinancesNotifier(this._ref) : super(const FinancesState());

  Future<void> chargerPatrimoine() async {
    state = state.copyWith(isLoadingPatrimoine: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).get('/finances/patrimoine');
      final data = PatrimoineData.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(patrimoine: data, isLoadingPatrimoine: false);
    } catch (e) {
      AppLogger.e('[Finances] Erreur patrimoine: $e');
      state = state.copyWith(isLoadingPatrimoine: false, error: e.toString());
    }
  }

  Future<void> chargerDepots({String? dateDebut, String? dateFin}) async {
    state = state.copyWith(isLoadingDepots: true, clearError: true);
    try {
      final queryParams = <String, dynamic>{};
      if (dateDebut != null) queryParams['dateDebut'] = dateDebut;
      if (dateFin != null) queryParams['dateFin'] = dateFin;
      final response = await _ref.read(apiClientProvider).get('/finances/depots', queryParameters: queryParams);
      final depots = (response.data['data'] as List)
          .map((e) => DepotBanque.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(depots: depots, isLoadingDepots: false);
    } catch (e) {
      AppLogger.e('[Finances] Erreur dépôts: $e');
      state = state.copyWith(isLoadingDepots: false, error: e.toString());
    }
  }

  Future<void> creerDepot({
    required String dateDepot,
    required int montantTheorique,
    required int montantReel,
    String? banque,
    String? reference,
    String? note,
  }) async {
    try {
      await _ref.read(apiClientProvider).post('/finances/depots', data: {
        'dateDepot': dateDepot,
        'montantTheorique': montantTheorique,
        'montantReel': montantReel,
        'banque': banque,
        'reference': reference,
        'note': note,
      });
      await chargerDepots();
    } catch (e) {
      AppLogger.e('[Finances] Erreur création dépôt: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> rapprocherDepot(String id) async {
    try {
      await _ref.read(apiClientProvider).post('/finances/depots/$id/rapprocher');
      await chargerDepots();
    } catch (e) {
      AppLogger.e('[Finances] Erreur rapprochement: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> genererExport(String dateDebut, String dateFin) async {
    state = state.copyWith(isLoadingExport: true, clearError: true);
    try {
      final response = await _ref.read(apiClientProvider).get(
        '/finances/export',
        queryParameters: {'dateDebut': dateDebut, 'dateFin': dateFin},
      );
      final data = ExportComptableData.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      state = state.copyWith(exportData: data, isLoadingExport: false);
    } catch (e) {
      AppLogger.e('[Finances] Erreur export: $e');
      state = state.copyWith(isLoadingExport: false, error: e.toString());
    }
  }
}

final financesProvider = StateNotifierProvider<FinancesNotifier, FinancesState>((ref) {
  return FinancesNotifier(ref);
});
