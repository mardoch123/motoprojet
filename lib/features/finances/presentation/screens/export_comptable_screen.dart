import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../finances_provider.dart';

/// Écran d'export comptable pour le Super Admin
class ExportComptableScreen extends ConsumerStatefulWidget {
  const ExportComptableScreen({super.key});

  @override
  ConsumerState<ExportComptableScreen> createState() => _ExportComptableScreenState();
}

class _ExportComptableScreenState extends ConsumerState<ExportComptableScreen> {
  DateTime _dateDebut = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateFin = DateTime.now();
  final _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(financesProvider.notifier).chargerPatrimoine();
      ref.read(financesProvider.notifier).chargerDepots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Comptable'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Patrimoine actuel ──
            _buildPatrimoineSection(state),
            const SizedBox(height: 24),

            // ── Dépôts en banque ──
            _buildDepotsSection(state),
            const SizedBox(height: 24),

            // ── Export comptable ──
            _buildExportSection(state),
          ],
        ),
      ),
    );
  }

  Widget _buildPatrimoineSection(FinancesState state) {
    final patrimoine = state.patrimoine;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'PATRIMOINE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                ),
                const Spacer(),
                if (state.isLoadingPatrimoine)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                if (!state.isLoadingPatrimoine)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => ref.read(financesProvider.notifier).chargerPatrimoine(),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (patrimoine == null)
              const Center(child: Text('Aucune donnée'))
            else ...[
              // Total patrimoine
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade50, Colors.indigo.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Patrimoine total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt.format(patrimoine.patrimoineTotal)} F',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.indigo.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPatrimoineItem(
                      'Cash en caisse',
                      patrimoine.cashEnCaisse,
                      Icons.money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPatrimoineItem(
                      'Véhicules actifs',
                      patrimoine.valeurVehiculesActifs,
                      Icons.directions_car,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStat('Véhicules actifs', patrimoine.nbVehiculesActifs.toString()),
                  const SizedBox(width: 16),
                  _buildStat('Véhicules remboursés', patrimoine.nbVehiculesRembourses.toString()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatrimoineItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text('${_fmt.format(value)} F', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Row(
      children: [
        Text('$value ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDepotsSection(FinancesState state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'DÉPÔTS EN BANQUE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                ),
                const Spacer(),
                if (state.isLoadingDepots)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                if (!state.isLoadingDepots)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => ref.read(financesProvider.notifier).chargerDepots(),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.depots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Aucun dépôt enregistré', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...state.depots.take(5).map((d) => _buildDepotItem(d)),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showNouveauDepotDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau dépôt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepotItem(DepotBanque depot) {
    final ecart = depot.ecart;
    final ecartColor = ecart == 0 ? Colors.green : (ecart < 0 ? Colors.red : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: depot.rapproche ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM/yyyy').format(DateTime.parse(depot.dateDepot)),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (depot.rapproche)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rapproché',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Théorique: ${_fmt.format(depot.montantTheorique)} F', style: const TextStyle(fontSize: 11)),
                    Text('Réel: ${_fmt.format(depot.montantReel)} F', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ecartColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Écart: ${ecart >= 0 ? '+' : ''}${_fmt.format(ecart)} F',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ecartColor),
                ),
              ),
            ],
          ),
          if (!depot.rapproche) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref.read(financesProvider.notifier).rapprocherDepot(depot.id),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Rapprocher'),
                style: TextButton.styleFrom(foregroundColor: Colors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportSection(FinancesState state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'EXPORT COMPTABLE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker('Du', _dateDebut, (d) => setState(() => _dateDebut = d)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDatePicker('Au', _dateFin, (d) => setState(() => _dateFin = d)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isLoadingExport
                    ? null
                    : () => ref.read(financesProvider.notifier).genererExport(
                          DateFormat('yyyy-MM-dd').format(_dateDebut),
                          DateFormat('yyyy-MM-dd').format(_dateFin),
                        ),
                icon: state.isLoadingExport
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download),
                label: Text(state.isLoadingExport ? 'Génération...' : 'Générer l\'export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (state.exportData != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildExportResume(state.exportData!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportResume(ExportComptableData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Résumé de la période', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildResumeRow('Total encaissé', data.totalEncaisse, Colors.green),
        _buildResumeRow('Salaires versés', data.totalSalaires, Colors.orange),
        _buildResumeRow('Dépenses incidents', data.totalDepenses, Colors.red),
        _buildResumeRow('Achats véhicules', data.totalAchats, Colors.blue),
        const Divider(),
        _buildResumeRow('Cash net', data.cashNet, Colors.indigo, bold: true),
        const SizedBox(height: 8),
        _buildResumeRow('Patrimoine final', data.patrimoineFinal, Colors.deepPurple, bold: true),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatChip('${data.nbPaiements} paiements', Colors.blue),
            const SizedBox(width: 8),
            _buildStatChip('${data.paiements.length} entrées', Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildResumeRow(String label, int value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: bold ? Colors.black : Colors.grey.shade700)),
          const Spacer(),
          Text(
            '${_fmt.format(value)} F',
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Future<void> _showNouveauDepotDialog() async {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final theoriqueController = TextEditingController();
    final reelController = TextEditingController();
    final banqueController = TextEditingController();
    final refController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau dépôt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: theoriqueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant théorique (F)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant réel déposé (F)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: banqueController,
                decoration: const InputDecoration(labelText: 'Banque'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: const InputDecoration(labelText: 'Référence'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final theorique = int.tryParse(theoriqueController.text) ?? 0;
              final reel = int.tryParse(reelController.text) ?? 0;
              if (theorique > 0 && reel >= 0) {
                ref.read(financesProvider.notifier).creerDepot(
                  dateDepot: dateController.text,
                  montantTheorique: theorique,
                  montantReel: reel,
                  banque: banqueController.text.isNotEmpty ? banqueController.text : null,
                  reference: refController.text.isNotEmpty ? refController.text : null,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
