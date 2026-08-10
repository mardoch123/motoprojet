import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// USAGE TRACKING — Métriques d'usage anonymisées
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Suit les écrans les plus utilisés et les taux d'échec pour prioriser
/// les améliorations. Aucune donnée personnelle n'est collectée.
///
/// Données stockées localement (Hive) et envoyées périodiquement au backend.
/// ═══════════════════════════════════════════════════════════════════════════

const String _kUsageBox = 'usage_metrics';

/// Compteur d'écran : combien de fois chaque écran est visité
class ScreenUsageEntry {
  final String screenName;
  int visitCount;
  DateTime lastVisited;

  ScreenUsageEntry({
    required this.screenName,
    this.visitCount = 0,
    DateTime? lastVisited,
  }) : lastVisited = lastVisited ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'screen': screenName,
    'count': visitCount,
    'lastVisited': lastVisited.toIso8601String(),
  };
}

/// Compteur d'actions : succès/échec des actions critiques
class ActionMetricEntry {
  final String actionName;
  int successCount;
  int failureCount;

  ActionMetricEntry({
    required this.actionName,
    this.successCount = 0,
    this.failureCount = 0,
  });

  int get totalCount => successCount + failureCount;
  double get successRate => totalCount == 0 ? 0 : successCount / totalCount;

  Map<String, dynamic> toJson() => {
    'action': actionName,
    'success': successCount,
    'failure': failureCount,
    'rate': successRate,
  };
}

class UsageTrackingService {
  static UsageTrackingService? _instance;
  static UsageTrackingService get instance => _instance ??= UsageTrackingService._();
  UsageTrackingService._();

  Box? _box;
  bool _initialized = false;

  /// Initialise le service (à appeler au démarrage).
  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_kUsageBox);
      _initialized = true;
      AppLogger.i('[UsageTracking] Initialisé');
    } catch (e) {
      AppLogger.e('[UsageTracking] Erreur init: $e');
    }
  }

  /// Enregistre une visite d'écran.
  void trackScreen(String screenName) {
    if (!_initialized || _box == null) return;

    final key = 'screen_$screenName';
    final existing = _box!.get(key);

    if (existing != null) {
      final entry = ScreenUsageEntry(
        screenName: screenName,
        visitCount: (existing['count'] as int) + 1,
        lastVisited: DateTime.now(),
      );
      _box!.put(key, entry.toJson());
    } else {
      final entry = ScreenUsageEntry(screenName: screenName, visitCount: 1);
      _box!.put(key, entry.toJson());
    }
  }

  /// Enregistre le résultat d'une action (succès ou échec).
  void trackAction(String actionName, {required bool success}) {
    if (!_initialized || _box == null) return;

    final key = 'action_$actionName';
    final existing = _box!.get(key);

    if (existing != null) {
      final entry = {
        'action': actionName,
        'success': (existing['success'] as int) + (success ? 1 : 0),
        'failure': (existing['failure'] as int) + (success ? 0 : 1),
      };
      final total = (entry['success'] as int) + (entry['failure'] as int);
      entry['rate'] = total == 0 ? 0.0 : (entry['success'] as int) / total;
      _box!.put(key, entry);
    } else {
      final entry = {
        'action': actionName,
        'success': success ? 1 : 0,
        'failure': success ? 0 : 1,
        'rate': success ? 1.0 : 0.0,
      };
      _box!.put(key, entry);
    }
  }

  /// Retourne les métriques d'écrans triées par popularité.
  List<ScreenUsageEntry> getTopScreens({int limit = 10}) {
    if (!_initialized || _box == null) return [];

    final screens = <ScreenUsageEntry>[];
    for (final key in _box!.keys) {
      if (key.toString().startsWith('screen_')) {
        final data = _box!.get(key) as Map;
        screens.add(ScreenUsageEntry(
          screenName: data['screen'] as String,
          visitCount: data['count'] as int,
          lastVisited: DateTime.tryParse(data['lastVisited'] as String? ?? ''),
        ));
      }
    }
    screens.sort((a, b) => b.visitCount.compareTo(a.visitCount));
    return screens.take(limit).toList();
  }

  /// Retourne les métriques d'actions.
  List<ActionMetricEntry> getActionMetrics() {
    if (!_initialized || _box == null) return [];

    final actions = <ActionMetricEntry>[];
    for (final key in _box!.keys) {
      if (key.toString().startsWith('action_')) {
        final data = _box!.get(key) as Map;
        actions.add(ActionMetricEntry(
          actionName: data['action'] as String,
          successCount: data['success'] as int,
          failureCount: data['failure'] as int,
        ));
      }
    }
    return actions;
  }

  /// Exporte toutes les métriques pour envoi au backend.
  Map<String, dynamic> exportMetrics() {
    return {
      'screens': getTopScreens(limit: 20).map((s) => s.toJson()).toList(),
      'actions': getActionMetrics().map((a) => a.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Réinitialise les métriques (après envoi réussi).
  Future<void> resetMetrics() async {
    if (!_initialized || _box == null) return;
    await _box!.clear();
  }
}

/// Observer de navigation pour tracker automatiquement les écrans visités.
class UsageTrackingObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    final screenName = route.settings.name ?? route.runtimeType.toString();
    UsageTrackingService.instance.trackScreen(screenName);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      final screenName = newRoute.settings.name ?? newRoute.runtimeType.toString();
      UsageTrackingService.instance.trackScreen(screenName);
    }
  }
}

/// Provider pour accéder au service.
final usageTrackingProvider = Provider<UsageTrackingService>((ref) {
  return UsageTrackingService.instance;
});
