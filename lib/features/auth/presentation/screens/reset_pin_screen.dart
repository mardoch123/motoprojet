import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// Écran admin pour réinitialiser le PIN d'un chauffeur.
/// Affiche la liste des chauffeurs et permet de générer un PIN temporaire.
class ResetPinScreen extends ConsumerStatefulWidget {
  const ResetPinScreen({super.key});

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _chauffeurs = [];

  @override
  void initState() {
    super.initState();
    _loadChauffeurs();
  }

  Future<void> _loadChauffeurs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/auth/chauffeurs-for-reset');
      final data = response.data['data'] as List<dynamic>;
      setState(() {
        _chauffeurs = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPin(String userId, String nom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le PIN ?'),
        content: Text('Un nouveau PIN temporaire sera généré pour $nom. '
            'Le chauffeur devra le changer à sa prochaine connexion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Réinitialiser')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/auth/reset-pin', data: {
        'user_id': userId,
      });

      final data = response.data['data'] as Map<String, dynamic>;
      final tempPin = data['temporary_pin'] as String;
      final telephone = data['telephone'] as String;

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PIN réinitialisé'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chauffeur : $nom'),
                Text('Téléphone : $telephone'),
                const SizedBox(height: 12),
                const Text('PIN temporaire :', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor),
                  ),
                  child: Text(
                    tempPin,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Communiquez ce PIN au chauffeur. Il devra le changer à sa première connexion.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadChauffeurs();
                },
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialisation PIN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChauffeurs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadChauffeurs, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_chauffeurs.isEmpty) {
      return const Center(child: Text('Aucun chauffeur enregistré'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _chauffeurs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _chauffeurs[index];
        final mustChange = c['must_change_pin'] as bool? ?? false;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: mustChange ? Colors.orange[100] : Colors.green[100],
            child: Icon(
              mustChange ? Icons.warning_amber : Icons.check_circle,
              color: mustChange ? Colors.orange : Colors.green,
            ),
          ),
          title: Text(c['nom']?.toString() ?? 'Sans nom'),
          subtitle: Text(
            '${c['telephone'] ?? ''}\n'
            '${mustChange ? "PIN temporaire (non changé)" : "PIN actif"}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: ElevatedButton.icon(
            onPressed: () => _resetPin(c['id'] as String, c['nom']?.toString() ?? ''),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Reset'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
