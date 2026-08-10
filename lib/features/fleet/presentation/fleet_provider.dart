import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class VehiculeFleet {
  final String id;
  final String immatriculation;
  final String type;
  final String statutMoteur;
  final String? imeiBoitier;
  final String? fournisseurBoitier;
  final double? latitude;
  final double? longitude;
  final double vitesse;
  final DateTime? derniereMajTelemetrie;
  final bool coupureAuto;
  final int seuilCoupureJours;
  final String? chauffeurId;
  final String? chauffeurNom;
  final String? chauffeurTelephone;
  final int commandesEnCours;

  VehiculeFleet({
    required this.id,
    required this.immatriculation,
    required this.type,
    required this.statutMoteur,
    this.imeiBoitier,
    this.fournisseurBoitier,
    this.latitude,
    this.longitude,
    required this.vitesse,
    this.derniereMajTelemetrie,
    required this.coupureAuto,
    required this.seuilCoupureJours,
    this.chauffeurId,
    this.chauffeurNom,
    this.chauffeurTelephone,
    required this.commandesEnCours,
  });

  factory VehiculeFleet.fromJson(Map<String, dynamic> json) {
    return VehiculeFleet(
      id: json['id'] as String,
      immatriculation: json['immatriculation'] as String? ?? '',
      type: json['type'] as String? ?? 'moto',
      statutMoteur: json['statut_moteur'] as String? ?? 'actif',
      imeiBoitier: json['imei_boitier'] as String?,
      fournisseurBoitier: json['fournisseur_boitier'] as String?,
      latitude: (json['derniere_latitude'] as num?)?.toDouble(),
      longitude: (json['derniere_longitude'] as num?)?.toDouble(),
      vitesse: (json['derniere_vitesse'] as num?)?.toDouble() ?? 0,
      derniereMajTelemetrie: json['derniere_maj_telemetrie'] != null
          ? DateTime.parse(json['derniere_maj_telemetrie'] as String)
          : null,
      coupureAuto: json['coupure_auto'] as bool? ?? true,
      seuilCoupureJours: (json['seuil_coupure_jours'] as num?)?.toInt() ?? 2,
      chauffeurId: json['chauffeur_id'] as String?,
      chauffeurNom: json['chauffeur_nom'] as String?,
      chauffeurTelephone: json['chauffeur_telephone'] as String?,
      commandesEnCours: (json['commandes_en_cours'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isMoving => vitesse > 0;
  bool get isEngineCut => statutMoteur == 'coupe';
  bool get hasPendingCommand => commandesEnCours > 0;
  bool get hasTracker => imeiBoitier != null && imeiBoitier!.isNotEmpty;
}

class CommandeBoitier {
  final String id;
  final String vehiculeId;
  final String typeCommande;
  final String statut;
  final String? declenchePar;
  final String? declencheurNom;
  final String? motif;
  final double? vitesseAuDeclenchement;
  final DateTime? envoyeLe;
  final DateTime? confirmeLe;
  final String? erreur;
  final int tentatives;
  final bool priorite;
  final DateTime creeLe;

  CommandeBoitier({
    required this.id,
    required this.vehiculeId,
    required this.typeCommande,
    required this.statut,
    this.declenchePar,
    this.declencheurNom,
    this.motif,
    this.vitesseAuDeclenchement,
    this.envoyeLe,
    this.confirmeLe,
    this.erreur,
    required this.tentatives,
    required this.priorite,
    required this.creeLe,
  });

  factory CommandeBoitier.fromJson(Map<String, dynamic> json) {
    return CommandeBoitier(
      id: json['id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      typeCommande: json['type_commande'] as String,
      statut: json['statut'] as String,
      declenchePar: json['declenche_par'] as String?,
      declencheurNom: json['declencheur_nom'] as String?,
      motif: json['motif'] as String?,
      vitesseAuDeclenchement: (json['vitesse_au_declenchement'] as num?)?.toDouble(),
      envoyeLe: json['envoye_le'] != null ? DateTime.parse(json['envoye_le'] as String) : null,
      confirmeLe: json['confirme_le'] != null ? DateTime.parse(json['confirme_le'] as String) : null,
      erreur: json['erreur'] as String?,
      tentatives: (json['tentatives'] as num?)?.toInt() ?? 0,
      priorite: json['priorite'] as bool? ?? false,
      creeLe: DateTime.parse(json['cree_le'] as String),
    );
  }
}

class AuditImmobilisation {
  final String id;
  final String vehiculeId;
  final String? immatriculation;
  final String? chauffeurNom;
  final String action;
  final String? declenchePar;
  final String? declencheurNom;
  final String source;
  final double? vitesseAuMoment;
  final double? latitude;
  final double? longitude;
  final DateTime horodatage;

  AuditImmobilisation({
    required this.id,
    required this.vehiculeId,
    this.immatriculation,
    this.chauffeurNom,
    required this.action,
    this.declenchePar,
    this.declencheurNom,
    required this.source,
    this.vitesseAuMoment,
    this.latitude,
    this.longitude,
    required this.horodatage,
  });

  factory AuditImmobilisation.fromJson(Map<String, dynamic> json) {
    return AuditImmobilisation(
      id: json['id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      immatriculation: json['immatriculation'] as String?,
      chauffeurNom: json['chauffeur_nom'] as String?,
      action: json['action'] as String,
      declenchePar: json['declenche_par'] as String?,
      declencheurNom: json['declencheur_nom'] as String?,
      source: json['source'] as String,
      vitesseAuMoment: (json['vitesse_au_moment'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      horodatage: DateTime.parse(json['horodatage'] as String),
    );
  }
}

class ParametresImmobilisation {
  final bool immobilisationActive;
  final int delaiPreavisHeures;
  final int dureeArretConfirmeSecondes;
  final double vitesseMaxCoupe;
  final String fournisseurApiUrl;
  final String webhookSecret;

  ParametresImmobilisation({
    required this.immobilisationActive,
    required this.delaiPreavisHeures,
    required this.dureeArretConfirmeSecondes,
    required this.vitesseMaxCoupe,
    required this.fournisseurApiUrl,
    required this.webhookSecret,
  });

  factory ParametresImmobilisation.fromJson(Map<String, dynamic> json) {
    return ParametresImmobilisation(
      immobilisationActive: json['immobilisation_active'] == 'true',
      delaiPreavisHeures: int.tryParse(json['delai_preavis_heures']?.toString() ?? '2') ?? 2,
      dureeArretConfirmeSecondes: int.tryParse(json['duree_arret_confirme_secondes']?.toString() ?? '30') ?? 30,
      vitesseMaxCoupe: double.tryParse(json['vitesse_max_coupe']?.toString() ?? '0') ?? 0,
      fournisseurApiUrl: json['fournisseur_api_url']?.toString() ?? '',
      webhookSecret: json['webhook_secret']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'immobilisation_active': immobilisationActive.toString(),
    'delai_preavis_heures': delaiPreavisHeures.toString(),
    'duree_arret_confirme_secondes': dureeArretConfirmeSecondes.toString(),
    'vitesse_max_coupe': vitesseMaxCoupe.toString(),
    'fournisseur_api_url': fournisseurApiUrl,
    'webhook_secret': webhookSecret,
  };
}

// ─── État ────────────────────────────────────────────────────────────────────

class FleetState {
  final List<VehiculeFleet> vehicules;
  final Map<String, List<CommandeBoitier>> commandes;
  final List<AuditImmobilisation> audit;
  final ParametresImmobilisation? parametres;
  final bool isLoading;
  final String? error;

  FleetState({
    this.vehicules = const [],
    this.commandes = const {},
    this.audit = const [],
    this.parametres,
    this.isLoading = false,
    this.error,
  });

  FleetState copyWith({
    List<VehiculeFleet>? vehicules,
    Map<String, List<CommandeBoitier>>? commandes,
    List<AuditImmobilisation>? audit,
    ParametresImmobilisation? parametres,
    bool? isLoading,
    String? error,
  }) {
    return FleetState(
      vehicules: vehicules ?? this.vehicules,
      commandes: commandes ?? this.commandes,
      audit: audit ?? this.audit,
      parametres: parametres ?? this.parametres,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class FleetNotifier extends StateNotifier<FleetState> {
  FleetNotifier(this._ref) : super(FleetState());

  final Ref _ref;

  Future<void> chargerVehicules() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _ref.read(apiClientProvider).get('/fleet/vehicules');
      final data = response.data as Map<String, dynamic>;
      final list = (data['vehicules'] as List)
          .map((e) => VehiculeFleet.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(vehicules: list, isLoading: false);
    } catch (e) {
      AppLogger.e('Erreur chargement véhicules fleet', error: e);
      state = state.copyWith(isLoading: false, error: 'Erreur chargement');
    }
  }

  Future<void> chargerCommandes(String vehiculeId) async {
    try {
      final response = await _ref.read(apiClientProvider).get('/fleet/vehicules/$vehiculeId/commandes');
      final data = response.data as Map<String, dynamic>;
      final list = (data['commandes'] as List)
          .map((e) => CommandeBoitier.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCommandes = Map<String, List<CommandeBoitier>>.from(state.commandes);
      newCommandes[vehiculeId] = list;
      state = state.copyWith(commandes: newCommandes);
    } catch (e) {
      AppLogger.e('Erreur chargement commandes', error: e);
    }
  }

  Future<void> chargerAudit({String? vehiculeId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (vehiculeId != null) queryParams['vehicule_id'] = vehiculeId;
      
      final response = await _ref.read(apiClientProvider).get(
        '/fleet/audit',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['audit'] as List)
          .map((e) => AuditImmobilisation.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(audit: list);
    } catch (e) {
      AppLogger.e('Erreur chargement audit', error: e);
    }
  }

  Future<void> chargerParametres() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/fleet/parametres');
      final data = response.data as Map<String, dynamic>;
      final parametres = ParametresImmobilisation.fromJson(data['parametres'] as Map<String, dynamic>);
      state = state.copyWith(parametres: parametres);
    } catch (e) {
      AppLogger.e('Erreur chargement paramètres', error: e);
    }
  }

  Future<bool> immobiliser(String vehiculeId, String motif) async {
    try {
      await _ref.read(apiClientProvider).post(
        '/fleet/vehicules/$vehiculeId/immobiliser',
        data: {'motif': motif, 'source': 'manuel'},
      );
      await chargerVehicules();
      return true;
    } catch (e) {
      AppLogger.e('Erreur immobilisation', error: e);
      return false;
    }
  }

  Future<bool> reactiver(String vehiculeId, String motif) async {
    try {
      await _ref.read(apiClientProvider).post(
        '/fleet/vehicules/$vehiculeId/reactiver',
        data: {'motif': motif},
      );
      await chargerVehicules();
      return true;
    } catch (e) {
      AppLogger.e('Erreur réactivation', error: e);
      return false;
    }
  }

  Future<bool> updateParametres(ParametresImmobilisation parametres) async {
    try {
      await _ref.read(apiClientProvider).put(
        '/fleet/parametres',
        data: parametres.toJson(),
      );
      await chargerParametres();
      return true;
    } catch (e) {
      AppLogger.e('Erreur update paramètres', error: e);
      return false;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref);
});
