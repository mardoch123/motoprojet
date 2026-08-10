import 'package:equatable/equatable.dart';

/// Modèle incident — panne ou accident sur un véhicule
class IncidentModel extends Equatable {
  final String id;
  final String vehiculeId;
  final String type; // 'panne' | 'accident'
  final String? description;
  final String? photoUrl;
  final double cout;
  final DateTime date;
  final String statut; // signale | en_cours | resolu

  const IncidentModel({
    required this.id,
    required this.vehiculeId,
    required this.type,
    this.description,
    this.photoUrl,
    this.cout = 0,
    required this.date,
    this.statut = 'signale',
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      cout: (json['cout'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      statut: json['statut'] as String? ?? 'signale',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicule_id': vehiculeId,
      'type': type,
      'description': description,
      'photo_url': photoUrl,
      'cout': cout,
      'date': date.toIso8601String().split('T')[0],
      'statut': statut,
    };
  }

  @override
  List<Object?> get props => [id, vehiculeId, type, description, photoUrl, cout, date, statut];
}
