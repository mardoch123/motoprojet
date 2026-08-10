import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../prochain_achat_provider.dart';
import 'package:motoprojet/features/finances/presentation/screens/apports_config_screen.dart';

/// Widget temps réel affichant les barres de progression
/// pour le prochain achat de moto et voiture.
class ProchainAchatWidget extends ConsumerStatefulWidget {
  const ProchainAchatWidget({super.key});

  @override
  ConsumerState<ProchainAchatWidget> createState() => _ProchainAchatWidgetState();
}

class _ProchainAchatWidgetState extends ConsumerState<ProchainAchatWidget> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(prochainAchatProvider.notifier).charger());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prochainAchatProvider);

    if (state.isLoading && state.data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.error != null && state.data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text('Erreur: ${state.error}')),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(prochainAchatProvider.notifier).charger(),
              ),
            ],
          ),
        ),
      );
    }

    final data = state.data!;
    final fmt = NumberFormat.decimalPattern('fr_FR');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ───────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.speed, size: 22, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text(
                  'PROCHAIN ACHAT',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                ),
                const Spacer(),
                // Rythme moyen
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '${fmt.format(data.rythme.moyenneJournaliere)} F/jour',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.savings, size: 18, color: Colors.amber),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApportsConfigScreen())),
                  tooltip: 'Configurer apports',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.read(prochainAchatProvider.notifier).charger(),
                  tooltip: 'Actualiser',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Trésorerie disponible
            Row(
              children: [
                Text(
                  'Caisse : ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '${fmt.format(data.tresorerie.disponible.round())} F',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Text(
                  '${data.tresorerie.nbVehiculesAchetes} véhicule(s) acheté(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 2 barres côte à côte ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BarreVehicule(
                    icone: Icons.two_wheeler,
                    label: 'Prochaine moto',
                    vehicule: data.moto,
                    couleur: Colors.deepOrange,
                    fmt: fmt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BarreVehicule(
                    icone: Icons.directions_car,
                    label: 'Prochaine voiture',
                    vehicule: data.voiture,
                    couleur: Colors.indigo,
                    fmt: fmt,
                  ),
                ),
              ],
            ),

            // ── Historique résumé ─────────────────────────────────────
            if (data.historique.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Derniers achats',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...data.historique.take(3).map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      h.type == 'moto' ? Icons.two_wheeler : Icons.directions_car,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(h.plaque, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(h.marque ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const Spacer(),
                    Text('${fmt.format(h.prix.round())} F', style: const TextStyle(fontSize: 11)),
                    if (h.date != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(h.date!),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

/// Barre de progression pour un type de véhicule
class _BarreVehicule extends StatelessWidget {
  final IconData icone;
  final String label;
  final ProchainAchatVehicule vehicule;
  final Color couleur;
  final NumberFormat fmt;

  const _BarreVehicule({
    required this.icone,
    required this.label,
    required this.vehicule,
    required this.couleur,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = vehicule.pct.clamp(0.0, 100.0);
    final estPossible = vehicule.achatPossible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          children: [
            Icon(icone, size: 18, color: couleur),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: couleur),
              ),
            ),
            if (estPossible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRÊT',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green.shade800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Barre de progression
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 14,
            backgroundColor: couleur.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
        const SizedBox(height: 6),

        // Montants
        Text(
          '${fmt.format(vehicule.cashAlloue.round())} F / ${fmt.format(vehicule.prix.round())} F',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        if (!estPossible) ...[
          const SizedBox(height: 2),
          Text(
            'Il manque ${fmt.format(vehicule.manque.round())} F',
            style: TextStyle(fontSize: 10, color: Colors.red.shade700),
          ),
        ],

        // Projection date
        const SizedBox(height: 8),
        if (estPossible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'Achat possible maintenant',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                ),
              ],
            ),
          )
        else if (vehicule.dateEstimee != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: couleur.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 11, color: couleur),
                const SizedBox(width: 4),
                Text(
                  _projectionLabel(vehicule),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: couleur),
                ),
              ],
            ),
          )
        else if (vehicule.rythmeJour == 0 && vehicule.apportsJour == 0)
          Text(
            'Aucun encaissement récent',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),

        // Apports personnels
        if (vehicule.apportsJour > 0)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.savings, size: 10, color: Colors.amber.shade800),
                const SizedBox(width: 4),
                Text(
                  '+${fmt.format(vehicule.apportsJour)} F/jour apports',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                ),
              ],
            ),
          ),

        // Pourcentage
        const SizedBox(height: 4),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
        ),
      ],
    );
  }

  String _projectionLabel(ProchainAchatVehicule v) {
    final jours = v.joursRestants;
    if (jours == null) return '';
    if (jours <= 1) return "Aujourd'hui !";
    if (jours <= 7) return 'Dans $jours jours';
    if (jours <= 30) return 'Dans ${jours ~/ 7} sem.';
    return '~${_formatDate(v.dateEstimee!)}';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
