import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/simulation/core/simulation_engine.dart';
import 'package:motoprojet/features/simulation/presentation/simulation_provider.dart';
import 'package:motoprojet/features/simulation/presentation/widgets/simulation_export.dart';

const _scenarioColors = [AppTheme.primaryColor, Colors.blue, Colors.deepOrange];

/// ─── Écran principal de simulation financière ────────────────────────────────
class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  static const _colors = _scenarioColors;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulation financière'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: List.generate(3, (i) {
            final scenario = i < state.scenarios.length ? state.scenarios[i] : null;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _scenarioColors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      scenario?.nom ?? 'Sc. ${i + 1}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Calculer tous les scénarios',
            onPressed: () => ref.read(simulationProvider.notifier).calculerTous(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenuAction(v, _currentTab),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renommer')),
              const PopupMenuItem(value: 'reset', child: Text('Réinitialiser')),
              const PopupMenuItem(value: 'export_csv', child: Text('Exporter CSV')),
              const PopupMenuItem(value: 'export_pdf', child: Text('Exporter PDF')),
              const PopupMenuItem(value: 'apply', child: Text('Appliquer aux paramètres réels')),
            ],
          ),
        ],
      ),
      body: state.scenarios.isEmpty
          ? const Center(child: Text('Aucun scénario'))
          : TabBarView(
              controller: _tabController,
              children: List.generate(3, (i) {
                if (i >= state.scenarios.length) {
                  return const Center(child: Text('Scénario vide'));
                }
                return _ScenarioTab(
                  index: i,
                  scenario: state.scenarios[i],
                  color: _colors[i],
                );
              }),
            ),
      bottomNavigationBar: _hasAnyResult(state)
          ? Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: SafeArea(
                child: Row(
                  children: [
                    // Toggle visibilité scénarios
                    ...List.generate(state.scenarios.length, (i) {
                      final s = state.scenarios[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(s.nom, style: const TextStyle(fontSize: 11)),
                          selected: s.actif,
                          onSelected: (_) => ref.read(simulationProvider.notifier).toggleScenario(i),
                          selectedColor: _scenarioColors[i].withValues(alpha: 0.2),
                          checkmarkColor: _scenarioColors[i],
                        ),
                      );
                    }),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(simulationProvider.notifier).calculerTous(),
                      icon: state.isCalculating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                      label: Text(state.isCalculating ? 'Calcul...' : 'Recalculer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  bool _hasAnyResult(SimulationState state) {
    return state.scenarios.any((s) => s.resultat != null);
  }

  void _onMenuAction(String action, int tabIndex) {
    final notifier = ref.read(simulationProvider.notifier);
    switch (action) {
      case 'rename':
        _showRenameDialog(tabIndex);
      case 'reset':
        notifier.reinitialiserScenario(tabIndex);
      case 'export_csv':
        final scenario = ref.read(simulationProvider).scenarios[tabIndex];
        if (scenario.resultat != null) {
          SimulationExport.exportCSV(scenario.nom, scenario.resultat!);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exporté')));
        }
      case 'export_pdf':
        final scenarios = ref.read(simulationProvider).scenarios.where((s) => s.resultat != null).toList();
        if (scenarios.isNotEmpty) {
          SimulationExport.exportPDF(scenarios);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF exporté')));
        }
      case 'apply':
        _showApplyDialog(tabIndex);
    }
  }

  void _showRenameDialog(int index) {
    final controller = TextEditingController(text: ref.read(simulationProvider).scenarios[index].nom);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer le scénario'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom du scénario'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              ref.read(simulationProvider.notifier).renommerScenario(index, controller.text);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showApplyDialog(int index) {
    final scenario = ref.read(simulationProvider).scenarios[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Appliquer les paramètres ?'),
        content: Text('Les paramètres de "${scenario.nom}" seront utilisés comme base réelle de l\'application (prix, durées, etc.).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              // TODO: Appeler l'API backend pour mettre à jour les paramètres réels
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Paramètres de "${scenario.nom}" appliqués')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }
}

// ─── Onglet de scénario (config + résultats) ─────────────────────────────────

class _ScenarioTab extends ConsumerStatefulWidget {
  final int index;
  final ScenarioConfig scenario;
  final Color color;

  const _ScenarioTab({required this.index, required this.scenario, required this.color});

  @override
  ConsumerState<_ScenarioTab> createState() => _ScenarioTabState();
}

class _ScenarioTabState extends ConsumerState<_ScenarioTab> {
  int get index => widget.index;
  ScenarioConfig get scenario => widget.scenario;
  Color get color => widget.color;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulationProvider);
    final currentScenario = index < state.scenarios.length ? state.scenarios[index] : scenario;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'F', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Paramètres ──
          _buildSectionTitle('Paramètres'),
          const SizedBox(height: 8),
          _buildParametresCard(context),
          const SizedBox(height: 16),

          // ── Bouton calculer ──
          Center(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(simulationProvider.notifier).calculerScenario(index),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lancer la simulation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Résultats ──
          if (currentScenario.resultat != null) ...[
            _buildSectionTitle('Résultats'),
            const SizedBox(height: 8),
            _buildResultatsCards(currentScenario.resultat!, fmt),
            const SizedBox(height: 16),
            _buildSectionTitle('Évolution du patrimoine'),
            const SizedBox(height: 8),
            _buildChart(context),
            const SizedBox(height: 16),
            _buildSectionTitle('Détail mensuel'),
            const SizedBox(height: 8),
            _buildTable(currentScenario.resultat!, fmt),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary));
  }

  Widget _buildParametresCard(BuildContext context) {
    final p = scenario.parametres;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildParamRow('Prix moto', '${_fmtNum(p.prixMoto)} FCFA', () => _editParam('Prix moto', p.prixMoto, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(prixMoto: v));
            })),
            _buildParamRow('Prix voiture', '${_fmtNum(p.prixVoiture)} FCFA', () => _editParam('Prix voiture', p.prixVoiture, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(prixVoiture: v));
            })),
            _buildParamRow('Remb. jour moto', '${_fmtNum(p.remboursementJourMoto)} FCFA', () => _editParam('Remboursement/jour moto', p.remboursementJourMoto, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(remboursementJourMoto: v));
            })),
            _buildParamRow('Remb. jour voiture', '${_fmtNum(p.remboursementJourVoiture)} FCFA', () => _editParam('Remboursement/jour voiture', p.remboursementJourVoiture, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(remboursementJourVoiture: v));
            })),
            _buildParamRow('Durée remboursement', '${p.dureeRemboursementMois} mois', () => _editParamInt('Durée (mois)', p.dureeRemboursementMois, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(dureeRemboursementMois: v));
            })),
            _buildParamRow('Taux recouvrement', '${(p.tauxRecouvrement * 100).toInt()}%', () => _editParam('Taux recouvrement (%)', p.tauxRecouvrement * 100, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(tauxRecouvrement: v / 100));
            })),
            _buildParamRow('Règle réinvestissement', _regleLabel(p.regle), () => _editRegle(index, p)),
            _buildParamRow('Cash initial', '${_fmtNum(p.cashInitial)} FCFA', () => _editParam('Cash initial', p.cashInitial, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(cashInitial: v));
            })),
            _buildParamRow('Durée simulation', '${p.dureeMois} mois', () => _editParamInt('Durée simulation (mois)', p.dureeMois, (v) {
              ref.read(simulationProvider.notifier).updateParametres(index, p.copyWith(dureeMois: v));
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow(String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 14, color: AppTheme.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildResultatsCards(ResultatSimulation r, NumberFormat fmt) {
    final d = r.dernier;
    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard('Véhicules achetés', '${d.totalVehicules}', '${d.motosAchetees} motos / ${d.voituresAchetees} voitures', Icons.directions_car, color),
            const SizedBox(width: 8),
            _buildMetricCard('Cash disponible', fmt.format(d.cashDisponible), 'Cash cumulé : ${fmt.format(d.cashCumuleTotal)}', Icons.account_balance, d.cashDisponible >= 0 ? Colors.green : Colors.red),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricCard('Véhicules actifs', '${d.totalActifs}', '${d.motosActives} motos / ${d.voituresActives} voitures', Icons.trending_up, Colors.blue),
            const SizedBox(width: 8),
            _buildMetricCard('Patrimoine total', fmt.format(d.patrimoineTotal), 'Cash + valeur résiduelle', Icons.account_balance_wallet, Colors.deepPurple),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String subtitle, IconData icon, Color c) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final state = ref.watch(simulationProvider);
    final actifs = state.scenarios.where((s) => s.actif && s.resultat != null).toList();

    if (actifs.isEmpty) return const SizedBox.shrink();

    // Si plusieurs scénarios actifs → graphique comparatif
    final allSpots = <int, List<FlSpot>>{};
    double maxY = 0;
    int maxX = 0;

    for (int i = 0; i < actifs.length; i++) {
      final scenarioIndex = state.scenarios.indexOf(actifs[i]);
      final spots = actifs[i].resultat!.snapshots.asMap().entries.map((e) {
        final y = e.value.patrimoineTotal / 1000000; // en millions
        if (y > maxY) maxY = y;
        if (e.key > maxX) maxX = e.key;
        return FlSpot(e.value.periode.toDouble(), y);
      }).toList();
      allSpots[scenarioIndex] = spots;
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => Text('${v.toInt()}M', style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => Text('M${v.toInt()}', style: const TextStyle(fontSize: 10)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: allSpots.entries.map((entry) {
            return LineChartBarData(
              spots: entry.value,
              isCurved: true,
              color: _scenarioColors[entry.key],
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: _scenarioColors[entry.key].withValues(alpha: 0.1)),
            );
          }).toList(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((s) {
                  final sIdx = allSpots.keys.toList()[spots.indexOf(s)];
                  return LineTooltipItem(
                    '${state.scenarios[sIdx].nom}: ${s.y.toStringAsFixed(1)}M FCFA',
                    TextStyle(color: _scenarioColors[sIdx], fontWeight: FontWeight.bold, fontSize: 11),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(ResultatSimulation r, NumberFormat fmt) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columns: const [
          DataColumn(label: Text('Mois', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Motos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Voitures', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Actifs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Cash', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Patrimoine', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
        ],
        rows: r.snapshots.map((s) {
          return DataRow(cells: [
            DataCell(Text('M${s.periode}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('${s.motosAchetees}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('${s.voituresAchetees}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('${s.totalActifs}', style: const TextStyle(fontSize: 11))),
            DataCell(Text(_fmtNum(s.cashDisponible), style: TextStyle(fontSize: 11, color: s.cashDisponible >= 0 ? Colors.green : Colors.red))),
            DataCell(Text(_fmtNum(s.patrimoineTotal), style: const TextStyle(fontSize: 11))),
          ]);
        }).toList(),
      ),
    );
  }

  // ─── Helpers d'édition ──────────────────────────────────────────────────────

  void _editParam(String label, double current, ValueChanged<double> onSave) {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'FCFA'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 0) onSave(v);
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
              if (v != null && v > 0) onSave(v);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editRegle(int scenarioIndex, ParametresSimulation p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Règle de réinvestissement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RegleReinvestissement.values.map((r) {
            final isSelected = p.regle == r;
            return ListTile(
              title: Text(_regleLabel(r), style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              )),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20)
                  : null,
              onTap: () {
                ref.read(simulationProvider.notifier).updateParametres(scenarioIndex, p.copyWith(regle: r));
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _regleLabel(RegleReinvestissement r) {
    switch (r) {
      case RegleReinvestissement.toutMoto: return '100% motos';
      case RegleReinvestissement.toutVoiture: return '100% voitures';
      case RegleReinvestissement.basculeDate: return 'Bascule à date fixe';
      case RegleReinvestissement.rythmeMixte: return 'Mixte (rythme)';
    }
  }

  String _fmtNum(double n) => NumberFormat.decimalPattern('fr_FR').format(n.round());
}
