import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/auth/permissions.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/incidents/presentation/incidents_provider.dart';
import 'package:motoprojet/features/vehicules/presentation/vehicules_provider.dart';

/// ─── Fiche véhicule avec onglets Info + Incidents ───────────────────────────
class VehiculeDetailScreen extends ConsumerStatefulWidget {
  final String vehiculeId;

  const VehiculeDetailScreen({super.key, required this.vehiculeId});

  @override
  ConsumerState<VehiculeDetailScreen> createState() => _VehiculeDetailScreenState();
}

class _VehiculeDetailScreenState extends ConsumerState<VehiculeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(vehiculeDetailProvider.notifier).loadDetail(widget.vehiculeId);
      ref.read(incidentsProvider.notifier).loadIncidents(vehiculeId: widget.vehiculeId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(vehiculeDetailProvider);
    final incidentsState = ref.watch(incidentsProvider);
    final data = detailState.data;
    final perms = ref.read(permissionsProvider);

    final incidents = incidentsState.incidents
        .where((i) => i.vehiculeId == widget.vehiculeId)
        .toList();
    final activeIncidents = incidents.where((i) => i.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(data != null ? (data['plaque'] as String? ?? 'Véhicule') : 'Véhicule'),
        actions: [
          if (perms.can(Capability.createIncidents))
            IconButton(
              icon: const Icon(Icons.warning_amber),
              tooltip: 'Signaler un incident',
              onPressed: () => context.push(
                '/incidents/new',
                extra: {'vehiculeId': widget.vehiculeId},
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Incidents'),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detailState.error != null
              ? _buildError(detailState.error!)
              : data == null
                  ? const Center(child: Text('Aucune donnée'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(data, perms),
                        _buildIncidentsTab(incidents, activeIncidents),
                      ],
                    ),
    );
  }

  // ─── Onglet Informations ────────────────────────────────────────────────────

  Widget _buildInfoTab(Map<String, dynamic> data, PermissionsService perms) {
    final plaque = data['plaque'] as String? ?? '—';
    final marque = data['marque'] as String? ?? '';
    final type = data['type'] as String? ?? 'moto';
    final statut = data['statut'] as String? ?? 'en_remboursement';
    final chauffeurNom = data['chauffeur_nom'] as String?;
    final couleurFlotte = data['couleur_flotte'] as String?;
    final prixAchat = _toDouble(data['prix_achat']);
    final totalVerse = _toDouble(data['total_verse']);
    final soldeRestant = _toDouble(data['solde_restant']);
    final pourcentage = _toDouble(data['pourcentage_rembourse']);
    final dateAchat = (data['date_achat'] as String?)?.substring(0, 10) ?? '—';

    final statutColor = _statutColor(statut);
    final isMoto = type == 'moto';

    return RefreshIndicator(
      onRefresh: () => ref.read(vehiculeDetailProvider.notifier).loadDetail(widget.vehiculeId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── En-tête véhicule ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statutColor, statutColor.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  isMoto ? Icons.two_wheeler : Icons.directions_car,
                  size: 56,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  plaque,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                if (marque.isNotEmpty)
                  Text(marque, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statutLabel(statut),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Incident actif ? ──
          if (statut == 'en_panne' || statut == 'accidente')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.errorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Véhicule exclu du calcul de recouvrement pendant la durée de l\'incident.',
                      style: TextStyle(fontSize: 12, color: AppTheme.errorColor.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),

          if (statut == 'en_panne' || statut == 'accidente')
            const SizedBox(height: 16),

          // ── Infos principales ──
          _card('Informations', [
            _infoRow('Type', isMoto ? 'Moto' : 'Voiture'),
            _infoRow('Plaque', plaque),
            if (marque.isNotEmpty) _infoRow('Marque', marque),
            _infoRow('Date d\'achat', dateAchat),
            if (chauffeurNom != null) _infoRow('Chauffeur', chauffeurNom),
            if (couleurFlotte != null) _infoRow('Statut flotte', _couleurFlotteLabel(couleurFlotte)),
          ]),

          const SizedBox(height: 12),

          // ── Financier (visible si permission) ──
          PermissionGate(
            capability: Capability.viewVehiclePrices,
            child: _card('Finances', [
              _infoRow('Prix d\'achat', '${_fmt(prixAchat)} F'),
              _infoRow('Total versé', '${_fmt(totalVerse)} F'),
              _infoRow('Solde restant', '${_fmt(soldeRestant)} F'),
              _progressRow(pourcentage, statutColor),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Actions ──
          Row(
            children: [
              if (perms.can(Capability.createIncidents))
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/incidents/new',
                      extra: {'vehiculeId': widget.vehiculeId},
                    ),
                    icon: const Icon(Icons.warning_amber, size: 18),
                    label: const Text('Signaler incident'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (perms.can(Capability.createIncidents))
                const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/vehicules/${widget.vehiculeId}/incidents'),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historique'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Onglet Incidents ──────────────────────────────────────────────────────

  Widget _buildIncidentsTab(List<IncidentModel> incidents, List<IncidentModel> activeIncidents) {
    if (incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun incident enregistré',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            if (ref.read(permissionsProvider).can(Capability.createIncidents))
              ElevatedButton.icon(
                onPressed: () => context.push(
                  '/incidents/new',
                  extra: {'vehiculeId': widget.vehiculeId},
                ),
                icon: const Icon(Icons.warning_amber),
                label: const Text('Signaler un incident'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(incidentsProvider.notifier).loadIncidents(vehiculeId: widget.vehiculeId),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Bouton nouveau
          if (ref.read(permissionsProvider).can(Capability.createIncidents)) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/incidents/new',
                  extra: {'vehiculeId': widget.vehiculeId},
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nouvel incident'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Résumé
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeIncidents.isNotEmpty
                  ? AppTheme.errorColor.withValues(alpha: 0.06)
                  : AppTheme.successColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  activeIncidents.isNotEmpty ? Icons.warning : Icons.check_circle,
                  color: activeIncidents.isNotEmpty ? AppTheme.errorColor : AppTheme.successColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeIncidents.isNotEmpty
                        ? '${activeIncidents.length} incident${activeIncidents.length > 1 ? 's' : ''} actif${activeIncidents.length > 1 ? 's' : ''}'
                        : 'Aucun incident actif — véhicule en service',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activeIncidents.isNotEmpty ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ),
                ),
                Text('${incidents.length} total',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Liste
          ...incidents.map((incident) => _buildIncidentCard(incident)),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(IncidentModel incident) {
    final typeColor = switch (incident.type) {
      'panne' => Colors.orange,
      'accident' => Colors.red,
      'vol' => Colors.purple,
      _ => Colors.grey,
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/vehicules/${widget.vehiculeId}/incidents'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  switch (incident.type) {
                    'panne' => Icons.build,
                    'accident' => Icons.car_crash,
                    'vol' => Icons.gpp_bad,
                    _ => Icons.report_problem,
                  },
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(incident.typeLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(incident.severityLabel,
                            style: TextStyle(fontSize: 11, color: _severityColor(incident.severity))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(incident.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (incident.isActive ? AppTheme.errorColor : AppTheme.successColor)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      incident.isActive ? 'Actif' : 'Résolu',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: incident.isActive ? AppTheme.errorColor : AppTheme.successColor,
                      ),
                    ),
                  ),
                  if (incident.coutReparation > 0) ...[
                    const SizedBox(height: 4),
                    Text('${incident.coutReparation.toStringAsFixed(0)} F',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets utilitaires ───────────────────────────────────────────────────

  Widget _card(String title, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _progressRow(double pourcentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Progression', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const Spacer(),
              Text('${pourcentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pourcentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text('Erreur : $error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(vehiculeDetailProvider.notifier).loadDetail(widget.vehiculeId),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Color _statutColor(String statut) => switch (statut) {
        'en_remboursement' => AppTheme.primaryColor,
        'rembourse' => Colors.blue,
        'en_panne' => Colors.orange,
        'accidente' => AppTheme.errorColor,
        'recupere' => Colors.grey,
        _ => Colors.grey,
      };

  String _statutLabel(String statut) => switch (statut) {
        'en_remboursement' => 'En remboursement',
        'rembourse' => 'Remboursé',
        'en_panne' => 'En panne',
        'accidente' => 'Accidenté',
        'recupere' => 'Récupéré',
        _ => statut,
      };

  String _couleurFlotteLabel(String couleur) => switch (couleur) {
        'a_jour' => 'À jour',
        'retard' => 'En retard',
        'defaut' => 'Défaut',
        'rembourse' => 'Remboursé',
        'probleme' => 'Problème',
        'en_attente' => 'En attente',
        _ => couleur,
      };

  Color _severityColor(String severity) => switch (severity) {
        'legere' => Colors.green,
        'moyenne' => Colors.orange,
        'grave' => Colors.red,
        _ => Colors.grey,
      };

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _fmt(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
  }
}
