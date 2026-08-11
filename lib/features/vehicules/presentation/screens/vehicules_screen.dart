import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/auth/permissions.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/shared/models/vehicule_model.dart';
import 'package:motoprojet/features/vehicules/presentation/vehicules_provider.dart';

class VehiculesScreen extends ConsumerStatefulWidget {
  const VehiculesScreen({super.key});

  @override
  ConsumerState<VehiculesScreen> createState() => _VehiculesScreenState();
}

class _VehiculesScreenState extends ConsumerState<VehiculesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vehiculesListProvider.notifier).loadVehicules());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _flotteColor(String? couleur) {
    switch (couleur) {
      case 'a_jour':
        return Colors.green;
      case 'retard':
        return Colors.orange;
      case 'defaut':
        return Colors.red;
      case 'rembourse':
        return Colors.blue;
      case 'probleme':
        return Colors.purple;
      case 'en_attente':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiculesListProvider);
    final list = state.filteredList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Véhicules'),
        actions: [
          // Toggle vue liste/grille
          IconButton(
            icon: Icon(state.isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: state.isGridView ? 'Vue liste' : 'Vue grille',
            onPressed: () => ref.read(vehiculesListProvider.notifier).toggleView(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text('${list.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Recherche ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par plaque…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(vehiculesListProvider.notifier).setSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) {
                ref.read(vehiculesListProvider.notifier).setSearch(value);
                setState(() {});
              },
            ),
          ),

          // ── Filtres ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('type', null, 'Tous', state.typeFilter),
                _buildFilterChip('type', 'moto', 'Motos', state.typeFilter),
                _buildFilterChip('type', 'voiture', 'Voitures', state.typeFilter),
                const SizedBox(width: 12),
                _buildFilterChip('statut', null, 'Tous statuts', state.statutFilter),
                _buildFilterChip('statut', 'en_remboursement', 'En cours', state.statutFilter),
                _buildFilterChip('statut', 'rembourse', 'Remboursés', state.statutFilter),
                _buildFilterChip('statut', 'en_panne', 'En panne', state.statutFilter),
                _buildFilterChip('statut', 'accidente', 'Accidentés', state.statutFilter),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Contenu ──
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _buildError(state.error!)
                    : list.isEmpty
                        ? _buildEmpty()
                        : state.isGridView
                            ? _buildGridView(list)
                            : _buildListView(list),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        capability: Capability.createVehicles,
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/vehicules/create'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau'),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterType, String? value, String label, String? current) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          final notifier = ref.read(vehiculesListProvider.notifier);
          if (filterType == 'type') {
            notifier.setTypeFilter(selected ? value : null);
          } else {
            notifier.setStatutFilter(selected ? value : null);
          }
        },
        selectedColor: AppTheme.successColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        checkmarkColor: Colors.white,
        side: BorderSide.none,
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
            onPressed: () => ref.read(vehiculesListProvider.notifier).loadVehicules(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            ref.read(vehiculesListProvider).searchQuery.isNotEmpty
                ? 'Aucun résultat'
                : 'Aucun véhicule enregistré',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  // ─── Vue Liste ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<VehiculeModel> list) {
    return RefreshIndicator(
      onRefresh: () => ref.read(vehiculesListProvider.notifier).loadVehicules(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildListCard(list[index]),
      ),
    );
  }

  Widget _buildListCard(VehiculeModel v) {
    final color = _flotteColor(v.couleurFlotte);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/vehicules/${v.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icône type
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  v.isMoto ? Icons.two_wheeler : Icons.directions_car,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.plaque, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.couleurFlotte?.replaceAll('_', ' ') ?? '—',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                          ),
                        ),
                        if (v.chauffeurNom != null) ...[
                          const SizedBox(width: 8),
                          Text(v.chauffeurNom!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Progression (visible seulement si permission)
              PermissionGate(
                capability: Capability.viewVehiclePrices,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${v.pourcentageRembourse.toStringAsFixed(0)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                    Text('${v.totalVerse.toStringAsFixed(0)} / ${v.prixAchat.toStringAsFixed(0)} F',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Vue Grille Flotte ─────────────────────────────────────────────────────
  Widget _buildGridView(List<VehiculeModel> list) {
    return RefreshIndicator(
      onRefresh: () => ref.read(vehiculesListProvider.notifier).loadVehicules(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildGridCard(list[index]),
      ),
    );
  }

  Widget _buildGridCard(VehiculeModel v) {
    final color = _flotteColor(v.couleurFlotte);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/vehicules/${v.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(v.isMoto ? Icons.two_wheeler : Icons.directions_car, color: color, size: 24),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(v.plaque, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(v.statutLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const Spacer(),
              // Barre de progression et montants (visible seulement si permission)
              PermissionGate(
                capability: Capability.viewVehiclePrices,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v.pourcentageRembourse / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${v.pourcentageRembourse.toStringAsFixed(0)}% — ${v.soldeRestant.toStringAsFixed(0)} F restants',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
