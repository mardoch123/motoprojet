import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/features/chauffeurs/presentation/chauffeurs_provider.dart';

/// Formulaire multi-étapes pour créer/modifier un chauffeur.
/// 4 étapes courtes : Identité → Documents → Contact → Objectif
class ChauffeurFormScreen extends ConsumerStatefulWidget {
  final String? chauffeurId; // null = création
  const ChauffeurFormScreen({super.key, this.chauffeurId});

  @override
  ConsumerState<ChauffeurFormScreen> createState() => _ChauffeurFormScreenState();
}

class _ChauffeurFormScreenState extends ConsumerState<ChauffeurFormScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // ── Controllers ──
  final _nomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pieceCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _contactUrgenceCtrl = TextEditingController();
  final _objectifCtrl = TextEditingController();

  File? _photoFile;
  File? _pieceFile;
  String? _photoUrl;
  String? _pieceUrl;

  final _picker = ImagePicker();
  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  bool get isEdit => widget.chauffeurId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    final notifier = ref.read(chauffeurDetailProvider.notifier);
    await notifier.loadDetail(widget.chauffeurId!);
    final data = ref.read(chauffeurDetailProvider).data;
    if (data != null && mounted) {
      _nomCtrl.text = data['nom']?.toString() ?? '';
      _pieceCtrl.text = data['piece_identite']?.toString() ?? '';
      _adresseCtrl.text = data['adresse']?.toString() ?? '';
      _contactUrgenceCtrl.text = data['contact_urgence']?.toString() ?? '';
      _objectifCtrl.text = (data['objectif_journalier'] ?? 0).toString();
      _photoUrl = data['photo_url']?.toString();
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _pinCtrl.dispose();
    _pieceCtrl.dispose();
    _adresseCtrl.dispose();
    _contactUrgenceCtrl.dispose();
    _objectifCtrl.dispose();
    super.dispose();
  }

  // ── Étape suivante / précédente ────────────────────────────────────────────
  void _nextStep() {
    final form = _formKeys[_currentStep].currentState;
    if (form != null && !form.validate()) return;

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ── Photo picker ───────────────────────────────────────────────────────────
  Future<void> _pickPhoto({bool isPiece = false}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir de la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (image == null) return;

    setState(() {
      if (isPiece) {
        _pieceFile = File(image.path);
      } else {
        _photoFile = File(image.path);
      }
    });
  }

  // ── Upload photo vers R2/S3 ───────────────────────────────────────────────
  Future<String?> _uploadPhoto(File file, String filename) async {
    try {
      final client = ref.read(apiClientProvider);
      final contentType = 'image/jpeg';

      // 1. Demander une URL signée
      final presignResp = await client.post('/upload/presign', data: {
        'filename': filename,
        'contentType': contentType,
      });
      final presignData = presignResp.data as Map<String, dynamic>;
      final uploadUrl = presignData['upload_url']?.toString();
      final publicUrl = presignData['public_url']?.toString();

      if (uploadUrl == null || publicUrl == null) return null;

      // 2. Upload direct vers le stockage (simulé en dev)
      // En production, on utiliserait Dio pour PUT le fichier vers uploadUrl
      // Pour l'instant on retourne la public_url
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  // ── Soumission ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // Upload photos si nécessaire
    if (_photoFile != null) {
      _photoUrl = await _uploadPhoto(_photoFile!, 'chauffeur-photo.jpg');
    }
    if (_pieceFile != null) {
      _pieceUrl = await _uploadPhoto(_pieceFile!, 'piece-identite.jpg');
    }

    final data = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'piece_identite': _pieceCtrl.text.trim().isNotEmpty ? _pieceCtrl.text.trim() : null,
      'adresse': _adresseCtrl.text.trim().isNotEmpty ? _adresseCtrl.text.trim() : null,
      'contact_urgence': _contactUrgenceCtrl.text.trim().isNotEmpty ? _contactUrgenceCtrl.text.trim() : null,
      'objectif_journalier': double.tryParse(_objectifCtrl.text) ?? 0,
    };

    if (_photoUrl != null) data['photo_url'] = _photoUrl;
    if (_pieceUrl != null) data['piece_identite'] = _pieceUrl;

    bool success;
    if (isEdit) {
      success = await ref.read(chauffeurDetailProvider.notifier).updateChauffeur(widget.chauffeurId!, data);
    } else {
      data['telephone'] = _telephoneCtrl.text.trim();
      data['pin'] = _pinCtrl.text.trim();
      success = await ref.read(chauffeurDetailProvider.notifier).createChauffeur(data);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        // Recharger la liste
        ref.read(chauffeursListProvider.notifier).loadChauffeurs();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Chauffeur modifié' : 'Chauffeur créé'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier chauffeur' : 'Nouveau chauffeur'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Stepper indicator ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(4, (i) {
                final isActive = i == _currentStep;
                final isDone = i < _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.primaryColor
                          : isActive
                              ? AppTheme.primaryColor.withValues(alpha: 0.5)
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Step title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${_currentStep + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _stepTitles[_currentStep],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Step content ──
          Expanded(
            child: Form(
              key: _formKeys[_currentStep],
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _buildStepContent(),
              ),
            ),
          ),

          // ── Navigation buttons ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _prevStep,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Précédent', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: _currentStep == 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _currentStep == 3 ? (isEdit ? 'Enregistrer' : 'Créer') : 'Suivant',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final _stepTitles = ['Identité', 'Documents', 'Contact', 'Objectif'];

  List<Widget> _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepIdentite();
      case 1:
        return _buildStepDocuments();
      case 2:
        return _buildStepContact();
      case 3:
        return _buildStepObjectif();
      default:
        return [];
    }
  }

  // ── Étape 1 : Identité ─────────────────────────────────────────────────────
  List<Widget> _buildStepIdentite() {
    return [
      const SizedBox(height: 8),
      const Text(
        'Informations de connexion du chauffeur',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: _nomCtrl,
        label: 'Nom complet',
        hint: 'Ex: Kouadio Jean',
        icon: Icons.person,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
      ),
      if (!isEdit) ...[
        const SizedBox(height: 16),
        _buildTextField(
          controller: _telephoneCtrl,
          label: 'Numéro de téléphone',
          hint: 'Ex: +229 97 00 00 00',
          icon: Icons.phone,
          keyboard: TextInputType.phone,
          validator: (v) => (v == null || v.length < 8) ? 'Numéro trop court' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _pinCtrl,
          label: 'Code PIN temporaire',
          hint: '4 à 6 chiffres',
          icon: Icons.lock,
          keyboard: TextInputType.number,
          isObscured: true,
          validator: (v) => (v == null || v.length < 4 || v.length > 6) ? 'PIN : 4-6 chiffres' : null,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Le chauffeur devra changer son PIN à la première connexion',
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  // ── Étape 2 : Documents ────────────────────────────────────────────────────
  List<Widget> _buildStepDocuments() {
    return [
      const SizedBox(height: 8),
      const Text(
        'Pièce d\'identité et photo du chauffeur',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: _pieceCtrl,
        label: 'N° Pièce d\'identité',
        hint: 'Ex: CNI-123456',
        icon: Icons.badge,
      ),
      const SizedBox(height: 16),

      // Photo chauffeur
      const Text('Photo du chauffeur', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _pickPhoto(isPiece: false),
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: _photoFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_photoFile!, fit: BoxFit.cover),
                )
              : _photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_photoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const _PhotoPlaceholder(icon: Icons.person, label: 'Photo chauffeur')),
                    )
                  : const _PhotoPlaceholder(icon: Icons.person, label: 'Photo chauffeur'),
        ),
      ),
      const SizedBox(height: 24),

      // Photo pièce d'identité
      const Text('Photo pièce d\'identité', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _pickPhoto(isPiece: true),
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: _pieceFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_pieceFile!, fit: BoxFit.cover),
                )
              : const _PhotoPlaceholder(icon: Icons.badge, label: 'Photo pièce d\'identité'),
        ),
      ),
    ];
  }

  // ── Étape 3 : Contact ──────────────────────────────────────────────────────
  List<Widget> _buildStepContact() {
    return [
      const SizedBox(height: 8),
      const Text(
        'Adresse et personne à contacter en cas d\'urgence',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: _adresseCtrl,
        label: 'Adresse',
        hint: 'Quartier, ville…',
        icon: Icons.home,
        maxLines: 2,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _contactUrgenceCtrl,
        label: 'Contact d\'urgence',
        hint: 'Nom + numéro (Ex: Marie +229 95 00 00 00)',
        icon: Icons.emergency,
      ),
    ];
  }

  // ── Étape 4 : Objectif ─────────────────────────────────────────────────────
  List<Widget> _buildStepObjectif() {
    return [
      const SizedBox(height: 8),
      const Text(
        'Revenu net visé par jour après remboursement',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: _objectifCtrl,
        label: 'Objectif journalier (F CFA)',
        hint: 'Ex: 5000',
        icon: Icons.flag,
        keyboard: TextInputType.number,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _recapRow('Nom', _nomCtrl.text),
            if (!isEdit) _recapRow('Téléphone', _telephoneCtrl.text),
            _recapRow('Adresse', _adresseCtrl.text.isNotEmpty ? _adresseCtrl.text : '—'),
            _recapRow('Contact urgence', _contactUrgenceCtrl.text.isNotEmpty ? _contactUrgenceCtrl.text : '—'),
            _recapRow('Objectif/jour', '${_objectifCtrl.text.isNotEmpty ? _objectifCtrl.text : '0'} F'),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    bool isObscured = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: isObscured,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PhotoPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Appuyer pour ajouter', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ],
    );
  }
}
