import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Service de suivi GPS pour le chauffeur.
/// Calcule le kilométrage journalier et les zones fréquentées.
/// Ne fonctionne que pendant les heures d'activité déclarées.
class GpsTrackingService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  double _dailyKm = 0;
  final Set<String> _zonesVisited = {};
  bool _isTracking = false;
  DateTime? _trackingStartTime;

  // Heures d'activité par défaut (peuvent être personnalisées)
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  bool get isTracking => _isTracking;
  double get dailyKm => _dailyKm;
  Set<String> get zonesVisited => Set.unmodifiable(_zonesVisited);
  DateTime? get trackingStartTime => _trackingStartTime;

  /// Démarre le suivi GPS.
  /// [startHour] et [endHour] définissent la plage horaire de suivi.
  Future<bool> startTracking({
    int startHour = 6,
    int endHour = 22,
  }) async {
    if (_isTracking) {
      AppLogger.w('[GPS] Tracking déjà actif');
      return false;
    }

    _startTime = TimeOfDay(hour: startHour, minute: 0);
    _endTime = TimeOfDay(hour: endHour, minute: 0);

    // Vérifier les permissions
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      AppLogger.e('[GPS] Permissions refusées');
      return false;
    }

    // Vérifier que le GPS est activé
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.e('[GPS] Service de localisation désactivé');
      return false;
    }

    _isTracking = true;
    _trackingStartTime = DateTime.now();
    _dailyKm = 0;
    _lastPosition = null;
    _zonesVisited.clear();

    // Écouter les positions GPS
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Mise à jour tous les 50m minimum
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionUpdate);

    AppLogger.i('[GPS] Tracking démarré (${_startTime.hour}h-${_endTime.hour}h)');
    return true;
  }

  /// Arrête le suivi GPS
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _lastPosition = null;
    AppLogger.i('[GPS] Tracking arrêté. Km: ${_dailyKm.toStringAsFixed(1)}, Zones: ${_zonesVisited.length}');
  }

  /// Réinitialise le compteur journalier (à appeler à minuit ou en nouvelle journée)
  void resetDaily() {
    _dailyKm = 0;
    _zonesVisited.clear();
    _lastPosition = null;
    AppLogger.i('[GPS] Compteur journalier réinitialisé');
  }

  /// Vérifie si on est dans les heures d'activité
  bool isWithinActiveHours() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  /// Callback appelé à chaque nouvelle position GPS
  void _onPositionUpdate(Position position) {
    if (!_isTracking) return;

    // Respect des heures d'activité
    if (!isWithinActiveHours()) {
      AppLogger.d('[GPS] Hors heures d\'activité, position ignorée');
      return;
    }

    // Calcul du kilométrage
    if (_lastPosition != null) {
      final distance = _calculateDistance(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Ignorer les sauts GPS aberrants (> 5km en une lecture = bruit)
      if (distance > 0 && distance < 5000) {
        _dailyKm += distance / 1000; // Convertir en km
      }
    }

    _lastPosition = position;

    // Détection de zone (reverse geocoding simplifié)
    _detectZone(position.latitude, position.longitude);
  }

  /// Calcule la distance entre deux points GPS (formule de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // Rayon terrestre en mètres
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  /// Détection de zone simplifiée — grille de 1km²
  /// Les coordonnées sont arrondies pour anonymiser (pas de GPS précis stocké)
  void _detectZone(double lat, double lon) {
    // Arrondir à ~0.01° ≈ 1km pour anonymiser
    final zoneLat = (lat * 100).round() / 100;
    final zoneLon = (lon * 100).round() / 100;
    final zoneName = 'Z${zoneLat.toStringAsFixed(2)}_${zoneLon.toStringAsFixed(2)}';
    _zonesVisited.add(zoneName);
  }

  /// Vérifie et demande les permissions de localisation
  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Retourne un résumé du tracking pour envoi à l'API
  Map<String, dynamic> getTrackingSummary() {
    return {
      'km_jour': _dailyKm,
      'zones': _zonesVisited.toList(),
      'tracking_actif': _isTracking,
      'heures_activite': '${_startTime.hour}h-${_endTime.hour}h',
      'debut_tracking': _trackingStartTime?.toIso8601String(),
    };
  }

  void dispose() {
    stopTracking();
  }
}
