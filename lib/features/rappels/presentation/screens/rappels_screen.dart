import 'package:flutter/material.dart';

class RappelsScreen extends StatelessWidget {
  const RappelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rappels')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Rappels de paiement', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Notifications et relances automatiques'),
          ],
        ),
      ),
    );
  }
}
