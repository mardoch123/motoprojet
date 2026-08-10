import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/shared/models/vehicule_model.dart';

/// État de la liste des véhicules
class VehiculesListState {
  final List<VehiculeModel> vehicules;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? typeFilter;
  final String? statutFilter;
  final String? chauffeurFilter;
  final bool isGridView;

  const VehiculesListState({
    this.vehicules = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.typeFilter,
    this.statutFilter,
    this.chauffeurFilter,
    this.isGridView = false,
  });

  VehiculesListState copyWith({
    List<VehiculeModel>? vehicules,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? typeFilter,
    String? statutFilter,
    String? chauffeurFilter,
    bool? isGridView,
    bool clearError = false,
    bool clearFilters = false,
  }) {
    return VehiculesListState(
      vehicules: vehicules ?? this.vehicules,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearFilters ? null : (typeFilter ?? this.typeFilter),
      statutFilter: clearFilters ? null : (statutFilter ?? this.statutFilter),
      chauffeurFilter: clearFilters ? null : (chauffeurFilter ?? this.chauffeurFilter),
      isGridView: isGridView ?? this.isGridView,
    );
  }

  /// Liste filtrée localement
  List<VehiculeModel> get filteredList {
    var list = vehicules;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((v) => v.plaque.toLowerCase().contains(q)).toList();
    }
    if (typeFilter != null && typeFilter!.isNotEmpty) {
      list = list.where((v) => v.type == typeFilter).toList();
    }
    if (statutFilter != null && statutFilter!.isNotEmpty) {
      list = list.where((v) => v.statut == statutFilter).toList();
    }
    if (chauffeurFilter != null && chauffeurFilter!.isNotEmpty) {
      list = list.where((v) => v.chauffeurId == chauffeurFilter).toList();
    }
    return list;
  }
}

/// État détaillé d'un véhicule
class VehiculeDetailState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? error;

  const VehiculeDetailState({this.data, this.isLoading = false, this.error});

  VehiculeDetailState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? error,
    bool clearData = false,
  }) {
    return VehiculeDetailState(
      data: clearData ? null : (data ?? this.data),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Provider liste véhicules
class VehiculesListNotifier extends StateNotifier<VehiculesListState> {
  final Ref ref;
  VehiculesListNotifier(this.ref) : super(const VehiculesListState());

  Future<void> loadVehicules() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (state.searchQuery.isNotEmpty) params['search'] = state.searchQuery;
      if (state.typeFilter != null && state.typeFilter!.isNotEmpty) params['type'] = state.typeFilter!;
      if (state.statutFilter != null && state.statutFilter!.isNotEmpty) params['statut'] = state.statutFilter!;
      if (state.chauffeurFilter != null && state.chauffeurFilter!.isNotEmpty) params['chauffeur_id'] = state.chauffeurFilter!;

      final response = await client.get('/vehicules', queryParameters: params);
      final responseData = response.data as Map<String, dynamic>;
      final list = (responseData['data'] as List)
          .map((e) => VehiculeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(vehicules: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    loadVehicules();
  }

  void setTypeFilter(String? type) {
    state = state.copyWith(typeFilter: type);
    loadVehicules();
  }

  void setStatutFilter(String? statut) {
    state = state.copyWith(statutFilter: statut);
    loadVehicules();
  }

  void setChauffeurFilter(String? chauffeurId) {
    state = state.copyWith(chauffeurFilter: chauffeurId);
    loadVehicules();
  }

  void toggleView() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void clearAllFilters() {
    state = state.copyWith(clearFilters: true);
    loadVehicules();
  }
}

/// Provider détail véhicule
class VehiculeDetailNotifier extends StateNotifier<VehiculeDetailState> {
  final Ref ref;
  VehiculeDetailNotifier(this.ref) : super(const VehiculeDetailState());

  Future<void> loadDetail(String vehiculeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/vehicules/$vehiculeId');
      final responseData = response.data as Map<String, dynamic>;
      state = VehiculeDetailState(data: responseData['data'] as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createVehicule(Map<String, dynamic> data) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/vehicules', data: data);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateVehicule(String id, Map<String, dynamic> data) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/vehicules/$id', data: data);
      await loadDetail(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> changeStatut(String id, String statut, {String? commentaire}) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/vehicules/$id/statut', data: {
        'statut': statut,
        if (commentaire != null) 'commentaire': commentaire,
      });
      await loadDetail(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkTransfertEligibilite(String id) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/vehicules/$id/transfert-eligibilite');
      final responseData = response.data as Map<String, dynamic>;
      return responseData['data'] as Map<String, dynamic>;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> executeTransfert(String id) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/vehicules/$id/transfert', data: {});
      final responseData = response.data as Map<String, dynamic>;
      await loadDetail(id);
      return responseData['data'] as Map<String, dynamic>;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void clear() {
    state = const VehiculeDetailState();
  }
}

// ─── Providers publics ───────────────────────────────────────────────────────

final vehiculesListProvider =
    StateNotifierProvider<VehiculesListNotifier, VehiculesListState>((ref) {
  return VehiculesListNotifier(ref);
});

final vehiculeDetailProvider =
    StateNotifierProvider<VehiculeDetailNotifier, VehiculeDetailState>((ref) {
  return VehiculeDetailNotifier(ref);
});
