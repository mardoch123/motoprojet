import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/paiements/presentation/paiements_provider.dart';
import 'package:motoprojet/shared/models/paiement_model.dart';

/// Historique des paiements avec filtres multiples et export
class HistoriquePaiementsScreen extends ConsumerStatefulWidget {
  const HistoriquePaiementsScreen({super.key});

  @override
  ConsumerState<HistoriquePaiementsScreen> createState() => _HistoriquePaiementsScreenState();
}

class _HistoriquePaiementsScreenState extends ConsumerState<HistoriquePaiementsScreen> {
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(paiementsListProvider.notifier).loadPaiements());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paiementsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique paiements'),
        actions: [
          // Bouton filtres
          IconButton(
            icon: Icon(_filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: state.chauffeurFilter != null || state.dateDebut != null ? AppTheme.primaryColor : null),
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
          ),
          // Bouton export
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exporter',
            onPressed: state.paiements.isEmpty ? null : () => _exportFiltres(state.paiements),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de filtres ──
          if (_filtersExpanded) _buildFiltersPanel(state),

          // ── Résumé ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Text('${state.paiements.length} paiement(s)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${state.totalMontant.toStringAsFixed(0)} FCFA',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
          ),

          // ── Liste ──
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.paiements.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => ref.read(paiementsListProvider.notifier).loadPaiements(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.paiements.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _buildPaiementCard(state.paiements[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/paiements/saisie'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ─── Panneau de filtres ────────────────────────────────────────────────────

  Widget _buildFiltersPanel(PaiementsListState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtre par date ──
          const Text('Période', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateChip(
                  label: state.dateDebut != null ? DateFormat('dd/MM/yy').format(DateTime.parse(state.dateDebut!)) : 'Début',
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16)),
              Expanded(
                child: _buildDateChip(
                  label: state.dateFin != null ? DateFormat('dd/MM/yy').format(DateTime.parse(state.dateFin!)) : 'Fin',
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Filtre par mode ──
          const Text('Mode', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildModeChip('Tous', null, state.modeFilter),
              _buildModeChip('KKiaPay', 'mobile_money_kkiapay', state.modeFilter),
              _buildModeChip('Mobile Money', 'mobile_money', state.modeFilter),
              _buildModeChip('Espèces', 'cash', state.modeFilter),
            ],
          ),
          const SizedBox(height: 12),

          // ── Effacer ──
          if (state.chauffeurFilter != null || state.dateDebut != null || state.modeFilter != null)
            TextButton.icon(
              onPressed: () => ref.read(paiementsListProvider.notifier).clearFilters(),
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Effacer les filtres'),
            ),
        ],
      ),
    );
  }

  Widget _buildDateChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String label, String? value, String? currentFilter) {
    final isSelected = currentFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) {
        ref.read(paiementsListProvider.notifier).setModeFilter(value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final dateStr = picked.toIso8601String().split('T')[0];
      if (isStart) {
        ref.read(paiementsListProvider.notifier).setDateRange(dateStr, ref.read(paiementsListProvider).dateFin);
      } else {
        ref.read(paiementsListProvider.notifier).setDateRange(ref.read(paiementsListProvider).dateDebut, dateStr);
      }
    }
  }

  // ─── Carte paiement ────────────────────────────────────────────────────────

  Widget _buildPaiementCard(PaiementModel paiement) {
    final isOffline = !paiement.synchroniseOffline && paiement.id.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icône mode
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (paiement.mode == 'mobile_money_kkiapay' ? const Color(0xFFFF6F00) : (paiement.mode == 'mobile_money' ? Colors.blue : Colors.green)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                paiement.mode == 'mobile_money_kkiapay' || paiement.mode == 'mobile_money' ? Icons.phone_android : Icons.payments,
                color: paiement.mode == 'mobile_money_kkiapay' ? const Color(0xFFFF6F00) : (paiement.mode == 'mobile_money' ? Colors.blue : Colors.green),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${paiement.montant.toStringAsFixed(0)} F',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isOffline) ...[
                        const SizedBox(width: 6),
                        Container(
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
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy', 'fr_FR').format(paiement.dateEnregistrement),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Véhicule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(paiement.vehiculeId.substring(0, 6).toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun paiement', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          const Text('Les paiements apparaîtront ici', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _exportFiltres(List<PaiementModel> paiements) {
    // Générer un CSV simple
    final buffer = StringBuffer();
    buffer.writeln('Date,Montant,Mode,Véhicule,Statut');
    for (final p in paiements) {
      buffer.writeln('${p.date},${p.montant.toStringAsFixed(0)},${p.mode},${p.vehiculeId},${p.synchroniseOffline ? "Sync" : "En attente"}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${paiements.length} paiement(s) exporté(s)')),
    );
  }
}
