import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/monitoring/sync_monitoring_service.dart';
import 'package:motoprojet/core/monitoring/usage_tracking_service.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ÉCRAN MONITORING — Tableau de bord technique (super_admin)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Affiche les métriques clés :
/// - Taux de succès sync offline (critique métier)
/// - Écrans les plus utilisés
/// - Taux d'échec des actions critiques
/// - État du backend (via /monitoring/health)
/// ═══════════════════════════════════════════════════════════════════════════
class MonitoringDashboardScreen extends ConsumerStatefulWidget {
  const MonitoringDashboardScreen({super.key});

  @override
  ConsumerState<MonitoringDashboardScreen> createState() => _MonitoringDashboardScreenState();
}

class _MonitoringDashboardScreenState extends ConsumerState<MonitoringDashboardScreen> {
  Map<String, dynamic>? _backendHealth;
  bool _loadingHealth = true;

  @override
  void initState() {
    super.initState();
    _loadBackendHealth();
  }

  Future<void> _loadBackendHealth() async {
    try {
      final client = ref.read(apiClientProvider);
      final resp = await client.get('/monitoring/health');
      setState(() {
        _backendHealth = resp.data as Map<String, dynamic>?;
        _loadingHealth = false;
      });
    } catch (e) {
      setState(() => _loadingHealth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStats = SyncMonitoringService.instance.getStats();
    final topScreens = UsageTrackingService.instance.getTopScreens(limit: 8);
    final actionMetrics = UsageTrackingService.instance.getActionMetrics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackendHealth,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBackendHealth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── SYNC OFFLINE (critique métier) ──────────────────────────
            _buildSectionTitle('Synchronisation hors-ligne', Icons.cloud_sync),
            const SizedBox(height: 8),
            _buildSyncCard(syncStats),
            const SizedBox(height: 24),

            // ─── ÉCRANS POPULAIRES ───────────────────────────────────────
            _buildSectionTitle('Écrans les plus utilisés', Icons.bar_chart),
            const SizedBox(height: 8),
            _buildScreensCard(topScreens),
            const SizedBox(height: 24),

            // ─── ACTIONS CRITIQUES ───────────────────────────────────────
            if (actionMetrics.isNotEmpty) ...[
              _buildSectionTitle('Taux de succès des actions', Icons.check_circle),
              const SizedBox(height: 8),
              _buildActionsCard(actionMetrics),
              const SizedBox(height: 24),
            ],

            // ─── ÉTAT BACKEND ────────────────────────────────────────────
            _buildSectionTitle('État du serveur', Icons.dns),
            const SizedBox(height: 8),
            _buildBackendCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brandGreen),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSyncCard(SyncStats stats) {
    final successColor = stats.successRate >= 0.95
        ? AppColors.statusSuccess
        : stats.successRate >= 0.8
            ? AppColors.statusWarning
            : AppColors.statusError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Taux de succès
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taux de succès', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${(stats.successRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.successRate,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(successColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 16),

            // Détails
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('Total offline', stats.totalOffline.toString(), AppColors.statusInfo),
                _buildStatChip('Synchronisés', stats.synced.toString(), AppColors.statusSuccess),
                _buildStatChip('En échec', stats.failed.toString(), AppColors.statusError),
                _buildStatChip('En attente', stats.pending.toString(), AppColors.statusWarning),
              ],
            ),

            if (stats.avgSyncDelaySeconds > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Délai moyen : ${_formatDelay(stats.avgSyncDelaySeconds)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildScreensCard(List<ScreenUsageEntry> screens) {
    if (screens.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Aucune donnée', style: TextStyle(color: Colors.grey.shade500)),
          ),
        ),
      );
    }

    final maxVisits = screens.first.visitCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: screens.map((screen) {
            final ratio = maxVisits > 0 ? screen.visitCount / maxVisits : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _shortenScreenName(screen.screenName),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${screen.visitCount}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionsCard(List<ActionMetricEntry> actions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: actions.map((action) {
            final color = action.successRate >= 0.95
                ? AppColors.statusSuccess
                : action.successRate >= 0.8
                    ? AppColors.statusWarning
                    : AppColors.statusError;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      action.actionName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${(action.successRate * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${action.totalCount})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBackendCard() {
    if (_loadingHealth) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_backendHealth == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.statusError),
              const SizedBox(width: 12),
              const Expanded(child: Text('Impossible de contacter le serveur')),
              TextButton(onPressed: _loadBackendHealth, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final status = _backendHealth!['status'] as String? ?? 'unknown';
    final uptime = _backendHealth!['uptime'] as num? ?? 0;
    final database = _backendHealth!['database'] as String? ?? 'unknown';
    final sentryEnabled = _backendHealth!['sentry'] as bool? ?? false;

    final statusColor = status == 'ok'
        ? AppColors.statusSuccess
        : status == 'degraded'
            ? AppColors.statusWarning
            : AppColors.statusError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Statut', style: TextStyle(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Détails
            _buildInfoRow('Base de données', database == 'connected' ? 'Connectée' : 'Déconnectée',
                database == 'connected' ? AppColors.statusSuccess : AppColors.statusError),
            const SizedBox(height: 8),
            _buildInfoRow('Uptime', _formatUptime(uptime.toDouble()), AppColors.textSecondaryLight),
            const SizedBox(height: 8),
            _buildInfoRow('Sentry', sentryEnabled ? 'Actif' : 'Désactivé',
                sentryEnabled ? AppColors.statusSuccess : AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  String _shortenScreenName(String name) {
    return name
        .replaceAll('/admin/', '')
        .replaceAll('/gestionnaire/', '')
        .replaceAll('/chauffeur/', '')
        .replaceAll('/', ' > ');
  }

  String _formatDelay(double seconds) {
    if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(0)}min';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  String _formatUptime(double seconds) {
    final days = (seconds / 86400).floor();
    final hours = ((seconds % 86400) / 3600).floor();
    if (days > 0) return '${days}j ${hours}h';
    final minutes = ((seconds % 3600) / 60).floor();
    return '${hours}h ${minutes}min';
  }
}
