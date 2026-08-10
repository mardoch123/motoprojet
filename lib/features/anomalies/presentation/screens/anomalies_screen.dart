import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/anomalies/presentation/anomalie_provider.dart';

/// ─── Écran de liste des anomalies détectées par l'IA ─────────────────────────
class AnomaliesScreen extends ConsumerStatefulWidget {
  const AnomaliesScreen({super.key});

  @override
  ConsumerState<AnomaliesScreen> createState() => _AnomaliesScreenState();
}

class _AnomaliesScreenState extends ConsumerState<AnomaliesScreen> {
  String? _filtreStatut;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(anomalieProvider.notifier).chargerAnomalies();
      ref.read(anomalieProvider.notifier).chargerStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(anomalieProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomalies détectées'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(anomalieProvider.notifier).chargerAnomalies(statut: _filtreStatut),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Forcer un scan',
            onPressed: () => _forcerScan(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats rapides
          if (state.stats != null) _buildStatsBar(state.stats!),
          // Filtres
          _buildFiltres(),
          // Liste
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.anomalies.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.anomalies.length,
                        itemBuilder: (context, index) {
                          return _buildAnomalieCard(state.anomalies[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(AnomalieStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Nouveaux', stats.nouveaux, Colors.orange),
          _buildStatItem('Critiques', stats.critiquesNouveaux, Colors.red),
          _buildStatItem('7 derniers jours', stats.derniers7j, AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFiltres() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Tous', null),
          const SizedBox(width: 8),
          _buildFilterChip('Nouveaux', 'nouveau'),
          const SizedBox(width: 8),
          _buildFilterChip('Critiques', null), // TODO: filter by severity
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? statut) {
    final isSelected = _filtreStatut == statut;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filtreStatut = selected ? statut : null;
        });
        ref.read(anomalieProvider.notifier).chargerAnomalies(statut: _filtreStatut);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune anomalie détectée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le système surveille en continu les indicateurs.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalieCard(Anomalie anomalie) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(anomalie.dateDetection.toLocal());

    Color severiteColor;
    switch (anomalie.severite) {
      case 'critique':
        severiteColor = Colors.red;
      case 'haute':
        severiteColor = Colors.orange;
      case 'moyenne':
        severiteColor = Colors.amber;
      default:
        severiteColor = Colors.blue;
    }

    Color statutColor;
    String statutLabel;
    switch (anomalie.statut) {
      case 'nouveau':
        statutColor = Colors.orange;
        statutLabel = 'Nouveau';
      case 'vu':
        statutColor = Colors.blue;
        statutLabel = 'Vu';
      case 'ignore':
        statutColor = Colors.grey;
        statutLabel = 'Ignoré';
      case 'traite':
        statutColor = Colors.green;
        statutLabel = 'Traité';
      default:
        statutColor = Colors.grey;
        statutLabel = anomalie.statut;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAnomalieDetail(anomalie),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Badge sévérité
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severiteColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: severiteColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      '${anomalie.emojiSeverite} ${anomalie.severite.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: severiteColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      anomalie.labelType,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  // Statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statutLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statutColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Titre
              Text(
                anomalie.titre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                anomalie.description,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnomalieDetail(Anomalie anomalie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _buildDetailContent(anomalie);
          },
        );
      },
    );
  }

  Widget _buildDetailContent(Anomalie anomalie) {
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(anomalie.dateDetection.toLocal());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        controller: ScrollController(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  anomalie.emojiSeverite,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anomalie.titre,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Détecté le $dateStr',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Description
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(anomalie.description),
            const SizedBox(height: 16),
            // Cause probable
            if (anomalie.causeProbable != null) ...[
              const Text('Cause probable', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(anomalie.causeProbable!),
              ),
              const SizedBox(height: 16),
            ],
            // Actions suggérées
            if (anomalie.actionsSuggerees.isNotEmpty) ...[
              const Text('Actions recommandées', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...anomalie.actionsSuggerees.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(entry.value),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            // Boutons d'action
            Row(
              children: [
                if (anomalie.statut == 'nouveau') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(anomalieProvider.notifier).changerStatut(anomalie.id, 'ignore');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Ignorer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(anomalieProvider.notifier).changerStatut(anomalie.id, 'traite');
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Marquer traité'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forcerScan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forcer un scan ?'),
        content: const Text('Cela va analyser tous les indicateurs et détecter les anomalies. Cela peut prendre quelques secondes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lancer le scan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(anomalieProvider.notifier).forcerScan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan terminé')),
        );
      }
    }
  }
}
