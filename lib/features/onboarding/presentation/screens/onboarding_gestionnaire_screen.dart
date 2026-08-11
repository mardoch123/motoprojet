import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ONBOARDING GESTIONNAIRE — Slides de bienvenue + tutoriel paiement
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 3 slides expliquant le périmètre d'accès :
/// 1. Bienvenue + vue d'ensemble du rôle
/// 2. Les fonctionnalités clés (tutoriel interactif simplifié)
/// 3. Invitation à enregistrer le premier paiement
///
class OnboardingGestionnaireScreen extends ConsumerStatefulWidget {
  const OnboardingGestionnaireScreen({super.key});

  @override
  ConsumerState<OnboardingGestionnaireScreen> createState() => _OnboardingGestionnaireScreenState();
}

class _OnboardingGestionnaireScreenState extends ConsumerState<OnboardingGestionnaireScreen> {
  final _pageController = PageController();
  int _currentSlide = 0;
  bool _isCompleting = false;

  static const int _totalSlides = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentSlide < _totalSlides - 1) {
      setState(() => _currentSlide++);
      _pageController.animateToPage(
        _currentSlide,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _terminer() async {
    setState(() => _isCompleting = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/auth/onboarding/complete');
    } catch (_) {}
    await ref.read(authProvider.notifier).completeOnboarding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/gestionnaire');
    });
  }

  void _skip() {
    ref.read(authProvider.notifier).completeOnboarding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/gestionnaire');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(_currentSlide == _totalSlides - 1 ? 'Plus tard' : 'Passer',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
            ),

            // ── Slides ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSlideBienvenue(),
                  _buildSlideFonctionnalites(),
                  _buildSlidePremierPaiement(),
                ],
              ),
            ),

            // ── Indicateurs + bouton ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalSlides, (index) {
                      final isActive = index == _currentSlide;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.brandGreen : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Bouton
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _currentSlide < _totalSlides - 1
                          ? _nextSlide
                          : (_isCompleting ? null : _terminer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                      child: _isCompleting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              _currentSlide < _totalSlides - 1 ? 'Suivant' : 'Commencer',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Slide 1 : Bienvenue ───────────────────────────────────────────────────

  Widget _buildSlideBienvenue() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.manage_accounts, size: 50, color: AppColors.brandGreen),
          ),
          const SizedBox(height: 32),
          Text('Bienvenue, Gestionnaire !',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'Vous gérez les opérations quotidiennes : paiements, chauffeurs, véhicules et suivi financier.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.dashboard, 'Tableau de bord', 'Vue d\'ensemble de l\'activité en un coup d\'œil'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.people, 'Chauffeurs & Véhicules', 'Gérez les contrats et le suivi'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.payments, 'Paiements', 'Enregistrez et consultez les versements'),
        ],
      ),
    );
  }

  // ─── Slide 2 : Fonctionnalités ─────────────────────────────────────────────

  Widget _buildSlideFonctionnalites() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.statusInfoSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tips_and_updates, size: 50, color: AppColors.statusInfo),
          ),
          const SizedBox(height: 32),
          Text('Vos outils principaux',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildToolCard(Icons.add_circle, 'Saisie rapide', 'Enregistrez un paiement en 3 taps : chauffeur, montant, valider'),
          const SizedBox(height: 12),
          _buildToolCard(Icons.history, 'Historique', 'Retrouvez tous les paiements avec filtres par date, chauffeur, mode'),
          const SizedBox(height: 12),
          _buildToolCard(Icons.phone_android, 'Mobile Money', 'Acceptez les paiements KKiaPay directement depuis l\'app'),
          const SizedBox(height: 12),
          _buildToolCard(Icons.cloud_off, 'Mode hors-ligne', 'Pas de réseau ? Les paiements cash sont synchronisés automatiquement'),
        ],
      ),
    );
  }

  // ─── Slide 3 : Premier paiement ────────────────────────────────────────────

  Widget _buildSlidePremierPaiement() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.statusSuccessSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration, size: 50, color: AppColors.statusSuccess),
          ),
          const SizedBox(height: 32),
          Text('Prêt à commencer ?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'Rendez-vous dans "Saisie rapide" depuis le tableau de bord pour enregistrer votre premier paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 32),
          // Mini tutoriel visuel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildStepIndicator(1, 'Choisissez un chauffeur'),
                const SizedBox(height: 8),
                _buildStepIndicator(2, 'Sélectionnez un véhicule'),
                const SizedBox(height: 8),
                _buildStepIndicator(3, 'Entrez le montant'),
                const SizedBox(height: 8),
                _buildStepIndicator(4, 'Appuyez sur "Payer"'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brandGreen, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.brandGreen,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
