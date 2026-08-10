import 'package:equatable/equatable.dart';

/// Modèle véhicule — moto-taxi ou voiture-taxi en financement
class VehiculeModel extends Equatable {
  final String id;
  final String type; // 'moto' | 'voiture'
  final String plaque;
  final String? marque;
  final String? immatriculation;
  final double prixAchat;
  final DateTime dateAchat;
  final DateTime? dateMiseCirculation;
  final DateTime? dateFinRemboursement;
  final String statut; // en_remboursement | rembourse | en_panne | accidente | recupere

  // Champs calculés temps réel (depuis l'API)
  final double totalVerse;
  final double soldeRestant;
  final double pourcentageRembourse;
  final String? chauffeurId;
  final String? chauffeurNom;
  final String? couleurFlotte; // a_jour | retard | defaut | rembourse | probleme | en_attente

  const VehiculeModel({
    required this.id,
    required this.type,
    required this.plaque,
    this.marque,
    this.immatriculation,
    required this.prixAchat,
    required this.dateAchat,
    this.dateMiseCirculation,
    this.dateFinRemboursement,
    this.statut = 'en_remboursement',
    this.totalVerse = 0,
    this.soldeRestant = 0,
    this.pourcentageRembourse = 0,
    this.chauffeurId,
    this.chauffeurNom,
    this.couleurFlotte,
  });

  factory VehiculeModel.fromJson(Map<String, dynamic> json) {
    return VehiculeModel(
      id: json['id'] as String,
      type: json['type'] as String,
      plaque: json['plaque'] as String,
      marque: json['marque'] as String?,
      immatriculation: json['immatriculation'] as String?,
      prixAchat: _toDouble(json['prix_achat']),
      dateAchat: DateTime.parse(json['date_achat'] as String),
      dateMiseCirculation: json['date_mise_circulation'] != null
          ? DateTime.parse(json['date_mise_circulation'] as String)
          : null,
      dateFinRemboursement: json['date_fin_remboursement'] != null
          ? DateTime.parse(json['date_fin_remboursement'] as String)
          : null,
      statut: json['statut'] as String? ?? 'en_remboursement',
      totalVerse: _toDouble(json['total_verse']),
      soldeRestant: _toDouble(json['solde_restant']),
      pourcentageRembourse: _toDouble(json['pourcentage_rembourse']),
      chauffeurId: json['chauffeur_id'] as String?,
      chauffeurNom: json['chauffeur_nom'] as String?,
      couleurFlotte: json['couleur_flotte'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'plaque': plaque,
      'marque': marque,
      'immatriculation': immatriculation,
      'prix_achat': prixAchat,
      'date_achat': dateAchat.toIso8601String().split('T')[0],
      'date_mise_circulation': dateMiseCirculation?.toIso8601String().split('T')[0],
      'date_fin_remboursement': dateFinRemboursement?.toIso8601String().split('T')[0],
      'statut': statut,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  /// Label du statut
  String get statutLabel {
    switch (statut) {
      case 'en_remboursement':
        return 'En remboursement';
      case 'rembourse':
        return 'Remboursé';
      case 'en_panne':
        return 'En panne';
      case 'accidente':
        return 'Accidenté';
      case 'recupere':
        return 'Récupéré';
      default:
        return statut;
    }
  }

  /// Icône du type
  bool get isMoto => type == 'moto';

  @override
  List<Object?> get props => [
        id, type, plaque, marque, immatriculation, prixAchat, dateAchat,
        dateMiseCirculation, dateFinRemboursement, statut, totalVerse,
        soldeRestant, pourcentageRembourse, chauffeurId, chauffeurNom, couleurFlotte,
      ];
}
