import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/network/sync_service.dart';
import 'package:motoprojet/features/paiements/presentation/paiement_repository.dart';
import 'package:motoprojet/features/paiements/presentation/payment_favorites_service.dart';
import 'package:motoprojet/shared/models/paiement_model.dart';

/// État de la liste des paiements
class PaiementsListState {
  final List<PaiementModel> paiements;
  final bool isLoading;
  final String? error;
  final String? chauffeurFilter;
  final String? vehiculeFilter;
  final String? dateDebut;
  final String? dateFin;
  final String? modeFilter;
  final int totalMontant;

  const PaiementsListState({
    this.paiements = const [],
    this.isLoading = false,
    this.error,
    this.chauffeurFilter,
    this.vehiculeFilter,
    this.dateDebut,
    this.dateFin,
    this.modeFilter,
    this.totalMontant = 0,
  });

  PaiementsListState copyWith({
    List<PaiementModel>? paiements,
    bool? isLoading,
    String? error,
    String? chauffeurFilter,
    String? vehiculeFilter,
    String? dateDebut,
    String? dateFin,
    String? modeFilter,
    int? totalMontant,
    bool clearError = false,
    bool clearFilters = false,
  }) {
    return PaiementsListState(
      paiements: paiements ?? this.paiements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      chauffeurFilter: clearFilters ? null : (chauffeurFilter ?? this.chauffeurFilter),
      vehiculeFilter: clearFilters ? null : (vehiculeFilter ?? this.vehiculeFilter),
      dateDebut: clearFilters ? null : (dateDebut ?? this.dateDebut),
      dateFin: clearFilters ? null : (dateFin ?? this.dateFin),
      modeFilter: clearFilters ? null : (modeFilter ?? this.modeFilter),
      totalMontant: totalMontant ?? this.totalMontant,
    );
  }
}

/// Provider liste des paiements
class PaiementsListNotifier extends StateNotifier<PaiementsListState> {
  final Ref ref;
  PaiementsListNotifier(this.ref) : super(const PaiementsListState());

  Future<void> loadPaiements() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(paiementRepositoryProvider);
      final list = await repo.getHistorique(
        chauffeurId: state.chauffeurFilter,
        vehiculeId: state.vehiculeFilter,
        dateDebut: state.dateDebut,
        dateFin: state.dateFin,
        mode: state.modeFilter,
      );
      final total = list.fold<int>(0, (sum, p) => sum + p.montant.toInt());
      state = state.copyWith(paiements: list, isLoading: false, totalMontant: total);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setChauffeurFilter(String? id) {
    state = state.copyWith(chauffeurFilter: id);
    loadPaiements();
  }

  void setVehiculeFilter(String? id) {
    state = state.copyWith(vehiculeFilter: id);
    loadPaiements();
  }

  void setDateRange(String? debut, String? fin) {
    state = state.copyWith(dateDebut: debut, dateFin: fin);
    loadPaiements();
  }

  void setModeFilter(String? mode) {
    state = state.copyWith(modeFilter: mode);
    loadPaiements();
  }

  void clearFilters() {
    state = state.copyWith(clearFilters: true);
    loadPaiements();
  }
}

/// État de la saisie rapide
class SaisieRapideState {
  final bool isSubmitting;
  final PaiementResult? lastResult;
  final String? error;
  final double? soldeRestant;

  const SaisieRapideState({
    this.isSubmitting = false,
    this.lastResult,
    this.error,
    this.soldeRestant,
  });

  SaisieRapideState copyWith({
    bool? isSubmitting,
    PaiementResult? lastResult,
    String? error,
    double? soldeRestant,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return SaisieRapideState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      error: clearError ? null : (error ?? this.error),
      soldeRestant: soldeRestant ?? this.soldeRestant,
    );
  }
}

/// Provider saisie rapide
class SaisieRapideNotifier extends StateNotifier<SaisieRapideState> {
  final Ref ref;
  SaisieRapideNotifier(this.ref) : super(const SaisieRapideState());

  Future<PaiementResult?> enregistrer({
    required String chauffeurId,
    required String vehiculeId,
    required double montant,
    required String date,
    String mode = 'mobile_money',
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearResult: true);
    try {
      final repo = ref.read(paiementRepositoryProvider);
      final result = await repo.enregistrer(
        chauffeurId: chauffeurId,
        vehiculeId: vehiculeId,
        montant: montant,
        date: date,
        mode: mode,
      );
      state = state.copyWith(
        isSubmitting: false,
        lastResult: result,
        soldeRestant: result.solde?.nouveauSolde,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const SaisieRapideState();
  }
}

/// Provider du statut de synchronisation
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

/// Provider de la liste des paiements en attente
final pendingSyncListProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final offlineStorage = ref.watch(offlineStorageProvider);
  return offlineStorage.getPendingSyncItems();
});

// ─── Providers publics ───────────────────────────────────────────────────────

final paiementsListProvider =
    StateNotifierProvider<PaiementsListNotifier, PaiementsListState>((ref) {
  return PaiementsListNotifier(ref);
});

final saisieRapideProvider =
    StateNotifierProvider<SaisieRapideNotifier, SaisieRapideState>((ref) {
  return SaisieRapideNotifier(ref);
});

// ─── Providers favoris paiement ─────────────────────────────────────────────

final paymentFavoritesServiceProvider = Provider<PaymentFavoritesService>((ref) {
  final service = PaymentFavoritesService();
  service.init();
  return service;
});

final lastPaymentProvider = Provider<LastPayment?>((ref) {
  final service = ref.watch(paymentFavoritesServiceProvider);
  return service.getLastPayment();
});

final paymentFavoritesProvider = Provider<List<PaymentFavorite>>((ref) {
  final service = ref.watch(paymentFavoritesServiceProvider);
  return service.getFavorites();
});
