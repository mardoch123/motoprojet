/// Moteur de simulation financière — Logique pure, sans dépendance UI.
///
/// Simule la croissance d'un parc de véhicules de taxi (motos/voitures)
/// avec réinvestissement des remboursements quotidiens.
///
/// Testable indépendamment de l'UI.
library;

// ─── Types ────────────────────────────────────────────────────────────────────

enum TypeVehicule { moto, voiture }

enum RegleReinvestissement {
  /// 100% motos
  toutMoto,
  /// 100% voitures
  toutVoiture,
  /// Bascule à une date fixe : motos avant, voitures après
  basculeDate,
  /// Rythme cyclique : ex. "3 motos puis 1 voiture"
  rythmeMixte,
}

enum PasSimulation {
  jour,
  mois,
}

// ─── Paramètres d'entrée ──────────────────────────────────────────────────────

class ParametresSimulation {
  // Prix d'achat
  final double prixMoto;
  final double prixVoiture;

  // Remboursement journalier par véhicule
  final double remboursementJourMoto;
  final double remboursementJourVoiture;

  // Durée de remboursement en mois
  final int dureeRemboursementMois;

  // Taux de recouvrement réel attendu (0.0 à 1.0)
  final double tauxRecouvrement;

  // Règle de réinvestissement
  final RegleReinvestissement regle;

  // Pour basculeDate : date de bascule (nombre de mois depuis le début)
  final int moisBascule;

  // Pour rythmeMixte : séquence [nbMotos, nbVoitures] ex: [3, 1]
  final int rythmeMotos;
  final int rythmeVoitures;

  // Véhicules de départ (déjà en circulation)
  final int motosInitiales;
  final int voituresInitiales;

  // Cash initial en caisse
  final double cashInitial;

  // Durée de simulation
  final int dureeMois; // nombre de mois à simuler

  // Pas de calcul
  final PasSimulation pas;

  // Impact salaire évolutif (Prompt 20) — % du cash retiré chaque mois pour salaires
  // null = pas d'impact
  final double? salaireMensuelMoto;
  final double? salaireMensuelVoiture;

  const ParametresSimulation({
    this.prixMoto = 500000,
    this.prixVoiture = 3000000,
    this.remboursementJourMoto = 5000,
    this.remboursementJourVoiture = 15000,
    this.dureeRemboursementMois = 14,
    this.tauxRecouvrement = 0.90,
    this.regle = RegleReinvestissement.toutMoto,
    this.moisBascule = 12,
    this.rythmeMotos = 3,
    this.rythmeVoitures = 1,
    this.motosInitiales = 0,
    this.voituresInitiales = 0,
    this.cashInitial = 0,
    this.dureeMois = 12,
    this.pas = PasSimulation.mois,
    this.salaireMensuelMoto,
    this.salaireMensuelVoiture,
  });

  /// Nombre de jours dans un mois (moyenne)
  static const int joursParMois = 30;

  /// Durée de remboursement en jours
  int get dureeRemboursementJours => dureeRemboursementMois * joursParMois;
}

// ─── Véhicule simulé ─────────────────────────────────────────────────────────

class _VehiculeSimule {
  final TypeVehicule type;
  final int jourAchat; // jour absolu où il a été acheté
  final int dureeRemboursementJours;
  final double remboursementJour;
  bool get estRembourse => false; // calculé dynamiquement

  _VehiculeSimule({
    required this.type,
    required this.jourAchat,
    required this.dureeRemboursementJours,
    required this.remboursementJour,
  });

  bool isRembourseAt(int jour) {
    return jour >= jourAchat + dureeRemboursementJours;
  }

  double valeurResiduelleAt(int jour, double prixAchat) {
    if (isRembourseAt(jour)) return 0;
    final joursRestants = (jourAchat + dureeRemboursementJours) - jour;
    final ratio = joursRestants / dureeRemboursementJours;
    return prixAchat * ratio;
  }
}

// ─── Snapshot à un instant t ──────────────────────────────────────────────────

class SnapshotSimulation {
  final int periode; // jour ou mois selon le pas
  final int motosAchetees;
  final int voituresAchetees;
  final int motosActives; // en cours de remboursement
  final int voituresActives;
  final int motosRemboursees;
  final int voituresRemboursees;
  final double cashDisponible;
  final double patrimoineTotal; // cash + valeur résiduelle véhicules actifs
  final double cashCumuleTotal; // total des encaissements depuis le début
  final int vehiculesAchetesPeriode; // nb de véhicules achetés sur cette période

  const SnapshotSimulation({
    required this.periode,
    required this.motosAchetees,
    required this.voituresAchetees,
    required this.motosActives,
    required this.voituresActives,
    required this.motosRemboursees,
    required this.voituresRemboursees,
    required this.cashDisponible,
    required this.patrimoineTotal,
    required this.cashCumuleTotal,
    required this.vehiculesAchetesPeriode,
  });

  int get totalVehicules => motosAchetees + voituresAchetees;
  int get totalActifs => motosActives + voituresActives;
}

// ─── Résultat complet ─────────────────────────────────────────────────────────

class ResultatSimulation {
  final List<SnapshotSimulation> snapshots;
  final ParametresSimulation parametres;

  const ResultatSimulation({
    required this.snapshots,
    required this.parametres,
  });

  SnapshotSimulation get dernier => snapshots.last;

  /// Point de bascule : premier mois où le cash devient négatif (si jamais)
  int? get moisDefaillance {
    for (final s in snapshots) {
      if (s.cashDisponible < 0) return s.periode;
    }
    return null;
  }
}

// ─── MOTEUR DE CALCUL ─────────────────────────────────────────────────────────

class MoteurSimulation {
  /// Exécute la simulation jour par jour (granularité maximale).
  /// Les snapshots mensuels sont agrégés depuis les données journalières.
  static ResultatSimulation executer(ParametresSimulation params) {
    final totalJours = params.dureeMois * ParametresSimulation.joursParMois;

    double cash = params.cashInitial;
    double cashCumule = 0;
    int motosAchetees = params.motosInitiales;
    int voituresAchetees = params.voituresInitiales;
    int prochainAchatVehiculeIndex = 0; // pour le rythme mixte

    // Liste des véhicules simulés
    final List<_VehiculeSimule> vehicules = [];

    // Ajouter les véhicules initiaux
    for (int i = 0; i < params.motosInitiales; i++) {
      vehicules.add(_VehiculeSimule(
        type: TypeVehicule.moto,
        jourAchat: 0,
        dureeRemboursementJours: params.dureeRemboursementJours,
        remboursementJour: params.remboursementJourMoto,
      ));
    }
    for (int i = 0; i < params.voituresInitiales; i++) {
      vehicules.add(_VehiculeSimule(
        type: TypeVehicule.voiture,
        jourAchat: 0,
        dureeRemboursementJours: params.dureeRemboursementJours,
        remboursementJour: params.remboursementJourVoiture,
      ));
    }

    // Snapshots intermédiaires (agrégation mensuelle)
    final List<SnapshotSimulation> snapshotsMensuels = [];

    // Compteurs mensuels
    int vehiculesAchetesCeMois = 0;

    for (int jour = 1; jour <= totalJours; jour++) {
      // 1. Collecter les paiements du jour
      double recetteJour = 0;
      for (final v in vehicules) {
        if (!v.isRembourseAt(jour)) {
          recetteJour += v.remboursementJour * params.tauxRecouvrement;
        }
      }
      cash += recetteJour;
      cashCumule += recetteJour;

      // 2. Déduire les salaires (si configurés)
      if (params.salaireMensuelMoto != null || params.salaireMensuelVoiture != null) {
        // Salaires appliqués chaque jour (1/30ème du montant mensuel)
        final motosActives = vehicules.where((v) => v.type == TypeVehicule.moto && !v.isRembourseAt(jour)).length;
        final voituresActives = vehicules.where((v) => v.type == TypeVehicule.voiture && !v.isRembourseAt(jour)).length;
        final salaireJour = ((params.salaireMensuelMoto ?? 0) * motosActives +
            (params.salaireMensuelVoiture ?? 0) * voituresActives) / ParametresSimulation.joursParMois;
        cash -= salaireJour;
      }

      // 3. Acheter un nouveau véhicule si possible
      final typeACheter = _determinerTypeAchat(params, jour, motosAchetees, voituresAchetees, prochainAchatVehiculeIndex);
      if (typeACheter != null) {
        final prix = typeACheter == TypeVehicule.moto ? params.prixMoto : params.prixVoiture;
        if (cash >= prix) {
          cash -= prix;
          vehicules.add(_VehiculeSimule(
            type: typeACheter,
            jourAchat: jour,
            dureeRemboursementJours: params.dureeRemboursementJours,
            remboursementJour: typeACheter == TypeVehicule.moto
                ? params.remboursementJourMoto
                : params.remboursementJourVoiture,
          ));
          if (typeACheter == TypeVehicule.moto) {
            motosAchetees++;
          } else {
            voituresAchetees++;
          }
          vehiculesAchetesCeMois++;
          prochainAchatVehiculeIndex++;
        }
      }

      // 4. Snapshot de fin de mois
      if (jour % ParametresSimulation.joursParMois == 0 || jour == totalJours) {
        final mois = (jour / ParametresSimulation.joursParMois).ceil();
        final motosActives = vehicules.where((v) => v.type == TypeVehicule.moto && !v.isRembourseAt(jour)).length;
        final voituresActives = vehicules.where((v) => v.type == TypeVehicule.voiture && !v.isRembourseAt(jour)).length;
        final motosRemb = vehicules.where((v) => v.type == TypeVehicule.moto && v.isRembourseAt(jour)).length;
        final voitRemb = vehicules.where((v) => v.type == TypeVehicule.voiture && v.isRembourseAt(jour)).length;

        // Patrimoine = cash + valeur résiduelle des véhicules actifs
        double valeurResiduelle = 0;
        for (final v in vehicules) {
          if (!v.isRembourseAt(jour)) {
            valeurResiduelle += v.remboursementJour *
                ((v.jourAchat + v.dureeRemboursementJours - jour)) * params.tauxRecouvrement;
          }
        }

        snapshotsMensuels.add(SnapshotSimulation(
          periode: mois,
          motosAchetees: motosAchetees,
          voituresAchetees: voituresAchetees,
          motosActives: motosActives,
          voituresActives: voituresActives,
          motosRemboursees: motosRemb,
          voituresRemboursees: voitRemb,
          cashDisponible: cash,
          patrimoineTotal: cash + valeurResiduelle,
          cashCumuleTotal: cashCumule,
          vehiculesAchetesPeriode: vehiculesAchetesCeMois,
        ));

        vehiculesAchetesCeMois = 0;
      }
    }

    return ResultatSimulation(snapshots: snapshotsMensuels, parametres: params);
  }

  /// Détermine le type de véhicule à acheter selon la règle de réinvestissement.
  /// Retourne null si aucun achat nécessaire/possible selon la règle.
  static TypeVehicule? _determinerTypeAchat(
    ParametresSimulation params,
    int jour,
    int motosAchetees,
    int voituresAchetees,
    int index,
  ) {
    final moisCourant = (jour / ParametresSimulation.joursParMois).ceil();

    switch (params.regle) {
      case RegleReinvestissement.toutMoto:
        return TypeVehicule.moto;

      case RegleReinvestissement.toutVoiture:
        return TypeVehicule.voiture;

      case RegleReinvestissement.basculeDate:
        if (moisCourant <= params.moisBascule) {
          return TypeVehicule.moto;
        } else {
          return TypeVehicule.voiture;
        }

      case RegleReinvestissement.rythmeMixte:
        final cycle = params.rythmeMotos + params.rythmeVoitures;
        if (cycle == 0) return null;
        final posInCycle = index % cycle;
        if (posInCycle < params.rythmeMotos) {
          return TypeVehicule.moto;
        } else {
          return TypeVehicule.voiture;
        }
    }
  }
}
