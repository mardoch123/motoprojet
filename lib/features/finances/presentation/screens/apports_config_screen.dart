import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:motoprojet/features/paiements/presentation/kkiapay_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../apports_provider.dart';

/// Écran de configuration des apports personnels
class ApportsConfigScreen extends ConsumerStatefulWidget {
  const ApportsConfigScreen({super.key});

  @override
  ConsumerState<ApportsConfigScreen> createState() => _ApportsConfigScreenState();
}

class _ApportsConfigScreenState extends ConsumerState<ApportsConfigScreen> {
  final _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(apportsProvider.notifier).chargerApports(actifsOnly: false));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(apportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apports personnels'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAjouterDialog(),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel apport'),
      ),
      body: state.isLoading && state.apports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.apports.isEmpty
              ? _buildEmpty()
              : _buildList(state),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Aucun apport configuré',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des apports personnels pour accélérer\nl\'achat de vos véhicules',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ApportsState state) {
    final apportsMoto = state.apports.where((a) => a.objectif == ObjectifApport.moto).toList();
    final apportsVoiture = state.apports.where((a) => a.objectif == ObjectifApport.voiture).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé
        _buildResume(state),
        const SizedBox(height: 24),

        // Apports moto
        if (apportsMoto.isNotEmpty) ...[
          _buildSectionTitle('MOTO', Icons.two_wheeler, Colors.deepOrange),
          const SizedBox(height: 8),
          ...apportsMoto.map((a) => _buildApportCard(a)),
          const SizedBox(height: 16),
        ],

        // Apports voiture
        if (apportsVoiture.isNotEmpty) ...[
          _buildSectionTitle('VOITURE', Icons.directions_car, Colors.indigo),
          const SizedBox(height: 8),
          ...apportsVoiture.map((a) => _buildApportCard(a)),
        ],
      ],
    );
  }

  Widget _buildResume(ApportsState state) {
    final totalMoto = state.totalMensuelPour(ObjectifApport.moto);
    final totalVoiture = state.totalMensuelPour(ObjectifApport.voiture);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RÉSUMÉ MENSUEL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResumeItem('Moto', totalMoto, Icons.two_wheeler, Colors.deepOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResumeItem('Voiture', totalVoiture, Icons.directions_car, Colors.indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumeItem(String label, int montant, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '${_fmt.format(montant)} F',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text('/ mois', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildApportCard(ApportPersonnel apport) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: apport.actif ? Colors.amber.shade200 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apport.libelle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${apport.frequence.label} • ${_fmt.format(apport.montant)} F',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (!apport.actif)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'INACTIF',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onPressed: () => _showActionsMenu(apport),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Début: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(apport.dateDebut))}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              if (apport.dateFin != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Fin: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(apport.dateFin!))}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showActionsMenu(ApportPersonnel apport) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(apport.actif ? Icons.pause : Icons.play_arrow),
              title: Text(apport.actif ? 'Désactiver' : 'Activer'),
              onTap: () {
                ref.read(apportsProvider.notifier).updateApport(apport.id, {'actif': !apport.actif});
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.green),
              title: const Text('Enregistrer un versement'),
              onTap: () {
                Navigator.pop(ctx);
                _showVersementDialog(apport);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await _confirmDelete(apport.libelle);
                if (confirm == true) {
                  ref.read(apportsProvider.notifier).supprimerApport(apport.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(String libelle) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text('Supprimer l\'apport "$libelle" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAjouterDialog() async {
    final libelleController = TextEditingController();
    final montantController = TextEditingController();
    FrequenceApport frequence = FrequenceApport.mensuel;
    ObjectifApport objectif = ObjectifApport.moto;
    DateTime dateDebut = DateTime.now();
    String? note;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nouvel apport'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: libelleController,
                  decoration: const InputDecoration(labelText: 'Libellé', hintText: 'Ex: Apport mensuel'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (F)'),
                ),
                const SizedBox(height: 16),
                const Text('Fréquence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: FrequenceApport.values.map((f) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(f.label.substring(0, 3), style: const TextStyle(fontSize: 10)),
                        selected: frequence == f,
                        onSelected: (_) => setState(() => frequence = f),
                        selectedColor: Colors.amber.shade200,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Objectif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: ObjectifApport.values.map((o) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(o.label),
                        selected: objectif == o,
                        onSelected: (_) => setState(() => objectif = o),
                        selectedColor: Colors.amber.shade200,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dateDebut,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => dateDebut = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text('Début: ${DateFormat('dd/MM/yyyy').format(dateDebut)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final libelle = libelleController.text.trim();
                final montant = int.tryParse(montantController.text);
                if (libelle.isNotEmpty && montant != null && montant > 0) {
                  ref.read(apportsProvider.notifier).creerApport(
                    libelle: libelle,
                    montant: montant,
                    frequence: frequence,
                    dateDebut: DateFormat('yyyy-MM-dd').format(dateDebut),
                    objectif: objectif,
                    note: note,
                  );
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVersementDialog(ApportPersonnel apport) async {
    final montantController = TextEditingController(text: apport.montant.toString());
    final telephoneController = TextEditingController();
    DateTime dateVersement = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Versement KKiaPay - ${apport.libelle}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône KKiaPay
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paiement Mobile Money (KKiaPay)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Le montant sera débité de votre compte mobile money',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant versé (F)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '229 XX XX XX XX',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dateVersement,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => dateVersement = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd/MM/yyyy').format(dateVersement)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton.icon(
              onPressed: () {
                final montant = int.tryParse(montantController.text);
                final telephone = telephoneController.text.trim().replaceAll(' ', '');
                if (montant != null && montant > 0 && telephone.isNotEmpty) {
                  Navigator.pop(ctx, {
                    'montant': montant,
                    'telephone': telephone,
                    'dateVersement': DateFormat('yyyy-MM-dd').format(dateVersement),
                  });
                } else if (telephone.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Veuillez saisir votre numéro de téléphone')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.phone_android, color: Colors.white),
              label: const Text('Payer via KKiaPay', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _lancerPaiementKKiaPay(
        apport: apport,
        montant: result['montant'] as int,
        telephone: result['telephone'] as String,
        dateVersement: result['dateVersement'] as String,
      );
    }
  }

  Future<void> _lancerPaiementKKiaPay({
    required ApportPersonnel apport,
    required int montant,
    required String telephone,
    required String dateVersement,
  }) async {
    final notifier = ref.read(apportsProvider.notifier);

    // Initier le paiement côté backend
    final transaction = await notifier.initierVersementKKiaPay(
      apportId: apport.id,
      dateVersement: dateVersement,
      montant: montant,
      telephone: telephone,
    );

    if (transaction == null || !mounted) return;

    // Récupérer la config KKiaPay pour le widget SDK
    final kkiapayService = ref.read(kkiapayServiceProvider);
    final config = await kkiapayService.getConfig();

    if (!config.isReady || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KKiaPay non configuré')),
        );
      }
      return;
    }

    // Ouvrir le widget KKiaPay (SDK officiel)
    final completer = Completer<String?>();

    final kkiapayWidget = KKiaPay(
      amount: montant,
      apikey: config.publicKey,
      sandbox: config.sandbox,
      phone: telephone,
      name: '',
      reason: 'Apport personnel',
      data: transaction.transactionId,
      countries: const ['BJ'],
      paymentMethods: const ['momo', 'card'],
      theme: '#FF6F00',
      callback: (Map<String, dynamic> response, BuildContext ctx) {
        final status = response['status'] as String? ?? '';
        switch (status) {
          case PAYMENT_SUCCESS:
            final txId = response['transactionId'] as String?
                ?? response['requestData']?['data'] as String?
                ?? transaction.transactionId;
            Navigator.pop(ctx);
            if (!completer.isCompleted) completer.complete(txId);
            break;
          case PAYMENT_CANCELLED:
            Navigator.pop(ctx);
            if (!completer.isCompleted) completer.complete(null);
            break;
          default:
            break;
        }
      },
    );

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => kkiapayWidget));

    // Si le widget est fermé sans callback
    if (!completer.isCompleted) completer.complete(null);

    final resultTxId = await completer.future;

    if (resultTxId != null && mounted) {
      // Lancer le polling pour suivre la confirmation
      notifier.attendreConfirmation(transaction.transactionId); // ignore: unawaited_futures
      await _showPaiementEnCoursScreen(
        transaction: transaction,
        montant: montant,
        telephone: telephone,
      );
    } else if (mounted) {
      notifier.reinitialiserStatutPaiement();
    }
  }

  Future<void> _showPaiementEnCoursScreen({
    required TransactionKKiaPay transaction,
    required int montant,
    required String telephone,
  }) async {
    final notifier = ref.read(apportsProvider.notifier);

    // Lancer le polling en arrière-plan
    notifier.attendreConfirmation(transaction.transactionId); // ignore: unawaited_futures

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(apportsProvider);
          final statut = state.statutPaiement;

          return AlertDialog(
            title: Row(
              children: [
                _buildStatutIcon(statut),
                const SizedBox(width: 8),
                const Text('Paiement KKiaPay'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_fmt.format(montant)} FCFA',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vers: $telephone',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                _buildStatutContent(statut, transaction),
              ],
            ),
            actions: [
              if (statut.isTerminal)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    notifier.reinitialiserStatutPaiement();
                  },
                  child: const Text('Fermer'),
                ),
              if (statut == StatutPaiementKKiaPay.pending && transaction.urlPaiement != null)
                TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(transaction.urlPaiement!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Ouvrir la page'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatutIcon(StatutPaiementKKiaPay statut) {
    switch (statut) {
      case StatutPaiementKKiaPay.initiating:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case StatutPaiementKKiaPay.pending:
        return Icon(Icons.hourglass_top, color: Colors.orange.shade700);
      case StatutPaiementKKiaPay.confirmed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case StatutPaiementKKiaPay.failed:
        return const Icon(Icons.error, color: Colors.red);
      case StatutPaiementKKiaPay.expired:
        return Icon(Icons.timer_off, color: Colors.grey.shade600);
      case StatutPaiementKKiaPay.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatutContent(StatutPaiementKKiaPay statut, TransactionKKiaPay transaction) {
    switch (statut) {
      case StatutPaiementKKiaPay.initiating:
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Initiation du paiement...'),
          ],
        );
      case StatutPaiementKKiaPay.pending:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Column(
            children: [
              Icon(Icons.phone_android, size: 32, color: Colors.orange),
              SizedBox(height: 8),
              Text(
                'Vérifiez votre téléphone',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Un message USSD vous a été envoyé.\nComposez le code pour confirmer le paiement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                'En attente de confirmation...',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      case StatutPaiementKKiaPay.confirmed:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Column(
            children: [
              Icon(Icons.check_circle, size: 40, color: Colors.green),
              SizedBox(height: 8),
              Text(
                'Paiement confirmé !',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
              ),
              SizedBox(height: 4),
              Text(
                'Votre versement a été enregistré avec succès.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      case StatutPaiementKKiaPay.failed:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Column(
            children: [
              Icon(Icons.error, size: 40, color: Colors.red),
              SizedBox(height: 8),
              Text(
                'Paiement échoué',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
              ),
              SizedBox(height: 4),
              Text(
                'Le paiement a été refusé. Vérifiez votre solde mobile money et réessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      case StatutPaiementKKiaPay.expired:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Column(
            children: [
              Icon(Icons.timer_off, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Paiement expiré',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Le délai de confirmation est dépassé. Veuillez réessayer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      case StatutPaiementKKiaPay.idle:
        return const SizedBox.shrink();
    }
  }
}
