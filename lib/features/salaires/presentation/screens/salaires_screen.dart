import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/salaires/presentation/salaires_provider.dart';

/// ─── Écran de gestion des salaires (Super Admin uniquement) ──────────────────
class SalairesScreen extends ConsumerStatefulWidget {
  const SalairesScreen({super.key});

  @override
  ConsumerState<SalairesScreen> createState() => _SalairesScreenState();
}

class _SalairesScreenState extends ConsumerState<SalairesScreen> {
  final _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salairesProvider.notifier).chargerSalaires();
      ref.read(salairesProvider.notifier).chargerParametres();
      ref.read(salairesProvider.notifier).chargerCumuls();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salairesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des salaires'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Calculer le mois courant',
            onPressed: () => _calculerMoisCourant(),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Simulateur d\'impact',
            onPressed: () => _showSimulateur(),
          ),
        ],
      ),
      body: state.isLoading && state.salaires.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(salairesProvider.notifier).chargerSalaires();
                await ref.read(salairesProvider.notifier).chargerCumuls();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Paramètres ──
                  _buildParametresSection(state),
                  const SizedBox(height: 16),

                  // ── Cumuls ──
                  if (state.cumuls != null) ...[
                    _buildCumulsSection(state.cumuls!),
                    const SizedBox(height: 16),
                  ],

                  // ── Historique ──
                  _buildHistoriqueSection(state),

                  // ── Simulation ──
                  if (state.simulation != null) ...[
                    const SizedBox(height: 16),
                    _buildSimulationSection(state.simulation!),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ─── Paramètres ──────────────────────────────────────────────────────────────

  Widget _buildParametresSection(SalairesState state) {
    final p = state.parametres;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Paramètres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (p != null)
                  Switch.adaptive(
                    value: p.actif,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (v) {
                      ref.read(salairesProvider.notifier).updateParametres(
                        ParametresSalaire(
                          pctProprietaire: p.pctProprietaire,
                          pctEmploye: p.pctEmploye,
                          seuilVehicules: p.seuilVehicules,
                          actif: v,
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: 12),
              _buildParamTile('% Propriétaire', '${p.pctProprietaire}%', () => _editParam(
                'Pourcentage propriétaire (%)', p.pctProprietaire, (v) {
                  ref.read(salairesProvider.notifier).updateParametres(
                    ParametresSalaire(pctProprietaire: v, pctEmploye: p.pctEmploye, seuilVehicules: p.seuilVehicules, actif: p.actif),
                  );
                },
              )),
              _buildParamTile('% Employé', '${p.pctEmploye}%', () => _editParam(
                'Pourcentage employé (%)', p.pctEmploye, (v) {
                  ref.read(salairesProvider.notifier).updateParametres(
                    ParametresSalaire(pctProprietaire: p.pctProprietaire, pctEmploye: v, seuilVehicules: p.seuilVehicules, actif: p.actif),
                  );
                },
              )),
              _buildParamTile('Seuil véhicules', '${p.seuilVehicules} véhicules', () => _editParamInt(
                'Seuil de démarrage (nb véhicules)', p.seuilVehicules, (v) {
                  ref.read(salairesProvider.notifier).updateParametres(
                    ParametresSalaire(pctProprietaire: p.pctProprietaire, pctEmploye: p.pctEmploye, seuilVehicules: v, actif: p.actif),
                  );
                },
              )),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aucun salaire versé tant que le nombre de véhicules actifs est inférieur au seuil.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParamTile(String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 14, color: AppTheme.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  // ─── Cumuls ──────────────────────────────────────────────────────────────────

  Widget _buildCumulsSection(CumulsSalaire cumuls) {
    return Row(
      children: [
        _buildCumulCard('Propriétaire', cumuls.parProfil['proprietaire'], Colors.deepPurple),
        const SizedBox(width: 8),
        _buildCumulCard('Employé', cumuls.parProfil['employe'], Colors.teal),
      ],
    );
  }

  Widget _buildCumulCard(String label, ProfilCumul? cumul, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${_fmt.format(cumul?.totalVerse ?? 0)} F',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text('Moy. ${_fmt.format(cumul?.moyenneMensuelle ?? 0)} F/mois',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text('${cumul?.nbMois ?? 0} mois · Versé: ${_fmt.format(cumul?.totalCalcule ?? 0)} F',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Historique ──────────────────────────────────────────────────────────────

  Widget _buildHistoriqueSection(SalairesState state) {
    // Grouper par mois
    final grouped = <String, List<Salaire>>{};
    for (final s in state.salaires) {
      grouped.putIfAbsent(s.mois, () => []).add(s);
    }
    final moisTries = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historique (${state.salaires.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        if (moisTries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun salaire enregistré', style: TextStyle(color: AppTheme.textSecondary))),
            ),
          )
        else
          ...moisTries.map((mois) => _buildMoisGroup(mois, grouped[mois]!)),
      ],
    );
  }

  Widget _buildMoisGroup(String mois, List<Salaire> salaires) {
    final total = salaires.fold<double>(0, (sum, s) => sum + s.montant);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.parse('$mois-01')),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Total: ${_fmt.format(total)} FCFA',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        children: salaires.map((s) => _buildSalaireTile(s)).toList(),
      ),
    );
  }

  Widget _buildSalaireTile(Salaire s) {
    final color = s.statut == 'verse' ? Colors.green : s.statut == 'annule' ? Colors.red : Colors.orange;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(
          s.profil == 'proprietaire' ? Icons.person : Icons.people,
          size: 16, color: color,
        ),
      ),
      title: Text(s.profil == 'proprietaire' ? 'Propriétaire' : 'Employé',
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${s.vehiculesActifs} véh. actifs · ${s.pctApplique}% · Revenu: ${_fmt.format(s.revenuEncaisse)} F${s.note != null ? '\n${s.note}' : ''}',
        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${_fmt.format(s.montant)} F',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(s.labelStatut, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      onTap: () => _showSalaireActions(s),
    );
  }

  // ─── Simulation ──────────────────────────────────────────────────────────────

  Widget _buildSimulationSection(SimulationResultat result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                const Text('Simulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {}), // fermer
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Fermer'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSimMetric('Total Prop.', '${_fmt.format(result.totalSalairesProprietaire)} F', Colors.deepPurple),
                const SizedBox(width: 8),
                _buildSimMetric('Total Emp.', '${_fmt.format(result.totalSalairesEmploye)} F', Colors.teal),
                const SizedBox(width: 8),
                _buildSimMetric('Total versé', '${_fmt.format(result.totalVerse)} F', AppTheme.primaryColor),
              ],
            ),
            if (result.moisDefaillance != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Salaire à 0 F dès ${result.moisDefaillance}',
                        style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: result.scenarios.length,
                itemBuilder: (_, i) {
                  final m = result.scenarios[i];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: m.seuilAtteint ? Colors.green.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: m.seuilAtteint ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.mois.substring(5), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${m.vehiculesActifs} véh.', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                        const Spacer(),
                        Text(_fmt.format(m.salaireProprietaire), style: const TextStyle(fontSize: 9, color: Colors.deepPurple)),
                        Text(_fmt.format(m.salaireEmploye), style: const TextStyle(fontSize: 9, color: Colors.teal)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  void _calculerMoisCourant() {
    final now = DateTime.now();
    final mois = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calculer les salaires'),
        content: Text('Calculer les salaires pour ${DateFormat('MMMM yyyy', 'fr_FR').format(now)} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(salairesProvider.notifier).calculerMois(mois);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Calculer'),
          ),
        ],
      ),
    );
  }

  void _showSalaireActions(Salaire s) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('${s.profil == 'proprietaire' ? 'Propriétaire' : 'Employé'} — ${s.mois}'),
              subtitle: Text('Montant: ${_fmt.format(s.montant)} F · ${s.labelStatut}'),
            ),
            const Divider(),
            if (s.statut == 'calcule')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Marquer comme versé'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(salairesProvider.notifier).validerSalaire(s.id);
                },
              ),
            if (s.statut != 'verse' && s.statut != 'annule')
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Annuler'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(salairesProvider.notifier).annulerSalaire(s.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSimulateur() {
    final params = ref.read(salairesProvider).parametres;
    double pctProp = params?.pctProprietaire ?? 8;
    double pctEmp = params?.pctEmploye ?? 4;
    int seuil = params?.seuilVehicules ?? 5;
    int nbMois = 12;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Simulateur d\'impact'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSlider('Propriétaire (%)', pctProp, 0, 30, 1, (v) {
                  setDialogState(() => pctProp = v);
                }),
                _buildSlider('Employé (%)', pctEmp, 0, 20, 1, (v) {
                  setDialogState(() => pctEmp = v);
                }),
                _buildSlider('Seuil véhicules', seuil.toDouble(), 0, 20, 1, (v) {
                  setDialogState(() => seuil = v.toInt());
                }),
                _buildSlider('Durée (mois)', nbMois.toDouble(), 3, 36, 1, (v) {
                  setDialogState(() => nbMois = v.toInt());
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(salairesProvider.notifier).simuler(
                  pctProprietaire: pctProp,
                  pctEmploye: pctEmp,
                  seuilVehicules: seuil,
                  nbMois: nbMois,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Simuler'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, int divisions, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: value.toStringAsFixed(0),
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _editParam(String label, double current, ValueChanged<double> onSave) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '%'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 0 && v <= 50) onSave(v);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editParamInt(String label, int current, ValueChanged<int> onSave) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v >= 0) onSave(v);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
