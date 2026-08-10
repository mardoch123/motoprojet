import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/api_client.dart';
import 'package:motoprojet/core/network/connectivity_service.dart';
import 'package:motoprojet/core/network/offline_storage_service.dart';
import 'package:motoprojet/core/network/sync_service.dart';

/// Provider global du client API (singleton)
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Provider du service de connectivité
final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider du stockage hors-ligne
final offlineStorageProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService();
});

/// Provider du service de synchronisation
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.watch(apiClientProvider),
    offlineStorage: ref.watch(offlineStorageProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});

/// Provider qui surveille l'état de la connexion
final isConnectedProvider = FutureProvider<bool>((ref) async {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.isConnected;
});

/// Provider du nombre d'éléments en attente de sync
final pendingSyncCountProvider = StateProvider<int>((ref) => 0);
