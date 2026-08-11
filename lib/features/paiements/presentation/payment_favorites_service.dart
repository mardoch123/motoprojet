import 'package:hive_flutter/hive_flutter.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SERVICE FAVORIS PAIEMENT — Paiement en un clic
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Stocke :
/// - Le dernier paiement effectué (chauffeur, véhicule, montant, mode)
/// - Les favoris (jusqu'à 3 chauffeurs/véhicules les plus utilisés)
///
/// Permet le pré-remplissage automatique de l'écran de saisie rapide
/// pour réduire le nombre de taps à 1 seul pour les paiements récurrents.
/// ═══════════════════════════════════════════════════════════════════════════

const String _kPaymentFavoritesBox = 'payment_favorites';
const String _kLastPaymentKey = 'last_payment';
const String _kFavoritesKey = 'favorites';
const int _maxFavorites = 3;

/// Représente un favori de paiement
class PaymentFavorite {
  final String chauffeurId;
  final String chauffeurNom;
  final String vehiculeId;
  final String vehiculePlaque;
  final double montant;
  final String mode;
  final int usageCount;
  final DateTime lastUsed;

  PaymentFavorite({
    required this.chauffeurId,
    required this.chauffeurNom,
    required this.vehiculeId,
    required this.vehiculePlaque,
    required this.montant,
    this.mode = 'cash',
    this.usageCount = 1,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'chauffeurId': chauffeurId,
        'chauffeurNom': chauffeurNom,
        'vehiculeId': vehiculeId,
        'vehiculePlaque': vehiculePlaque,
        'montant': montant,
        'mode': mode,
        'usageCount': usageCount,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory PaymentFavorite.fromMap(Map<String, dynamic> map) => PaymentFavorite(
        chauffeurId: map['chauffeurId'] as String,
        chauffeurNom: map['chauffeurNom'] as String,
        vehiculeId: map['vehiculeId'] as String,
        vehiculePlaque: map['vehiculePlaque'] as String,
        montant: (map['montant'] as num).toDouble(),
        mode: map['mode'] as String? ?? 'cash',
        usageCount: map['usageCount'] as int? ?? 1,
        lastUsed: DateTime.tryParse(map['lastUsed'] as String? ?? ''),
      );

  /// Clé unique pour identifier ce favori (combinaison chauffeur + véhicule)
  String get key => '${chauffeurId}_${vehiculeId}';
}

/// Dernier paiement effectué (pour pré-remplissage)
class LastPayment {
  final String chauffeurId;
  final String chauffeurNom;
  final String vehiculeId;
  final String vehiculePlaque;
  final double montant;
  final String mode;
  final DateTime timestamp;

  LastPayment({
    required this.chauffeurId,
    required this.chauffeurNom,
    required this.vehiculeId,
    required this.vehiculePlaque,
    required this.montant,
    this.mode = 'cash',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'chauffeurId': chauffeurId,
        'chauffeurNom': chauffeurNom,
        'vehiculeId': vehiculeId,
        'vehiculePlaque': vehiculePlaque,
        'montant': montant,
        'mode': mode,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LastPayment.fromMap(Map<String, dynamic> map) => LastPayment(
        chauffeurId: map['chauffeurId'] as String,
        chauffeurNom: map['chauffeurNom'] as String,
        vehiculeId: map['vehiculeId'] as String,
        vehiculePlaque: map['vehiculePlaque'] as String,
        montant: (map['montant'] as num).toDouble(),
        mode: map['mode'] as String? ?? 'cash',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Service de gestion des favoris de paiement
class PaymentFavoritesService {
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_kPaymentFavoritesBox);
    AppLogger.i('PaymentFavorites initialisé');
  }

  /// Enregistre un paiement et met à jour les favoris
  Future<void> recordPayment({
    required String chauffeurId,
    required String chauffeurNom,
    required String vehiculeId,
    required String vehiculePlaque,
    required double montant,
    String mode = 'cash',
  }) async {
    // Mettre à jour le dernier paiement
    final lastPayment = LastPayment(
      chauffeurId: chauffeurId,
      chauffeurNom: chauffeurNom,
      vehiculeId: vehiculeId,
      vehiculePlaque: vehiculePlaque,
      montant: montant,
      mode: mode,
    );
    await _box.put(_kLastPaymentKey, lastPayment.toMap());

    // Mettre à jour les favoris
    final favorites = _getFavoritesList();
    final key = '${chauffeurId}_${vehiculeId}';

    final existingIndex = favorites.indexWhere((f) => f.key == key);
    if (existingIndex >= 0) {
      // Incrémenter le compteur d'utilisation
      final existing = favorites[existingIndex];
      favorites[existingIndex] = PaymentFavorite(
        chauffeurId: chauffeurId,
        chauffeurNom: chauffeurNom,
        vehiculeId: vehiculeId,
        vehiculePlaque: vehiculePlaque,
        montant: montant,
        mode: mode,
        usageCount: existing.usageCount + 1,
      );
    } else {
      // Ajouter un nouveau favori
      favorites.add(PaymentFavorite(
        chauffeurId: chauffeurId,
        chauffeurNom: chauffeurNom,
        vehiculeId: vehiculeId,
        vehiculePlaque: vehiculePlaque,
        montant: montant,
        mode: mode,
      ));
    }

    // Trier par usage (les plus utilisés en premier) et garder les top N
    favorites.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final topFavorites = favorites.take(_maxFavorites).toList();

    await _box.put(
      _kFavoritesKey,
      topFavorites.map((f) => f.toMap()).toList(),
    );

    AppLogger.d('[Favoris] Paiement enregistré: $chauffeurNom — $montant FCFA');
  }

  /// Récupère le dernier paiement effectué
  LastPayment? getLastPayment() {
    final data = _box.get(_kLastPaymentKey);
    if (data == null) return null;
    return LastPayment.fromMap(Map<String, dynamic>.from(data as Map));
  }

  /// Récupère la liste des favoris (triés par usage)
  List<PaymentFavorite> getFavorites() {
    return _getFavoritesList();
  }

  List<PaymentFavorite> _getFavoritesList() {
    final data = _box.get(_kFavoritesKey);
    if (data == null) return [];
    return (data as List)
        .whereType<Map>()
        .map((m) => PaymentFavorite.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Supprime un favori
  Future<void> removeFavorite(String chauffeurId, String vehiculeId) async {
    final favorites = _getFavoritesList();
    final key = '${chauffeurId}_${vehiculeId}';
    favorites.removeWhere((f) => f.key == key);
    await _box.put(_kFavoritesKey, favorites.map((f) => f.toMap()).toList());
  }

  /// Efface tous les favoris
  Future<void> clearAll() async {
    await _box.delete(_kLastPaymentKey);
    await _box.delete(_kFavoritesKey);
  }
}
