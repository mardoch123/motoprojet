import 'package:equatable/equatable.dart';

/// Modèle paiement — versement quotidien du chauffeur
class PaiementModel extends Equatable {
  final String id;
  final String chauffeurId;
  final String vehiculeId;
  final double montant;
  final String date; // ISO date
  final String mode; // 'cash' | 'mobile_money' | 'mobile_money_kkiapay'
  final String? transactionKkiapayId;
  final double? kkiapayFrais;
  final bool synchroniseOffline;
  final DateTime dateEnregistrement;

  const PaiementModel({
    required this.id,
    required this.chauffeurId,
    required this.vehiculeId,
    required this.montant,
    required this.date,
    this.mode = 'cash',
    this.transactionKkiapayId,
    this.kkiapayFrais,
    this.synchroniseOffline = false,
    required this.dateEnregistrement,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> json) {
    return PaiementModel(
      id: json['id'] as String,
      chauffeurId: json['chauffeur_id'] as String,
      vehiculeId: json['vehicule_id'] as String,
      montant: (json['montant'] as num).toDouble(),
      date: json['date'] as String,
      mode: json['mode'] as String? ?? 'cash',
      transactionKkiapayId: json['transaction_kkiapay_id'] as String?,
      kkiapayFrais: (json['kkiapay_frais'] as num?)?.toDouble(),
      synchroniseOffline: json['synchronise_offline'] as bool? ?? false,
      dateEnregistrement: DateTime.parse(json['date_enregistrement'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chauffeur_id': chauffeurId,
      'vehicule_id': vehiculeId,
      'montant': montant,
      'date': date,
      'mode': mode,
      if (transactionKkiapayId != null) 'transaction_kkiapay_id': transactionKkiapayId,
      if (kkiapayFrais != null) 'kkiapay_frais': kkiapayFrais,
      'synchronise_offline': synchroniseOffline,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
    };
  }

  /// Pour stockage Hive hors-ligne
  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'chauffeurId': chauffeurId,
      'vehiculeId': vehiculeId,
      'montant': montant,
      'date': date,
      'mode': mode,
      if (transactionKkiapayId != null) 'transactionKkiapayId': transactionKkiapayId,
      if (kkiapayFrais != null) 'kkiapayFrais': kkiapayFrais,
      'synchroniseOffline': synchroniseOffline,
      'dateEnregistrement': dateEnregistrement.toIso8601String(),
    };
  }

  factory PaiementModel.fromHiveMap(Map<String, dynamic> map) {
    return PaiementModel(
      id: map['id'] as String,
      chauffeurId: map['chauffeurId'] as String,
      vehiculeId: map['vehiculeId'] as String,
      montant: (map['montant'] as num).toDouble(),
      date: map['date'] as String,
      mode: map['mode'] as String? ?? 'cash',
      transactionKkiapayId: map['transactionKkiapayId'] as String?,
      kkiapayFrais: (map['kkiapayFrais'] as num?)?.toDouble(),
      synchroniseOffline: map['synchroniseOffline'] as bool? ?? false,
      dateEnregistrement: DateTime.parse(map['dateEnregistrement'] as String),
    );
  }

  @override
  List<Object?> get props => [id, chauffeurId, vehiculeId, montant, date, mode, transactionKkiapayId, kkiapayFrais, synchroniseOffline, dateEnregistrement];
}
