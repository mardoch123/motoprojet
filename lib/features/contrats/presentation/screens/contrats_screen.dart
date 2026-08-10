import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import '../contrats_provider.dart';

/// Écran principal de gestion des contrats
class ContratsScreen extends ConsumerStatefulWidget {
  const ContratsScreen({super.key});

  @override
  ConsumerState<ContratsScreen> createState() => _ContratsScreenState();
}

class _ContratsScreenState extends ConsumerState<ContratsScreen> with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat.decimalPattern('fr_FR');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(contratsProvider.notifier).chargerContrats();
      ref.read(contratsProvider.notifier).chargerGarants();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contratsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrats'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Contrats'),
            Tab(text: 'Garants'),
            Tab(text: 'Paramètres'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateContratDialog(),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau contrat'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContratsList(state),
          _buildGarantsList(state),
          _buildParametresTab(state),
        ],
      ),
    );
  }

  Widget _buildContratsList(ContratsState state) {
    if (state.isLoading && state.contrats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.contrats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun contrat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Créez un contrat pour commencer', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(contratsProvider.notifier).chargerContrats(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.contrats.length,
        itemBuilder: (ctx, i) => _buildContratCard(state.contrats[i]),
      ),
    );
  }

  Widget _buildContratCard(Contrat contrat) {
    final statutColor = _getStatutColor(contrat.statut);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showContratDetail(contrat),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statutColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      contrat.statut.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statutColor),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    contrat.numero,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contrat.chauffeur?['nom'] as String? ?? 'Chauffeur',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    contrat.vehicule?['plaque'] as String? ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.parse(contrat.dateDebut)),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip('Prix', '${_fmt.format(contrat.prixAchat)} F', Colors.blue),
                  _buildInfoChip('Échéance', '${_fmt.format(contrat.montantEcheance)} F', Colors.green),
                  _buildInfoChip(contrat.frequencePaiement.label, '', Colors.orange),
                ],
              ),
              if (contrat.signatures.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: contrat.signatures.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.isEmpty ? label : '$label: $value',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Color _getStatutColor(StatutContrat statut) {
    switch (statut) {
      case StatutContrat.brouillon: return Colors.grey;
      case StatutContrat.enCours: return Colors.orange;
      case StatutContrat.signe: return Colors.green;
      case StatutContrat.resilie: return Colors.red;
      case StatutContrat.termine: return Colors.blue;
    }
  }

  // ─── Garants ─────────────────────────────────────────────────────────────

  Widget _buildGarantsList(ContratsState state) {
    if (state.garants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun garant enregistré'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showGarantDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un garant'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.garants.length,
      itemBuilder: (ctx, i) => _buildGarantCard(state.garants[i]),
    );
  }

  Widget _buildGarantCard(Garant garant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(garant.nom.isNotEmpty ? garant.nom[0].toUpperCase() : '?'),
        ),
        title: Text(garant.nomComplet),
        subtitle: Text([garant.profession, garant.telephone].where((s) => s != null && s.isNotEmpty).join(' • ')),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _showGarantDialog(garant: garant),
        ),
      ),
    );
  }

  // ─── Paramètres ──────────────────────────────────────────────────────────

  Widget _buildParametresTab(ContratsState state) {
    if (state.parametres.isEmpty) {
      Future.microtask(() => ref.read(contratsProvider.notifier).chargerParametres());
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.parametres.length,
      itemBuilder: (ctx, i) {
        final param = state.parametres[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(param['cle'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(param['valeur'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _showParametreDialog(param['cle']!, param['valeur']!),
          ),
        );
      },
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  Future<void> _showContratDetail(Contrat contrat) async {
    await ref.read(contratsProvider.notifier).chargerContrat(contrat.id);
    if (!mounted) return;

    final state = ref.read(contratsProvider);
    final contratDetail = state.contratSelectionne ?? contrat;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: _ContratDetailScreen(contrat: contratDetail),
      ),
    );
  }

  Future<void> _showCreateContratDialog() async {
    // This would be a complex multi-step form
    // For now, show a simplified version
    await showDialog(
      context: context,
      builder: (ctx) => const _CreateContratDialog(),
    );
  }

  Future<void> _showGarantDialog({Garant? garant}) async {
    final nomController = TextEditingController(text: garant?.nom ?? '');
    final prenomController = TextEditingController(text: garant?.prenom ?? '');
    final telephoneController = TextEditingController(text: garant?.telephone ?? '');
    final professionController = TextEditingController(text: garant?.profession ?? '');
    final adresseController = TextEditingController(text: garant?.adresse ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(garant != null ? 'Modifier le garant' : 'Nouveau garant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom *')),
              const SizedBox(height: 8),
              TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 8),
              TextField(controller: telephoneController, decoration: const InputDecoration(labelText: 'Téléphone *'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: professionController, decoration: const InputDecoration(labelText: 'Profession')),
              const SizedBox(height: 8),
              TextField(controller: adresseController, decoration: const InputDecoration(labelText: 'Adresse'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final nom = nomController.text.trim();
              final telephone = telephoneController.text.trim();
              if (nom.isEmpty || telephone.isEmpty) return;

              final data = {
                'nom': nom,
                'prenom': prenomController.text.trim(),
                'telephone': telephone,
                'profession': professionController.text.trim(),
                'adresse': adresseController.text.trim(),
              };

              if (garant != null) {
                await ref.read(contratsProvider.notifier).updateGarant(garant.id, data);
              } else {
                await ref.read(contratsProvider.notifier).creerGarant(data);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showParametreDialog(String cle, String valeur) async {
    final controller = TextEditingController(text: valeur);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cle),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Valeur')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              ref.read(contratsProvider.notifier).updateParametre(cle, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ─── Écran détail contrat ────────────────────────────────────────────────────

class _ContratDetailScreen extends ConsumerWidget {
  final Contrat contrat;
  const _ContratDetailScreen({required this.contrat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contratsProvider);
    final c = state.contratSelectionne ?? contrat;
    final fmt = NumberFormat.decimalPattern('fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.numero),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatutColor(c.statut).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatutColor(c.statut).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getStatutIcon(c.statut), color: _getStatutColor(c.statut)),
                  const SizedBox(width: 8),
                  Text(c.statut.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _getStatutColor(c.statut))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Infos financières
            const Text('CONDITIONS FINANCIÈRES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            _buildDetailRow('Prix d\'achat', '${fmt.format(c.prixAchat)} FCFA'),
            _buildDetailRow('Apport initial', '${fmt.format(c.apportInitial)} FCFA'),
            _buildDetailRow('Montant financé', '${fmt.format(c.montantFinanc)} FCFA'),
            _buildDetailRow('Fréquence', c.frequencePaiement.label),
            _buildDetailRow('Échéance', '${fmt.format(c.montantEcheance)} FCFA'),
            if (c.nombreEcheances != null) _buildDetailRow('Nombre d\'échéances', '${c.nombreEcheances}'),
            const SizedBox(height: 20),

            // Chauffeur
            if (c.chauffeur != null) ...[
              const Text('BÉNÉFICIAIRE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              _buildDetailRow('Nom', c.chauffeur!['nom'] as String? ?? ''),
              _buildDetailRow('Téléphone', c.chauffeur!['telephone'] as String? ?? ''),
              _buildDetailRow('Pièce d\'identité', c.chauffeur!['piece_identite'] as String? ?? ''),
              const SizedBox(height: 20),
            ],

            // Véhicule
            if (c.vehicule != null) ...[
              const Text('VÉHICULE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              _buildDetailRow('Type', c.vehicule!['type'] as String? ?? ''),
              _buildDetailRow('Marque', c.vehicule!['marque'] as String? ?? ''),
              _buildDetailRow('Plaque', c.vehicule!['plaque'] as String? ?? ''),
              const SizedBox(height: 20),
            ],

            // Garant
            if (c.garant != null) ...[
              const Text('GARANT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              _buildDetailRow('Nom', c.garant!.nomComplet),
              _buildDetailRow('Téléphone', c.garant!.telephone),
              _buildDetailRow('Profession', c.garant!.profession ?? ''),
              _buildDetailRow('Lien de parenté', c.garant!.lienParente ?? ''),
              const SizedBox(height: 20),
            ],

            // Signatures
            const Text('SIGNATURES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            if (c.signatures.isEmpty)
              const Text('Aucune signature', style: TextStyle(color: Colors.grey))
            else
              ...c.signatures.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.signataireNom, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${s.signataireType} • ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(s.dateSignature))}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

            const SizedBox(height: 20),

            // Bouton signer
            if (c.statut == StatutContrat.brouillon || c.statut == StatutContrat.enCours)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSignerDialog(context, ref, c),
                  icon: const Icon(Icons.edit),
                  label: const Text('Signer ce contrat'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                ),
              ),

            const SizedBox(height: 12),

            // Bouton voir contenu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showContenuContrat(context, ref, c.id),
                icon: const Icon(Icons.description),
                label: const Text('Voir le contenu du contrat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Color _getStatutColor(StatutContrat statut) {
    switch (statut) {
      case StatutContrat.brouillon: return Colors.grey;
      case StatutContrat.enCours: return Colors.orange;
      case StatutContrat.signe: return Colors.green;
      case StatutContrat.resilie: return Colors.red;
      case StatutContrat.termine: return Colors.blue;
    }
  }

  IconData _getStatutIcon(StatutContrat statut) {
    switch (statut) {
      case StatutContrat.brouillon: return Icons.drafts;
      case StatutContrat.enCours: return Icons.hourglass_top;
      case StatutContrat.signe: return Icons.check_circle;
      case StatutContrat.resilie: return Icons.cancel;
      case StatutContrat.termine: return Icons.verified;
    }
  }

  Future<void> _showSignerDialog(BuildContext context, WidgetRef ref, Contrat contrat) async {
    final nomController = TextEditingController();
    String signataireType = 'chauffeur';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Signer le contrat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: signataireType,
                decoration: const InputDecoration(labelText: 'Type de signataire'),
                items: const [
                  DropdownMenuItem(value: 'chauffeur', child: Text('Chauffeur (Bénéficiaire)')),
                  DropdownMenuItem(value: 'garant', child: Text('Garant')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                ],
                onChanged: (v) => setState(() => signataireType = v ?? 'chauffeur'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom complet du signataire'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La signature sera horodatée et hashée pour garantir l\'intégrité.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final nom = nomController.text.trim();
                if (nom.isEmpty) return;
                Navigator.pop(ctx);
                final success = await ref.read(contratsProvider.notifier).signerContrat(
                  contratId: contrat.id,
                  signataireType: signataireType,
                  signataireNom: nom,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Contrat signé avec succès' : 'Erreur de signature')),
                  );
                }
              },
              child: const Text('Signer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContenuContrat(BuildContext context, WidgetRef ref, String contratId) async {
    final contenu = await ref.read(contratsProvider.notifier).getContenuContrat(contratId);
    if (contenu == null || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('Contenu du contrat')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContenuContrat(contenu),
          ),
        ),
      ),
    );
  }

  Widget _buildContenuContrat(Map<String, dynamic> contenu) {
    final clauses = contenu['clauses'] as Map<String, dynamic>? ?? {};
    final parties = contenu['parties'] as Map<String, dynamic>? ?? {};
    final conditions = contenu['conditions'] as Map<String, dynamic>? ?? {};
    final fmt = NumberFormat.decimalPattern('fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text(contenu['titre'] as String? ?? 'CONTRAT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Center(child: Text('N° ${(contenu['numero'] as String?) ?? ''}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        Center(child: Text('Date: ${contenu['date'] as String? ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        const SizedBox(height: 24),
        _buildSection('ENTRE LES SOUSSIGNÉS', [
          'Financeur : MotoProjet Bénin',
          'Bénéficiaire : ${parties['beneficiaire']?['nom'] ?? ''}',
          if (parties['garant'] != null) 'Garant : ${parties['garant']?['nom'] ?? ''}',
        ]),
        _buildSection('OBJET DU CONTRAT', [clauses['objet'] as String? ?? '']),
        _buildSection('CONDITIONS FINANCIÈRES', [
          'Prix d\'achat : ${fmt.format((conditions['prix_achat'] as num?)?.toInt() ?? 0)} FCFA',
          'Apport initial : ${fmt.format((conditions['apport_initial'] as num?)?.toInt() ?? 0)} FCFA',
          'Montant financé : ${fmt.format((conditions['montant_financ'] as num?)?.toInt() ?? 0)} FCFA',
          'Fréquence : ${conditions['frequence_paiement'] ?? ''}',
          'Échéance : ${fmt.format((conditions['montant_echeance'] as num?)?.toInt() ?? 0)} FCFA',
        ]),
        _buildSection('OBLIGATIONS DU BÉNÉFICIAIRE', [clauses['obligations_beneficiaire'] as String? ?? '']),
        _buildSection('OBLIGATIONS DU FINANCEUR', [clauses['obligations_financeur'] as String? ?? '']),
        _buildSection('RETARD DE PAIEMENT', [clauses['retard'] as String? ?? '']),
        _buildSection('RÉSILIATION', [clauses['resiliation'] as String? ?? '']),
        if (parties['garant'] != null) _buildSection('ENGAGEMENT DU GARANT', [clauses['garant'] as String? ?? '']),
        _buildSection('JURIDICTION', [clauses['juridiction'] as String? ?? '']),
      ],
    );
  }

  Widget _buildSection(String title, List<String> content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
          const SizedBox(height: 4),
          ...content.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(c, style: const TextStyle(fontSize: 12, height: 1.4)),
          )),
          const Divider(),
        ],
      ),
    );
  }
}

// ─── Dialog création contrat ─────────────────────────────────────────────────

class _CreateContratDialog extends ConsumerStatefulWidget {
  const _CreateContratDialog();

  @override
  ConsumerState<_CreateContratDialog> createState() => _CreateContratDialogState();
}

class _CreateContratDialogState extends ConsumerState<_CreateContratDialog> {
  final _prixAchatCtrl = TextEditingController();
  final _apportCtrl = TextEditingController(text: '0');
  final _echeanceCtrl = TextEditingController();
  int _nombreEcheances = 0;
  FrequencePaiement _frequence = FrequencePaiement.journalier;
  String? _chauffeurId;
  String? _vehiculeId;
  String? _garantId;
  List<Map<String, dynamic>> _chauffeurs = [];
  List<Map<String, dynamic>> _vehicules = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final chauffeursRes = await api.get('/chauffeurs');
      final vehiculesRes = await api.get('/vehicules');
      setState(() {
        _chauffeurs = List<Map<String, dynamic>>.from(chauffeursRes.data['data'] as List);
        _vehicules = List<Map<String, dynamic>>.from(vehiculesRes.data['data'] as List);
      });
    } catch (e) {
      AppLogger.e('[Contrats] Erreur chargement données: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final garants = ref.watch(contratsProvider).garants;

    return AlertDialog(
      title: const Text('Nouveau contrat'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Chauffeur *'),
              items: _chauffeurs.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nom'] as String))).toList(),
              onChanged: (v) => setState(() => _chauffeurId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Véhicule *'),
              items: _vehicules.map((v) => DropdownMenuItem(value: v['id'] as String, child: Text('${v['plaque']} - ${v['type']}'))).toList(),
              onChanged: (v) => setState(() => _vehiculeId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Garant'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                ...garants.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nomComplet))),
              ],
              onChanged: (v) => setState(() => _garantId = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _prixAchatCtrl, decoration: const InputDecoration(labelText: 'Prix d\'achat (FCFA) *'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _apportCtrl, decoration: const InputDecoration(labelText: 'Apport initial (FCFA)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _echeanceCtrl, decoration: const InputDecoration(labelText: 'Montant échéance (FCFA) *'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            DropdownButtonFormField<FrequencePaiement>(
              initialValue: _frequence,
              decoration: const InputDecoration(labelText: 'Fréquence *'),
              items: FrequencePaiement.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
              onChanged: (v) => setState(() => _frequence = v ?? FrequencePaiement.journalier),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            if (_chauffeurId == null || _vehiculeId == null) return;
            final prixAchat = int.tryParse(_prixAchatCtrl.text);
            final echeance = int.tryParse(_echeanceCtrl.text);
            if (prixAchat == null || echeance == null) return;

            final contrat = await ref.read(contratsProvider.notifier).creerContrat({
              'chauffeurId': _chauffeurId,
              'vehiculeId': _vehiculeId,
              'garantId': _garantId,
              'prixAchat': prixAchat,
              'apportInitial': int.tryParse(_apportCtrl.text) ?? 0,
              'frequencePaiement': _frequence.name,
              'montantEcheance': echeance,
              'dateDebut': DateTime.now().toIso8601String().split('T').first,
            });
            if (contrat != null && mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Contrat ${contrat.numero} créé')),
              );
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
