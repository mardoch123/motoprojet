import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/shared/models/chauffeur_model.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/chauffeurs/presentation/chauffeurs_provider.dart';

class ChauffeursScreen extends ConsumerStatefulWidget {
  const ChauffeursScreen({super.key});

  @override
  ConsumerState<ChauffeursScreen> createState() => _ChauffeursScreenState();
}

class _ChauffeursScreenState extends ConsumerState<ChauffeursScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chauffeursListProvider.notifier).loadChauffeurs());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final state = ref.watch(chauffeursListProvider);
    final list = state.filteredList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chauffeurs'),
        actions: [
          // Compteur par statut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${list.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou téléphone…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(chauffeursListProvider.notifier).setSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) {
                ref.read(chauffeursListProvider.notifier).setSearch(value);
                setState(() {});
              },
            ),
          ),

          // ── Filtres par statut ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip(null, 'Tous', state.statutFilter),
                _buildFilterChip('actif', 'Actifs', state.statutFilter),
                _buildFilterChip('retard', 'En retard', state.statutFilter),
                _buildFilterChip('defaut', 'En défaut', state.statutFilter),
                _buildFilterChip('termine', 'Terminés', state.statutFilter),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Liste ───────────────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Erreur : ${state.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(chauffeursListProvider.notifier).loadChauffeurs(),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  state.searchQuery.isNotEmpty || state.statutFilter != null
                                      ? 'Aucun résultat'
                                      : 'Aucun chauffeur enregistré',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref.read(chauffeursListProvider.notifier).loadChauffeurs(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _buildChauffeurCard(list[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chauffeurs/create'),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau'),
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label, String? current) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          ref.read(chauffeursListProvider.notifier).setStatutFilter(
                selected ? value : null,
              );
        },
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildChauffeurCard(ChauffeurModel chauffeur) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/chauffeurs/${chauffeur.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: _statutColor(chauffeur.statut).withValues(alpha: 0.15),
                child: Text(
                  chauffeur.nom.isNotEmpty ? chauffeur.nom[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _statutColor(chauffeur.statut),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chauffeur.nom,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Badge statut
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statutColor(chauffeur.statut).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            chauffeur.statutLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _statutColor(chauffeur.statut),
                            ),
                          ),
                        ),
                        if (chauffeur.telephone != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text(
                            chauffeur.telephone!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Montant total versé
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${chauffeur.totalVerse.toStringAsFixed(0)} F',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text('Total versé', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),

              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
