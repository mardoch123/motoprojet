import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/network/sync_service.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/paiements/presentation/paiements_provider.dart';

/// Écran "Paiements en attente de synchronisation" — visible par l'admin.
/// Montre tous les paiements hors-ligne avec leur statut de sync.
class PendingSyncScreen extends ConsumerStatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  ConsumerState<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends ConsumerState<PendingSyncScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingItems = ref.watch(pendingSyncListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        actions: [
          // Statut sync
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _buildStatusBadge(syncStatus)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Résumé ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pendingItems.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                  pendingItems.isEmpty ? Colors.green.shade100 : Colors.orange.shade100,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  pendingItems.isEmpty ? Icons.cloud_done : Icons.cloud_upload,
                  size: 48,
                  color: pendingItems.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  pendingItems.isEmpty ? 'Tout est synchronisé' : '${pendingItems.length} paiement(s) en attente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: pendingItems.isEmpty ? Colors.green.shade800 : Colors.orange.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  pendingItems.isEmpty
                      ? 'Tous les paiements sont en ligne'
                      : 'En attente de connexion réseau',
                  style: TextStyle(color: pendingItems.isEmpty ? Colors.green.shade600 : Colors.orange.shade600),
                ),
              ],
            ),
          ),

          // ── Bouton sync manuelle ──
          if (pendingItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _forceSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Synchronisation...' : 'Forcer la synchronisation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          // ── Liste des paiements en attente ──
          Expanded(
            child: pendingItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade200),
                        const SizedBox(height: 16),
                        const Text('Aucun paiement bloqué',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pendingItems.length,
                    itemBuilder: (context, index) {
                      return _buildPendingItem(pendingItems[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(SyncStatus status) {
    final (String label, Color color, IconData icon) = switch (status) {
      SyncStatus.idle => ('À jour', Colors.green, Icons.check_circle),
      SyncStatus.syncing => ('En cours...', Colors.blue, Icons.sync),
      SyncStatus.waitingConnection => ('Hors-ligne', Colors.orange, Icons.cloud_off),
      SyncStatus.offline => ('Hors-ligne', Colors.orange, Icons.cloud_off),
      SyncStatus.partialError => ('Erreurs partielles', Colors.orange, Icons.warning),
      SyncStatus.error => ('Erreur', Colors.red, Icons.error),
      SyncStatus.busy => ('Occupé', Colors.blue, Icons.hourglass_top),
      SyncStatus.maxRetriesReached => ('Max retries', Colors.red, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildPendingItem(Map<String, dynamic> item) {
    final data = Map<String, dynamic>.from(item['data'] as Map);
    final montant = (data['montant'] as num).toDouble();
    final date = data['date'] as String;
    final mode = data['mode'] as String? ?? 'cash';
    final attemptCount = item['attemptCount'] as int? ?? 0;
    final lastAttempt = item['lastAttempt'] as String?;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${montant.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd MMM yyyy HH:mm', 'fr_FR').format(DateTime.parse(date)),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Badge tentatives
                if (attemptCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: attemptCount >= 3 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${attemptCount} tentative${attemptCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: attemptCount >= 3 ? Colors.red : Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            if (lastAttempt != null) ...[
              const SizedBox(height: 8),
              Text('Dernière tentative: ${DateFormat('HH:mm:ss').format(DateTime.parse(lastAttempt))}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(mode == 'mobile_money' ? Icons.phone_android : Icons.payments, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(mode == 'mobile_money' ? 'Mobile Money' : 'Espèces',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncService = ref.read(syncServiceProvider);
      final result = await syncService.syncAll();

      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync: ${result.success} succès, ${result.failed} échecs'),
            backgroundColor: result.hasErrors ? Colors.orange : Colors.green,
          ),
        );
        // Rafraîchir la liste
        ref.invalidate(pendingSyncListProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sync: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
