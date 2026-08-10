import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// KPI WIDGETS — Cartes de KPI pour dashboard
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Conçus pour une lisibilité maximale en extérieur :
/// - Gros chiffres en FontWeight.w800
/// - Icônes colorées dans un conteneur
/// - Bordure subtile de la couleur du KPI
/// - Support du mode sombre
///
/// Usage :
///   KpiCard(
///     label: 'Véhicules actifs',
///     value: '42',
///     icon: Icons.directions_car,
///     color: AppColors.statusSuccess,
///   )
///
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.25),
            width: 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icône + trailing ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.cardInnerGap),

            // ── Valeur (gros chiffre) ─────────────────────────────────────
            Text(
              value,
              style: AppTypography.kpiValue.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // ── Label ─────────────────────────────────────────────────────
            Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: secondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),

            // ── Subtitle (optionnel) ──────────────────────────────────────
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.labelSm.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// KPI COMPACT — Version compacte pour rangées de 2-3 KPI
/// ═══════════════════════════════════════════════════════════════════════════
class KpiCompact extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiCompact({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.cardInnerGap),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.kpiValueCompact.copyWith(color: color),
                ),
                Text(
                  label,
                  style: AppTypography.labelSm.copyWith(color: secondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// GAUGE PROGRESS — Jauge circulaire avec pourcentage
/// ═══════════════════════════════════════════════════════════════════════════
class GaugeProgress extends StatelessWidget {
  final double value; // 0.0 à 1.0
  final double size;
  final double strokeWidth;
  final String? label;
  final Color? activeColor;

  const GaugeProgress({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.label,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? _colorForValue(value);
    final trackColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GaugePainter(
                progress: value.clamp(0.0, 1.0),
                strokeWidth: strokeWidth,
                color: color,
                trackColor: trackColor,
              ),
            ),
          ),
          Text(
            label ?? '${(value * 100).toStringAsFixed(0)}%',
            style: AppTypography.kpiValueCompact.copyWith(
              fontSize: size * 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForValue(double v) {
    if (v >= 0.75) return AppColors.statusSuccess;
    if (v >= 0.50) return AppColors.brandAmber;
    if (v >= 0.25) return AppColors.statusWarning;
    return AppColors.statusError;
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background (track)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MINI SPARKLINE — Mini graphique de tendance
/// ═══════════════════════════════════════════════════════════════════════════
class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(data: data, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal;
    if (range == 0) return;

    final stepX = size.width / (data.length - 1);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Ligne
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Gradient sous la ligne
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// SECTION HEADER — En-tête de section
/// ═══════════════════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sectionGap, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.headingMd.copyWith(color: textColor),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
