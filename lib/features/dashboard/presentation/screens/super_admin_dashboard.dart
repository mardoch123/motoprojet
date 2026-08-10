import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/dashboard/presentation/dashboard_provider.dart';
import 'package:motoprojet/features/ia/presentation/admin_ia_provider.dart';
import 'package:motoprojet/features/ia/presentation/screens/admin_ia_screen.dart';
import 'package:motoprojet/features/anomalies/presentation/anomalie_provider.dart';
import 'package:motoprojet/features/anomalies/presentation/widgets/anomalies_dashboard_widget.dart';
import 'package:motoprojet/features/simulation/presentation/screens/simulation_screen.dart';
import 'package:motoprojet/features/salaires/presentation/screens/salaires_screen.dart';
import 'package:motoprojet/features/dashboard/presentation/widgets/prochain_achat_widget.dart';
import 'package:motoprojet/features/dashboard/presentation/prochain_achat_provider.dart';
import 'package:motoprojet/shared/widgets/kpi_widgets.dart';

/// ─── Écran principal du Super Admin ─────────────────────────────────────────
/// Tableau de bord terrain : lisible en plein soleil, gros chiffres,
/// pull-to-refresh, rafraîchissement auto toutes les 5 min.
class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadDashboard();
      ref.read(dashboardProvider.notifier).startAutoRefresh();
      // Charger le rapport IA admin
      ref.read(adminIaProvider.notifier).chargerRapport();
      // Charger les anomalies
      ref.read(anomalieProvider.notifier).chargerAnomalies(statut: 'nouveau');
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(dashboardProvider.notifier).loadDashboard();
    await ref.read(prochainAchatProvider.notifier).charger();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: state.isLoading && state.lastRefresh == null
            ? _buildLoading()
            : state.error != null && state.lastRefresh == null
                ? _buildError(state.error!)
                : _buildContent(state),
      ),
    );
  }

  // ─── Loading / Error ───────────────────────────────────────────────────────

  Widget _buildLoading() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        SizedBox(height: 16),
        Center(child: Text('Chargement du tableau de bord...')),
      ],
    );
  }

  Widget _buildError(String error) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        const Text('Impossible de charger les données',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Contenu principal ─────────────────────────────────────────────────────

  Widget _buildContent(DashboardState state) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'F', decimalDigits: 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── En-tête avec heure de dernière MAJ ──
        _buildHeader(state),

        // ── Compteurs prochain achat (temps réel) ──
        const ProchainAchatWidget(),

        // ── Cash encaissé ──
        _buildCashSection(state, fmt),

        // ── Véhicules actifs / remboursés ──
        _buildVehiculesSection(state),

        // ── Taux de recouvrement ──
        _buildRecouvrementSection(state, fmt),

        // ── Chauffeurs en retard ──
        _buildRetardsSection(state, fmt),

        // ── Recommandations IA ──
        _buildIASection(state),

        // ── Anomalies détectées ──
        const AnomaliesDashboardWidget(),

        // ── Simulation financière ──
        _buildSimulationSection(),

        // ── Salaires ──
        _buildSalairesSection(),

        // ── Finances (Patrimoine + Dépôts + Export) ──
        _buildFinancesSection(),
        const SizedBox(height: 16),
        // ── Pénalités de retard ──
        _buildPenalitesSection(),
        const SizedBox(height: 16),
        // ── Suivi flotte & immobilisation ──
        _buildFleetSection(),
        const SizedBox(height: 16),
        // ── Contrats numérisés ──
        _buildContratsSection(),

        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashboardState state) {
    final lastRefresh = state.lastRefresh;
    final timeStr = lastRefresh != null
        ? 'MAJ ${DateFormat('HH:mm').format(lastRefresh)}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Text('Tableau de bord',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const Spacer(),
          if (timeStr.isNotEmpty)
            Text(timeStr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          if (state.isLoading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  // ─── Cash encaissé ─────────────────────────────────────────────────────────

  Widget _buildCashSection(DashboardState state, NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CASH ENCAISSÉ'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: KpiCard(
              label: "Aujourd'hui",
              value: fmt.format(state.cashAujourdhui),
              icon: Icons.today,
              color: AppTheme.successColor,
            )),
            const SizedBox(width: 8),
            Expanded(child: KpiCard(
              label: 'Cette semaine',
              value: fmt.format(state.cashSemaine),
              icon: Icons.date_range,
              color: AppTheme.primaryColor,
            )),
            const SizedBox(width: 8),
            Expanded(child: KpiCard(
              label: 'Ce mois',
              value: fmt.format(state.cashMois),
              icon: Icons.calendar_month,
              color: AppTheme.secondaryColor,
            )),
          ],
        ),
        if (state.cashTendance.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tendance 7 jours', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                MiniSparkline(data: state.cashTendance, color: AppTheme.successColor, height: 50),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Véhicules ─────────────────────────────────────────────────────────────

  Widget _buildVehiculesSection(DashboardState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'VÉHICULES'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildVehiculeCard('Motos actives', state.motosActives, Icons.two_wheeler, AppTheme.primaryColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildVehiculeCard('Motos remboursées', state.motosRemboursees, Icons.two_wheeler, AppTheme.successColor)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildVehiculeCard('Voitures actives', state.voituresActives, Icons.directions_car, AppTheme.secondaryColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildVehiculeCard('Voitures remboursées', state.voituresRemboursees, Icons.directions_car, AppTheme.successColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildVehiculeCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          )),
        ],
      ),
    );
  }

  // ─── Recouvrement ──────────────────────────────────────────────────────────

  Widget _buildRecouvrementSection(DashboardState state, NumberFormat fmt) {
    final taux = state.tauxRecouvrement / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'TAUX DE RECOUVREMENT'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _recouvrementColor(taux).withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            children: [
              GaugeProgress(value: taux, size: 90, strokeWidth: 10),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${state.tauxRecouvrement.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _recouvrementColor(taux))),
                  const SizedBox(height: 4),
                  Text('Reçu: ${fmt.format(state.montantReel)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text('Attendu: ${fmt.format(state.montantTheorique)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    KpiCompact(label: 'À jour', value: '${state.nbAJour}', icon: Icons.check_circle, color: AppTheme.successColor),
                    const SizedBox(width: 6),
                    KpiCompact(label: 'Retard', value: '${state.nbEnRetard}', icon: Icons.warning, color: AppTheme.warningColor),
                    const SizedBox(width: 6),
                    KpiCompact(label: 'Défaut', value: '${state.nbEnDefaut}', icon: Icons.error, color: AppTheme.errorColor),
                  ]),
                ],
              )),
            ],
          ),
        ),
      ],
    );
  }

  Color _recouvrementColor(double taux) {
    if (taux >= 0.75) return AppTheme.successColor;
    if (taux >= 0.5) return AppTheme.secondaryColor;
    if (taux >= 0.25) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  // ─── Chauffeurs en retard ──────────────────────────────────────────────────

  Widget _buildRetardsSection(DashboardState state, NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'CHAUFFEURS EN RETARD',
          trailing: state.chauffeursEnRetard.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${state.chauffeursEnRetard.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (state.chauffeursEnRetard.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
                SizedBox(width: 12),
                Text('Aucun chauffeur en retard', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          ...state.chauffeursEnRetard.map((chauffeur) => _buildRetardCard(chauffeur, fmt)),
      ],
    );
  }

  Widget _buildRetardCard(RetardChauffeur chauffeur, NumberFormat fmt) {
    final isDefaut = chauffeur.statut == 'defaut';
    final color = isDefaut ? AppTheme.errorColor : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(isDefaut ? 'DÉFAUT' : 'RETARD',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(chauffeur.nom,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis)),
              Text('${chauffeur.joursImpayes}j',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.payments, size: 14, color: color),
              const SizedBox(width: 4),
              Text('Dû: ${fmt.format(chauffeur.montantDu)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              if (chauffeur.telephone != null && chauffeur.telephone!.isNotEmpty) ...[
                _buildActionChip(Icons.call, AppTheme.successColor, () => _launchPhone('tel:${chauffeur.telephone}')),
                const SizedBox(width: 6),
                _buildActionChip(Icons.message, AppTheme.primaryColor, () => _launchPhone('sms:${chauffeur.telephone}')),
              ],
            ],
          ),
          if (chauffeur.vehicules.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...chauffeur.vehicules.map((v) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${v.plaque} — ${v.tauxRecouvrement.toStringAsFixed(0)}% (reste ${fmt.format(v.soldeRestant)})',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _launchPhone(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ─── Analyse IA ──────────────────────────────────────────────────────────

  Widget _buildIASection(DashboardState state) {
    final iaState = ref.watch(adminIaProvider);
    final rapport = iaState.dernierRapport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'ANALYSE IA',
          trailing: rapport != null
              ? GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminIaScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _iaTrajectoireColor(rapport.trajectoire).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _iaTrajectoireLabel(rapport.trajectoire),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _iaTrajectoireColor(rapport.trajectoire)),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminIaScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rapport != null
                    ? [_iaTrajectoireColor(rapport.trajectoire).withOpacity(0.06), AppTheme.secondaryColor.withOpacity(0.04)]
                    : [AppTheme.primaryColor.withOpacity(0.05), AppTheme.secondaryColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rapport != null
                    ? _iaTrajectoireColor(rapport.trajectoire).withOpacity(0.2)
                    : AppTheme.primaryColor.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppTheme.secondaryColor),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Rapport IA hebdomadaire',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                  if (rapport != null)
                    Text(DateFormat('dd/MM').format(rapport.date),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: 10),
                if (rapport != null) ...[
                  Text(rapport.rapport,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                  if (rapport.actionsProposees.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...rapport.actionsProposees.take(2).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 5),
                              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(a, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3))),
                        ],
                      ),
                    )),
                  ],
                ] else if (iaState.rapportStatus == AdminIaStatus.loading)
                  const Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Génération du rapport...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ])
                else
                  const Text('Appuyez pour générer le rapport IA',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Voir tout →',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor.withOpacity(0.7))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _iaTrajectoireColor(String trajectoire) {
    switch (trajectoire) {
      case 'en_avance': return AppTheme.successColor;
      case 'a_temps': return AppTheme.secondaryColor;
      case 'en_retard': return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }

  String _iaTrajectoireLabel(String trajectoire) {
    switch (trajectoire) {
      case 'en_avance': return 'EN AVANCE';
      case 'a_temps': return 'À TEMPS';
      case 'en_retard': return 'EN RETARD';
      default: return 'IA';
    }
  }

  // ─── Exports comptables ────────────────────────────────────────────────────

  // ─── Salaires ─────────────────────────────────────────────────────────────

  Widget _buildSalairesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'SALAIRES'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalairesScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.withValues(alpha: 0.06), AppTheme.primaryColor.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestion des salaires',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Configurez les pourcentages, calculez et versez les salaires mensuels',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Simulation financière ───────────────────────────────────────────────

  Widget _buildSimulationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'SIMULATION FINANCIÈRE'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.withValues(alpha: 0.06), AppTheme.primaryColor.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights, color: Colors.deepPurple, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Projection de croissance',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Simulez l\'expansion du parc avec différents scénarios de réinvestissement',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Finances (Patrimoine + Dépôts + Export) ─────────────────────────────

  Widget _buildFinancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'FINANCES & EXPORT'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/admin/finances'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.withValues(alpha: 0.06), Colors.deepPurple.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.indigo, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patrimoine & Export comptable',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Suivi du patrimoine, dépôts banque et export PDF/Excel',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Pénalités de retard ──────────────────────────────────────────────────

  Widget _buildPenalitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'PÉNALITÉS DE RETARD'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/admin/penalites'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withValues(alpha: 0.06), Colors.red.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configuration des pénalités',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Paramétrer les règles de pénalités et exemptions',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Suivi flotte & immobilisation ───────────────────────────────────────

  Widget _buildFleetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'SUIVI FLOTTE & IMMOBILISATION'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/admin/fleet'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.withValues(alpha: 0.06), Colors.cyan.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gps_fixed, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Suivi flotte & immobilisation',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Position GPS, statut moteur, commandes à distance',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Contrats numérisés ───────────────────────────────────────────────────

  Widget _buildContratsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CONTRATS NUMÉRISES'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/admin/contrats'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.withValues(alpha: 0.06), Colors.blue.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: Colors.indigo, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contrats & Signatures',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Création, signature électronique, clauses légales',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
