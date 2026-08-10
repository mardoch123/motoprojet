import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/features/ia/presentation/ia_provider.dart';

class IaScreen extends ConsumerStatefulWidget {
  const IaScreen({super.key});

  @override
  ConsumerState<IaScreen> createState() => _IaScreenState();
}

class _IaScreenState extends ConsumerState<IaScreen> {
  final _revenuController = TextEditingController();
  final _objectifController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Charger l'historique au démarrage
    Future.microtask(() {
      ref.read(iaProvider.notifier).chargerHistorique();
    });
  }

  @override
  void dispose() {
    _revenuController.dispose();
    _objectifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iaState = ref.watch(iaProvider);
    final theme = Theme.of(context);

    // Synchroniser l'objectif depuis l'état
    if (_objectifController.text.isEmpty && iaState.objectifJournalier > 0) {
      _objectifController.text = iaState.objectifJournalier.toStringAsFixed(0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant IA'),
        actions: [
          // Indicateur GPS
          IconButton(
            icon: Icon(
              iaState.gpsActif ? Icons.gps_fixed : Icons.gps_off,
              color: iaState.gpsActif ? Colors.green : null,
            ),
            tooltip: iaState.gpsActif ? 'GPS actif' : 'GPS inactif',
            onPressed: () => _showGpsDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(iaProvider.notifier).refreshGpsData();
          await ref.read(iaProvider.notifier).chargerHistorique();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Carte objectif ──────────────────────────────────────────
              _buildObjectifCard(context, theme, iaState),
              const SizedBox(height: 16),

              // ─── Carte suivi du jour ─────────────────────────────────────
              _buildSuiviJourCard(context, theme, iaState),
              const SizedBox(height: 16),

              // ─── Bouton demander recommandation ──────────────────────────
              _buildRecommandationButton(context, theme, iaState),
              const SizedBox(height: 16),

              // ─── Carte recommandation ────────────────────────────────────
              if (iaState.status == IaStatus.loading)
                _buildLoadingCard(theme)
              else if (iaState.derniereRecommandation != null)
                _buildRecommandationCard(context, theme, iaState),

              if (iaState.status == IaStatus.error && iaState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              iaState.errorMessage!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ─── Historique ──────────────────────────────────────────────
              if (iaState.historique != null) _buildHistoriqueSection(context, theme, iaState),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Carte objectif ───────────────────────────────────────────────────────
  Widget _buildObjectifCard(BuildContext context, ThemeData theme, IaState iaState) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Objectif journalier', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _objectifController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Ex: 10000',
                      suffixText: 'FCFA',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(_objectifController.text);
                    if (val != null && val > 0) {
                      ref.read(iaProvider.notifier).updateObjectif(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Objectif : ${val.toStringAsFixed(0)} FCFA/jour')),
                      );
                    }
                  },
                  child: const Text('Définir'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Objectif actuel : ${iaState.objectifJournalier.toStringAsFixed(0)} FCFA/jour',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Carte suivi du jour ──────────────────────────────────────────────────
  Widget _buildSuiviJourCard(BuildContext context, ThemeData theme, IaState iaState) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text('Suivi du jour', style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iaState.gpsActif ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    iaState.gpsActif ? '🟢 GPS actif' : '⚪ GPS inactif',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Revenu saisi
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _revenuController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Revenu du jour',
                      hintText: 'Ex: 12000',
                      suffixText: 'FCFA',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats GPS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                  Icons.directions_car,
                  '${iaState.kmParcourus.toStringAsFixed(1)} km',
                  'Aujourd\'hui',
                  theme,
                ),
                _buildMiniStat(
                  Icons.map_outlined,
                  '${iaState.zonesVisitees.length}',
                  'Zones visitées',
                  theme,
                ),
                if (iaState.derniereRecommandation != null)
                  _buildMiniStat(
                    iaState.derniereRecommandation!.objectifAtteint
                        ? Icons.check_circle
                        : Icons.trending_up,
                    '${iaState.derniereRecommandation!.joursObjectifAtteint7j}/7',
                    'Objectifs (7j)',
                    theme,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  // ─── Bouton recommandation ────────────────────────────────────────────────
  Widget _buildRecommandationButton(BuildContext context, ThemeData theme, IaState iaState) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: iaState.status == IaStatus.loading
            ? null
            : () {
                final revenu = double.tryParse(_revenuController.text) ?? 0;
                ref.read(iaProvider.notifier).demanderRecommandation(revenuJour: revenu);
              },
        icon: iaState.status == IaStatus.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          iaState.status == IaStatus.loading
              ? 'Analyse en cours...'
              : 'Demander une recommandation',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ─── Carte recommandation ─────────────────────────────────────────────────
  Widget _buildRecommandationCard(BuildContext context, ThemeData theme, IaState iaState) {
    final reco = iaState.derniereRecommandation!;
    final isAtteint = reco.objectifAtteint;

    return Card(
      elevation: 3,
      color: isAtteint ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAtteint ? Icons.celebration : Icons.lightbulb_outline,
                  color: isAtteint ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAtteint ? 'Objectif atteint !' : 'Conseil du jour',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isAtteint ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'Via ${reco.modeleUtilise == 'deepseek' ? 'Deepseek' : 'Claude'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reco.recommandation,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Résumé chiffré
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildChip(
                  Icons.account_balance_wallet,
                  '${reco.revenuJour.toStringAsFixed(0)} / ${reco.objectifJour.toStringAsFixed(0)} FCFA',
                  isAtteint ? Colors.green : Colors.orange,
                ),
                _buildChip(
                  Icons.directions_car,
                  '${reco.kmJour.toStringAsFixed(1)} km aujourd\'hui',
                  Colors.blue,
                ),
                _buildChip(
                  Icons.calendar_today,
                  '${reco.km7j.toStringAsFixed(0)} km (7j)',
                  Colors.purple,
                ),
                if (reco.ecart >= 0)
                  _buildChip(Icons.savings, '+${reco.ecart.toStringAsFixed(0)} FCFA surplus', Colors.green.shade700)
                else
                  _buildChip(Icons.trending_up, '${reco.ecart.toStringAsFixed(0)} FCFA à rattraper', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────
  Widget _buildLoadingCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Analyse de votre journée en cours...', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('L\'assistant prépare vos recommandations', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  // ─── Historique ───────────────────────────────────────────────────────────
  Widget _buildHistoriqueSection(BuildContext context, ThemeData theme, IaState iaState) {
    final historique = iaState.historique!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        // Stats globales
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('${historique.totalJours}', 'Jours analysés', theme),
                _buildStatColumn('${historique.joursObjectifAtteint}', 'Objectifs atteints', theme),
                _buildStatColumn('${historique.tauxReussite}%', 'Taux réussite', theme),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Liste des recommandations récentes
        ...historique.recommandations.take(7).map((reco) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: reco.objectifAtteint ? Colors.green.shade100 : Colors.orange.shade100,
                child: Icon(
                  reco.objectifAtteint ? Icons.check : Icons.trending_up,
                  color: reco.objectifAtteint ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              title: Text(
                reco.recommandation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${reco.date.day}/${reco.date.month} • ${reco.revenuJour.toStringAsFixed(0)} FCFA • ${reco.kmJour.toStringAsFixed(0)} km',
                style: theme.textTheme.bodySmall,
              ),
              dense: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatColumn(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  // ─── Dialog GPS ───────────────────────────────────────────────────────────
  void _showGpsDialog(BuildContext context) {
    final iaState = ref.read(iaProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(iaState.gpsActif ? 'Suivi GPS actif' : 'Activer le suivi GPS'),
        content: Text(
          iaState.gpsActif
              ? 'Le GPS suit vos déplacements de 6h à 22h pour calculer votre kilométrage et les zones fréquentées. Aucune coordonnée précise n\'est transmise.'
              : 'Activez le GPS pour suivre automatiquement votre kilométrage et vos zones d\'activité. Le suivi ne fonctionne que pendant vos heures de travail (6h-22h).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          if (!iaState.gpsActif)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(iaProvider.notifier).demarrerGps();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible d\'activer le GPS. Vérifiez les permissions.')),
                  );
                }
              },
              child: const Text('Activer'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(iaProvider.notifier).arreterGps();
              },
              child: const Text('Arrêter', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
