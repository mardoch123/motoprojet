import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:motoprojet/core/network/api_client.dart';
import 'package:motoprojet/core/network/connectivity_service.dart';
import 'package:motoprojet/core/network/offline_storage_service.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Synchronise les paiements hors-ligne avec le serveur.
///
/// Fonctionnement :
/// 1. Écoute les changements de connectivité
/// 2. Dès que le réseau revient → sync batch automatique
/// 3. Retry exponentiel en cas d'échec (max 5 tentatives)
/// 4. Déduplication par UUID côté serveur
class SyncService {
  final ApiClient apiClient;
  final OfflineStorageService offlineStorage;
  final ConnectivityService connectivity;

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _retryTimer;
  int _currentRetryDelay = 0;

  /// Callback pour notifier l'UI des changements de statut sync
  void Function(SyncStatus)? onStatusChanged;

  static const int _maxRetries = 5;
  static const List<int> _retryDelaysMs = [2000, 5000, 15000, 30000, 60000];

  SyncService({
    required this.apiClient,
    required this.offlineStorage,
    required this.connectivity,
  });

  /// Démarre l'écoute de la connectivité et lance une sync initiale si connecté
  void start() {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected && !_isSyncing) {
        AppLogger.i('[Sync] Connexion détectée — lancement sync automatique');
        syncAll();
      }
    });

    // Sync initiale au démarrage
    syncAll();
  }

  /// Arrête le service
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  /// Nombre d'éléments en attente
  int get pendingCount => offlineStorage.pendingSyncCount;

  /// Récupère les éléments en attente de sync
  List<Map<String, dynamic>> getPendingItems() => offlineStorage.getPendingSyncItems();

  /// Lance la synchronisation batch de tous les paiements en attente
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      AppLogger.w('[Sync] Déjà en cours de synchronisation');
      return const SyncResult(success: 0, failed: 0, skipped: 0, status: SyncStatus.busy);
    }

    final hasConnection = await connectivity.isConnected;
    if (!hasConnection) {
      AppLogger.w('[Sync] Pas de connexion — sync reportée');
      onStatusChanged?.call(SyncStatus.waitingConnection);
      return SyncResult(success: 0, failed: 0, skipped: offlineStorage.pendingSyncCount, status: SyncStatus.offline);
    }

    final pendingItems = offlineStorage.getPendingSyncItems();
    if (pendingItems.isEmpty) {
      AppLogger.d('[Sync] Rien à synchroniser');
      onStatusChanged?.call(SyncStatus.idle);
      return const SyncResult(success: 0, failed: 0, skipped: 0, status: SyncStatus.idle);
    }

    _isSyncing = true;
    onStatusChanged?.call(SyncStatus.syncing);
    AppLogger.i('[Sync] Synchronisation de ${pendingItems.length} paiements (batch)...');

    try {
      // Construire le batch pour l'API
      final batchPaiements = pendingItems.map((item) {
        final data = Map<String, dynamic>.from(item['data'] as Map);
        return {
          'id': data['id'],
          'vehicule_id': data['vehiculeId'],
          'montant': data['montant'],
          'date': data['date'],
          'mode': data['mode'] ?? 'cash',
        };
      }).toList();

      // Envoyer en batch
      final response = await apiClient.post('/paiements/sync-batch', data: {
        'paiements': batchPaiements,
      });

      final responseData = response.data as Map<String, dynamic>;
      final syncData = responseData['data'] as Map<String, dynamic>;

      final created = List<String>.from(syncData['created'] as List);
      final duplicates = List<String>.from(syncData['duplicates'] as List);
      final errors = List<Map<String, dynamic>>.from(syncData['errors'] as List);

      // Supprimer les paiements synchronisés avec succès (créés + doublons)
      for (final id in [...created, ...duplicates]) {
        await offlineStorage.removeOfflinePayment(id);
      }

      // Incrémenter les tentatives pour les erreurs
      for (final err in errors) {
        await offlineStorage.incrementSyncAttempt(err['id'] as String);
      }

      final result = SyncResult(
        success: created.length + duplicates.length,
        failed: errors.length,
        skipped: 0,
        status: errors.isEmpty ? SyncStatus.idle : SyncStatus.partialError,
      );

      AppLogger.i('[Sync] Terminée — ${result.success} succès, ${result.failed} échecs, ${duplicates.length} doublons');

      _isSyncing = false;
      _currentRetryDelay = 0; // Reset retry delay on success
      onStatusChanged?.call(result.status);

      // Si des erreurs persistent, programmer un retry
      if (result.failed > 0) {
        _scheduleRetry();
      }

      return result;
    } catch (e) {
      _isSyncing = false;
      AppLogger.e('[Sync] Erreur batch : $e');
      onStatusChanged?.call(SyncStatus.error);
      _scheduleRetry();
      return SyncResult(success: 0, failed: pendingItems.length, skipped: 0, status: SyncStatus.error);
    }
  }

  /// Programmation d'un retry avec délai exponentiel
  void _scheduleRetry() {
    _retryTimer?.cancel();

    if (_currentRetryDelay >= _maxRetries) {
      AppLogger.w('[Sync] Nombre max de retries atteint ($_maxRetries)');
      onStatusChanged?.call(SyncStatus.maxRetriesReached);
      return;
    }

    final delay = _retryDelaysMs[_currentRetryDelay];
    _currentRetryDelay++;
    AppLogger.i('[Sync] Retry #${_currentRetryDelay} dans ${delay}ms');

    _retryTimer = Timer(Duration(milliseconds: delay), () {
      syncAll();
    });
  }

  /// Résout les conflits de double saisie (même chauffeur, même date, même montant)
  Future<void> resolveConflicts() async {
    final offlinePayments = offlineStorage.getAllOfflinePayments();
    final seen = <String>{};

    for (final paiement in offlinePayments) {
      final key = '${paiement.chauffeurId}_${paiement.date}_${paiement.montant}';
      if (seen.contains(key)) {
        AppLogger.w('[Sync] Conflit détecté (doublon supprimé): ${paiement.id}');
        await offlineStorage.removeOfflinePayment(paiement.id);
      } else {
        seen.add(key);
      }
    }
  }
}

/// Résultat d'une synchronisation
class SyncResult {
  final int success;
  final int failed;
  final int skipped;
  final SyncStatus status;

  const SyncResult({
    required this.success,
    required this.failed,
    required this.skipped,
    this.status = SyncStatus.idle,
  });

  int get total => success + failed + skipped;
  bool get hasErrors => failed > 0;
}

/// Statut de la synchronisation
enum SyncStatus {
  idle,               // Rien à faire
  syncing,            // En cours de sync
  waitingConnection,  // En attente de connexion
  offline,            // Pas de connexion
  partialError,       // Certains paiements ont échoué
  error,              // Erreur générale
  busy,               // Déjà en cours
  maxRetriesReached,  // Nombre max de tentatives atteint
}
