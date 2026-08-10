import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:motoprojet/core/network/providers.dart';

/// ─── Modèle Incident ────────────────────────────────────────────────────────
class IncidentModel {
  final String id;
  final String vehiculeId;
  final String? vehiculePlaque;
  final String? vehiculeType;
  final String? chauffeurNom;
  final String type; // panne, accident, vol
  final String? description;
  final String? photoUrl;
  final List<String> photoUrls;
  final String severity; // legere, moyenne, grave
  final String? lieu;
  final double cout;
  final String date;
  final String statut; // signale, en_cours, resolu, classe_sans_suite
  final String statutReparation; // en_attente, en_cours, termine
  final double coutReparation;
  final String? dateRemiseEnService;
  final String? declaredBy;

  const IncidentModel({
    required this.id,
    required this.vehiculeId,
    this.vehiculePlaque,
    this.vehiculeType,
    this.chauffeurNom,
    required this.type,
    this.description,
    this.photoUrl,
    this.photoUrls = const [],
    this.severity = 'moyenne',
    this.lieu,
    this.cout = 0,
    required this.date,
    this.statut = 'signale',
    this.statutReparation = 'en_attente',
    this.coutReparation = 0,
    this.dateRemiseEnService,
    this.declaredBy,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      vehiculeId: json['vehicule_id']?.toString() ?? '',
      vehiculePlaque: json['vehicule_plaque']?.toString(),
      vehiculeType: json['vehicule_type']?.toString(),
      chauffeurNom: json['chauffeur_nom']?.toString(),
      type: json['type']?.toString() ?? 'panne',
      description: json['description']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      severity: json['severity']?.toString() ?? 'moyenne',
      lieu: json['lieu']?.toString(),
      cout: (json['cout'] as num?)?.toDouble() ?? 0,
      date: json['date']?.toString().substring(0, 10) ?? '',
      statut: json['statut']?.toString() ?? 'signale',
      statutReparation: json['statut_reparation']?.toString() ?? 'en_attente',
      coutReparation: (json['cout_reparation'] as num?)?.toDouble() ?? 0,
      dateRemiseEnService: json['date_remise_en_service']?.toString(),
      declaredBy: json['declared_by']?.toString(),
    );
  }

  bool get isActive => statut != 'resolu' && statut != 'classe_sans_suite';
  bool get isResolved => statut == 'resolu';

  String get typeLabel => switch (type) {
    'panne' => 'Panne',
    'accident' => 'Accident',
    'vol' => 'Vol',
    _ => type,
  };

  String get severityLabel => switch (severity) {
    'legere' => 'Légère',
    'moyenne' => 'Moyenne',
    'grave' => 'Grave',
    _ => severity,
  };

  String get statutReparationLabel => switch (statutReparation) {
    'en_attente' => 'En attente',
    'en_cours' => 'En cours',
    'termine' => 'Terminée',
    _ => statutReparation,
  };
}

/// ─── État ───────────────────────────────────────────────────────────────────
class IncidentsState {
  final bool isLoading;
  final String? error;
  final List<IncidentModel> incidents;
  final List<IncidentModel> activeIncidents;

  const IncidentsState({
    this.isLoading = false,
    this.error,
    this.incidents = const [],
    this.activeIncidents = const [],
  });

  IncidentsState copyWith({
    bool? isLoading,
    String? error,
    List<IncidentModel>? incidents,
    List<IncidentModel>? activeIncidents,
    bool clearError = false,
  }) {
    return IncidentsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      incidents: incidents ?? this.incidents,
      activeIncidents: activeIncidents ?? this.activeIncidents,
    );
  }
}

/// ─── Notifier ───────────────────────────────────────────────────────────────
class IncidentsNotifier extends StateNotifier<IncidentsState> {
  final Ref ref;

  IncidentsNotifier(this.ref) : super(const IncidentsState());

  /// Charge la liste des incidents
  Future<void> loadIncidents({String? vehiculeId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final api = ref.read(apiClientProvider);
      final query = vehiculeId != null ? '?vehicule_id=$vehiculeId&limit=200' : '?limit=200';
      final response = await api.get('/incidents$query');
      final list = (response.data['data'] as List).map((j) => IncidentModel.fromJson(j)).toList();
      state = state.copyWith(isLoading: false, incidents: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Charge les incidents actifs
  Future<void> loadActiveIncidents() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/incidents/actifs');
      final list = (response.data['data'] as List).map((j) => IncidentModel.fromJson(j)).toList();
      state = state.copyWith(activeIncidents: list);
    } catch (_) {
      // Non critique
    }
  }

  /// Crée un incident avec photos compressées
  Future<IncidentModel?> createIncident({
    required String vehiculeId,
    required String type,
    required String severity,
    required String lieu,
    required String description,
    List<File> photos = const [],
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Compresser et uploader les photos
      final photoUrls = <String>[];
      for (final photo in photos) {
        final url = await _compressAndUpload(photo);
        if (url != null) photoUrls.add(url);
      }

      final api = ref.read(apiClientProvider);
      final response = await api.post('/incidents', data: {
        'vehicule_id': vehiculeId,
        'type': type,
        'severity': severity,
        'lieu': lieu,
        'description': description,
        'photo_urls': photoUrls,
        if (photoUrls.isNotEmpty) 'photo_url': photoUrls.first,
      });

      final incident = IncidentModel.fromJson(response.data['data'] as Map<String, dynamic>);
      await loadIncidents();
      return incident;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Met à jour le suivi de réparation d'un incident
  Future<bool> updateRepair({
    required String incidentId,
    String? statut,
    String? statutReparation,
    double? coutReparation,
    String? dateRemiseEnService,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/incidents/$incidentId', data: {
        if (statut != null) 'statut': statut,
        if (statutReparation != null) 'statut_reparation': statutReparation,
        if (coutReparation != null) 'cout_reparation': coutReparation,
        if (dateRemiseEnService != null) 'date_remise_en_service': dateRemiseEnService,
      });
      await loadIncidents();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Compresse une image et l'upload via presigned URL
  Future<String?> _compressAndUpload(File file) async {
    try {
      // Compression : max 800px, qualité 70%, format JPEG
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        '${file.absolute.path}_compressed.jpg',
        quality: 70,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;

      // Demander une URL signée
      final api = ref.read(apiClientProvider);
      final fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final presignResponse = await api.post('/upload/presign', data: {
        'filename': fileName,
        'contentType': 'image/jpeg',
      });

      final uploadUrl = presignResponse.data['data']['upload_url'] as String;
      final publicUrl = presignResponse.data['data']['public_url'] as String;
      final mode = presignResponse.data['data']['mode'];

      // Si mode mock (dev), retourner l'URL publique directement
      if (mode == 'mock') return publicUrl;

      // Upload du fichier compressé vers S3/R2
      final compressedFile = File(result.path);
      final bytes = await compressedFile.readAsBytes();

      final dio = Dio();
      await dio.put(
        uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': 'image/jpeg'}),
      );

      return publicUrl;
    } catch (e) {
      debugPrint('Erreur upload photo: $e');
      return null;
    }
  }
}

/// ─── Provider ───────────────────────────────────────────────────────────────
final incidentsProvider =
    StateNotifierProvider<IncidentsNotifier, IncidentsState>((ref) {
  return IncidentsNotifier(ref);
});
