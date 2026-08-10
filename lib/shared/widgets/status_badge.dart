import 'package:flutter/material.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// STATUS BADGE — Badge de statut universel
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Code couleur sémantique :
///   • StatusType.success → vert = à jour, validé, payé
///   • StatusType.warning → orange = retard léger, en attente
///   • StatusType.error   → rouge = défaut, impayé, critique
///   • StatusType.info    → bleu = en cours, information
///   • StatusType.neutral → gris = inactif, brouillon
///
/// Usage :
///   StatusBadge(label: 'À jour', type: StatusType.success)
///   StatusBadge(label: '3j retard', type: StatusType.warning, icon: Icons.warning_amber)
///   StatusBadge.dot(label: 'En ligne')
///
class StatusType {
  final Color color;
  final Color subtleColor;
  final Color onColor;

  const StatusType._({
    required this.color,
    required this.subtleColor,
    required this.onColor,
  });

  static const StatusType success = StatusType._(
    color: AppColors.statusSuccess,
    subtleColor: AppColors.statusSuccessSubtle,
    onColor: AppColors.statusSuccessOn,
  );

  static const StatusType warning = StatusType._(
    color: AppColors.statusWarning,
    subtleColor: AppColors.statusWarningSubtle,
    onColor: AppColors.statusWarningOn,
  );

  static const StatusType error = StatusType._(
    color: AppColors.statusError,
    subtleColor: AppColors.statusErrorSubtle,
    onColor: AppColors.statusErrorOn,
  );

  static const StatusType info = StatusType._(
    color: AppColors.statusInfo,
    subtleColor: AppColors.statusInfoSubtle,
    onColor: AppColors.statusInfoOn,
  );

  static const StatusType neutral = StatusType._(
    color: AppColors.textSecondaryLight,
    subtleColor: AppColors.surfaceLightVariant,
    onColor: AppColors.textPrimaryLight,
  );
}

/// ─── Variantes de style ────────────────────────────────────────────────────
enum StatusBadgeVariant {
  /// Fond coloré subtil, texte coloré (défaut — lisible en extérieur)
  subtle,

  /// Fond plein, texte blanc (pour mise en avant)
  filled,

  /// Bordure colorée, fond transparent
  outlined,

  /// Pastille + texte (compact, pour listes)
  dot,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final StatusBadgeVariant variant;
  final IconData? icon;
  final bool compact;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.variant = StatusBadgeVariant.subtle,
    this.icon,
    this.compact = false,
    this.onTap,
  });

  /// Constructeur rapide pour le variant dot
  const StatusBadge.dot({
    super.key,
    required this.label,
    required this.type,
    this.variant = StatusBadgeVariant.dot,
    this.icon,
    this.compact = true,
    this.onTap,
  });

  /// Déterminer le StatusType depuis un string de statut backend
  /// Utilisable pour mapper les statuts de l'API vers le bon type visuel.
  static StatusType fromStatusString(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'active':
      case 'a_jour':
      case 'a_jour_retard_leger': // cas spécial : encore considéré OK
      case 'valide':
      case 'validé':
      case 'termine':
      case 'terminé':
        return StatusType.success;

      case 'pending':
      case 'en_attente':
      case 'en_cours':
      case 'retard_leger':
      case 'partiel':
        return StatusType.warning;

      case 'failed':
      case 'defaulted':
      case 'impaye':
      case 'impayé':
      case 'resilie':
      case 'résilié':
      case 'retard_import':
      case 'annule':
      case 'annulé':
        return StatusType.error;

      case 'info':
      case 'synced':
      case 'brouillon':
      case 'draft':
        return StatusType.info;

      default:
        return StatusType.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: variant == StatusBadgeVariant.dot
          ? _buildDotBadge(isDark)
          : _buildStandardBadge(isDark),
    );
  }

  Widget _buildStandardBadge(bool isDark) {
    final Color bgColor;
    final Color fgColor;
    final Color borderColor;

    switch (variant) {
      case StatusBadgeVariant.subtle:
        bgColor = isDark ? type.color.withValues(alpha: 0.15) : type.subtleColor;
        fgColor = type.color;
        borderColor = Colors.transparent;
      case StatusBadgeVariant.filled:
        bgColor = type.color;
        fgColor = type.onColor;
        borderColor = Colors.transparent;
      case StatusBadgeVariant.outlined:
        bgColor = Colors.transparent;
        fgColor = type.color;
        borderColor = type.color;
      case StatusBadgeVariant.dot:
        bgColor = isDark ? type.color.withValues(alpha: 0.15) : type.subtleColor;
        fgColor = type.color;
        borderColor = Colors.transparent;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: borderColor != Colors.transparent
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: fgColor),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotBadge(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: type.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

/// ─── Badge de statut avec compteur ─────────────────────────────────────────
/// Pour afficher un nombre associé à un statut (ex: "3 impayés")
class StatusCountBadge extends StatelessWidget {
  final int count;
  final StatusType type;
  final String? label;

  const StatusCountBadge({
    super.key,
    required this.count,
    required this.type,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? type.color.withValues(alpha: 0.15) : type.subtleColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: type.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
