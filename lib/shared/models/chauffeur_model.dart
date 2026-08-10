import 'package:equatable/equatable.dart';

/// Modèle chauffeur — informations métier (étend users)
class ChauffeurModel extends Equatable {
  final String id;
  final String userId;
  final String nom;
  final String? telephone;
  final String? pieceIdentite;
  final String? photoUrl;
  final String? adresse;
  final String? contactUrgence;
  final double objectifJournalier;
  final String statut; // actif | retard | defaut | termine
  final double totalVerse;
  final bool mustChangePin;

  const ChauffeurModel({
    required this.id,
    required this.userId,
    required this.nom,
    this.telephone,
    this.pieceIdentite,
    this.photoUrl,
    this.adresse,
    this.contactUrgence,
    this.objectifJournalier = 0,
    this.statut = 'actif',
    this.totalVerse = 0,
    this.mustChangePin = false,
  });

  factory ChauffeurModel.fromJson(Map<String, dynamic> json) {
    return ChauffeurModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nom: json['nom'] as String,
      telephone: json['telephone'] as String?,
      pieceIdentite: json['piece_identite'] as String?,
      photoUrl: json['photo_url'] as String?,
      adresse: json['adresse'] as String?,
      contactUrgence: json['contact_urgence'] as String?,
      objectifJournalier: _toDouble(json['objectif_journalier']),
      statut: json['statut'] as String? ?? 'actif',
      totalVerse: _toDouble(json['total_verse']),
      mustChangePin: json['must_change_pin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nom': nom,
      'telephone': telephone,
      'piece_identite': pieceIdentite,
      'photo_url': photoUrl,
      'adresse': adresse,
      'contact_urgence': contactUrgence,
      'objectif_journalier': objectifJournalier,
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

  /// Couleur du statut
  String get statutLabel {
    switch (statut) {
      case 'actif':
        return 'Actif';
      case 'retard':
        return 'En retard';
      case 'defaut':
        return 'En défaut';
      case 'termine':
        return 'Terminé';
      default:
        return statut;
    }
  }

  @override
  List<Object?> get props => [
        id, userId, nom, telephone, pieceIdentite, photoUrl,
        adresse, contactUrgence, objectifJournalier, statut, totalVerse,
      ];
}
