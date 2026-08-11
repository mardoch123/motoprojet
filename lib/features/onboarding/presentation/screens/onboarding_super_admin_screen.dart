import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ONBOARDING SUPER ADMIN — Assistant de configuration initiale
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Premier lancement de l'application par l'entreprise.
/// Pré-rempli avec les valeurs par défaut de la simulation, modifiable.
///
/// Étapes :
/// 1. Informations entreprise (nom, prix moto/voiture)
/// 2. Paramètres remboursement (durée, montants journaliers)
/// 3. Salaires et seuils
/// 4. (Optionnel) Créer un premier compte Gestionnaire
///
class OnboardingSuperAdminScreen extends ConsumerStatefulWidget {
  const OnboardingSuperAdminScreen({super.key});

  @override
  ConsumerState<OnboardingSuperAdminScreen> createState() => _OnboardingSuperAdminScreenState();
}

class _OnboardingSuperAdminScreenState extends ConsumerState<OnboardingSuperAdminScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // ── Étape 1 : Entreprise ──
  final _nomEntrepriseController = TextEditingController(text: 'Mon Entreprise');
  final _prixMotoController = TextEditingController(text: '500000');
  final _prixVoitureController = TextEditingController(text: '3000000');

  // ── Étape 2 : Remboursement ──
  final _dureeRemboursementController = TextEditingController(text: '14');
  final _montantJourMotoController = TextEditingController(text: '5000');
  final _montantJourVoitureController = TextEditingController(text: '15000');

  // ── Étape 3 : Salaires ──
  final _salaireMotoController = TextEditingController(text: '50000');
  final _salaireVoitureController = TextEditingController(text: '100000');
  final _seuilDemarrageController = TextEditingController(text: '500000');

  // ── Étape 4 : Gestionnaire (optionnel) ──
  final _gestNomController = TextEditingController();
  final _gestTelephoneController = TextEditingController();
  bool _creerGestionnaire = false;

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nomEntrepriseController.dispose();
    _prixMotoController.dispose();
    _prixVoitureController.dispose();
    _dureeRemboursementController.dispose();
    _montantJourMotoController.dispose();
    _montantJourVoitureController.dispose();
    _salaireMotoController.dispose();
    _salaireVoitureController.dispose();
    _seuilDemarrageController.dispose();
    _gestNomController.dispose();
    _gestTelephoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _terminer() async {
    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      // Sauvegarder la configuration entreprise
      try {
        await apiClient.post('/dashboard/config', data: {
          'nom_entreprise': _nomEntrepriseController.text.trim(),
          'prix_moto': double.tryParse(_prixMotoController.text) ?? 500000,
          'prix_voiture': double.tryParse(_prixVoitureController.text) ?? 3000000,
          'duree_remboursement_mois': int.tryParse(_dureeRemboursementController.text) ?? 14,
          'montant_jour_moto': double.tryParse(_montantJourMotoController.text) ?? 5000,
          'montant_jour_voiture': double.tryParse(_montantJourVoitureController.text) ?? 15000,
          'salaire_mensuel_moto': double.tryParse(_salaireMotoController.text) ?? 50000,
          'salaire_mensuel_voiture': double.tryParse(_salaireVoitureController.text) ?? 100000,
          'seuil_demarrage': double.tryParse(_seuilDemarrageController.text) ?? 500000,
        });
      } catch (_) {}

      // Créer le gestionnaire si demandé
      if (_creerGestionnaire && _gestTelephoneController.text.isNotEmpty) {
        try {
          await apiClient.post('/auth/register', data: {
            'telephone': _gestTelephoneController.text.trim(),
            'nom': _gestNomController.text.trim(),
            'role': 'gestionnaire',
          });
        } catch (_) {}
      }

      // Marquer l'onboarding comme terminé
      await apiClient.post('/auth/onboarding/complete');
      await ref.read(authProvider.notifier).completeOnboarding();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/admin');
        });
      }
    } catch (e) {
      // Même en cas d'erreur, marquer comme terminé pour ne pas bloquer
      await ref.read(authProvider.notifier).completeOnboarding();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/admin');
        });
      }
    }
  }

  void _skip() {
    // Passer l'onboarding sans sauvegarder
    ref.read(authProvider.notifier).completeOnboarding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/admin');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Indicateur d'étapes
                  Expanded(
                    child: Row(
                      children: List.generate(_totalSteps, (index) {
                        final isActive = index == _currentStep;
                        final isDone = index < _currentStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isDone || isActive
                                  ? AppColors.brandGreen
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentStep + 1}/$_totalSteps',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _skip,
                    child: Text(_currentStep == _totalSteps - 1 ? 'Plus tard' : 'Passer',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                ],
              ),
            ),

            // ── Contenu ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepEntreprise(),
                  _buildStepRemboursement(),
                  _buildStepSalaires(),
                  _buildStepGestionnaire(),
                ],
              ),
            ),

            // ── Boutons navigation ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Retour'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  const Spacer(),
                  if (_currentStep < _totalSteps - 1)
                    ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Suivant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _terminer,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSubmitting ? 'Configuration...' : 'Terminer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
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

  // ─── Étape 1 : Entreprise ──────────────────────────────────────────────────

  Widget _buildStepEntreprise() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business, size: 48, color: AppColors.brandGreen),
          const SizedBox(height: 16),
          Text('Configuration de votre entreprise',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Ces valeurs pré-remplies correspondent à la simulation standard. Modifiez-les selon votre activité.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          _buildTextField(_nomEntrepriseController, "Nom de l'entreprise", Icons.business),
          const SizedBox(height: 20),

          Text('Prix d\'achat des véhicules', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMontantField(_prixMotoController, 'Prix moto', Icons.two_wheeler),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMontantField(_prixVoitureController, 'Prix voiture', Icons.directions_car),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Étape 2 : Remboursement ───────────────────────────────────────────────

  Widget _buildStepRemboursement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, size: 48, color: AppColors.brandGreen),
          const SizedBox(height: 16),
          Text('Paramètres de remboursement',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Durée et montants attendus pour le remboursement des véhicules.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          _buildNumberField(_dureeRemboursementController, 'Durée de remboursement (mois)', Icons.calendar_month),
          const SizedBox(height: 20),

          Text('Montants journaliers attendus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMontantField(_montantJourMotoController, 'Moto / jour', Icons.two_wheeler),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMontantField(_montantJourVoitureController, 'Voiture / jour', Icons.directions_car),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Étape 3 : Salaires ────────────────────────────────────────────────────

  Widget _buildStepSalaires() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments, size: 48, color: AppColors.brandGreen),
          const SizedBox(height: 16),
          Text('Salaires et seuils',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Pourcentages et montants pour la rémunération et le réinvestissement.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          Text('Salaire mensuel par véhicule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMontantField(_salaireMotoController, 'Moto / mois', Icons.two_wheeler),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMontantField(_salaireVoitureController, 'Voiture / mois', Icons.directions_car),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildMontantField(_seuilDemarrageController, 'Seuil de démarrage caisse', Icons.account_balance),
          const SizedBox(height: 12),
          Text('Montant minimum en caisse avant d\'acheter un nouveau véhicule.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ─── Étape 4 : Gestionnaire ────────────────────────────────────────────────

  Widget _buildStepGestionnaire() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_add, size: 48, color: AppColors.brandGreen),
          const SizedBox(height: 16),
          Text('Créer un compte Gestionnaire ?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Vous pouvez créer un premier compte gestionnaire pour déléguer certaines tâches. C\'est optionnel.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          // Switch pour activer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _creerGestionnaire
                  ? AppColors.brandGreen.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: _creerGestionnaire ? AppColors.brandGreen : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _creerGestionnaire ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _creerGestionnaire ? AppColors.brandGreen : Colors.grey,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Créer un compte gestionnaire maintenant',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _creerGestionnaire,
                  activeColor: AppColors.brandGreen,
                  onChanged: (v) => setState(() => _creerGestionnaire = v),
                ),
              ],
            ),
          ),

          if (_creerGestionnaire) ...[
            const SizedBox(height: 20),
            _buildTextField(_gestNomController, 'Nom du gestionnaire', Icons.person),
            const SizedBox(height: 16),
            _buildTextField(_gestTelephoneController, 'Numéro de téléphone', Icons.phone),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusInfoSubtle,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.statusInfo),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un PIN temporaire sera généré et envoyé au gestionnaire.',
                      style: TextStyle(fontSize: 12, color: AppColors.statusInfo),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusSuccessSubtle,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.celebration, color: AppColors.statusSuccess, size: 22),
                    SizedBox(width: 8),
                    Text('Configuration terminée !', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.statusSuccess)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Appuyez sur "Terminer" pour accéder à votre tableau de bord. Vous pourrez modifier ces paramètres à tout moment.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers UI ────────────────────────────────────────────────────────────

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildMontantField(TextEditingController controller, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.brandGreen, size: 20),
            suffixText: 'F',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }
}
