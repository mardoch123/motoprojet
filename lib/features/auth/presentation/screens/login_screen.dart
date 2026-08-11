import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/l10n/generated/app_localizations.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _telephoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePin = true;

  @override
  void dispose() {
    _telephoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/auth/login', data: {
        'telephone': _telephoneController.text.trim(),
        'pin': _pinController.text,
      });

      final data = response.data['data'] as Map<String, dynamic>;
      final mustChangePin = data['must_change_pin'] as bool? ?? false;
      final onboardingCompleted = data['onboarding_completed'] as bool? ?? false;
      final refreshToken = data['refresh_token'] as String?;

      // Stocker le refresh token s'il est présent
      if (refreshToken != null) {
        await ref.read(authProvider.notifier).saveRefreshToken(refreshToken);
      }

      await ref.read(authProvider.notifier).login(
            token: data['access_token'] as String,
            userId: data['user_id'] as String,
            role: data['role'] as String,
            statut: data['statut'] as String?,
            mustChangePin: mustChangePin,
            onboardingCompleted: onboardingCompleted,
          );

      if (mustChangePin) {
        // Rediriger vers l'écran de changement de PIN obligatoire
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/change-pin');
        });
        return;
      }

      // Navigation explicite vers le dashboard selon le rôle
      final role = data['role'] as String;
      final targetRoute = switch (role) {
        'super_admin' => '/admin',
        'gestionnaire' => '/gestionnaire',
        'chauffeur' => '/chauffeur',
        _ => '/login',
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(targetRoute);
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = l10n.authErrorInvalidCredentials;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Connexion rapide : remplit les champs et lance la connexion
  Future<void> _quickLogin(String telephone, String pin) async {
    _telephoneController.text = telephone;
    _pinController.text = pin;
    await _login();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                  Semantics(
                    label: l10n.appTitle,
                    child: const Icon(Icons.directions_bike, size: 80, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authLoginSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _telephoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.authPhone,
                      prefixIcon: const Icon(Icons.phone),
                      hintText: l10n.authPhoneHint,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authErrorPhoneRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.authPin,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authErrorPinRequired;
                      }
                      if (value.length < 4) {
                        return l10n.authErrorPinTooShort;
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.errorColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.authLogin),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/forgot-pin'),
                    child: Text(l10n.authForgotPin),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Connexion rapide (test)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _quickLogin('+22934567890', '1234'),
                          icon: const Icon(Icons.directions_bike, size: 18),
                          label: const Text('Chauffeur', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.successColor,
                            side: const BorderSide(color: AppTheme.successColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _quickLogin('+22912345678', '1234'),
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Super Admin', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
