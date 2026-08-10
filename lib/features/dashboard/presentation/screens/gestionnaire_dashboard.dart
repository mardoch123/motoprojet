import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/dashboard/presentation/dashboard_provider.dart';
import 'package:motoprojet/features/incidents/presentation/screens/incident_form_screen.dart';
import 'package:motoprojet/shared/widgets/kpi_widgets.dart';

/// ─── Dashboard opérationnel Gestionnaire ────────────────────────────────────
/// Vue terrain : retards, recouvrement, tâches de relance.
/// Pas de données financières globales (cash, prix, exports).
class GestionnaireDashboard extends ConsumerStatefulWidget {
  const GestionnaireDashboard({super.key});

  @override
  ConsumerState<GestionnaireDashboard> createState() => _GestionnaireDashboardState();
}

class _GestionnaireDashboardState extends ConsumerState<GestionnaireDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadDashboard();
      ref.read(dashboardProvider.notifier).startAutoRefresh();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(dashboardProvider.notifier).loadDashboard();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const IncidentFormScreen())),
        icon: const Icon(Icons.report_problem),
        label: const Text('Signaler'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(children: const [
      SizedBox(height: 120),
      Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      SizedBox(height: 16),
      Center(child: Text('Chargement...')),
    ]);
  }

  Widget _buildError(String error) {
    return ListView(children: [
      const SizedBox(height: 120),
      const Icon(Icons.cloud_off, size: 64, color: AppTheme.textSecondary),
      const SizedBox(height: 16),
      const Text('Impossible de charger les données',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      Center(
        child: ElevatedButton.icon(
          onPressed: _onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent(DashboardState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── En-tête ──
        _buildHeader(state),

        // ── Taux de recouvrement (jauge) ──
        _buildRecouvrementSection(state),

        // ── Véhicules : aperçu opérationnel ──
        _buildVehiculesResume(state),

        // ── Chauffeurs en retard ──
        _buildRetardsSection(state),

        // ── Tâches de relance du jour ──
        _buildTachesDuJour(state),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashboardState state) {
    final today = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());
    final lastRefresh = state.lastRefresh;
    final timeStr = lastRefresh != null ? DateFormat('HH:mm').format(lastRefresh) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(today, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            const Text('Opérations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const Spacer(),
            if (timeStr.isNotEmpty)
              Text('MAJ $timeStr', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            if (state.isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
            ],
          ]),
        ],
      ),
    );
  }

  // ─── Recouvrement ──────────────────────────────────────────────────────────

  Widget _buildRecouvrementSection(DashboardState state) {
    final taux = state.tauxRecouvrement / 100;
    final color = _colorForTaux(taux);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GaugeProgress(value: taux, size: 90, strokeWidth: 10),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RECOUVREMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('${state.tauxRecouvrement.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 8),
              Row(children: [
                _miniBadge('${state.nbAJour} à jour', AppTheme.successColor),
                const SizedBox(width: 6),
                _miniBadge('${state.nbEnRetard} retard', AppTheme.warningColor),
                const SizedBox(width: 6),
                _miniBadge('${state.nbEnDefaut} défaut', AppTheme.errorColor),
              ]),
            ],
          )),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Color _colorForTaux(double taux) {
    if (taux >= 0.75) return AppTheme.successColor;
    if (taux >= 0.5) return AppTheme.secondaryColor;
    if (taux >= 0.25) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  // ─── Véhicules résumé ──────────────────────────────────────────────────────

  Widget _buildVehiculesResume(DashboardState state) {
    final total = state.motosActives + state.voituresActives;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VÉHICULES EN CIRCULATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: KpiCompact(label: 'Motos actives', value: '${state.motosActives}', icon: Icons.two_wheeler, color: AppTheme.primaryColor)),
            const SizedBox(width: 8),
            Expanded(child: KpiCompact(label: 'Voitures actives', value: '${state.voituresActives}', icon: Icons.directions_car, color: AppTheme.secondaryColor)),
            const SizedBox(width: 8),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.pin, color: AppTheme.successColor, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                  const Text('Total', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ])),
              ]),
            )),
          ]),
        ],
      ),
    );
  }

  // ─── Chauffeurs en retard ──────────────────────────────────────────────────

  Widget _buildRetardsSection(DashboardState state) {
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
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
              SizedBox(width: 12),
              Text('Aucun retard — tout est en ordre', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            ]),
          )
        else
          ...state.chauffeursEnRetard.map((c) => _buildRetardCard(c)),
      ],
    );
  }

  Widget _buildRetardCard(RetardChauffeur chauffeur) {
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
          Row(children: [
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
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Spacer(),
            if (chauffeur.telephone != null && chauffeur.telephone!.isNotEmpty) ...[
              _actionChip(Icons.call, AppTheme.successColor, () => _launch('tel:${chauffeur.telephone}')),
              const SizedBox(width: 6),
              _actionChip(Icons.message, AppTheme.primaryColor, () => _launch('sms:${chauffeur.telephone}')),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ─── Tâches de relance du jour ─────────────────────────────────────────────

  Widget _buildTachesDuJour(DashboardState state) {
    final taches = <_TacheRelance>[];

    // Générer les tâches depuis les retards
    for (final c in state.chauffeursEnRetard) {
      if (c.statut == 'defaut') {
        taches.add(_TacheRelance(
          priorite: _Priorite.urgente,
          description: 'Appeler ${c.nom} — en défaut depuis ${c.joursImpayes}j',
          action: () => c.telephone != null ? _launch('tel:${c.telephone}') : null,
          icon: Icons.phone_callback,
        ));
      } else if (c.joursImpayes >= 3) {
        taches.add(_TacheRelance(
          priorite: _Priorite.haute,
          description: 'Relancer ${c.nom} — ${c.joursImpayes}j de retard',
          action: () => c.telephone != null ? _launch('sms:${c.telephone}') : null,
          icon: Icons.sms,
        ));
      }
    }

    // Tâches générales
    if (state.nbEnRetard > 0 && state.nbEnDefaut == 0) {
      taches.add(_TacheRelance(
        priorite: _Priorite.normale,
        description: 'Vérifier les paiements en attente (${state.nbEnRetard} véhicules)',
        action: null,
        icon: Icons.pending_actions,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'TÂCHES DE RELANCE'),
        const SizedBox(height: 8),
        if (taches.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.celebration, color: AppTheme.successColor, size: 24),
              SizedBox(width: 12),
              Text('Aucune tâche — journée calme', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            ]),
          )
        else
          ...taches.map((t) => _buildTacheCard(t)),
      ],
    );
  }

  Widget _buildTacheCard(_TacheRelance tache) {
    final color = switch (tache.priorite) {
      _Priorite.urgente => AppTheme.errorColor,
      _Priorite.haute => AppTheme.warningColor,
      _Priorite.normale => AppTheme.primaryColor,
    };
    final label = switch (tache.priorite) {
      _Priorite.urgente => 'URGENT',
      _Priorite.haute => 'HAUTE',
      _Priorite.normale => 'NORMALE',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(tache.icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(tache.description, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ],
        )),
        if (tache.action != null)
          IconButton(icon: Icon(Icons.arrow_forward, color: color, size: 20), onPressed: tache.action!),
      ]),
    );
  }
}

enum _Priorite { urgente, haute, normale }

class _TacheRelance {
  final _Priorite priorite;
  final String description;
  final VoidCallback? action;
  final IconData icon;

  _TacheRelance({required this.priorite, required this.description, this.action, required this.icon});
}
