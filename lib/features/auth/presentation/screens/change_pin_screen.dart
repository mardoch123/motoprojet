import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// Écran de changement de PIN obligatoire (1ère connexion ou après reset admin)
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePins = true;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/api/v1/auth/change-pin', data: {
        'old_pin': _oldPinController.text,
        'new_pin': _newPinController.text,
        'confirm_pin': _confirmPinController.text,
      });

      // Mettre à jour l'état local
      await ref.read(authProvider.notifier).pinChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        // Le router redirect enverra vers le dashboard
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du changement de PIN. Vérifiez votre ancien PIN.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    authState.mustChangePin
                        ? 'Changez votre PIN'
                        : 'Modifier le PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authState.mustChangePin
                        ? 'Vous devez définir un nouveau code PIN avant de continuer.'
                        : 'Choisissez un nouveau code PIN sécurisé.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _oldPinController,
                    obscureText: _obscurePins,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Ancien PIN',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 4) {
                        return 'PIN invalide (4-6 chiffres)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPinController,
                    obscureText: _obscurePins,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Nouveau PIN',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePins ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePins = !_obscurePins),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 4) {
                        return 'Le PIN doit faire au moins 4 chiffres';
                      }
                      if (value == _oldPinController.text) {
                        return 'Le nouveau PIN doit être différent';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPinController,
                    obscureText: _obscurePins,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau PIN',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value != _newPinController.text) {
                        return 'Les PINs ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _changePin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Changer le PIN'),
                  ),
                  if (!authState.mustChangePin) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Annuler'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
