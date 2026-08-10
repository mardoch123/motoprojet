import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/ia/presentation/admin_ia_provider.dart';

/// Écran Rapports IA — Super Admin
/// Affiche le dernier rapport, l'historique, et un chat libre avec les données.
class AdminIaScreen extends ConsumerStatefulWidget {
  const AdminIaScreen({super.key});

  @override
  ConsumerState<AdminIaScreen> createState() => _AdminIaScreenState();
}

class _AdminIaScreenState extends ConsumerState<AdminIaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(adminIaProvider.notifier);
      notifier.chargerRapport();
      notifier.chargerHistorique();
      notifier.chargerObjectifs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports IA'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.summarize), text: 'Rapport'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRapportTab(),
          _buildHistoriqueTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  // ─── Onglet Rapport ────────────────────────────────────────────────────────
  Widget _buildRapportTab() {
    final state = ref.watch(adminIaProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(adminIaProvider.notifier).chargerRapport(force: true),
      child: state.rapportStatus == AdminIaStatus.loading && state.dernierRapport == null
          ? _buildLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Carte rapport principal ──
                if (state.dernierRapport != null)
                  _buildRapportCard(state.dernierRapport!),

                if (state.rapportStatus == AdminIaStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (state.rapportStatus == AdminIaStatus.error)
                  _buildErrorCard(state.errorMessage ?? 'Erreur inconnue'),

                const SizedBox(height: 16),

                // ── Objectifs ──
                if (state.objectifs.isNotEmpty) ...[
                  _buildSectionTitle('Objectifs définis'),
                  const SizedBox(height: 8),
                  ...state.objectifs.map(_buildObjectifCard),
                  const SizedBox(height: 16),
                ],

                // ── Bouton forcer le rapport ──
                OutlinedButton.icon(
                  onPressed: state.rapportStatus == AdminIaStatus.loading
                      ? null
                      : () => ref.read(adminIaProvider.notifier).chargerRapport(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Régénérer le rapport'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Indicateur fraîcheur ──
                if (state.dernierRapport != null)
                  Center(
                    child: Text(
                      state.rapportFrais
                          ? 'Rapport généré à l\'instant'
                          : 'Rapport du ${DateFormat('dd/MM/yyyy HH:mm').format(state.dernierRapport!.date)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRapportCard(AdminRapport rapport) {
    final couleurTrajectoire = _trajectoireColor(rapport.trajectoire);
    final labelTrajectoire = _trajectoireLabel(rapport.trajectoire);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [couleurTrajectoire.withOpacity(0.08), couleurTrajectoire.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleurTrajectoire.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: couleurTrajectoire.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: couleurTrajectoire, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Rapport hebdomadaire IA',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurTrajectoire,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labelTrajectoire,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Contenu du rapport
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              rapport.rapport,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary),
            ),
          ),

          // Actions proposées
          if (rapport.actionsProposees.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions prioritaires',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ...rapport.actionsProposees.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  'Via ${rapport.modeleUtilise == 'claude' ? 'Claude' : 'Deepseek'}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy').format(rapport.date),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectifCard(AdminObjectif objectif) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.flag, color: AppTheme.secondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(objectif.libelle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  'Cible : ${objectif.valeurCible.toStringAsFixed(0)} ${_uniteLabel(objectif.unite)} — ${objectif.delaiMois} mois',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Onglet Historique ─────────────────────────────────────────────────────
  Widget _buildHistoriqueTab() {
    final state = ref.watch(adminIaProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(adminIaProvider.notifier).chargerHistorique(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${state.totalRapports}', 'Rapports', AppTheme.primaryColor),
                _buildStatItem('${state.rapportsEnAvance}', 'En avance', AppTheme.successColor),
                _buildStatItem('${state.rapportsAtemps}', 'À temps', AppTheme.secondaryColor),
                _buildStatItem('${state.rapportsEnRetard}', 'En retard', AppTheme.errorColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Liste
          if (state.historique.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Aucun rapport dans l\'historique',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...state.historique.map((rapport) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    backgroundColor: _trajectoireColor(rapport.trajectoire).withOpacity(0.15),
                    child: Icon(
                      rapport.type == 'chat' ? Icons.chat : Icons.summarize,
                      color: _trajectoireColor(rapport.trajectoire),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    rapport.rapport,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(rapport.date)} • ${_trajectoireLabel(rapport.trajectoire)} • ${rapport.modeleUtilise}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                  trailing: rapport.actionsProposees.isNotEmpty
                      ? Badge(
                          label: Text('${rapport.actionsProposees.length}'),
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          textColor: AppTheme.primaryColor,
                        )
                      : null,
                  onTap: () => _showRapportDetail(rapport),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Onglet Chat ───────────────────────────────────────────────────────────
  Widget _buildChatTab() {
    final state = ref.watch(adminIaProvider);

    return Column(
      children: [
        // Messages
        Expanded(
          child: state.chatMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 56, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text(
                          'Posez une question sur votre business',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'L\'IA analyse vos données et répond en langage naturel.\nExemples :',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _buildQuestionSuggestion('Quel est mon taux de recouvrement ce mois ?'),
                        _buildQuestionSuggestion('Combien de véhicules puis-je acheter ce trimestre ?'),
                        _buildQuestionSuggestion('Quels chauffeurs dois-je relancer en priorité ?'),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = state.chatMessages[index];
                    return _buildChatBubble(msg);
                  },
                ),
        ),

        // Loading indicator
        if (state.chatStatus == AdminIaStatus.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),

        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Posez votre question...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _envoyerChat,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: state.chatStatus == AdminIaStatus.loading ? null : () => _envoyerChat(_chatController.text),
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _envoyerChat(String text) {
    if (text.trim().isEmpty) return;
    ref.read(adminIaProvider.notifier).envoyerChat(text.trim());
    _chatController.clear();
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Text(
                msg.question,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Réponse
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.secondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(msg.date),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(msg.reponse, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSuggestion(String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          _tabController.index = 2;
          _envoyerChat(question);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Utilitaires ───────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  void _showRapportDetail(AdminRapport rapport) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _trajectoireColor(rapport.trajectoire),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _trajectoireLabel(rapport.trajectoire),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(rapport.date),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 16),
              Text(rapport.rapport, style: const TextStyle(fontSize: 15, height: 1.5)),
              if (rapport.actionsProposees.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Actions proposées', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...rapport.actionsProposees.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _trajectoireColor(String trajectoire) {
    switch (trajectoire) {
      case 'en_avance':
        return AppTheme.successColor;
      case 'a_temps':
        return AppTheme.secondaryColor;
      case 'en_retard':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _trajectoireLabel(String trajectoire) {
    switch (trajectoire) {
      case 'en_avance':
        return 'En avance';
      case 'a_temps':
        return 'À temps';
      case 'en_retard':
        return 'En retard';
      default:
        return 'Non évalué';
    }
  }

  String _uniteLabel(String unite) {
    switch (unite) {
      case 'nb_vehicules':
        return 'véhicules';
      case 'taux_recouvrement':
        return '%';
      case 'revenu_mensuel':
        return 'FCFA/mois';
      case 'delai_mois':
        return 'mois';
      default:
        return unite;
    }
  }
}

// Extension pour mapper les listes avec index
extension _MapWithIndex<E> on List<E> {
  Iterable<MapEntry<int, E>> get asMap sync* {
    for (var i = 0; i < length; i++) {
      yield MapEntry(i, this[i]);
    }
  }
}
