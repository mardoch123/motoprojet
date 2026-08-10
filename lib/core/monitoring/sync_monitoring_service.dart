import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SYNC MONITORING — Suivi du taux de succès de synchronisation offline
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Critique métier : les paiements enregistrés hors-ligne doivent être
/// synchronisés dès le retour réseau. Ce service suit :
/// - Nombre de paiements créés offline
/// - Nombre synchronisés avec succès
/// - Nombre en échec (et raison)
/// - Taux de succès global
/// - Délai moyen de synchronisation
///
/// Les données sont persistées localement (Hive) et envoyées au backend.
/// ═══════════════════════════════════════════════════════════════════════════

const String _kSyncBox = 'sync_monitoring';

/// Résultat d'une tentative de synchronisation
enum SyncResult { success, failed, pending }

/// Entrée de monitoring pour un paiement offline
class SyncEntry {
  final String paiementId;
  final DateTime createdAt;
  DateTime? syncedAt;
  SyncResult status;
  String? errorMessage;
  int retryCount;

  SyncEntry({
    required this.paiementId,
    required this.createdAt,
    this.syncedAt,
    this.status = SyncResult.pending,
    this.errorMessage,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': paiementId,
    'createdAt': createdAt.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
    'status': status.name,
    'error': errorMessage,
    'retries': retryCount,
  };

  factory SyncEntry.fromJson(Map data) => SyncEntry(
    paiementId: data['id'] as String,
    createdAt: DateTime.parse(data['createdAt'] as String),
    syncedAt: data['syncedAt'] != null ? DateTime.tryParse(data['syncedAt'] as String) : null,
    status: SyncResult.values.firstWhere((e) => e.name == data['status'], orElse: () => SyncResult.pending),
    errorMessage: data['error'] as String?,
    retryCount: data['retries'] as int? ?? 0,
  );
}

/// Statistiques globales de synchronisation
class SyncStats {
  final int totalOffline;
  final int synced;
  final int failed;
  final int pending;
  final double successRate;
  final double avgSyncDelaySeconds;

  const SyncStats({
    required this.totalOffline,
    required this.synced,
    required this.failed,
    required this.pending,
    required this.successRate,
    required this.avgSyncDelaySeconds,
  });

  Map<String, dynamic> toJson() => {
    'totalOffline': totalOffline,
    'synced': synced,
    'failed': failed,
    'pending': pending,
    'successRate': successRate,
    'avgDelaySec': avgSyncDelaySeconds,
  };
}

class SyncMonitoringService {
  static SyncMonitoringService? _instance;
  static SyncMonitoringService get instance => _instance ??= SyncMonitoringService._();
  SyncMonitoringService._();

  Box? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_kSyncBox);
      _initialized = true;
      AppLogger.i('[SyncMonitoring] Initialisé');
    } catch (e) {
      AppLogger.e('[SyncMonitoring] Erreur init: $e');
    }
  }

  /// Enregistre un nouveau paiement créé hors-ligne.
  void recordOfflinePayment(String paiementId) {
    if (!_initialized || _box == null) return;

    final entry = SyncEntry(paiementId: paiementId, createdAt: DateTime.now());
    _box!.put(paiementId, entry.toJson());
    AppLogger.i('[SyncMonitoring] Paiement offline enregistré: $paiementId');
  }

  /// Marque un paiement comme synchronisé avec succès.
  void recordSyncSuccess(String paiementId) {
    if (!_initialized || _box == null) return;

    final data = _box!.get(paiementId);
    if (data == null) return;

    final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
    entry.status = SyncResult.success;
    entry.syncedAt = DateTime.now();
    _box!.put(paiementId, entry.toJson());
  }

  /// Marque un paiement comme échec de synchronisation.
  void recordSyncFailure(String paiementId, String error) {
    if (!_initialized || _box == null) return;

    final data = _box!.get(paiementId);
    if (data == null) return;

    final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
    entry.status = SyncResult.failed;
    entry.errorMessage = error;
    entry.retryCount += 1;
    _box!.put(paiementId, entry.toJson());
  }

  /// Calcule les statistiques globales.
  SyncStats getStats() {
    if (!_initialized || _box == null) {
      return const SyncStats(
        totalOffline: 0, synced: 0, failed: 0, pending: 0,
        successRate: 0, avgSyncDelaySeconds: 0,
      );
    }

    int total = 0, synced = 0, failed = 0, pending = 0;
    double totalDelay = 0;
    int delayCount = 0;

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data == null) continue;

      final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
      total++;

      switch (entry.status) {
        case SyncResult.success:
          synced++;
          if (entry.syncedAt != null) {
            totalDelay += entry.syncedAt!.difference(entry.createdAt).inSeconds;
            delayCount++;
          }
          break;
        case SyncResult.failed:
          failed++;
          break;
        case SyncResult.pending:
          pending++;
          break;
      }
    }

    final resolved = synced + failed;
    final successRate = resolved == 0 ? 0 : synced / resolved;
    final avgDelay = delayCount == 0 ? 0 : totalDelay / delayCount;

    return SyncStats(
      totalOffline: total,
      synced: synced,
      failed: failed,
      pending: pending,
      successRate: (successRate).toDouble(),
      avgSyncDelaySeconds: (avgDelay).toDouble(),
    );
  }

  /// Retourne les paiements en échec (pour retry).
  List<SyncEntry> getFailedPayments() {
    if (!_initialized || _box == null) return [];

    final failed = <SyncEntry>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data == null) continue;
      final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
      if (entry.status == SyncResult.failed) {
        failed.add(entry);
      }
    }
    return failed;
  }

  /// Retourne les paiements en attente.
  List<SyncEntry> getPendingPayments() {
    if (!_initialized || _box == null) return [];

    final pending = <SyncEntry>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data == null) continue;
      final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
      if (entry.status == SyncResult.pending) {
        pending.add(entry);
      }
    }
    return pending;
  }

  /// Exporte les stats pour envoi au backend.
  Map<String, dynamic> exportStats() {
    return {
      'stats': getStats().toJson(),
      'failedCount': getFailedPayments().length,
      'pendingCount': getPendingPayments().length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Nettoie les entrées anciennes (sync réussies depuis > 7 jours).
  Future<void> cleanup() async {
    if (!_initialized || _box == null) return;

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final keysToRemove = <String>[];

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data == null) continue;
      final entry = SyncEntry.fromJson(Map<String, dynamic>.from(data));
      if (entry.status == SyncResult.success && entry.syncedAt != null && entry.syncedAt!.isBefore(cutoff)) {
        keysToRemove.add(key.toString());
      }
    }

    for (final key in keysToRemove) {
      await _box!.delete(key);
    }

    if (keysToRemove.isNotEmpty) {
      AppLogger.i('[SyncMonitoring] Nettoyé ${keysToRemove.length} entrées anciennes');
    }
  }
}

/// Provider
final syncMonitoringProvider = Provider<SyncMonitoringService>((ref) {
  return SyncMonitoringService.instance;
});

/// Provider pour les stats de sync
final syncStatsProvider = Provider<SyncStats>((ref) {
  return SyncMonitoringService.instance.getStats();
});
