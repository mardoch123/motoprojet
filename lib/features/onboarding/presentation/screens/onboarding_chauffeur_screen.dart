import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ONBOARDING CHAUFFEUR — Bienvenue + objectif journalier
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Ce parcours s'affiche APRÈS le changement obligatoire du PIN.
///
/// Étapes :
/// 1. Bienvenue avec pictogrammes (solde, date de fin, objectif)
/// 2. Définir son objectif de revenu journalier
/// 3. Terminé — accès à l'app
///
/// Note : Le changement du PIN temporaire est déjà géré par ChangePinScreen.
///
class OnboardingChauffeurScreen extends ConsumerStatefulWidget {
  const OnboardingChauffeurScreen({super.key});

  @override
  ConsumerState<OnboardingChauffeurScreen> createState() => _OnboardingChauffeurScreenState();
}

class _OnboardingChauffeurScreenState extends ConsumerState<OnboardingChauffeurScreen> {
  final _pageController = PageController();
  int _currentSlide = 0;
  bool _isCompleting = false;

  // Objectif journalier
  final _objectifController = TextEditingController(text: '5000');

  static const int _totalSlides = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _objectifController.dispose();
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
      // Sauvegarder l'objectif (optionnel, peut échouer sans bloquer)
      try {
        await apiClient.post('/api/v1/auth/onboarding/complete', data: {
          'objectif_journalier': double.tryParse(_objectifController.text) ?? 5000,
        });
      } catch (_) {}
    } catch (_) {}
    await ref.read(authProvider.notifier).completeOnboarding();
    // Délayer la navigation après le rebuild du router déclenché par completeOnboarding()
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/chauffeur');
      });
    }
  }

  void _skip() {
    ref.read(authProvider.notifier).completeOnboarding();
    // Délayer la navigation après le rebuild du router
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/chauffeur');
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
                  _buildSlideObjectif(),
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
                              _currentSlide < _totalSlides - 1 ? 'Suivant' : 'C\'est parti !',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_bike, size: 56, color: AppColors.brandGreen),
          ),
          const SizedBox(height: 32),
          Text('Bienvenue !',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Votre espace chauffeur vous permet de suivre votre remboursement en temps réel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 40),
          _buildPictogramCard(
            Icons.account_balance_wallet,
            'Votre solde',
            'Consultez combien vous avez déjà remboursé et ce qu\'il reste à payer.',
            AppColors.brandGreen,
          ),
          const SizedBox(height: 16),
          _buildPictogramCard(
            Icons.calendar_today,
            'Date de fin',
            'Voyez la date estimée de fin de remboursement.',
            AppColors.statusInfo,
          ),
          const SizedBox(height: 16),
          _buildPictogramCard(
            Icons.flag,
            'Votre objectif',
            'Suivez votre progression vers votre objectif journalier.',
            AppColors.statusWarning,
          ),
        ],
      ),
    );
  }

  // ─── Slide 2 : Fonctionnalités ─────────────────────────────────────────────

  Widget _buildSlideFonctionnalites() {
    return SingleChildScrollView(
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
            child: const Icon(Icons.touch_app, size: 50, color: AppColors.statusInfo),
          ),
          const SizedBox(height: 32),
          Text('Ce que vous pouvez faire',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),
          _buildFeatureItem(Icons.check_circle, 'Voir vos paiements', 'Historique complet de vos versements'),
          const SizedBox(height: 14),
          _buildFeatureItem(Icons.check_circle, 'Suivre votre solde', 'Progression en temps réel vers le remboursement total'),
          const SizedBox(height: 14),
          _buildFeatureItem(Icons.check_circle, 'Payer par Mobile Money', 'Réglez directement depuis votre téléphone'),
          const SizedBox(height: 14),
          _buildFeatureItem(Icons.check_circle, 'Signaler un incident', 'Informez en cas de problème avec le véhicule'),
          const SizedBox(height: 14),
          _buildFeatureItem(Icons.check_circle, 'Recevoir des rappels', 'Notifications pour ne rien oublier'),
        ],
      ),
    );
  }

  // ─── Slide 3 : Objectif journalier ─────────────────────────────────────────

  Widget _buildSlideObjectif() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.statusWarningSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, size: 50, color: AppColors.statusWarning),
          ),
          const SizedBox(height: 32),
          Text('Votre objectif journalier',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Combien souhaitez-vous rembourser chaque jour ? Cela vous aidera à suivre votre progression.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 32),

          // Champ montant objectif
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.statusWarning, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: AppColors.statusWarning, size: 24),
                    const SizedBox(width: 8),
                    Text('Objectif', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _objectifController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Montants rapides
          Row(
            children: [
              _buildQuickGoal(3000),
              const SizedBox(width: 8),
              _buildQuickGoal(5000),
              const SizedBox(width: 8),
              _buildQuickGoal(10000),
              const SizedBox(width: 8),
              _buildQuickGoal(15000),
            ],
          ),
          const SizedBox(height: 24),

          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusSuccessSubtle,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Builder(builder: (context) {
              final objectif = double.tryParse(_objectifController.text) ?? 5000;
              final joursRestants = objectif > 0 ? (3000000 / objectif).ceil() : 0;
              return Row(
                children: [
                  const Icon(Icons.lightbulb, color: AppColors.statusSuccess, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      joursRestants > 0
                          ? 'À $objectif F/jour, il faudra environ $joursRestants jours pour rembourser une moto.'
                          : 'Choisissez un objectif pour voir l\'estimation.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildPictogramCard(IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandGreen, size: 22),
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

  Widget _buildQuickGoal(double amount) {
    final currentGoal = double.tryParse(_objectifController.text) ?? 0;
    final isSelected = currentGoal == amount;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          _objectifController.text = amount.toStringAsFixed(0);
          setState(() {});
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.statusWarning : null,
          foregroundColor: isSelected ? Colors.white : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text('${amount.toStringAsFixed(0)} F',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
