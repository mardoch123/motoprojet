import 'package:equatable/equatable.dart';

/// Modèle trajet — course effectuée par un chauffeur
class TrajetModel extends Equatable {
  final String id;
  final String chauffeurId;
  final DateTime date;
  final double kmParcourus;
  final List<String> zones;
  final double revenuGenere;

  const TrajetModel({
    required this.id,
    required this.chauffeurId,
    required this.date,
    this.kmParcourus = 0,
    this.zones = const [],
    this.revenuGenere = 0,
  });

  factory TrajetModel.fromJson(Map<String, dynamic> json) {
    return TrajetModel(
      id: json['id'] as String,
      chauffeurId: json['chauffeur_id'] as String,
      date: DateTime.parse(json['date'] as String),
      kmParcourus: (json['km_parcourus'] as num?)?.toDouble() ?? 0,
      zones: json['zones'] is List
          ? List<String>.from(json['zones'] as List)
          : const [],
      revenuGenere: (json['revenu_genere'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chauffeur_id': chauffeurId,
      'date': date.toIso8601String().split('T')[0],
      'km_parcourus': kmParcourus,
      'zones': zones,
      'revenu_genere': revenuGenere,
    };
  }

  @override
  List<Object?> get props => [id, chauffeurId, date, kmParcourus, zones, revenuGenere];
}
