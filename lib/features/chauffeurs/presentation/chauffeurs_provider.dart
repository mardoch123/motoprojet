import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/shared/models/chauffeur_model.dart';

/// État de la liste des chauffeurs
class ChauffeursListState {
  final List<ChauffeurModel> chauffeurs;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? statutFilter;

  const ChauffeursListState({
    this.chauffeurs = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statutFilter,
  });

  ChauffeursListState copyWith({
    List<ChauffeurModel>? chauffeurs,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? statutFilter,
    bool clearError = false,
    bool clearFilter = false,
  }) {
    return ChauffeursListState(
      chauffeurs: chauffeurs ?? this.chauffeurs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      statutFilter: clearFilter ? null : (statutFilter ?? this.statutFilter),
    );
  }

  /// Liste filtrée localement (fallback si pas de query params API)
  List<ChauffeurModel> get filteredList {
    var list = chauffeurs;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((c) =>
          c.nom.toLowerCase().contains(q) ||
          (c.telephone?.contains(q) ?? false)).toList();
    }
    if (statutFilter != null && statutFilter!.isNotEmpty) {
      list = list.where((c) => c.statut == statutFilter).toList();
    }
    return list;
  }
}

/// État détaillé d'un chauffeur (fiche complète)
class ChauffeurDetailState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? error;

  const ChauffeurDetailState({this.data, this.isLoading = false, this.error});

  ChauffeurDetailState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? error,
    bool clearData = false,
  }) {
    return ChauffeurDetailState(
      data: clearData ? null : (data ?? this.data),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Provider de la liste des chauffeurs
class ChauffeursListNotifier extends StateNotifier<ChauffeursListState> {
  final Ref ref;
  ChauffeursListNotifier(this.ref) : super(const ChauffeursListState());

  Future<void> loadChauffeurs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (state.searchQuery.isNotEmpty) params['search'] = state.searchQuery;
      if (state.statutFilter != null && state.statutFilter!.isNotEmpty) {
        params['statut'] = state.statutFilter!;
      }
      final response = await client.get('/chauffeurs', queryParameters: params);
      final responseData = response.data as Map<String, dynamic>;
      final list = (responseData['data'] as List)
          .map((e) => ChauffeurModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(chauffeurs: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    loadChauffeurs();
  }

  void setStatutFilter(String? statut) {
    state = state.copyWith(statutFilter: statut);
    loadChauffeurs();
  }

  Future<void> terminerChauffeur(String id) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/chauffeurs/$id', data: {'statut': 'termine'});
      await loadChauffeurs();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider de détail d'un chauffeur
class ChauffeurDetailNotifier extends StateNotifier<ChauffeurDetailState> {
  final Ref ref;
  ChauffeurDetailNotifier(this.ref) : super(const ChauffeurDetailState());

  Future<void> loadDetail(String chauffeurId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/chauffeurs/$chauffeurId');
      final responseData = response.data as Map<String, dynamic>;
      state = ChauffeurDetailState(data: responseData['data'] as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createChauffeur(Map<String, dynamic> data) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/chauffeurs', data: data);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateChauffeur(String id, Map<String, dynamic> data) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/chauffeurs/$id', data: data);
      await loadDetail(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> createAffectation(String chauffeurId, String vehiculeId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/chauffeurs/$chauffeurId/affectations', data: {
        'vehicule_id': vehiculeId,
      });
      await loadDetail(chauffeurId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> terminerAffectation(String affectationId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/chauffeurs/affectations/$affectationId/terminer', data: {});
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clear() {
    state = const ChauffeurDetailState();
  }
}

// ─── Providers publics ───────────────────────────────────────────────────────

final chauffeursListProvider =
    StateNotifierProvider<ChauffeursListNotifier, ChauffeursListState>((ref) {
  return ChauffeursListNotifier(ref);
});

final chauffeurDetailProvider =
    StateNotifierProvider<ChauffeurDetailNotifier, ChauffeurDetailState>((ref) {
  return ChauffeurDetailNotifier(ref);
});

/// Provider utilitaire pour récupérer les véhicules disponibles
final vehiculesDisponiblesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/vehicules');
    final responseData = response.data as Map<String, dynamic>;
    final all = (responseData['data'] as List).cast<Map<String, dynamic>>();
    return all.where((v) => v['statut'] == 'disponible' || v['statut'] == 'actif').toList();
  } catch (_) {
    return [];
  }
});
