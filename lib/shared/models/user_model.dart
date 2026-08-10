import 'package:equatable/equatable.dart';

/// Modèle utilisateur — authentification par PIN, rôles multiples
class UserModel extends Equatable {
  final String id;
  final String telephone;
  final String role; // super_admin | gestionnaire | chauffeur
  final String statut; // actif | suspendu | desactive
  final DateTime dateCreation;

  const UserModel({
    required this.id,
    required this.telephone,
    required this.role,
    this.statut = 'actif',
    required this.dateCreation,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      telephone: json['telephone'] as String,
      role: json['role'] as String,
      statut: json['statut'] as String? ?? 'actif',
      dateCreation: DateTime.parse(json['date_creation'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'telephone': telephone,
      'role': role,
      'statut': statut,
      'date_creation': dateCreation.toIso8601String(),
    };
  }

  bool get isActive => statut == 'actif';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isGestionnaire => role == 'gestionnaire';
  bool get isChauffeur => role == 'chauffeur';

  @override
  List<Object?> get props => [id, telephone, role, statut, dateCreation];
}
