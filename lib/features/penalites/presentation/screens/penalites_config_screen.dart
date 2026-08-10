import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../penalites_provider.dart';

class PenalitesConfigScreen extends ConsumerStatefulWidget {
  const PenalitesConfigScreen({super.key});

  @override
  ConsumerState<PenalitesConfigScreen> createState() => _PenalitesConfigScreenState();
}

class _PenalitesConfigScreenState extends ConsumerState<PenalitesConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(penalitesProvider.notifier).chargerParametres();
      ref.read(penalitesProvider.notifier).chargerExemptions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(penalitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pénalités de retard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Paramètres', icon: Icon(Icons.settings)),
            Tab(text: 'Exemptions', icon: Icon(Icons.shield)),
            Tab(text: 'Historique', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildParametresTab(state),
          _buildExemptionsTab(state),
          _buildHistoriqueTab(state),
        ],
      ),
    );
  }

  Widget _buildParametresTab(PenalitesState state) {
    if (state.isLoading && state.parametres.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(penalitesProvider.notifier).chargerParametres(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.blue),
              title: Text('Configuration des pénalités'),
              subtitle: Text(
                'Les pénalités sont calculées automatiquement chaque jour pour les véhicules en retard de paiement.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...state.parametres.map((p) => _buildParametreCard(p)),
        ],
      ),
    );
  }

  Widget _buildParametreCard(ParametrePenalite parametre) {
    final typeLabel = switch (parametre.typeVehicule) {
      'general' => 'Règles générales',
      'moto' => 'Motos',
      'voiture' => 'Voitures',
      _ => parametre.typeVehicule,
    };

    final typeIcon = switch (parametre.typeVehicule) {
      'general' => Icons.rule,
      'moto' => Icons.two_wheeler,
      'voiture' => Icons.directions_car,
      _ => Icons.settings,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(typeIcon, color: Colors.deepOrange),
        title: Text(typeLabel),
        subtitle: Text(
          parametre.actif 
            ? (parametre.typeCalcul == 'fixe' ? '${parametre.montantFixe.toStringAsFixed(0)} F/jour' : '${parametre.pourcentage}% du montant journalier')
            : 'Désactivé',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Type de calcul', parametre.typeCalcul == 'fixe' ? 'Montant fixe' : 'Pourcentage'),
                if (parametre.typeCalcul == 'fixe')
                  _buildInfoRow('Montant par jour', '${parametre.montantFixe.toStringAsFixed(0)} F')
                else
                  _buildInfoRow('Pourcentage', '${parametre.pourcentage}%'),
                _buildInfoRow('Seuil de déclenchement', 'J+${parametre.seuilJours}'),
                _buildInfoRow('Plafond', parametre.plafond != null ? '${parametre.plafond!.toStringAsFixed(0)} F' : 'Illimité'),
                _buildInfoRow('Statut', parametre.actif ? 'Actif' : 'Désactivé'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditDialog(parametre),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _toggleActif(parametre),
                        icon: Icon(parametre.actif ? Icons.pause : Icons.play_arrow),
                        label: Text(parametre.actif ? 'Désactiver' : 'Activer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExemptionsTab(PenalitesState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _showAddExemptionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une exemption'),
          ),
        ),
        Expanded(
          child: state.exemptions.isEmpty
              ? const Center(child: Text('Aucune exemption active'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(penalitesProvider.notifier).chargerExemptions(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.exemptions.length,
                    itemBuilder: (context, index) {
                      final exemption = state.exemptions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                            child: const Icon(Icons.shield, color: Colors.green),
                          ),
                          title: Text(exemption.immatriculation ?? exemption.chauffeurNom ?? 'Exemption'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exemption.motif),
                              Text(
                                'Du ${_formatDate(exemption.dateDebut)}${exemption.dateFin != null ? ' au ${_formatDate(exemption.dateFin!)}' : ' (indéterminée)'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmSupprimerExemption(exemption.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoriqueTab(PenalitesState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilterChip(
                  selected: true,
                  label: const Text('Toutes'),
                  onSelected: (_) {
                    ref.read(penalitesProvider.notifier).chargerPenalites();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  selected: false,
                  label: const Text('Actives'),
                  onSelected: (_) {
                    ref.read(penalitesProvider.notifier).chargerPenalites(statut: 'active');
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.penalites.isEmpty
              ? const Center(child: Text('Aucune pénalité enregistrée'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(penalitesProvider.notifier).chargerPenalites(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.penalites.length,
                    itemBuilder: (context, index) {
                      final penalite = state.penalites[index];
                      return _buildPenaliteTile(penalite);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPenaliteTile(Penalite penalite) {
    final statutColor = switch (penalite.statut) {
      'active' => Colors.orange,
      'payee' => Colors.green,
      'annulee' => Colors.grey,
      _ => Colors.grey,
    };

    final statutLabel = switch (penalite.statut) {
      'active' => 'Active',
      'payee' => 'Payée',
      'annulee' => 'Annulée',
      _ => penalite.statut,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statutColor.withValues(alpha: 0.1),
          child: Icon(
            penalite.statut == 'active' ? Icons.warning : penalite.statut == 'payee' ? Icons.check_circle : Icons.cancel,
            color: statutColor,
          ),
        ),
        title: Text('${penalite.immatriculation ?? 'Véhicule'} — ${penalite.montant.toStringAsFixed(0)} F'),
        subtitle: Text(
          '${_formatDate(penalite.datePenalite)} • $statutLabel${penalite.chauffeurNom != null ? ' • ${penalite.chauffeurNom}' : ''}',
        ),
        trailing: penalite.statut == 'active'
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'annuler') _showAnnulerDialog(penalite);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'annuler', child: Text('Annuler')),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _showEditDialog(ParametrePenalite parametre) async {
    String typeCalcul = parametre.typeCalcul;
    double montantFixe = parametre.montantFixe;
    double pourcentage = parametre.pourcentage;
    int seuilJours = parametre.seuilJours;
    double? plafond = parametre.plafond;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modifier ${parametre.typeVehicule}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: typeCalcul,
                  decoration: const InputDecoration(labelText: 'Type de calcul'),
                  items: const [
                    DropdownMenuItem(value: 'fixe', child: Text('Montant fixe')),
                    DropdownMenuItem(value: 'pourcentage', child: Text('Pourcentage')),
                  ],
                  onChanged: (v) => setState(() => typeCalcul = v ?? 'fixe'),
                ),
                if (typeCalcul == 'fixe')
                  TextFormField(
                    initialValue: montantFixe.toString(),
                    decoration: const InputDecoration(labelText: 'Montant fixe (F/jour)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => montantFixe = double.tryParse(v) ?? montantFixe,
                  )
                else
                  TextFormField(
                    initialValue: pourcentage.toString(),
                    decoration: const InputDecoration(labelText: 'Pourcentage (%)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => pourcentage = double.tryParse(v) ?? pourcentage,
                  ),
                TextFormField(
                  initialValue: seuilJours.toString(),
                  decoration: const InputDecoration(labelText: 'Seuil (jours de retard)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => seuilJours = int.tryParse(v) ?? seuilJours,
                ),
                TextFormField(
                  initialValue: plafond?.toString() ?? '',
                  decoration: const InputDecoration(labelText: 'Plafond (vide = illimité)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => plafond = v.isEmpty ? null : double.tryParse(v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final updated = ParametrePenalite(
                  id: parametre.id,
                  typeVehicule: parametre.typeVehicule,
                  typeCalcul: typeCalcul,
                  montantFixe: montantFixe,
                  pourcentage: pourcentage,
                  seuilJours: seuilJours,
                  plafond: plafond,
                  actif: parametre.actif,
                );
                final success = await ref.read(penalitesProvider.notifier).updateParametre(
                  parametre.typeVehicule,
                  updated,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paramètres mis à jour')),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActif(ParametrePenalite parametre) async {
    final updated = ParametrePenalite(
      id: parametre.id,
      typeVehicule: parametre.typeVehicule,
      typeCalcul: parametre.typeCalcul,
      montantFixe: parametre.montantFixe,
      pourcentage: parametre.pourcentage,
      seuilJours: parametre.seuilJours,
      plafond: parametre.plafond,
      actif: !parametre.actif,
    );
    await ref.read(penalitesProvider.notifier).updateParametre(parametre.typeVehicule, updated);
  }

  Future<void> _showAddExemptionDialog() async {
    String motif = '';
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une exemption'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Motif de l\'exemption'),
                  maxLines: 2,
                  onChanged: (v) => motif = v,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date de début'),
                  subtitle: Text(dateDebut != null ? _formatDate(dateDebut.toString()) : 'Sélectionner'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => dateDebut = date);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date de fin (optionnelle)'),
                  subtitle: Text(dateFin != null ? _formatDate(dateFin.toString()) : 'Indéterminée'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => dateFin = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (motif.isEmpty || dateDebut == null) return;
                final success = await ref.read(penalitesProvider.notifier).ajouterExemption(
                  motif: motif,
                  dateDebut: dateDebut!.toString().split(' ')[0],
                  dateFin: dateFin?.toString().split(' ')[0],
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exemption ajoutée')),
                    );
                  }
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSupprimerExemption(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'exemption ?'),
        content: const Text('Les pénalités reprendront pour ce véhicule/chauffeur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(penalitesProvider.notifier).supprimerExemption(id);
    }
  }

  Future<void> _showAnnulerDialog(Penalite penalite) async {
    String motif = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Annuler la pénalité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pénalité de ${penalite.montant.toStringAsFixed(0)} F du ${_formatDate(penalite.datePenalite)}'),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Motif de l\'annulation'),
                maxLines: 3,
                onChanged: (v) => motif = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () async {
                if (motif.isEmpty) return;
                final success = await ref.read(penalitesProvider.notifier).annulerPenalite(penalite.id, motif);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pénalité annulée')),
                    );
                  }
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
