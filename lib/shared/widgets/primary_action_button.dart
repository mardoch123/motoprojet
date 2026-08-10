import 'package:flutter/material.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PRIMARY ACTION BUTTON — Bouton d'action principal large
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Conçu pour une saisie au pouce sur le terrain :
/// - Hauteur minimale 56 px (comfortableTarget)
/// - Texte gros et lisible
/// - Feedback tactile immédiat (haptic + visuel)
/// - États loading/disabled clairs
///
/// Usage :
///   PrimaryActionButton(
///     label: 'Enregistrer paiement',
///     icon: Icons.check,
///     onPressed: () => _save(),
///   )
///
///   PrimaryActionButton.loading()  // État de chargement
///
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;
  final Color? backgroundColor;
  final Color? textColor;
  final double? minHeight;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.backgroundColor,
    this.textColor,
    this.minHeight,
  });

  /// Constructeur pour l'état de chargement
  PrimaryActionButton.loading({
    super.key,
    this.label = 'Chargement...',
    this.icon,
    this.onPressed,
    this.isLoading = true,
    this.isExpanded = true,
    this.backgroundColor,
    this.textColor,
    this.minHeight,
  });

  /// Variante destructive (suppression, annulation)
  PrimaryActionButton.destructive({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.backgroundColor = AppColors.statusError,
    this.textColor = AppColors.statusErrorOn,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.brandGreen;
    final txtColor = textColor ?? AppColors.textOnBrandLight;
    final height = minHeight ?? AppTouch.comfortableTarget;

    final button = SizedBox(
      width: isExpanded ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: txtColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: txtColor.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTypography.bodyLg.copyWith(
                      color: txtColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: txtColor),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.bodyLg.copyWith(
                        color: txtColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    return button;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SECONDARY ACTION BUTTON — Bouton d'action secondaire
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Pour les actions secondaires (annuler, voir plus, etc.)
///
class SecondaryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;

  const SecondaryActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.brandGreenLight : AppColors.brandGreen;

    final button = SizedBox(
      width: isExpanded ? double.infinity : null,
      height: AppTouch.comfortableTarget,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          side: BorderSide(color: fgColor, width: 1.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fgColor),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.bodyLg.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    return button;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ICON ACTION BUTTON — Bouton circulaire avec icône
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Pour les FAB et boutons d'action rapide
///
class IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.brandGreen;
    final icColor = iconColor ?? AppColors.textOnBrandLight;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bgColor,
        elevation: 0,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: icColor, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
