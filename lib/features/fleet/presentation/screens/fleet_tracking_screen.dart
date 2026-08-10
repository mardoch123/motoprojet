import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../fleet_provider.dart';

class FleetTrackingScreen extends ConsumerStatefulWidget {
  const FleetTrackingScreen({super.key});

  @override
  ConsumerState<FleetTrackingScreen> createState() => _FleetTrackingScreenState();
}

class _FleetTrackingScreenState extends ConsumerState<FleetTrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(fleetProvider.notifier).chargerVehicules();
      ref.read(fleetProvider.notifier).chargerAudit();
      ref.read(fleetProvider.notifier).chargerParametres();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fleetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi Flotte & Immobilisation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Véhicules', icon: Icon(Icons.directions_car)),
            Tab(text: 'Audit', icon: Icon(Icons.history)),
            Tab(text: 'Paramètres', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVehiculesTab(state),
          _buildAuditTab(state),
          _buildParametresTab(state),
        ],
      ),
    );
  }

  Widget _buildVehiculesTab(FleetState state) {
    if (state.isLoading && state.vehicules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(fleetProvider.notifier).chargerVehicules(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.vehicules.length,
        itemBuilder: (context, index) {
          final vehicule = state.vehicules[index];
          return _buildVehiculeCard(vehicule);
        },
      ),
    );
  }

  Widget _buildVehiculeCard(VehiculeFleet vehicule) {
    final statutColor = switch (vehicule.statutMoteur) {
      'actif' => Colors.green,
      'coupe' => Colors.red,
      'coupure_en_attente' => Colors.orange,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statutColor.withValues(alpha: 0.1),
          child: Icon(
            vehicule.type == 'voiture' ? Icons.directions_car : Icons.two_wheeler,
            color: statutColor,
          ),
        ),
        title: Row(
          children: [
            Text(vehicule.immatriculation, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (vehicule.isMoving)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${vehicule.vitesse.toStringAsFixed(0)} km/h',
                    style: const TextStyle(fontSize: 10, color: Colors.blue)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vehicule.chauffeurNom ?? 'Pas de chauffeur'),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: statutColor),
                const SizedBox(width: 4),
                Text(
                  vehicule.isEngineCut ? 'Moteur coupé' : (vehicule.hasTracker ? 'En ligne' : 'Sans boîtier'),
                  style: TextStyle(fontSize: 12, color: statutColor),
                ),
                if (vehicule.hasPendingCommand) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.pending, size: 12, color: Colors.orange),
                  const Text(' Commande en cours', style: TextStyle(fontSize: 10, color: Colors.orange)),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vehicule.hasTracker) ...[
                  _buildInfoRow('IMEI', vehicule.imeiBoitier!),
                  if (vehicule.latitude != null && vehicule.longitude != null)
                    _buildInfoRow('Position', '${vehicule.latitude!.toStringAsFixed(5)}, ${vehicule.longitude!.toStringAsFixed(5)}'),
                  if (vehicule.derniereMajTelemetrie != null)
                    _buildInfoRow('Dernière MAJ', _formatDateTime(vehicule.derniereMajTelemetrie!)),
                  _buildInfoRow('Vitesse', '${vehicule.vitesse.toStringAsFixed(1)} km/h'),
                  const Divider(),
                ],
                _buildInfoRow('Coupure auto', vehicule.coupureAuto ? 'Activée' : 'Manuelle'),
                _buildInfoRow('Seuil coupure', 'J+${vehicule.seuilCoupureJours}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!vehicule.isEngineCut)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: vehicule.hasTracker ? () => _showImmobiliserDialog(vehicule) : null,
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('Immobiliser'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1)),
                        ),
                      ),
                    if (vehicule.isEngineCut)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showReactiverDialog(vehicule),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Réactiver'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    if (!vehicule.isEngineCut && vehicule.hasTracker) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showImmobiliserDialog(vehicule),
                          icon: const Icon(Icons.block),
                          label: const Text('Couper'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showCommandesHistory(vehicule),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Voir historique commandes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab(FleetState state) {
    return RefreshIndicator(
      onRefresh: () => ref.read(fleetProvider.notifier).chargerAudit(),
      child: state.audit.isEmpty
          ? const Center(child: Text('Aucun événement d\'audit'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.audit.length,
              itemBuilder: (context, index) {
                final item = state.audit[index];
                return _buildAuditTile(item);
              },
            ),
    );
  }

  Widget _buildAuditTile(AuditImmobilisation item) {
    final actionColor = switch (item.action) {
      'coupure_demandee' => Colors.orange,
      'coupure_envoyee' => Colors.deepOrange,
      'coupure_confirmee' => Colors.red,
      'reactivation' => Colors.green,
      _ => Colors.grey,
    };

    final actionIcon = switch (item.action) {
      'coupure_demandee' => Icons.request_page,
      'coupure_envoyee' => Icons.send,
      'coupure_confirmee' => Icons.power_settings_new,
      'reactivation' => Icons.play_circle,
      _ => Icons.info,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withValues(alpha: 0.1),
          child: Icon(actionIcon, color: actionColor, size: 20),
        ),
        title: Text(item.immatriculation ?? item.vehiculeId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.action} • ${item.source}'),
            if (item.declencheurNom != null)
              Text('Par: ${item.declencheurNom}', style: const TextStyle(fontSize: 11)),
            Text(_formatDateTime(item.horodatage), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: item.vitesseAuMoment != null
            ? Text('${item.vitesseAuMoment!.toStringAsFixed(0)} km/h',
                style: TextStyle(
                  color: item.vitesseAuMoment! > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ))
            : null,
      ),
    );
  }

  Widget _buildParametresTab(FleetState state) {
    final parametres = state.parametres;
    if (parametres == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Immobilisation activée'),
          subtitle: const Text('Activer/désactiver globalement l\'immobilisation'),
          value: parametres.immobilisationActive,
          onChanged: (value) {
            final updated = ParametresImmobilisation(
              immobilisationActive: value,
              delaiPreavisHeures: parametres.delaiPreavisHeures,
              dureeArretConfirmeSecondes: parametres.dureeArretConfirmeSecondes,
              vitesseMaxCoupe: parametres.vitesseMaxCoupe,
              fournisseurApiUrl: parametres.fournisseurApiUrl,
              webhookSecret: parametres.webhookSecret,
            );
            ref.read(fleetProvider.notifier).updateParametres(updated);
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Délai préavis'),
          subtitle: Text('${parametres.delaiPreavisHeures} heures avant coupure'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editIntParam('Délai préavis (heures)', parametres.delaiPreavisHeures, (v) {
              final updated = ParametresImmobilisation(
                immobilisationActive: parametres.immobilisationActive,
                delaiPreavisHeures: v,
                dureeArretConfirmeSecondes: parametres.dureeArretConfirmeSecondes,
                vitesseMaxCoupe: parametres.vitesseMaxCoupe,
                fournisseurApiUrl: parametres.fournisseurApiUrl,
                webhookSecret: parametres.webhookSecret,
              );
              ref.read(fleetProvider.notifier).updateParametres(updated);
            }),
          ),
        ),
        ListTile(
          title: const Text('Durée arrêt confirmé'),
          subtitle: Text('${parametres.dureeArretConfirmeSecondes} secondes'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editIntParam('Durée arrêt confirmé (secondes)', parametres.dureeArretConfirmeSecondes, (v) {
              final updated = ParametresImmobilisation(
                immobilisationActive: parametres.immobilisationActive,
                delaiPreavisHeures: parametres.delaiPreavisHeures,
                dureeArretConfirmeSecondes: v,
                vitesseMaxCoupe: parametres.vitesseMaxCoupe,
                fournisseurApiUrl: parametres.fournisseurApiUrl,
                webhookSecret: parametres.webhookSecret,
              );
              ref.read(fleetProvider.notifier).updateParametres(updated);
            }),
          ),
        ),
        const Divider(),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security, color: Colors.green),
            title: Text('Garde-fous de sécurité'),
            subtitle: Text(
              '• Coupure jamais en mouvement\n'
              '• Double confirmation d\'arrêt requise\n'
              '• Réactivation d\'urgence toujours disponible\n'
              '• Journal d\'audit complet',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _showImmobiliserDialog(VehiculeFleet vehicule) async {
    String motif = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Immobiliser le véhicule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vehicule.isMoving)
                const Card(
                  color: Colors.orange,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Véhicule en mouvement ! La coupure sera mise en attente jusqu\'à l\'arrêt.',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Motif de l\'immobilisation'),
                maxLines: 3,
                onChanged: (v) => motif = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (motif.isEmpty) return;
                Navigator.pop(context);
                final success = await ref.read(fleetProvider.notifier).immobiliser(vehicule.id, motif);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Commande envoyée' : 'Erreur')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirmer l\'immobilisation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReactiverDialog(VehiculeFleet vehicule) async {
    String motif = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Réactivation d\'urgence'),
          content: TextFormField(
            decoration: const InputDecoration(labelText: 'Motif de la réactivation'),
            maxLines: 3,
            onChanged: (v) => motif = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (motif.isEmpty) return;
                Navigator.pop(context);
                final success = await ref.read(fleetProvider.notifier).reactiver(vehicule.id, motif);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Réactivation envoyée' : 'Erreur')),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Réactiver'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommandesHistory(VehiculeFleet vehicule) async {
    await ref.read(fleetProvider.notifier).chargerCommandes(vehicule.id);
    if (!mounted) return;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final commandes = ref.read(fleetProvider).commandes[vehicule.id] ?? [];
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: commandes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Text('Historique des commandes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
                }
                final cmd = commandes[index - 1];
                return _buildCommandeTile(cmd);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommandeTile(CommandeBoitier cmd) {
    final statutColor = switch (cmd.statut) {
      'en_attente' => Colors.orange,
      'envoyee' => Colors.blue,
      'confirmee' => Colors.green,
      'echouee' => Colors.red,
      'annulee' => Colors.grey,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          cmd.typeCommande == 'immobiliser' ? Icons.power_settings_new : Icons.play_arrow,
          color: statutColor,
        ),
        title: Text(cmd.typeCommande),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cmd.motif ?? ''),
            Text('${cmd.statut} • ${_formatDateTime(cmd.creeLe)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            if (cmd.erreur != null)
              Text('Erreur: ${cmd.erreur}', style: const TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Future<void> _editIntParam(String title, int currentValue, Function(int) onSave) async {
    final controller = TextEditingController(text: currentValue.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                onSave(value);
              }
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
