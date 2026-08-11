import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/l10n/generated/app_localizations.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/dashboard/presentation/dashboard_chauffeur_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DASHBOARD CHAUFFEUR — Vue principale du chauffeur
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Affiche les informations essentielles :
/// - Véhicule en cours avec progression du remboursement
/// - Derniers paiements
/// - Paiements en retard (alerte)
/// - Incidents ouverts
/// - Résumé semaine/mois
///
class ChauffeurDashboardScreen extends ConsumerStatefulWidget {
  const ChauffeurDashboardScreen({super.key});

  @override
  ConsumerState<ChauffeurDashboardScreen> createState() => _ChauffeurDashboardScreenState();
}

class _ChauffeurDashboardScreenState extends ConsumerState<ChauffeurDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardChauffeurProvider.notifier).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardChauffeurProvider);
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardChauffeurProvider.notifier).loadDashboard(),
        child: state.isLoading && state.vehiculeActif == null
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.vehiculeActif == null
                ? _buildError(l10n, state.error!)
                : _buildContent(context, state, l10n, isDark),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n, String error) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Connexion impossible', style: AppTypography.headingMd),
              const SizedBox(height: 8),
              Text('Vérifiez votre connexion internet et réessayez.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(dashboardChauffeurProvider.notifier).loadDashboard(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DashboardChauffeurState state,
      AppLocalizations l10n, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      children: [
        // ── En-tête bonjour ──────────────────────────────────────────────
        _buildHeader(state, l10n, isDark),
        const SizedBox(height: AppSpacing.md),

        // ── Alerte retards (si paiements en retard) ──────────────────────
        if (state.impayes.isNotEmpty) ...[
          _buildRetardAlert(state, l10n, isDark),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Alerte incidents (si incidents ouverts) ──────────────────────
        if (state.incidentsOuverts.isNotEmpty) ...[
          _buildIncidentAlert(state, l10n, isDark),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Carte véhicule + progression ─────────────────────────────────
        if (state.vehiculeActif != null && state.progression != null) ...[
          _buildVehiculeCard(state, l10n, isDark),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── KPIs semaine/mois ────────────────────────────────────────────
        _buildPeriodKpis(state, l10n, isDark),
        const SizedBox(height: AppSpacing.md),

        // ── Derniers paiements ───────────────────────────────────────────
        _buildDerniersPaiements(context, state, l10n, isDark),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  // ─── En-tête ────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashboardChauffeurState state, AppLocalizations l10n, bool isDark) {
    final nom = state.chauffeur?.nom ?? 'Chauffeur';
    final statut = state.chauffeur?.statut ?? 'actif';
    final statutColor = _statutColor(statut);
    final statutLabel = _statutLabel(statut, l10n);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $nom',
                  style: AppTypography.headingLg.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statutColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statutLabel,
                      style: AppTypography.bodySm.copyWith(color: statutColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bouton accès rapide paiements
          IconButton.filled(
            onPressed: () => context.push('/chauffeur/paiements'),
            icon: const Icon(Icons.add, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Alerte retards ─────────────────────────────────────────────────────────

  Widget _buildRetardAlert(DashboardChauffeurState state, AppLocalizations l10n, bool isDark) {
    final nbImpayes = state.impayes.length;
    final totalEcart = state.impayes.fold<double>(0, (sum, i) => sum + i.ecart);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusErrorSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.statusError.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.statusError.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.statusError, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nbImpayes paiement${nbImpayes > 1 ? 's' : ''} en retard',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.statusError,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Montant dû : ${_formatMontant(totalEcart)} FCFA',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.statusError.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.statusError),
        ],
      ),
    );
  }

  // ─── Alerte incidents ───────────────────────────────────────────────────────

  Widget _buildIncidentAlert(DashboardChauffeurState state, AppLocalizations l10n, bool isDark) {
    final nbIncidents = state.incidentsOuverts.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusWarningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.statusWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.build_circle_outlined, color: AppColors.statusWarning, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nbIncidents incident${nbIncidents > 1 ? 's' : ''} en cours',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.statusWarning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  state.incidentsOuverts.first.description ?? state.incidentsOuverts.first.type,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.statusWarning.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/chauffeur/incidents'),
            icon: const Icon(Icons.chevron_right, color: AppColors.statusWarning),
          ),
        ],
      ),
    );
  }

  // ─── Carte véhicule + progression ──────────────────────────────────────────

  Widget _buildVehiculeCard(DashboardChauffeurState state, AppLocalizations l10n, bool isDark) {
    final vehicule = state.vehiculeActif!;
    final progression = state.progression!;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info véhicule ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vehicule.type == 'moto' ? Icons.two_wheeler : Icons.directions_car,
                  color: AppColors.brandGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicule.plaque,
                      style: AppTypography.headingSm.copyWith(color: textColor),
                    ),
                    if (vehicule.marque != null && vehicule.marque!.isNotEmpty)
                      Text(
                        vehicule.marque!,
                        style: AppTypography.bodySm.copyWith(color: secondaryColor),
                      ),
                  ],
                ),
              ),
              _buildStatutBadge(vehicule.statut, l10n),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Progression circulaire + chiffres ──────────────────────────
          Row(
            children: [
              // Cercle de progression
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: progression.pourcentage / 100,
                    backgroundColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    progressColor: _progressColor(progression.pourcentage),
                    strokeWidth: 8,
                  ),
                  child: Center(
                    child: Text(
                      '${progression.pourcentage}%',
                      style: AppTypography.headingSm.copyWith(
                        color: _progressColor(progression.pourcentage),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Détails
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Payé', '${_formatMontant(progression.totalPaye)} FCFA',
                        AppColors.statusSuccess, isDark),
                    const SizedBox(height: 6),
                    _buildInfoRow('Restant', '${_formatMontant(progression.soldeRestant)} FCFA',
                        AppColors.statusWarning, isDark),
                    const SizedBox(height: 6),
                    _buildInfoRow('Total', '${_formatMontant(progression.prixAchat)} FCFA',
                        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, isDark),
                  ],
                ),
              ),
            ],
          ),

          // ── Date fin remboursement ─────────────────────────────────────
          if (vehicule.dateFinRemboursement != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fin prévue', style: AppTypography.bodySm.copyWith(color: secondaryColor)),
                Text(
                  DateFormat('dd/MM/yyyy').format(vehicule.dateFinRemboursement!),
                  style: AppTypography.bodySm.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── KPIs période ──────────────────────────────────────────────────────────

  Widget _buildPeriodKpis(DashboardChauffeurState state, AppLocalizations l10n, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniKpi(
            label: 'Cette semaine',
            value: '${_formatMontant(state.totalSemaine)}',
            subtitle: '${state.nbPaiementsSemaine} paiement${state.nbPaiementsSemaine > 1 ? 's' : ''}',
            icon: Icons.date_range,
            color: AppColors.statusInfo,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildMiniKpi(
            label: 'Ce mois',
            value: '${_formatMontant(state.totalMois)}',
            subtitle: '${state.nbPaiementsMois} paiement${state.nbPaiementsMois > 1 ? 's' : ''}',
            icon: Icons.calendar_month,
            color: AppColors.brandGreen,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniKpi({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(label, style: AppTypography.bodyXs.copyWith(color: secondaryColor)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$value FCFA',
            style: AppTypography.headingSm.copyWith(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.bodyXs.copyWith(color: secondaryColor)),
        ],
      ),
    );
  }

  // ─── Derniers paiements ────────────────────────────────────────────────────

  Widget _buildDerniersPaiements(BuildContext context, DashboardChauffeurState state,
      AppLocalizations l10n, bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: [
                Text('Derniers paiements', style: AppTypography.headingSm.copyWith(color: textColor)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/chauffeur/paiements'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Liste
          if (state.derniersPaiements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Aucun paiement enregistré',
                        style: AppTypography.bodySm.copyWith(color: secondaryColor)),
                  ],
                ),
              ),
            )
          else
            ...state.derniersPaiements.map((p) => _buildPaiementItem(p, isDark)),
        ],
      ),
    );
  }

  Widget _buildPaiementItem(DernierPaiement p, bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final modeIcon = p.mode == 'cash' ? Icons.payments : Icons.phone_android;
    final modeLabel = p.mode == 'cash' ? 'Espèces' : p.mode == 'kkiapay' ? 'KKiaPay' : 'Mobile';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.statusSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(modeIcon, color: AppColors.statusSuccess, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatMontant(p.montant)} FCFA',
                  style: AppTypography.bodyMd.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(p.date)} · $modeLabel',
                  style: AppTypography.bodyXs.copyWith(color: secondaryColor),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.statusSuccess, size: 20),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildInfoRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        )),
        Text(value, style: AppTypography.bodySm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }

  Widget _buildStatutBadge(String statut, AppLocalizations l10n) {
    final color = _vehiculeStatutColor(statut);
    final label = switch (statut) {
      'en_remboursement' => 'En cours',
      'rembourse' => 'Remboursé',
      'en_panne' => 'En panne',
      'accidente' => 'Accidenté',
      'recupere' => 'Récupéré',
      _ => statut,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTypography.bodyXs.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      )),
    );
  }

  Color _statutColor(String statut) {
    return switch (statut) {
      'actif' => AppColors.statusSuccess,
      'retard' => AppColors.statusWarning,
      'defaut' => AppColors.statusError,
      'termine' => AppColors.statusInfo,
      _ => AppColors.statusInfo,
    };
  }

  String _statutLabel(String statut, AppLocalizations l10n) {
    return switch (statut) {
      'actif' => 'À jour',
      'retard' => 'En retard',
      'defaut' => 'En défaut',
      'termine' => 'Terminé',
      _ => statut,
    };
  }

  Color _vehiculeStatutColor(String statut) {
    return switch (statut) {
      'en_remboursement' => AppColors.statusInfo,
      'rembourse' => AppColors.statusSuccess,
      'en_panne' => AppColors.statusWarning,
      'accidente' => AppColors.statusError,
      _ => AppColors.statusInfo,
    };
  }

  Color _progressColor(int pourcentage) {
    if (pourcentage >= 75) return AppColors.statusSuccess;
    if (pourcentage >= 40) return AppColors.statusInfo;
    if (pourcentage >= 20) return AppColors.statusWarning;
    return AppColors.statusError;
  }

  String _formatMontant(double montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1)}M';
    }
    if (montant >= 1000) {
      return NumberFormat('#,##0', 'fr_FR').format(montant.toInt());
    }
    return montant.toInt().toString();
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
