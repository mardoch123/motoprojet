import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/auth/permissions.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/chauffeurs/presentation/chauffeurs_provider.dart';

class ChauffeurDetailScreen extends ConsumerStatefulWidget {
  final String chauffeurId;
  const ChauffeurDetailScreen({super.key, required this.chauffeurId});

  @override
  ConsumerState<ChauffeurDetailScreen> createState() => _ChauffeurDetailScreenState();
}

class _ChauffeurDetailScreenState extends ConsumerState<ChauffeurDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Nombre d'onglets variable selon permissions
    final perms = ref.read(permissionsProvider);
    final tabCount = perms.can(Capability.viewChauffeurFinancials) ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    Future.microtask(() =>
        ref.read(chauffeurDetailProvider.notifier).loadDetail(widget.chauffeurId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'actif':
        return Colors.green;
      case 'retard':
        return Colors.orange;
      case 'defaut':
        return Colors.red;
      case 'termine':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chauffeurDetailProvider);
    final perms = ref.watch(permissionsProvider);
    final showFinancials = perms.can(Capability.viewChauffeurFinancials);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.data?['nom']?.toString() ?? 'Chauffeur'),
        actions: [
          PermissionGate(
            capability: Capability.editChauffeurs,
            child: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier',
              onPressed: () => context.push('/chauffeurs/${widget.chauffeurId}/edit'),
            ),
          ),
        ],
        bottom: state.data != null
            ? TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Infos', icon: Icon(Icons.person)),
                  if (showFinancials) const Tab(text: 'Paiements', icon: Icon(Icons.payment)),
                  const Tab(text: 'Véhicules', icon: Icon(Icons.directions_car)),
                ],
              )
            : null,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(state.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(chauffeurDetailProvider.notifier)
                            .loadDetail(widget.chauffeurId),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : state.data == null
                  ? const Center(child: Text('Aucune donnée'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfosTab(state.data!, showFinancials),
                        if (showFinancials) _buildPaiementsTab(state.data!),
                        _buildVehiculesTab(state.data!),
                      ],
                    ),
    );
  }

  // ─── Onglet Infos ──────────────────────────────────────────────────────────
  Widget _buildInfosTab(Map<String, dynamic> data, bool showFinancials) {
    final statut = data['statut']?.toString() ?? 'actif';
    final objectif = _toDouble(data['objectif_journalier']);
    final stats = data['stats'] as Map<String, dynamic>?;
    final vehiculeActuel = data['vehicule_actuel'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(chauffeurDetailProvider.notifier)
          .loadDetail(widget.chauffeurId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── En-tête avec avatar et statut ──
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _statutColor(statut).withValues(alpha: 0.15),
                  child: data['photo_url'] != null
                      ? ClipOval(
                          child: Image.network(
                            data['photo_url'].toString(),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              data['nom']?.toString()[0].toUpperCase() ?? '?',
                              style: TextStyle(fontSize: 28, color: _statutColor(statut)),
                            ),
                          ),
                        )
                      : Text(
                          data['nom']?.toString()[0].toUpperCase() ?? '?',
                          style: TextStyle(fontSize: 28, color: _statutColor(statut)),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  data['nom']?.toString() ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statutColor(statut).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statutLabel(statut),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statutColor(statut),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Stats rapides (financières masquées si pas de permission) ──
          if (showFinancials) Row(
            children: [
              _buildStatCard(
                'Total versé',
                '${_toDouble(stats?['total_verse']).toStringAsFixed(0)} F',
                Icons.account_balance_wallet,
                AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Paiements',
                '${stats?['nb_paiements'] ?? 0}',
                Icons.receipt_long,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showFinancials) ...[
                _buildStatCard(
                  'Objectif/jour',
                  '${objectif.toStringAsFixed(0)} F',
                  Icons.flag,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.directions_car, color: Colors.purple, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        vehiculeActuel?['plaque']?.toString() ?? 'Aucun',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text('Véhicule', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Informations détaillées ──
          _buildInfoTile(Icons.phone, 'Téléphone', data['telephone']?.toString() ?? '—'),
          _buildInfoTile(Icons.badge, 'Pièce d\'identité', data['piece_identite']?.toString() ?? '—'),
          _buildInfoTile(Icons.home, 'Adresse', data['adresse']?.toString() ?? '—'),
          _buildInfoTile(Icons.emergency, 'Contact urgence', data['contact_urgence']?.toString() ?? '—'),
          if (showFinancials && stats?['dernier_paiement'] != null)
            _buildInfoTile(
              Icons.event,
              'Dernier paiement',
              DateFormat('dd/MM/yyyy').format(DateTime.parse(stats!['dernier_paiement'].toString())),
            ),
        ],
      ),
    );
  }

  // ─── Onglet Paiements ─────────────────────────────────────────────────────
  Widget _buildPaiementsTab(Map<String, dynamic> data) {
    final paiements = (data['historique_paiements'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (paiements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun paiement enregistré'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: paiements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final p = paiements[index];
        final montant = _toDouble(p['montant']);
        final date = p['date'] != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date'].toString()))
            : '—';
        final mode = p['mode']?.toString() ?? 'cash';

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: mode == 'mobile_money' ? Colors.blue.shade50 : Colors.green.shade50,
              child: Icon(
                mode == 'mobile_money' ? Icons.phone_android : Icons.payments,
                color: mode == 'mobile_money' ? Colors.blue : Colors.green,
              ),
            ),
            title: Text('${montant.toStringAsFixed(0)} F CFA'),
            subtitle: Text('$date • ${p['vehicule_plaque']?.toString() ?? '—'} • $mode'),
            trailing: Text(
              '#${index + 1}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // ─── Onglet Véhicules ─────────────────────────────────────────────────────
  Widget _buildVehiculesTab(Map<String, dynamic> data) {
    final affectations = (data['historique_affectations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        // Bouton pour ajouter une affectation
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddAffectationDialog(),
              icon: const Icon(Icons.add_link),
              label: const Text('Affecter un véhicule'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: affectations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Aucune affectation'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: affectations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final a = affectations[index];
                    final isActive = a['date_fin'] == null;
                    final dateDebut = a['date_debut'] != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(a['date_debut'].toString()))
                        : '—';
                    final dateFin = a['date_fin'] != null
                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(a['date_fin'].toString()))
                        : 'En cours';

                    return Card(
                      color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.05) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
                          child: Icon(
                            Icons.directions_car,
                            color: isActive ? Colors.white : Colors.grey,
                          ),
                        ),
                        title: Text(
                          a['plaque']?.toString() ?? '—',
                          style: TextStyle(fontWeight: isActive ? FontWeight.bold : null),
                        ),
                        subtitle: Text('$dateDebut → $dateFin'),
                        trailing: isActive
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Actif',
                                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Dialogs & Helpers ─────────────────────────────────────────────────────

  void _showAddAffectationDialog() {
    final vehiculesRef = ref.read(vehiculesDisponiblesProvider);
    vehiculesRef.whenData((vehicules) {
      if (vehicules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun véhicule disponible')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Affecter un véhicule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: vehicules.map((v) {
              return ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(v['plaque']?.toString() ?? '—'),
                subtitle: Text('${v['type']?.toString() ?? ''} ${v['marque']?.toString() ?? ''}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await ref
                      .read(chauffeurDetailProvider.notifier)
                      .createAffectation(widget.chauffeurId, v['id'].toString());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Affectation créée' : 'Erreur'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'actif': return 'Actif';
      case 'retard': return 'En retard';
      case 'defaut': return 'En défaut';
      case 'termine': return 'Terminé';
      default: return statut;
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
