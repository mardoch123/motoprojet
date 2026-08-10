import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';

/// ─── État du dashboard ──────────────────────────────────────────────────────
class DashboardState {
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  // Cash
  final double cashAujourdhui;
  final double cashSemaine;
  final double cashMois;
  final List<double> cashTendance; // 7 derniers jours

  // Véhicules
  final int motosActives;
  final int motosRemboursees;
  final int voituresActives;
  final int voituresRemboursees;

  // Recouvrement
  final double tauxRecouvrement;
  final double montantReel;
  final double montantTheorique;
  final int nbVehiculesActifs;
  final int nbAJour;
  final int nbEnRetard;
  final int nbEnDefaut;

  // Retards
  final List<RetardChauffeur> chauffeursEnRetard;

  // Prochains achats
  final double caisseMoto;
  final double prixMoto;
  final double caisseVoiture;
  final double prixVoiture;

  // IA
  final List<String> recommandationsIA;

  const DashboardState({
    this.isLoading = false,
    this.error,
    this.lastRefresh,
    this.cashAujourdhui = 0,
    this.cashSemaine = 0,
    this.cashMois = 0,
    this.cashTendance = const [],
    this.motosActives = 0,
    this.motosRemboursees = 0,
    this.voituresActives = 0,
    this.voituresRemboursees = 0,
    this.tauxRecouvrement = 0,
    this.montantReel = 0,
    this.montantTheorique = 0,
    this.nbVehiculesActifs = 0,
    this.nbAJour = 0,
    this.nbEnRetard = 0,
    this.nbEnDefaut = 0,
    this.chauffeursEnRetard = const [],
    this.caisseMoto = 0,
    this.prixMoto = 0,
    this.caisseVoiture = 0,
    this.prixVoiture = 0,
    this.recommandationsIA = const [],
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
    double? cashAujourdhui,
    double? cashSemaine,
    double? cashMois,
    List<double>? cashTendance,
    int? motosActives,
    int? motosRemboursees,
    int? voituresActives,
    int? voituresRemboursees,
    double? tauxRecouvrement,
    double? montantReel,
    double? montantTheorique,
    int? nbVehiculesActifs,
    int? nbAJour,
    int? nbEnRetard,
    int? nbEnDefaut,
    List<RetardChauffeur>? chauffeursEnRetard,
    double? caisseMoto,
    double? prixMoto,
    double? caisseVoiture,
    double? prixVoiture,
    List<String>? recommandationsIA,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastRefresh: lastRefresh ?? this.lastRefresh,
      cashAujourdhui: cashAujourdhui ?? this.cashAujourdhui,
      cashSemaine: cashSemaine ?? this.cashSemaine,
      cashMois: cashMois ?? this.cashMois,
      cashTendance: cashTendance ?? this.cashTendance,
      motosActives: motosActives ?? this.motosActives,
      motosRemboursees: motosRemboursees ?? this.motosRemboursees,
      voituresActives: voituresActives ?? this.voituresActives,
      voituresRemboursees: voituresRemboursees ?? this.voituresRemboursees,
      tauxRecouvrement: tauxRecouvrement ?? this.tauxRecouvrement,
      montantReel: montantReel ?? this.montantReel,
      montantTheorique: montantTheorique ?? this.montantTheorique,
      nbVehiculesActifs: nbVehiculesActifs ?? this.nbVehiculesActifs,
      nbAJour: nbAJour ?? this.nbAJour,
      nbEnRetard: nbEnRetard ?? this.nbEnRetard,
      nbEnDefaut: nbEnDefaut ?? this.nbEnDefaut,
      chauffeursEnRetard: chauffeursEnRetard ?? this.chauffeursEnRetard,
      caisseMoto: caisseMoto ?? this.caisseMoto,
      prixMoto: prixMoto ?? this.prixMoto,
      caisseVoiture: caisseVoiture ?? this.caisseVoiture,
      prixVoiture: prixVoiture ?? this.prixVoiture,
      recommandationsIA: recommandationsIA ?? this.recommandationsIA,
    );
  }
}

class RetardChauffeur {
  final String id;
  final String nom;
  final String statut;
  final int joursImpayes;
  final double montantDu;
  final String? telephone;
  final List<VehiculeRetard> vehicules;

  const RetardChauffeur({
    required this.id,
    required this.nom,
    required this.statut,
    required this.joursImpayes,
    required this.montantDu,
    this.telephone,
    this.vehicules = const [],
  });
}

class VehiculeRetard {
  final String plaque;
  final double tauxRecouvrement;
  final double soldeRestant;

  const VehiculeRetard({
    required this.plaque,
    required this.tauxRecouvrement,
    required this.soldeRestant,
  });
}

/// ─── Notifier ───────────────────────────────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref ref;
  Timer? _autoRefreshTimer;

  DashboardNotifier(this.ref) : super(const DashboardState());

  /// Charge toutes les données du dashboard en parallèle
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final api = ref.read(apiClientProvider);

      // Appels API en parallèle
      final results = await Future.wait([
        api.get('/dashboard'),
        api.get('/dashboard/recuperation', queryParameters: {'periode': 'semaine'}),
        api.get('/dashboard/retards'),
        api.get('/vehicules', queryParameters: {'limit': 500}),
        api.get('/paiements', queryParameters: {'limit': 500}),
      ]);

      final dashboardData = results[0].data as Map<String, dynamic>;
      final recuperationData = results[1].data as Map<String, dynamic>;
      final retardsData = results[2].data as Map<String, dynamic>;
      final vehiculesData = results[3].data as Map<String, dynamic>;
      final paiementsData = results[4].data as Map<String, dynamic>;

      // ── Dashboard principal ──
      final dashData = dashboardData['data'] as Map<String, dynamic>;
      final cashData = dashData['cash'] as Map<String, dynamic>?;
      final recouvrementData = dashData['recouvrement'] as Map<String, dynamic>?;

      // ── Recouvrement détaillé ──
      final recData = recuperationData['data'] as Map<String, dynamic>;
      final actuel = recData['actuel'] as Map<String, dynamic>?;

      // ── Retards ──
      final retardsList = (retardsData['data'] as List).map((r) {
        final rMap = r as Map<String, dynamic>;
        final vehicules = (rMap['vehicules'] as List? ?? []).map((v) {
          final vMap = v as Map<String, dynamic>;
          return VehiculeRetard(
            plaque: vMap['plaque']?.toString() ?? '',
            tauxRecouvrement: (vMap['taux_recouvrement'] as num?)?.toDouble() ?? 0,
            soldeRestant: (vMap['solde_restant'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
        return RetardChauffeur(
          id: rMap['chauffeur_id']?.toString() ?? '',
          nom: rMap['nom']?.toString() ?? '',
          statut: rMap['statut']?.toString() ?? '',
          joursImpayes: (rMap['jours_impayes_cumules'] as num?)?.toInt() ?? 0,
          montantDu: (rMap['montant_du'] as num?)?.toDouble() ?? 0,
          telephone: rMap['telephone']?.toString(),
          vehicules: vehicules,
        );
      }).toList();

      // ── Cash par période (calculé depuis les paiements) ──
      final paiements = (paiementsData['data'] as List? ?? []);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      double cashJour = 0, cashSem = 0, cashMoi = 0;
      final Map<String, double> cashParJour = {};

      for (final p in paiements) {
        final montant = (p['montant'] as num?)?.toDouble() ?? 0;
        final dateStr = p['date']?.toString() ?? '';
        if (dateStr.isEmpty) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;

        if (date.isAfter(today) || date.isAtSameMomentAs(today)) cashJour += montant;
        if (date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart)) cashSem += montant;
        if (date.isAfter(monthStart) || date.isAtSameMomentAs(monthStart)) cashMoi += montant;

        final key = dateStr.substring(0, 10);
        cashParJour[key] = (cashParJour[key] ?? 0) + montant;
      }

      // Tendance 7 jours
      final tendance = <double>[];
      for (int i = 6; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        final key = day.toIso8601String().substring(0, 10);
        tendance.add(cashParJour[key] ?? 0);
      }

      // ── Véhicules ──
      final vehicules = (vehiculesData['data'] as List? ?? []);
      int motosAct = 0, motosRem = 0, voituresAct = 0, voituresRem = 0;
      double prixMoyenMoto = 450000, prixMoyenVoiture = 3000000;

      for (final v in vehicules) {
        final type = v['type']?.toString() ?? '';
        final statut = v['statut']?.toString() ?? '';
        final prix = (v['prix_achat'] as num?)?.toDouble() ?? 0;
        if (type == 'moto') {
          prixMoyenMoto = prix > 0 ? prix : prixMoyenMoto;
          if (statut == 'en_remboursement') motosAct++;
          if (statut == 'rembourse') motosRem++;
        } else if (type == 'voiture') {
          prixMoyenVoiture = prix > 0 ? prix : prixMoyenVoiture;
          if (statut == 'en_remboursement') voituresAct++;
          if (statut == 'rembourse') voituresRem++;
        }
      }

      // ── Prochains achats (caisse cumulée vs prix) ──
      final totalCash = (cashData?['total_general'] as num?)?.toDouble() ?? cashMoi;

      state = state.copyWith(
        isLoading: false,
        lastRefresh: DateTime.now(),
        cashAujourdhui: cashJour,
        cashSemaine: cashSem,
        cashMois: cashMoi,
        cashTendance: tendance,
        motosActives: motosAct,
        motosRemboursees: motosRem,
        voituresActives: voituresAct,
        voituresRemboursees: voituresRem,
        tauxRecouvrement: (actuel?['taux_recouvrement'] as num?)?.toDouble() ??
            (recouvrementData?['taux_recouvrement'] as num?)?.toDouble() ?? 0,
        montantReel: (actuel?['montant_reel'] as num?)?.toDouble() ?? 0,
        montantTheorique: (actuel?['montant_theorique'] as num?)?.toDouble() ?? 0,
        nbVehiculesActifs: (actuel?['nb_vehicules_actifs'] as num?)?.toInt() ?? 0,
        nbAJour: (actuel?['nb_a_jour'] as num?)?.toInt() ?? 0,
        nbEnRetard: (actuel?['nb_en_retard'] as num?)?.toInt() ?? 0,
        nbEnDefaut: (actuel?['nb_en_defaut'] as num?)?.toInt() ?? 0,
        chauffeursEnRetard: retardsList,
        caisseMoto: totalCash,
        prixMoto: prixMoyenMoto,
        caisseVoiture: totalCash,
        prixVoiture: prixMoyenVoiture,
        recommandationsIA: _generateRecommandations(retardsList, actuel),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Démarre le rafraîchissement automatique (toutes les 5 min)
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      loadDashboard();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Recommandations synthétiques basées sur les données
  List<String> _generateRecommandations(List<RetardChauffeur> retards, Map<String, dynamic>? actuel) {
    final recos = <String>[];
    if (retards.isEmpty) {
      recos.add('Aucun retard détecté — le parc est sain');
    } else {
      final defauts = retards.where((r) => r.statut == 'defaut').length;
      if (defauts > 0) {
        recos.add('$defauts chauffeur(s) en défaut — action urgente requise');
      }
      recos.add('${retards.length} chauffeur(s) en retard — relancer en priorité');
    }

    final taux = (actuel?['taux_recouvrement'] as num?)?.toDouble() ?? 0;
    if (taux < 50) {
      recos.add('Taux de recouvrement critique (${taux.toStringAsFixed(0)}%) — revoir la stratégie');
    } else if (taux < 75) {
      recos.add('Taux de recouvrement moyen — intensifier les relances');
    } else {
      recos.add('Bon taux de recouvrement (${taux.toStringAsFixed(0)}%) — continuer');
    }

    return recos;
  }
}

/// ─── Provider ───────────────────────────────────────────────────────────────
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
