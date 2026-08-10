import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DUAL PROGRESS BAR — Barre de progression double (compteur prochain achat)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Affiche deux barres de progression côte à côte (moto + voiture)
/// avec les montants cibles, les montants actuels et le pourcentage.
///
/// Conçu pour être lisible en un coup d'œil sur le terrain :
/// - Gros chiffres avec formatage FCFA
/// - Couleur de progression qui change selon l'avancement
/// - Label avec icône du type de véhicule
///
/// Usage :
///   DualProgressBar(
///     moto: ProgressBarData(current: 800000, target: 1200000, label: 'Moto'),
///     voiture: ProgressBarData(current: 2000000, target: 5000000, label: 'Voiture'),
///   )
///
class ProgressBarData {
  final double current;
  final double target;
  final String label;
  final IconData icon;
  final Color? customColor;

  const ProgressBarData({
    required this.current,
    required this.target,
    required this.label,
    this.icon = Icons.two_wheeler,
    this.customColor,
  });

  /// Progression de 0.0 à 1.0
  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  /// Pourcentage arrondi
  int get percent => (progress * 100).round();

  /// Montant restant
  double get remaining => (target - current).clamp(0.0, double.infinity);
}

class DualProgressBar extends StatelessWidget {
  final ProgressBarData moto;
  final ProgressBarData voiture;
  final String? headerLabel;
  final VoidCallback? onTap;

  const DualProgressBar({
    super.key,
    required this.moto,
    required this.voiture,
    this.headerLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: _dividerColor(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────────
            if (headerLabel != null) ...[
              Text(
                headerLabel!,
                style: AppTypography.labelCaps.copyWith(
                  color: _textSecondary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── 2 barres côte à côte ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SingleProgressBar(data: moto)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _SingleProgressBar(data: voiture)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Barre de progression simple (un véhicule) ─────────────────────────────
class _SingleProgressBar extends StatelessWidget {
  final ProgressBarData data;

  const _SingleProgressBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = data.customColor ?? _colorForProgress(data.progress);
    final fmt = NumberFormat.decimalPattern('fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Icône + label ─────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.label,
                style: AppTypography.labelSm.copyWith(
                  color: _textSecondary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Montant actuel / cible ────────────────────────────────────────
        Text(
          '${fmt.format(data.current.round())} F',
          style: AppTypography.kpiValueCompact.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '/ ${fmt.format(data.target.round())} F',
          style: AppTypography.bodySm.copyWith(
            color: _textTertiary(context),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Barre de progression ──────────────────────────────────────────
        _ProgressBar(
          progress: data.progress,
          color: color,
          height: 10,
          isDark: isDark,
        ),

        const SizedBox(height: AppSpacing.xs),

        // ── Pourcentage ───────────────────────────────────────────────────
        Text(
          '${data.percent}%',
          style: AppTypography.labelSm.copyWith(color: color),
        ),
      ],
    );
  }

  Color _colorForProgress(double progress) {
    if (progress >= 0.75) return AppColors.statusSuccess;
    if (progress >= 0.50) return AppColors.brandAmber;
    if (progress >= 0.25) return AppColors.statusWarning;
    return AppColors.statusError;
  }
}

/// ─── Painter de la barre de progression ────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;
  final bool isDark;

  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              height: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Helpers de couleur ──────────────────────────────────────────────────────

Color _surfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.surfaceDark
      : AppColors.surfaceLight;
}

Color _dividerColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.dividerDark
      : AppColors.dividerLight;
}

Color _textSecondary(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.textSecondaryDark
      : AppColors.textSecondaryLight;
}

Color _textTertiary(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.textTertiaryDark
      : AppColors.textTertiaryLight;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SINGLE PROGRESS BAR — Version standalone (un seul véhicule)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Usage :
///   SingleProgressBar(
///     data: ProgressBarData(
///       current: 800000,
///       target: 1200000,
///       label: 'Prochaine moto',
///       icon: Icons.two_wheeler,
///     ),
///   )
///
class SingleProgressBar extends StatelessWidget {
  final ProgressBarData data;
  final bool showHeader;

  const SingleProgressBar({
    super.key,
    required this.data,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SingleProgressBar(data: data);
  }
}
