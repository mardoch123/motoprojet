import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/paiements/presentation/paiements_provider.dart';

/// Hub principal des paiements — accès rapide aux sous-écrans
class PaiementsScreen extends ConsumerStatefulWidget {
  const PaiementsScreen({super.key});

  @override
  ConsumerState<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends ConsumerState<PaiementsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(paiementsListProvider.notifier).loadPaiements());
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isConnectedProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final paiementsState = ref.watch(paiementsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiements'),
        actions: [
          // Indicateur connexion + sync
          isConnected.when(
            data: (connected) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.push('/paiements/sync'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: connected
                          ? (pendingCount > 0 ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15))
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connected ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: connected ? (pendingCount > 0 ? Colors.orange : Colors.green) : Colors.orange,
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 4),
                          Text('$pendingCount',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                  color: connected ? Colors.orange : Colors.orange)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Icon(Icons.cloud_off),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(paiementsListProvider.notifier).loadPaiements(),
        child: Column(
          children: [
            // ── Résumé financier ──
            _buildSummaryCard(paiementsState),

            // ── Actions rapides ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildQuickAction(
                    icon: Icons.add_circle,
                    label: 'Saisie rapide',
                    color: AppTheme.primaryColor,
                    onTap: () => context.push('/paiements/saisie'),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    icon: Icons.history,
                    label: 'Historique',
                    color: Colors.blue,
                    onTap: () => context.push('/paiements/historique'),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    icon: Icons.sync,
                    label: 'En attente',
                    color: pendingCount > 0 ? Colors.orange : Colors.grey,
                    badge: pendingCount > 0 ? '$pendingCount' : null,
                    onTap: () => context.push('/paiements/sync'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Derniers paiements ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Derniers paiements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/paiements/historique'),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
            ),

            // ── Liste ──
            Expanded(
              child: paiementsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paiementsState.paiements.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: paiementsState.paiements.length.clamp(0, 20),
                          itemBuilder: (context, index) {
                            final p = paiementsState.paiements[index];
                            return _buildPaiementTile(p);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/paiements/saisie'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau paiement'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCard(PaiementsListState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total du jour', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${state.totalMontant.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transactions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${state.paiements.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(top: -4, right: -4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaiementTile(dynamic p) {
    final isKKiaPay = p.mode == 'mobile_money_kkiapay';
    final modeColor = isKKiaPay ? const Color(0xFFFF6F00) : (p.mode == 'mobile_money' ? Colors.blue : Colors.green);
    final modeIcon = isKKiaPay ? Icons.phone_android : (p.mode == 'mobile_money' ? Icons.phone_android : Icons.payments);
    final modeLabel = isKKiaPay ? 'KKiaPay' : (p.mode == 'mobile_money' ? 'Mobile Money' : 'Espèces');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: modeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(modeIcon, color: modeColor, size: 20),
        ),
        title: Text('${p.montant.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${p.date ?? ''} • $modeLabel', style: const TextStyle(fontSize: 12)),
        trailing: !p.synchroniseOffline
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync, size: 10, color: Colors.orange),
                    SizedBox(width: 2),
                    Text('En attente', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : const Icon(Icons.check_circle, color: Colors.green, size: 18),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payments, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun paiement', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          const Text('Appuyez sur + pour enregistrer', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
