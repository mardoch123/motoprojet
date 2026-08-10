import 'package:flutter/material.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PICTOGRAM BUTTON — Bouton d'action avec pictogramme + libellé court
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Conçu pour les utilisateurs peu à l'aise avec l'écrit :
/// - Icône grande et visible (pictogramme)
/// - Libellé court et simple
/// - Zone tactile ≥ 48px
/// - Support lecteur d'écran via Semantics
///
/// Usage :
///   PictogramButton(
///     icon: Icons.payments,
///     label: 'Paiement',
///     semanticsLabel: 'Enregistrer un paiement',
///     onTap: () => ...,
///   )
/// ═══════════════════════════════════════════════════════════════════════════
class PictogramButton extends StatelessWidget {
  const PictogramButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticsLabel,
    this.semanticsHint,
    this.color,
    this.backgroundColor,
    this.size = PictogramButtonSize.medium,
    this.badge,
  });

  /// Icône du pictogramme (affichée grande)
  final IconData icon;

  /// Libellé court affiché sous l'icône
  final String label;

  /// Label sémantique pour le lecteur d'écran (plus descriptif)
  final String? semanticsLabel;

  /// Hint sémantique pour le lecteur d'écran
  final String? semanticsHint;

  /// Couleur de l'icône et du texte
  final Color? color;

  /// Couleur de fond du bouton
  final Color? backgroundColor;

  /// Taille du bouton
  final PictogramButtonSize size;

  /// Badge optionnel (ex: nombre de retards)
  final String? badge;

  /// Callback au tap
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    final bgColor = backgroundColor ?? Colors.transparent;

    final config = switch (size) {
      PictogramButtonSize.small => _PictogramConfig(
          iconSize: 28.0,
          labelFontSize: 11.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gap: 4.0,
          minWidth: 64.0,
        ),
      PictogramButtonSize.medium => _PictogramConfig(
          iconSize: 36.0,
          labelFontSize: 13.0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gap: 6.0,
          minWidth: 80.0,
        ),
      PictogramButtonSize.large => _PictogramConfig(
          iconSize: 48.0,
          labelFontSize: 15.0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          gap: 8.0,
          minWidth: 100.0,
        ),
    };

    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      hint: semanticsHint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: config.padding,
          constraints: BoxConstraints(minWidth: config.minWidth),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: config.iconSize, color: iconColor),
                  SizedBox(height: config.gap),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: config.labelFontSize,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Badge optionnel (ex: "3" pour 3 retards)
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.statusError,
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tailles prédéfinies pour le PictogramButton
enum PictogramButtonSize {
  /// Petit — pour les barres d'outils compactes
  small,

  /// Moyen — usage standard (défaut)
  medium,

  /// Grand — pour les actions principales
  large,
}

class _PictogramConfig {
  const _PictogramConfig({
    required this.iconSize,
    required this.labelFontSize,
    required this.padding,
    required this.gap,
    required this.minWidth,
  });

  final double iconSize;
  final double labelFontSize;
  final EdgeInsets padding;
  final double gap;
  final double minWidth;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// PICTOGRAM CHIP — Pictogramme compact inline (icône + texte sur une ligne)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Usage : afficher une info courte avec pictogramme dans un texte ou une liste.
///
///   PictogramChip(icon: Icons.check_circle, label: 'À jour', color: Colors.green)
///
class PictogramChip extends StatelessWidget {
  const PictogramChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final fgColor = color ?? Theme.of(context).colorScheme.primary;
    final bgColor = backgroundColor ?? fgColor.withValues(alpha: 0.12);

    return Semantics(
      label: semanticsLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// PICTOGRAM LIST TILE — Tuile de liste avec pictogramme proéminent
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Pour les listes d'actions ou de fonctionnalités.
/// L'icône est grande et le texte est à côté.
///
class PictogramListTile extends StatelessWidget {
  const PictogramListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
    this.semanticsLabel,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? semanticsLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fgColor = iconColor ?? Theme.of(context).colorScheme.primary;
    final bgColor = iconBackgroundColor ?? fgColor.withValues(alpha: 0.12);

    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? title,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Icon(icon, color: fgColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
      ),
    );
  }
}
