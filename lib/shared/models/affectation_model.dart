import 'package:equatable/equatable.dart';

/// Modèle affectation — lien chauffeur ↔ véhicule dans le temps
class AffectationModel extends Equatable {
  final String id;
  final String chauffeurId;
  final String vehiculeId;
  final DateTime dateDebut;
  final DateTime? dateFin;

  const AffectationModel({
    required this.id,
    required this.chauffeurId,
    required this.vehiculeId,
    required this.dateDebut,
    this.dateFin,
  });

  factory AffectationModel.fromJson(Map<String, dynamic> json) {
    return AffectationModel(
      id: json['id'] as String,
      chauffeurId: json['chauffeur_id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chauffeur_id': chauffeurId,
      'vehicule_id': vehiculeId,
      'date_debut': dateDebut.toIso8601String().split('T')[0],
      'date_fin': dateFin?.toIso8601String().split('T')[0],
    };
  }

  bool get isActive => dateFin == null;

  @override
  List<Object?> get props => [id, chauffeurId, vehiculeId, dateDebut, dateFin];
}
