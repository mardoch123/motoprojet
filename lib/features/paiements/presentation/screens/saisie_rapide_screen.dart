import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/l10n/generated/app_localizations.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/paiements/presentation/paiements_provider.dart';
import 'package:motoprojet/features/paiements/presentation/widgets/kkiapay_paiement_button.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ÉCRAN SAISIE RAPIDE — Pleinement internationalisé et accessible
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Optimisé terrain :
/// - Gros boutons, minimum de taps, feedback visuel immédiat
/// - Internationalisé (i18n) via AppLocalizations
/// - Accessible (Semantics) pour lecteurs d'écran
/// - Pictogrammes à côté des libellés pour utilisateurs peu à l'aise avec l'écrit
/// ═══════════════════════════════════════════════════════════════════════════
class SaisieRapideScreen extends ConsumerStatefulWidget {
  const SaisieRapideScreen({super.key});

  @override
  ConsumerState<SaisieRapideScreen> createState() => _SaisieRapideScreenState();
}

class _SaisieRapideScreenState extends ConsumerState<SaisieRapideScreen> {
  String? _selectedChauffeurId;
  String? _selectedChauffeurNom;
  String? _selectedVehiculeId;
  String? _selectedVehiculePlaque;
  String? _selectedTelephone;
  double _montant = 5000; // Montant standard pré-rempli
  String _mode = 'mobile_money';
  DateTime _date = DateTime.now();
  bool _showSuccess = false;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Liste simplifiée des chauffeurs (chargée depuis l'API)
  List<Map<String, dynamic>> _chauffeurs = [];
  List<Map<String, dynamic>> _vehicules = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    // Écouter la connectivité pour masquer Mobile Money si hors-ligne
    final connectivity = ref.read(connectivityProvider);
    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isOnline = online;
          // Si on passe hors-ligne et qu'on était en Mobile Money, basculer en cash
          if (!online && _mode == 'mobile_money') {
            _mode = 'cash';
          }
        });
      }
    });
    // Charger les données après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(apiClientProvider);
      // Charger chauffeurs
      final chauffeursResp = await client.get('/chauffeurs');
      final chauffeursData = chauffeursResp.data as Map<String, dynamic>;
      _chauffeurs = List<Map<String, dynamic>>.from(chauffeursData['data'] as List);

      // Charger véhicules
      final vehiculesResp = await client.get('/vehicules');
      final vehiculesData = vehiculesResp.data as Map<String, dynamic>;
      _vehicules = List<Map<String, dynamic>>.from(vehiculesData['data'] as List);

      // Pré-remplir depuis le dernier paiement (paiement en un clic)
      _prefillFromLastPayment();
    } catch (e) {
      // En cas d'erreur, continuer avec des listes vides
    }
    if (mounted) {
      setState(() => _loadingData = false);
    }
  }

  /// Pré-remplit les champs depuis le dernier paiement enregistré
  void _prefillFromLastPayment() {
    try {
      final favoritesService = ref.read(paymentFavoritesServiceProvider);
      final lastPayment = favoritesService.getLastPayment();
      if (lastPayment == null) return;

      // Pré-remplir chauffeur si toujours dans la liste
      final chauffeurExists = _chauffeurs.any((c) => c['id']?.toString() == lastPayment.chauffeurId);
      if (chauffeurExists) {
        _selectedChauffeurId = lastPayment.chauffeurId;
        _selectedChauffeurNom = lastPayment.chauffeurNom;
        _selectedTelephone = _chauffeurs
            .firstWhere((c) => c['id']?.toString() == lastPayment.chauffeurId, orElse: () => {})
            ['telephone']
            ?.toString();
      }

      // Pré-remplir véhicule si toujours dans la liste
      final vehiculeExists = _vehicules.any((v) => v['id']?.toString() == lastPayment.vehiculeId);
      if (vehiculeExists) {
        _selectedVehiculeId = lastPayment.vehiculeId;
        _selectedVehiculePlaque = lastPayment.vehiculePlaque;
      }

      // Pré-remplir le montant
      _montant = lastPayment.montant;

      // Pré-remplir le mode
      _mode = lastPayment.mode;
    } catch (_) {
      // Silencieux en cas d'erreur
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saisieState = ref.watch(saisieRapideProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentNew),
        actions: [
          // Indicateur sync avec Semantics
          StreamBuilder<int>(
            stream: Stream.periodic(const Duration(seconds: 5), (_) {
              ref.read(pendingSyncCountProvider.notifier).state = ref.read(offlineStorageProvider).pendingSyncCount;
              return ref.read(pendingSyncCountProvider.notifier).state;
            }),
            initialData: 0,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Semantics(
                label: l10n.accessibilitySyncIndicator(count),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sync, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _showSuccess
          ? _buildSuccessView(l10n)
          : _loadingData
              ? Center(child: Semantics(label: l10n.commonLoading, child: const CircularProgressIndicator()))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Paiement rapide (favoris) ──
                      _buildQuickPaySection(l10n),

                      // ── Chauffeur ──
                      _buildSectionTitle(l10n.paymentDriver, Icons.person),
                      const SizedBox(height: 8),
                      _buildDropdown<Map<String, dynamic>>(
                        items: _chauffeurs,
                        value: _selectedChauffeurId,
                        hint: l10n.paymentDriverSelect,
                        semanticsLabel: l10n.accessibilityDriverDropdown,
                        labelGetter: (item) => item['nom']?.toString() ?? '—',
                        valueGetter: (item) => item['id']?.toString() ?? '',
                        onChanged: (value) {
                          setState(() {
                            _selectedChauffeurId = value;
                            final chauffeur = _chauffeurs.firstWhere((c) => c['id'] == value, orElse: () => {});
                            _selectedChauffeurNom = chauffeur['nom']?.toString();
                            _selectedTelephone = chauffeur['telephone']?.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Véhicule ──
                      _buildSectionTitle(l10n.paymentVehicle, Icons.directions_car),
                      const SizedBox(height: 8),
                      _buildDropdown<Map<String, dynamic>>(
                        items: _vehicules,
                        value: _selectedVehiculeId,
                        hint: l10n.paymentVehicleSelect,
                        semanticsLabel: l10n.accessibilityVehicleDropdown,
                        labelGetter: (item) => '${item['plaque'] ?? '—'} (${item['type'] ?? ''})',
                        valueGetter: (item) => item['id']?.toString() ?? '',
                        onChanged: (value) {
                          setState(() {
                            _selectedVehiculeId = value;
                            final vehicule = _vehicules.firstWhere((v) => v['id'] == value, orElse: () => {});
                            _selectedVehiculePlaque = vehicule['plaque']?.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Montant ──
                      _buildSectionTitle(l10n.paymentAmount, Icons.payments),
                      const SizedBox(height: 8),
                      _buildMontantInput(l10n),
                      const SizedBox(height: 8),
                      // Montants rapides
                      Row(
                        children: [
                          _buildQuickAmount(3000, l10n),
                          const SizedBox(width: 8),
                          _buildQuickAmount(5000, l10n),
                          const SizedBox(width: 8),
                          _buildQuickAmount(10000, l10n),
                          const SizedBox(width: 8),
                          _buildQuickAmount(15000, l10n),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Mode ──
                      _buildSectionTitle(l10n.paymentMode, Icons.account_balance_wallet),
                      const SizedBox(height: 8),
                      if (!_isOnline)
                        Semantics(
                          label: l10n.paymentOfflineMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarningSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off, color: AppColors.statusWarning, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.paymentOfflineMessage,
                                    style: const TextStyle(fontSize: 13, color: AppColors.statusWarning, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (_isOnline)
                            _buildModeButton('mobile_money', l10n.paymentModeMobileMoney, Icons.phone_android, l10n),
                          if (_isOnline)
                            const SizedBox(width: 12),
                          _buildModeButton('cash', l10n.paymentModeCash, Icons.payments, l10n),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Date ──
                      _buildSectionTitle(l10n.paymentDate, Icons.calendar_today),
                      const SizedBox(height: 8),
                      _buildDatePicker(l10n),
                      const SizedBox(height: 32),

                      // ── Solde restant (si online) ──
                      if (saisieState.soldeRestant != null && saisieState.lastResult != null && !saisieState.lastResult!.isOffline)
                        _buildSoldeCard(saisieState, l10n),

                      const SizedBox(height: 16),

                      // ── Erreur ──
                      if (saisieState.error != null)
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(saisieState.error!, style: const TextStyle(color: Colors.red)),
                          ),
                        ),

                      // ── Bouton valider / KKiaPay ──
                      if (_mode == 'mobile_money' && _isOnline && _selectedChauffeurId != null && _selectedVehiculeId != null)
                        KkiapayPaiementButton(
                          vehiculeId: _selectedVehiculeId!,
                          vehiculePlaque: _selectedVehiculePlaque ?? '—',
                          montant: _montant,
                          chauffeurNom: _selectedChauffeurNom ?? '—',
                          telephone: _selectedTelephone ?? '',
                          date: _date.toIso8601String().split('T')[0],
                          onPaiementConfirm: (solde) {
                            setState(() => _showSuccess = true);
                          },
                          onFallbackCash: () {
                            setState(() => _mode = 'cash');
                          },
                        )
                      else
                        SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            onPressed: saisieState.isSubmitting || _selectedChauffeurId == null || _selectedVehiculeId == null
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _mode == 'cash'
                                  ? AppColors.brandGreen
                                  : AppTheme.primaryColor,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                            ),
                            child: Semantics(
                              label: l10n.accessibilitySubmitPayment,
                              child: saisieState.isSubmitting
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _mode == 'cash' ? Icons.payments : Icons.check_circle,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _mode == 'cash' ? l10n.paymentRegisterCash : l10n.paymentValidate,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ─── Helpers UI ────────────────────────────────────────────────────────────

  /// Section "Paiement rapide" — affiche les favoris pour paiement en un clic
  Widget _buildQuickPaySection(AppLocalizations l10n) {
    final favorites = ref.watch(paymentFavoritesProvider);
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.authPaymentQuickPay, Icons.flash_on),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final fav = favorites[index];
              final isSelected = _selectedChauffeurId == fav.chauffeurId &&
                  _selectedVehiculeId == fav.vehiculeId &&
                  _montant == fav.montant;
              return Semantics(
                label: '${l10n.authPaymentQuickPay}: ${fav.chauffeurNom} — ${fav.montant.toStringAsFixed(0)} FCFA',
                selected: isSelected,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedChauffeurId = fav.chauffeurId;
                      _selectedChauffeurNom = fav.chauffeurNom;
                      _selectedVehiculeId = fav.vehiculeId;
                      _selectedVehiculePlaque = fav.vehiculePlaque;
                      _montant = fav.montant;
                      _mode = fav.mode;
                      // Récupérer le téléphone si disponible
                      final chauffeur = _chauffeurs.firstWhere(
                        (c) => c['id']?.toString() == fav.chauffeurId,
                        orElse: () => {},
                      );
                      _selectedTelephone = chauffeur['telephone']?.toString();
                    });
                  },
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppTheme.primaryColor, Color(0xFF1565C0)],
                            )
                          : null,
                      color: isSelected ? null : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              size: 14,
                              color: isSelected ? Colors.white : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                fav.chauffeurNom,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fav.vehiculePlaque} — ${fav.montant.toStringAsFixed(0)} F',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${fav.usageCount}× ${fav.mode == 'cash' ? l10n.paymentModeCash : l10n.paymentModeMobileMoney}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white60 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required List<T> items,
    required String? value,
    required String hint,
    required String Function(T) labelGetter,
    required String Function(T) valueGetter,
    required ValueChanged<String?> onChanged,
    String? semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel ?? hint,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        hint: Text(hint),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: valueGetter(item),
            child: Text(labelGetter(item)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMontantInput(AppLocalizations l10n) {
    return Semantics(
      label: l10n.accessibilityAmountField,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(l10n.commonFCFA, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                controller: TextEditingController(text: _montant.toStringAsFixed(0)),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) setState(() => _montant = parsed);
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmount(double amount, AppLocalizations l10n) {
    final isSelected = _montant == amount;
    return Expanded(
      child: Semantics(
        label: l10n.paymentQuickAmount(amount.toStringAsFixed(0)),
        selected: isSelected,
        child: OutlinedButton(
          onPressed: () => setState(() => _montant = amount),
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected ? AppTheme.primaryColor : null,
            foregroundColor: isSelected ? Colors.white : null,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l10n.paymentQuickAmount(amount.toStringAsFixed(0)), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon, AppLocalizations l10n) {
    final isSelected = _mode == mode;
    return Expanded(
      child: Semantics(
        label: '${l10n.accessibilityPaymentMode}: $label',
        selected: isSelected,
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey, size: 28),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(AppLocalizations l10n) {
    return Semantics(
      label: l10n.accessibilityDatePicker,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _date = picked);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text(DateFormat('dd MMMM yyyy').format(_date), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoldeCard(SaisieRapideState state, AppLocalizations l10n) {
    final solde = state.lastResult!.solde;
    if (solde == null) return const SizedBox.shrink();

    return Semantics(
      label: '${l10n.paymentRemainingBalance}: ${solde.nouveauSolde.toStringAsFixed(0)} FCFA',
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.paymentRemainingBalance, style: const TextStyle(color: Colors.grey)),
                Text(
                  '${solde.nouveauSolde.toStringAsFixed(0)} F',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: solde.nouveauSolde <= 0 ? Colors.green : AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: solde.pourcentageRembourse / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.paymentReimbursedPercent(solde.pourcentageRembourse.toStringAsFixed(1)),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(AppLocalizations l10n) {
    final result = ref.read(saisieRapideProvider).lastResult;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: result?.isOffline == true ? l10n.paymentOffline : l10n.paymentSuccess,
              child: Icon(
                result?.isOffline == true ? Icons.cloud_off : Icons.check_circle,
                size: 80,
                color: result?.isOffline == true ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              result?.isOffline == true ? l10n.paymentOffline : l10n.paymentSuccess,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_montant.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 4),
            Text('${_selectedChauffeurNom ?? ''} — ${_selectedVehiculePlaque ?? ''}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            if (result?.isOffline == true) ...[
              const SizedBox(height: 16),
              Semantics(
                label: l10n.paymentSyncPending,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.paymentSyncPending, style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => setState(() => _showSuccess = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.paymentNewPayment, style: const TextStyle(fontSize: 16, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.commonBack),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final result = await ref.read(saisieRapideProvider.notifier).enregistrer(
          chauffeurId: _selectedChauffeurId!,
          vehiculeId: _selectedVehiculeId!,
          montant: _montant,
          date: _date.toIso8601String().split('T')[0],
          mode: _mode,
        );

    if (result != null && mounted) {
      // Enregistrer dans les favoris pour paiement en un clic
      try {
        final favoritesService = ref.read(paymentFavoritesServiceProvider);
        await favoritesService.recordPayment(
          chauffeurId: _selectedChauffeurId!,
          chauffeurNom: _selectedChauffeurNom ?? '',
          vehiculeId: _selectedVehiculeId!,
          vehiculePlaque: _selectedVehiculePlaque ?? '',
          montant: _montant,
          mode: _mode,
        );
      } catch (_) {
        // Silencieux — les favoris ne doivent pas bloquer le paiement
      }

      setState(() => _showSuccess = true);
    }
  }
}
