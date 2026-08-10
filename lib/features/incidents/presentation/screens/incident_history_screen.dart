import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/auth/permissions.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/incidents/presentation/incidents_provider.dart';

/// ─── Historique des incidents d'un véhicule + suivi réparations ─────────────
/// Affiche tous les incidents (actifs et résolus) pour un véhicule donné.
/// Permet le suivi des réparations (statut, coût) pour admin/gestionnaire.
class IncidentHistoryScreen extends ConsumerStatefulWidget {
  final String vehiculeId;
  final String? vehiculePlaque;

  const IncidentHistoryScreen({
    super.key,
    required this.vehiculeId,
    this.vehiculePlaque,
  });

  @override
  ConsumerState<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends ConsumerState<IncidentHistoryScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(incidentsProvider.notifier).loadIncidents(vehiculeId: widget.vehiculeId);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidentsProvider);
    final allIncidents = state.incidents
        .where((i) => i.vehiculeId == widget.vehiculeId)
        .toList();
    final activeIncidents = allIncidents.where((i) => i.isActive).toList();
    final resolvedIncidents = allIncidents.where((i) => i.isResolved).toList();

    // Stats rapides
    final totalCost = allIncidents.fold<double>(
        0, (sum, i) => sum + i.coutReparation);
    final activeCount = activeIncidents.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehiculePlaque != null
            ? 'Incidents — ${widget.vehiculePlaque}'
            : 'Incidents'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
        bottom: (allIncidents.isNotEmpty)
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Actifs ($activeCount)'),
                  Tab(text: 'Historique (${resolvedIncidents.length})'),
                  Tab(text: 'Tout (${allIncidents.length})'),
                ],
                indicatorColor: Colors.white,
              )
            : null,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : allIncidents.isEmpty
              ? _buildEmpty()
              : _buildContent(allIncidents, activeIncidents, resolvedIncidents,
                  activeCount, totalCost),
    );
  }

  Widget _buildContent(
    List<IncidentModel> all,
    List<IncidentModel> active,
    List<IncidentModel> resolved,
    int activeCount,
    double totalCost,
  ) {
    return Column(
      children: [
        // ── Bannière stats ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: activeCount > 0
                  ? [AppTheme.errorColor, Colors.orange.shade700]
                  : [AppTheme.successColor, AppTheme.successColor],
            ),
          ),
          child: Row(
            children: [
              Icon(
                activeCount > 0 ? Icons.warning_amber : Icons.check_circle,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeCount > 0
                          ? '$activeCount incident${activeCount > 1 ? 's' : ''} actif${activeCount > 1 ? 's' : ''}'
                          : 'Aucun incident actif',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (totalCost > 0)
                      Text(
                        'Coût total réparations: ${_fmt(totalCost)} F',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Liste par section ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Incidents actifs', active.length, AppTheme.errorColor),
                const SizedBox(height: 8),
                ...active.map((i) => _buildIncidentCard(i)),
                const SizedBox(height: 16),
              ],
              if (resolved.isNotEmpty) ...[
                _sectionHeader('Résolus / Classés', resolved.length, AppTheme.successColor),
                const SizedBox(height: 8),
                ...resolved.map((i) => _buildIncidentCard(i)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Text('($count)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildIncidentCard(IncidentModel incident) {
    final perms = ref.read(permissionsProvider);
    final typeColor = _typeColor(incident.type);
    final severityColor = _severityColor(incident.severity);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showIncidentDetail(incident),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne du haut : type + sévérité + date ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon(incident.type), size: 14, color: typeColor),
                        const SizedBox(width: 4),
                        Text(incident.typeLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(incident.severityLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: severityColor)),
                  ),
                  const Spacer(),
                  Text(incident.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),

              const SizedBox(height: 8),

              // ── Description ──
              if (incident.description != null)
                Text(
                  incident.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),

              if (incident.lieu != null && incident.lieu!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(incident.lieu!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // ── Photos thumbnails ──
              if (incident.photoUrls.isNotEmpty)
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: incident.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        incident.photoUrls[index],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade200,
                          child: Icon(Icons.broken_image, size: 20, color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // ── Statut réparation + coût ──
              Row(
                children: [
                  // Statut incident
                  _statusBadge(incident.statut),
                  const SizedBox(width: 8),
                  // Statut réparation
                  _repairBadge(incident.statutReparation),
                  const Spacer(),
                  if (incident.coutReparation > 0)
                    Text(
                      'Réparation: ${_fmt(incident.coutReparation)} F',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: incident.coutReparation > 0 ? AppTheme.errorColor : Colors.grey,
                      ),
                    ),
                ],
              ),

              // ── Actions de suivi réparation (admin/gestionnaire) ──
              if (incident.isActive && perms.can(Capability.createIncidents)) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (incident.statutReparation == 'en_attente')
                      _actionChip('Démarrer réparation', Icons.play_arrow, Colors.orange,
                          () => _updateRepair(incident, statutReparation: 'en_cours')),
                    if (incident.statutReparation == 'en_cours')
                      _actionChip('Marquer terminée', Icons.check_circle, AppTheme.successColor,
                          () => _updateRepair(incident, statutReparation: 'termine')),
                    const SizedBox(width: 8),
                    _actionChip('Résoudre incident', Icons.healing, AppTheme.successColor,
                        () => _resolveIncident(incident)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String statut) {
    final (label, color) = switch (statut) {
      'signale' => ('Signalé', Colors.orange),
      'en_cours' => ('En cours', Colors.blue),
      'resolu' => ('Résolu', AppTheme.successColor),
      'classe_sans_suite' => ('Classé', Colors.grey),
      _ => (statut, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _repairBadge(String statut) {
    final (label, icon, color) = switch (statut) {
      'en_attente' => ('Réparation en attente', Icons.hourglass_empty, Colors.grey),
      'en_cours' => ('Réparation en cours', Icons.build, Colors.orange),
      'termine' => ('Réparation terminée', Icons.check, AppTheme.successColor),
      _ => (statut, Icons.help, Colors.grey),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
          Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun incident pour ce véhicule',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('L\'historique des incidents apparaîtra ici.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _updateRepair(IncidentModel incident,
      {String? statutReparation, double? coutReparation}) async {
    // Demander le coût si pas encore renseigné
    if (coutReparation == null && incident.coutReparation == 0) {
      final cost = await _showCostDialog();
      if (cost != null) coutReparation = cost;
    }

    final success = await ref.read(incidentsProvider.notifier).updateRepair(
          incidentId: incident.id,
          statutReparation: statutReparation,
          coutReparation: coutReparation,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Réparation mise à jour' : 'Erreur lors de la mise à jour'),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _resolveIncident(IncidentModel incident) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Résoudre l\'incident ?'),
        content: const Text(
          'Le véhicule sera remis en service et réintégré dans le calcul du taux de recouvrement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirmer'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(incidentsProvider.notifier).updateRepair(
          incidentId: incident.id,
          statut: 'resolu',
          statutReparation: 'termine',
          dateRemiseEnService: DateTime.now().toIso8601String().split('T').first,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Incident résolu — véhicule remis en service'
            : 'Erreur lors de la résolution'),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<double?> _showCostDialog() async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Coût de la réparation'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Montant (FCFA)',
            hintText: 'Ex: 50000',
            prefixIcon: const Icon(Icons.payments),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Ignorer')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value ?? 0);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showIncidentDetail(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _IncidentDetailSheet(
          incident: incident,
          scrollController: scrollController,
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Color _typeColor(String type) => switch (type) {
        'panne' => Colors.orange,
        'accident' => Colors.red,
        'vol' => Colors.purple,
        _ => Colors.grey,
      };

  IconData _typeIcon(String type) => switch (type) {
        'panne' => Icons.build,
        'accident' => Icons.car_crash,
        'vol' => Icons.gpp_bad,
        _ => Icons.report_problem,
      };

  Color _severityColor(String severity) => switch (severity) {
        'legere' => Colors.green,
        'moyenne' => Colors.orange,
        'grave' => Colors.red,
        _ => Colors.grey,
      };

  String _fmt(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
  }
}

/// ─── Sheet détail d'un incident ─────────────────────────────────────────────
class _IncidentDetailSheet extends StatelessWidget {
  final IncidentModel incident;
  final ScrollController scrollController;

  const _IncidentDetailSheet({required this.incident, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),),
          const SizedBox(height: 16),

          // Titre
          Row(
            children: [
              Icon(_typeIcon(incident.type), color: _typeColor(incident.type), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.typeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Sévérité: ${incident.severityLabel}', style: TextStyle(fontSize: 12, color: _severityColor(incident.severity))),
                  ],
                ),
              ),
              Text(incident.date, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Description
          if (incident.description != null) ...[
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            Text(incident.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
          ],

          // Lieu
          if (incident.lieu != null && incident.lieu!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(incident.lieu!, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Photos
          if (incident.photoUrls.isNotEmpty) ...[
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: incident.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    incident.photoUrls[index],
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160, height: 160,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(),

          // Suivi réparation
          const Text('Suivi réparation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _infoRow('Statut incident', incident.statut),
          _infoRow('Statut réparation', incident.statutReparationLabel),
          if (incident.coutReparation > 0)
            _infoRow('Coût réparation', '${incident.coutReparation.toStringAsFixed(0)} F'),
          if (incident.dateRemiseEnService != null)
            _infoRow('Remise en service', incident.dateRemiseEnService!),
          if (incident.declaredBy != null)
            _infoRow('Déclaré par', incident.declaredBy!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'panne' => Colors.orange,
        'accident' => Colors.red,
        'vol' => Colors.purple,
        _ => Colors.grey,
      };

  IconData _typeIcon(String type) => switch (type) {
        'panne' => Icons.build,
        'accident' => Icons.car_crash,
        'vol' => Icons.gpp_bad,
        _ => Icons.report_problem,
      };

  Color _severityColor(String severity) => switch (severity) {
        'legere' => Colors.green,
        'moyenne' => Colors.orange,
        'grave' => Colors.red,
        _ => Colors.grey,
      };
}
