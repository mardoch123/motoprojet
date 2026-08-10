import 'package:flutter/material.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord financier')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé financier
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vue d\'ensemble', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatCard(
                          label: 'Total collecté',
                          value: '12 450 000',
                          unit: 'FCFA',
                          icon: Icons.account_balance_wallet,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'En cours',
                          value: '3 200 000',
                          unit: 'FCFA',
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatCard(
                          label: 'Chauffeurs actifs',
                          value: '45',
                          unit: '',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Véhicules financés',
                          value: '38',
                          unit: '',
                          icon: Icons.directions_car,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Financements actifs
            Text('Financements actifs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.motorcycle)),
                title: const Text('Moto Jakarta — Koffi A.'),
                subtitle: LinearProgressIndicator(value: 0.65),
                trailing: const Text('65%'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                title: const Text('Toyota Corolla — Mensah B.'),
                subtitle: LinearProgressIndicator(value: 0.32),
                trailing: const Text('32%'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              '$value $unit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
