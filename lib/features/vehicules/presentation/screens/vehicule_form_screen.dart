import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Formulaire de création d'un véhicule
class VehiculeFormScreen extends ConsumerStatefulWidget {
  const VehiculeFormScreen({super.key});

  @override
  ConsumerState<VehiculeFormScreen> createState() => _VehiculeFormScreenState();
}

class _VehiculeFormScreenState extends ConsumerState<VehiculeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plaqueCtrl = TextEditingController();
  final _marqueCtrl = TextEditingController();
  final _immatCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();

  String _type = 'moto';
  DateTime? _dateAchat;
  DateTime? _dateMiseCirculation;
  bool _isSaving = false;

  @override
  void dispose() {
    _plaqueCtrl.dispose();
    _marqueCtrl.dispose();
    _immatCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, {required bool isMiseCirculation}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isMiseCirculation) {
          _dateMiseCirculation = picked;
        } else {
          _dateAchat = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/vehicules', data: {
        'type': _type,
        'plaque': _plaqueCtrl.text.trim().toUpperCase(),
        'prix_achat': double.parse(_prixCtrl.text),
        'date_achat': _dateAchat?.toIso8601String().split('T').first,
        'date_mise_circulation': _dateMiseCirculation?.toIso8601String().split('T').first,
        'marque': _marqueCtrl.text.trim().isNotEmpty ? _marqueCtrl.text.trim() : null,
        'immatriculation': _immatCtrl.text.trim().isNotEmpty ? _immatCtrl.text.trim() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Véhicule créé avec succès'), backgroundColor: AppTheme.successColor),
        );
        context.pop();
      }
    } catch (e) {
      AppLogger.e('[VehiculeForm] Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau véhicule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Type ──
            const Text('Type de véhicule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip('moto', 'Moto', Icons.two_wheeler),
                const SizedBox(width: 12),
                _typeChip('voiture', 'Voiture', Icons.directions_car),
              ],
            ),
            const SizedBox(height: 20),

            // ── Plaque ──
            TextFormField(
              controller: _plaqueCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration('Plaque d\'immatriculation', Icons.badge),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Marque ──
            TextFormField(
              controller: _marqueCtrl,
              decoration: _inputDecoration('Marque (ex: Honda, Toyota)', Icons.label),
            ),
            const SizedBox(height: 16),

            // ── Prix d'achat ──
            TextFormField(
              controller: _prixCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Prix d\'achat (FCFA)', Icons.attach_money),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                if (double.tryParse(v) == null) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Date d'achat ──
            _buildDateField(
              label: 'Date d\'achat',
              value: _dateAchat,
              onTap: () => _selectDate(context, isMiseCirculation: false),
            ),
            const SizedBox(height: 16),

            // ── Date mise en circulation ──
            _buildDateField(
              label: 'Date de mise en circulation',
              value: _dateMiseCirculation,
              onTap: () => _selectDate(context, isMiseCirculation: true),
            ),
            const SizedBox(height: 16),

            // ── Immatriculation ──
            TextFormField(
              controller: _immatCtrl,
              decoration: _inputDecoration('N° immatriculation', Icons.confirmation_number),
            ),
            const SizedBox(height: 32),

            // ── Bouton ──
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Enregistrement...' : 'Créer le véhicule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.successColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.successColor : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, DateTime? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label, Icons.calendar_today),
        child: Text(
          value != null ? '${value.day}/${value.month}/${value.year}' : 'Sélectionner une date',
          style: TextStyle(color: value != null ? Colors.black87 : Colors.grey.shade500),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
    );
  }
}
