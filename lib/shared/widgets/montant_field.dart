import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MONTANT FIELD — Champ de saisie de montant optimisé terrain
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Optimisations pour la saisie rapide au Bénin :
/// - Clavier numérique par défaut (TextInputType.number)
/// - Formatage automatique en FCFA pendant la saisie
/// - Montants rapides pré-remplissables (500, 1000, 2000, 5000, 10000)
/// - Gros chiffres lisibles
/// - Validation intégrée (montant min/max optionnel)
///
/// Usage :
///   MontantField(
///     controller: controller,
///     label: 'Montant payé',
///     onChanged: (value) => print(value),
///     quickAmounts: [500, 1000, 2000, 5000],
///   )
///
class MontantField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onSubmitted;
  final List<int>? quickAmounts;
  final int? minAmount;
  final int? maxAmount;
  final int? initialValue;
  final bool autoFocus;
  final String? errorText;
  final bool enabled;

  const MontantField({
    super.key,
    this.controller,
    this.label = 'Montant',
    this.hint = '0',
    this.onChanged,
    this.onSubmitted,
    this.quickAmounts,
    this.minAmount,
    this.maxAmount,
    this.initialValue,
    this.autoFocus = false,
    this.errorText,
    this.enabled = true,
  });

  /// Montants rapides par défaut adaptés au contexte béninois
  static const List<int> defaultQuickAmounts = [500, 1000, 2000, 5000, 10000];

  @override
  State<MontantField> createState() => _MontantFieldState();
}

class _MontantFieldState extends State<MontantField> {
  late TextEditingController _controller;
  final _fmt = NumberFormat.decimalPattern('fr_FR');
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null && widget.initialValue! > 0) {
      _controller.text = _fmt.format(widget.initialValue);
    }

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (_isFormatting) return;

    final rawValue = _parseRawValue(_controller.text);
    widget.onChanged?.call(rawValue);
  }

  /// Parse la valeur brute depuis le texte formaté
  int _parseRawValue(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// Formate le texte avec séparateurs de milliers
  void _formatText() {
    if (_isFormatting) return;
    _isFormatting = true;

    final rawValue = _parseRawValue(_controller.text);
    if (rawValue > 0) {
      final formatted = _fmt.format(rawValue);
      if (_controller.text != formatted) {
        _controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    _isFormatting = false;
  }

  /// Insère un montant rapide
  void _setQuickAmount(int amount) {
    final formatted = _fmt.format(amount);
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged?.call(amount);
    widget.onSubmitted?.call(amount);
  }

  /// Valide le montant selon les contraintes
  String? _validate(int value) {
    if (widget.errorText != null) return widget.errorText;
    if (widget.minAmount != null && value < widget.minAmount!) {
      return 'Minimum : ${_fmt.format(widget.minAmount)} F';
    }
    if (widget.maxAmount != null && value > widget.maxAmount!) {
      return 'Maximum : ${_fmt.format(widget.maxAmount)} F';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quickAmounts = widget.quickAmounts ?? MontantField.defaultQuickAmounts;
    final currentValue = _parseRawValue(_controller.text);
    final error = _validate(currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ─────────────────────────────────────────────────────────
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.labelMd.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Champ de saisie ───────────────────────────────────────────────
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12), // Max 999 milliards
          ],
          style: AppTypography.montantInput.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixText: 'F CFA',
            suffixStyle: AppTypography.bodyMd.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDarkVariant : AppColors.surfaceLight,
          ),
          autofocus: widget.autoFocus,
          enabled: widget.enabled,
          onTapOutside: (_) => _formatText(),
          onEditingComplete: () {
            _formatText();
            widget.onSubmitted?.call(currentValue);
          },
        ),

        // ── Erreur ────────────────────────────────────────────────────────
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            error,
            style: AppTypography.bodySm.copyWith(color: AppColors.statusError),
          ),
        ],

        // ── Montants rapides ──────────────────────────────────────────────
        if (quickAmounts.isNotEmpty && widget.enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: quickAmounts.map((amount) {
              return _QuickAmountChip(
                label: '${_fmt.format(amount)} F',
                onTap: () => _setQuickAmount(amount),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// ─── Puce de montant rapide ────────────────────────────────────────────────
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.surfaceDarkVariant : AppColors.surfaceLightVariant,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MONTANT DISPLAY — Affichage formaté d'un montant (lecture seule)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Usage :
///   MontantDisplay(amount: 150000)  // Affiche "150 000 F"
///   MontantDisplay(amount: 150000, size: MontantDisplaySize.large)
///
enum MontantDisplaySize { small, medium, large }

class MontantDisplay extends StatelessWidget {
  final double amount;
  final MontantDisplaySize size;
  final Color? color;
  final bool showDecimals;

  const MontantDisplay({
    super.key,
    required this.amount,
    this.size = MontantDisplaySize.medium,
    this.color,
    this.showDecimals = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final displayAmount = showDecimals ? amount : amount.round();
    final text = '${fmt.format(displayAmount)} F';

    final TextStyle style;
    switch (size) {
      case MontantDisplaySize.small:
        style = AppTypography.bodySm;
      case MontantDisplaySize.medium:
        style = AppTypography.kpiValueCompact;
      case MontantDisplaySize.large:
        style = AppTypography.kpiValue;
    }

    return Text(
      text,
      style: style.copyWith(
        color: color ?? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
