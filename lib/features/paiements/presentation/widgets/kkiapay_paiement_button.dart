import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/paiements/presentation/kkiapay_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// KKiaPay PAIEMENT WIDGET — Bouton + flux complet Mobile Money
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Gère les 4 statuts du callback KKiaPay :
/// 1. PAYMENT_INIT → afficher le widget
/// 2. PENDING_PAYMENT → loading spinner
/// 3. PAYMENT_SUCCESS → vérification serveur + confirmation
/// 4. PAYMENT_CANCELLED → proposer fallback cash
///
/// SÉCURITÉ : Le paiement n'est validé QU'APRÈS vérification serveur.
/// Le callback client ne suffit PAS.
///
/// Usage :
///   KkiapayPaiementButton(
///     vehiculeId: 'xxx',
///     vehiculePlaque: 'AA-123-BJ',
///     montant: 5000,
///     chauffeurNom: 'Jean',
///     telephone: '22912345678',
///     onPaiementConfirm: (solde) { ... },
///     onFallbackCash: () { ... },
///   )
///
class KkiapayPaiementButton extends ConsumerStatefulWidget {
  final String vehiculeId;
  final String vehiculePlaque;
  final double montant;
  final String chauffeurNom;
  final String telephone;
  final String? date;
  final void Function(SoldeKkiapay solde)? onPaiementConfirm;
  final VoidCallback? onFallbackCash;

  const KkiapayPaiementButton({
    super.key,
    required this.vehiculeId,
    required this.vehiculePlaque,
    required this.montant,
    required this.chauffeurNom,
    required this.telephone,
    this.date,
    this.onPaiementConfirm,
    this.onFallbackCash,
  });

  @override
  ConsumerState<KkiapayPaiementButton> createState() => _KkiapayPaiementButtonState();
}

class _KkiapayPaiementButtonState extends ConsumerState<KkiapayPaiementButton> {
  _PaiementStatus _status = _PaiementStatus.idle;
  String? _errorMessage;

  final _fmt = NumberFormat.decimalPattern('fr_FR');

  /// Lance le flux complet de paiement KKiaPay
  Future<void> _lancerPaiement() async {
    final kkiapayService = ref.read(kkiapayServiceProvider);

    setState(() {
      _status = _PaiementStatus.initiating;
      _errorMessage = null;
    });

    try {
      // ── 1. Récupérer la config KKiaPay ──────────────────────────────────
      final config = await kkiapayService.getConfig();

      if (!config.isReady) {
        setState(() {
          _status = _PaiementStatus.error;
          _errorMessage = 'KKiaPay non configuré. Utilisez le paiement cash.';
        });
        return;
      }

      // ── 2. Initier la transaction côté backend ──────────────────────────
      final initResult = await kkiapayService.initierTransaction(
        vehiculeId: widget.vehiculeId,
        montant: widget.montant,
        date: widget.date,
      );

      setState(() => _status = _PaiementStatus.pendingWidget);

      // ── 3. Ouvrir le widget KKiaPay (SDK officiel) ─────────────────────
      final kkiapayWidget = KKiaPay(
        amount: widget.montant.toInt(),
        apikey: config.publicKey,
        sandbox: config.sandbox,
        phone: widget.telephone,
        name: widget.chauffeurNom,
        reason: 'Remboursement ${widget.vehiculePlaque}',
        data: initResult.transactionId,
        countries: const ['BJ'],
        paymentMethods: const ['momo', 'card'],
        theme: '#FF6F00',
        callback: _onKKiaPayCallback,
      );

      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => kkiapayWidget));

      // Si le widget est fermé sans callback (bouton retour)
      if (mounted && _status == _PaiementStatus.pendingWidget) {
        setState(() => _status = _PaiementStatus.cancelled);
      }

    } catch (e) {
      setState(() {
        _status = _PaiementStatus.error;
        _errorMessage = 'Erreur : $e';
      });
    }
  }

  /// Callback du SDK KKiaPay — gère les statuts du widget
  void _onKKiaPayCallback(Map<String, dynamic> response, BuildContext ctx) async {
    final status = response['status'] as String? ?? '';

    switch (status) {
      case PAYMENT_SUCCESS:
        Navigator.pop(ctx);
        final transactionId = response['transactionId'] as String? ??
            response['requestData']?['data'] as String? ?? '';
        if (transactionId.isNotEmpty) {
          await _verifierEtConfirmer(transactionId);
        } else {
          setState(() {
            _status = _PaiementStatus.error;
            _errorMessage = 'Identifiant de transaction manquant';
          });
        }
        break;

      case PAYMENT_CANCELLED:
        Navigator.pop(ctx);
        setState(() => _status = _PaiementStatus.cancelled);
        break;

      case PENDING_PAYMENT:
        // L'utilisateur est en train de confirmer — le widget reste ouvert
        break;

      case PAYMENT_INIT:
        // Widget initialisé, en attente de l'action utilisateur
        break;

      default:
        break;
    }
  }

  /// Vérification server-to-server du statut de transaction
  /// et création du paiement en base
  Future<void> _verifierEtConfirmer(String transactionId) async {
    final kkiapayService = ref.read(kkiapayServiceProvider);

    setState(() => _status = _PaiementStatus.verifying);

    final result = await kkiapayService.verifierTransaction(
      transactionId: transactionId,
      vehiculeId: widget.vehiculeId,
      montant: widget.montant,
      date: widget.date,
    );

    if (result.success && result.solde != null) {
      setState(() => _status = _PaiementStatus.success);
      widget.onPaiementConfirm?.call(result.solde!);
    } else {
      setState(() {
        _status = _PaiementStatus.error;
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Bouton principal ──────────────────────────────────────────────
        _buildMainButton(),

        // ── États intermédiaires ──────────────────────────────────────────
        if (_status == _PaiementStatus.verifying) ...[
          const SizedBox(height: 16),
          _buildVerifyingState(),
        ],

        if (_status == _PaiementStatus.success) ...[
          const SizedBox(height: 16),
          _buildSuccessState(),
        ],

        if (_status == _PaiementStatus.cancelled) ...[
          const SizedBox(height: 16),
          _buildCancelledState(),
        ],

        if (_status == _PaiementStatus.error && _errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorState(),
        ],
      ],
    );
  }

  Widget _buildMainButton() {
    final isLoading = _status == _PaiementStatus.initiating ||
        _status == _PaiementStatus.pendingWidget ||
        _status == _PaiementStatus.verifying;

    return SizedBox(
      height: AppTouch.comfortableTarget,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _lancerPaiement,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6F00), // Orange KKiaPay
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.phone_android, size: 22),
        label: Text(
          isLoading ? 'Paiement en cours...' : 'Payer ${_fmt.format(widget.montant)} F — Mobile Money',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildVerifyingState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusInfoSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.statusInfo),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vérification du paiement...',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.statusInfo),
                ),
                Text(
                  'Confirmation serveur en cours',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusSuccessSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.statusSuccess, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Paiement confirmé !',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.statusSuccess),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusWarningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel, color: AppColors.statusWarning, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Paiement annulé',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.statusWarning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Vous pouvez réessayer ou enregistrer le paiement en espèces.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),
          // Bouton fallback cash
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _status = _PaiementStatus.idle);
              widget.onFallbackCash?.call();
            },
            icon: const Icon(Icons.payments, size: 18),
            label: const Text('Enregistrer en espèces'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandGreen,
              side: const BorderSide(color: AppColors.brandGreen),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusErrorSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: AppColors.statusError, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Erreur de paiement',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.statusError),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _status = _PaiementStatus.idle;
                    _errorMessage = null;
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _status = _PaiementStatus.idle;
                    _errorMessage = null;
                  });
                  widget.onFallbackCash?.call();
                },
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('Espèces'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// États internes du widget
enum _PaiementStatus {
  idle,            // Prêt à démarrer
  initiating,      // Appel backend pour initier la transaction
  pendingWidget,   // Widget KKiaPay ouvert, en attente
  verifying,       // Vérification server-to-server en cours
  success,         // Paiement confirmé
  cancelled,       // Annulé par l'utilisateur
  error,           // Erreur
}
