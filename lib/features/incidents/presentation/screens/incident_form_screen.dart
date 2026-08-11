import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/incidents/presentation/incidents_provider.dart';
import 'package:motoprojet/features/vehicules/presentation/vehicules_provider.dart';

/// ─── Formulaire complet de signalement d'incident ──────────────────────────
/// Supporte: caméra/galerie, compression, multi-photos, sévérité, lieu.
class IncidentFormScreen extends ConsumerStatefulWidget {
  /// Véhicule pré-sélectionné (optionnel, depuis la fiche véhicule)
  final String? preselectedVehiculeId;

  const IncidentFormScreen({super.key, this.preselectedVehiculeId});

  @override
  ConsumerState<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends ConsumerState<IncidentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _photos = <File>[];
  final _descriptionController = TextEditingController();
  final _lieuController = TextEditingController();
  final _coutController = TextEditingController();

  String? _vehiculeId;
  String _typeIncident = 'panne';
  String _severity = 'moyenne';
  bool _isSubmitting = false;

  // GPS
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _vehiculeId = widget.preselectedVehiculeId;
    // Charger les véhicules pour le sélecteur
    Future.microtask(() => ref.read(vehiculesListProvider.notifier).loadVehicules());
    // Détecter automatiquement la position GPS
    _detectLocation();
  }

  /// Détection automatique du GPS (latitude/longitude)
  Future<void> _detectLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });
    try {
      // Vérifier les permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isGettingLocation = false;
          _locationError = 'Service de localisation désactivé';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isGettingLocation = false;
            _locationError = 'Permission de localisation refusée';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isGettingLocation = false;
          _locationError = 'Permission de localisation refusée définitivement';
        });
        return;
      }

      // Obtenir la position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
        _locationError = 'Erreur GPS: $e';
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _lieuController.dispose();
    _coutController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null && _photos.length < 5) {
        setState(() => _photos.add(File(image.path)));
      } else if (_photos.length >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 photos')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur sélection photo: $e');
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Ajouter une photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Ouvrir la caméra'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.secondaryColor),
              title: const Text('Choisir depuis la galerie'),
              subtitle: const Text('Sélectionner une image'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiculesState = ref.watch(vehiculesListProvider);
    final vehicules = vehiculesState.vehicules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un incident'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Type d'incident ──
            const Text('Type d\'incident',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _typeCard('panne', 'Panne', Icons.build, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _typeCard('accident', 'Accident', Icons.car_crash, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _typeCard('vol', 'Vol', Icons.gpp_bad, Colors.purple)),
            ]),

            const SizedBox(height: 20),

            // ── Véhicule ──
            const Text('Véhicule concerné',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _vehiculeId,
              decoration: _inputDecoration('Sélectionner un véhicule', Icons.directions_car),
              items: vehicules.map((v) => DropdownMenuItem(
                value: v.id,
                child: Text('${v.plaque} (${v.isMoto ? 'Moto' : 'Voiture'})'),
              )).toList(),
              onChanged: (v) => setState(() => _vehiculeId = v),
              validator: (v) => v == null ? 'Sélectionnez un véhicule' : null,
            ),

            const SizedBox(height: 20),

            // ── Sévérité ──
            const Text('Sévérité',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _severityChip('legere', 'Légère', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _severityChip('moyenne', 'Moyenne', Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _severityChip('grave', 'Grave', Colors.red)),
            ]),

            const SizedBox(height: 20),

            // ── Lieu ──
            TextFormField(
              controller: _lieuController,
              decoration: _inputDecoration('Lieu de l\'incident', Icons.location_on,
                  hint: 'Ex: Carrefour Dantokpa, Cotonou'),
              validator: (v) => v == null || v.isEmpty ? 'Veuillez indiquer le lieu' : null,
            ),

            const SizedBox(height: 8),

            // ── GPS automatique ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _latitude != null
                    ? Colors.green.withOpacity(0.08)
                    : _locationError != null
                        ? Colors.red.withOpacity(0.08)
                        : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _latitude != null
                      ? Colors.green.withOpacity(0.3)
                      : _locationError != null
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  if (_isGettingLocation)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _latitude != null ? Icons.gps_fixed : (_locationError != null ? Icons.gps_off : Icons.location_searching),
                      size: 20,
                      color: _latitude != null ? Colors.green : (_locationError != null ? Colors.red : Colors.blue),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isGettingLocation
                          ? 'D\u00e9tection GPS en cours...'
                          : _latitude != null
                              ? 'GPS : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                              : _locationError ?? 'Localisation en cours...',
                      style: TextStyle(
                        fontSize: 12,
                        color: _latitude != null ? Colors.green.shade800 : (_locationError != null ? Colors.red.shade800 : Colors.blue.shade800),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_locationError != null)
                    GestureDetector(
                      onTap: _detectLocation,
                      child: const Icon(Icons.refresh, size: 20, color: Colors.blue),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Description ──
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration('Description', Icons.description,
                  hint: 'Décrivez ce qui s\'est passé...').copyWith(alignLabelWithHint: true),
              validator: (v) => v == null || v.length < 10 ? 'Minimum 10 caractères' : null,
            ),

            const SizedBox(height: 20),

            // ── Photos ──
            const Text('Photos *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Au moins une photo obligatoire — jusqu\u00e0 5 photos — compress\u00e9es automatiquement',
                style: TextStyle(fontSize: 11, color: _photos.isEmpty ? Colors.red.shade700 : AppTheme.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Bouton ajouter
                  GestureDetector(
                    onTap: _showPhotoSourceSheet,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 28, color: Colors.grey.shade400),
                          const SizedBox(height: 4),
                          Text('Photo', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                  // Photos sélectionnées
                  ..._photos.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                          ),
                          // Bouton supprimer
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(entry.key)),
                              child: Container(
                                width: 24, height: 24,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Coût estimé (optionnel) ──
            TextFormField(
              controller: _coutController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Coût estimé (optionnel)', Icons.payments,
                  hint: 'Ex: 50000'),
            ),

            const SizedBox(height: 24),

            // ── Bouton Envoyer ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Envoi en cours...' : 'Signaler l\'incident'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Note informative ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppTheme.secondaryColor),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Un véhicule en incident est temporairement exclu du calcul du taux de recouvrement.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _typeCard(String value, String label, IconData icon, Color color) {
    final isSelected = _typeIncident == value;
    return GestureDetector(
      onTap: () => setState(() => _typeIncident = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey)),
        ]),
      ),
    );
  }

  Widget _severityChip(String value, String label, Color color) {
    final isSelected = _severity == value;
    return GestureDetector(
      onTap: () => setState(() => _severity = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation : au moins une photo obligatoire
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Au moins une photo est obligatoire pour signaler un incident'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation : GPS obligatoire
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationError ?? 'Les coordonnées GPS sont obligatoires. Veuillez réessayer.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ref.read(incidentsProvider.notifier).createIncident(
      vehiculeId: _vehiculeId!,
      type: _typeIncident,
      severity: _severity,
      lieu: _lieuController.text,
      description: _descriptionController.text,
      latitude: _latitude!,
      longitude: _longitude!,
      photos: _photos,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident signalé — le véhicule est temporairement exclu du calcul'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${ref.read(incidentsProvider).error ?? "inconnue"}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}


