import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/anomalies/presentation/anomalie_provider.dart';
import 'package:motoprojet/features/anomalies/presentation/screens/anomalies_screen.dart';

/// ─── Widget de résumé des anomalies pour le dashboard ────────────────────────
/// Affiche un badge avec le nombre d'anomalies nouvelles et critiques.
/// Tappable pour naviguer vers l'écran complet.
class AnomaliesDashboardWidget extends ConsumerWidget {
  const AnomaliesDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(anomalieProvider);
    final anomalies = state.anomalies.where((a) => a.statut == 'nouveau').toList();

    if (anomalies.isEmpty) {
      return const SizedBox.shrink();
    }

    final nbCritiques = anomalies.where((a) => a.severite == 'critique').length;
    final nbNouveaux = anomalies.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: nbCritiques > 0 ? Colors.red.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: nbCritiques > 0 ? Colors.red.shade200 : Colors.orange.shade200,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnomaliesScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    nbCritiques > 0 ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: nbCritiques > 0 ? Colors.red : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Anomalies détectées',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Badge count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: nbCritiques > 0 ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$nbNouveaux',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 12),
              // Liste des 3 premières anomalies
              ...anomalies.take(3).map((anomalie) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anomalie.emojiSeverite,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anomalie.titre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              anomalie.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Lien voir plus
              if (anomalies.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${anomalies.length - 3} autre(s) anomalie(s)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
