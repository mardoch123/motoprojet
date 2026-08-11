import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class ChauffeurInfo {
  final String id;
  final String nom;
  final String statut;
  final double objectifJournalier;

  const ChauffeurInfo({
    required this.id,
    required this.nom,
    required this.statut,
    required this.objectifJournalier,
  });

  factory ChauffeurInfo.fromJson(Map<String, dynamic> json) {
    return ChauffeurInfo(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? '',
      statut: json['statut'] as String? ?? 'actif',
      objectifJournalier: double.tryParse(json['objectif_journalier'].toString()) ?? 0,
    );
  }
}

class VehiculeActif {
  final String id;
  final String plaque;
  final String? marque;
  final String type;
  final String statut;
  final double prixAchat;
  final DateTime? affectationDepuis;
  final DateTime? dateFinRemboursement;

  const VehiculeActif({
    required this.id,
    required this.plaque,
    this.marque,
    required this.type,
    required this.statut,
    required this.prixAchat,
    this.affectationDepuis,
    this.dateFinRemboursement,
  });

  factory VehiculeActif.fromJson(Map<String, dynamic> json) {
    return VehiculeActif(
      id: json['id'] as String,
      plaque: json['plaque'] as String? ?? '',
      marque: json['marque'] as String?,
      type: json['type'] as String? ?? 'moto',
      statut: json['statut'] as String? ?? 'en_remboursement',
      prixAchat: double.tryParse(json['prix_achat'].toString()) ?? 0,
      affectationDepuis: json['affectation_depuis'] != null
          ? DateTime.tryParse(json['affectation_depuis'] as String)
          : null,
      dateFinRemboursement: json['date_fin_remboursement'] != null
          ? DateTime.tryParse(json['date_fin_remboursement'] as String)
          : null,
    );
  }
}

class ProgressionPaiement {
  final double totalPaye;
  final double prixAchat;
  final double soldeRestant;
  final int pourcentage;
  final int nbPaiements;

  const ProgressionPaiement({
    required this.totalPaye,
    required this.prixAchat,
    required this.soldeRestant,
    required this.pourcentage,
    required this.nbPaiements,
  });

  factory ProgressionPaiement.fromJson(Map<String, dynamic> json) {
    return ProgressionPaiement(
      totalPaye: double.tryParse(json['total_paye'].toString()) ?? 0,
      prixAchat: double.tryParse(json['prix_achat'].toString()) ?? 0,
      soldeRestant: double.tryParse(json['solde_restant'].toString()) ?? 0,
      pourcentage: int.tryParse(json['pourcentage'].toString()) ?? 0,
      nbPaiements: int.tryParse(json['nb_paiements'].toString()) ?? 0,
    );
  }
}

class DernierPaiement {
  final String id;
  final double montant;
  final DateTime date;
  final String mode;
  final String vehiculePlaque;

  const DernierPaiement({
    required this.id,
    required this.montant,
    required this.date,
    required this.mode,
    required this.vehiculePlaque,
  });

  factory DernierPaiement.fromJson(Map<String, dynamic> json) {
    return DernierPaiement(
      id: json['id'] as String,
      montant: double.tryParse(json['montant'].toString()) ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      mode: json['mode'] as String? ?? 'cash',
      vehiculePlaque: json['vehicule_plaque'] as String? ?? '',
    );
  }
}

class Impaye {
  final String id;
  final DateTime date;
  final double montantAttendu;
  final double montantVerse;
  final double ecart;
  final String statut;
  final String vehiculePlaque;

  const Impaye({
    required this.id,
    required this.date,
    required this.montantAttendu,
    required this.montantVerse,
    required this.ecart,
    required this.statut,
    required this.vehiculePlaque,
  });

  factory Impaye.fromJson(Map<String, dynamic> json) {
    return Impaye(
      id: json['id'] as String,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      montantAttendu: double.tryParse(json['montant_attendu'].toString()) ?? 0,
      montantVerse: double.tryParse(json['montant_verse'].toString()) ?? 0,
      ecart: double.tryParse(json['ecart'].toString()) ?? 0,
      statut: json['statut'] as String? ?? 'impaye',
      vehiculePlaque: json['vehicule_plaque'] as String? ?? '',
    );
  }
}

class IncidentOuvert {
  final String id;
  final String type;
  final String statut;
  final String? description;
  final DateTime date;
  final double cout;
  final String vehiculePlaque;

  const IncidentOuvert({
    required this.id,
    required this.type,
    required this.statut,
    this.description,
    required this.date,
    required this.cout,
    required this.vehiculePlaque,
  });

  factory IncidentOuvert.fromJson(Map<String, dynamic> json) {
    return IncidentOuvert(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      statut: json['statut'] as String? ?? 'signale',
      description: json['description'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      cout: double.tryParse(json['cout'].toString()) ?? 0,
      vehiculePlaque: json['vehicule_plaque'] as String? ?? '',
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

class DashboardChauffeurState {
  final bool isLoading;
  final String? error;
  final ChauffeurInfo? chauffeur;
  final VehiculeActif? vehiculeActif;
  final ProgressionPaiement? progression;
  final List<DernierPaiement> derniersPaiements;
  final double totalSemaine;
  final double totalMois;
  final int nbPaiementsSemaine;
  final int nbPaiementsMois;
  final List<Impaye> impayes;
  final List<IncidentOuvert> incidentsOuverts;

  const DashboardChauffeurState({
    this.isLoading = false,
    this.error,
    this.chauffeur,
    this.vehiculeActif,
    this.progression,
    this.derniersPaiements = const [],
    this.totalSemaine = 0,
    this.totalMois = 0,
    this.nbPaiementsSemaine = 0,
    this.nbPaiementsMois = 0,
    this.impayes = const [],
    this.incidentsOuverts = const [],
  });

  DashboardChauffeurState copyWith({
    bool? isLoading,
    String? error,
    ChauffeurInfo? chauffeur,
    VehiculeActif? vehiculeActif,
    ProgressionPaiement? progression,
    List<DernierPaiement>? derniersPaiements,
    double? totalSemaine,
    double? totalMois,
    int? nbPaiementsSemaine,
    int? nbPaiementsMois,
    List<Impaye>? impayes,
    List<IncidentOuvert>? incidentsOuverts,
  }) {
    return DashboardChauffeurState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      chauffeur: chauffeur ?? this.chauffeur,
      vehiculeActif: vehiculeActif ?? this.vehiculeActif,
      progression: progression ?? this.progression,
      derniersPaiements: derniersPaiements ?? this.derniersPaiements,
      totalSemaine: totalSemaine ?? this.totalSemaine,
      totalMois: totalMois ?? this.totalMois,
      nbPaiementsSemaine: nbPaiementsSemaine ?? this.nbPaiementsSemaine,
      nbPaiementsMois: nbPaiementsMois ?? this.nbPaiementsMois,
      impayes: impayes ?? this.impayes,
      incidentsOuverts: incidentsOuverts ?? this.incidentsOuverts,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

class DashboardChauffeurNotifier extends StateNotifier<DashboardChauffeurState> {
  final Ref ref;
  DashboardChauffeurNotifier(this.ref) : super(const DashboardChauffeurState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/dashboard/chauffeur');
      final data = response.data as Map<String, dynamic>;
      final dashboardData = data['data'] as Map<String, dynamic>;

      // Si pas de profil chauffeur
      if (dashboardData.containsKey('message')) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final chauffeur = ChauffeurInfo.fromJson(dashboardData['chauffeur'] as Map<String, dynamic>);
      
      VehiculeActif? vehicule;
      if (dashboardData['vehicule_actif'] != null) {
        vehicule = VehiculeActif.fromJson(dashboardData['vehicule_actif'] as Map<String, dynamic>);
      }

      final progression = ProgressionPaiement.fromJson(dashboardData['progression'] as Map<String, dynamic>);

      final derniersPaiements = (dashboardData['derniers_paiements'] as List)
          .map((e) => DernierPaiement.fromJson(e as Map<String, dynamic>))
          .toList();

      final periodes = dashboardData['periodes'] as Map<String, dynamic>;
      
      final impayes = (dashboardData['impayes'] as List)
          .map((e) => Impaye.fromJson(e as Map<String, dynamic>))
          .toList();

      final incidents = (dashboardData['incidents_ouverts'] as List)
          .map((e) => IncidentOuvert.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        chauffeur: chauffeur,
        vehiculeActif: vehicule,
        progression: progression,
        derniersPaiements: derniersPaiements,
        totalSemaine: double.tryParse(periodes['semaine'].toString()) ?? 0,
        totalMois: double.tryParse(periodes['mois'].toString()) ?? 0,
        nbPaiementsSemaine: int.tryParse(periodes['nb_paiements_semaine'].toString()) ?? 0,
        nbPaiementsMois: int.tryParse(periodes['nb_paiements_mois'].toString()) ?? 0,
        impayes: impayes,
        incidentsOuverts: incidents,
      );
    } catch (e) {
      AppLogger.e('[DashboardChauffeur] Erreur: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardChauffeurProvider = StateNotifierProvider<DashboardChauffeurNotifier, DashboardChauffeurState>((ref) {
  return DashboardChauffeurNotifier(ref);
});
