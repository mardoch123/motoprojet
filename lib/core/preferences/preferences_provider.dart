import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PREFERENCES UTILISATEUR — Accessibilité & Personnalisation
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Gère :
/// - Taille de police (scale factor)
/// - Contraste renforcé (high contrast mode)
/// - Langue de l'application (locale)
///
/// Persistance via FlutterSecureStorage pour cohérence avec le reste du projet.
/// ═══════════════════════════════════════════════════════════════════════════

// ─── Constantes de stockage ──────────────────────────────────────────────────
const String _kFontScaleKey = 'font_scale';
const String _kHighContrastKey = 'high_contrast';
const String _kLocaleKey = 'locale';

// ─── Échelle de police ───────────────────────────────────────────────────────
///
/// Valeurs prédéfinies pour le slider de taille de police.
/// - Petit : 0.85x
/// - Normal : 1.0x (défaut)
/// - Grand : 1.15x
/// - Très grand : 1.3x
///
enum FontScaleOption {
  small(0.85, 'settingsFontSizeSmall'),
  normal(1.0, 'settingsFontSizeNormal'),
  large(1.15, 'settingsFontSizeLarge'),
  extraLarge(1.3, 'settingsFontSizeExtraLarge');

  const FontScaleOption(this.scale, this.labelKey);
  final double scale;
  final String labelKey;

  static FontScaleOption fromScale(double scale) {
    return FontScaleOption.values.firstWhere(
      (e) => e.scale == scale,
      orElse: () => FontScaleOption.normal,
    );
  }
}

// ─── State ───────────────────────────────────────────────────────────────────
class PreferencesState {
  final double fontScale;
  final bool highContrast;
  final Locale locale;
  final bool isLoading;

  const PreferencesState({
    this.fontScale = 1.0,
    this.highContrast = false,
    this.locale = const Locale('fr'),
    this.isLoading = true,
  });

  PreferencesState copyWith({
    double? fontScale,
    bool? highContrast,
    Locale? locale,
    bool? isLoading,
  }) {
    return PreferencesState(
      fontScale: fontScale ?? this.fontScale,
      highContrast: highContrast ?? this.highContrast,
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────
class PreferencesNotifier extends StateNotifier<PreferencesState> {
  PreferencesNotifier() : super(const PreferencesState()) {
    _loadFromStorage();
  }

  static const _storage = FlutterSecureStorage();

  Future<void> _loadFromStorage() async {
    try {
      final fontScaleStr = await _storage.read(key: _kFontScaleKey);
      final highContrastStr = await _storage.read(key: _kHighContrastKey);
      final localeStr = await _storage.read(key: _kLocaleKey);

      final fontScale = fontScaleStr != null ? double.tryParse(fontScaleStr) ?? 1.0 : 1.0;
      final highContrast = highContrastStr == 'true';
      final locale = localeStr != null ? Locale(localeStr) : const Locale('fr');

      state = PreferencesState(
        fontScale: fontScale,
        highContrast: highContrast,
        locale: locale,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale);
    await _storage.write(key: _kFontScaleKey, value: scale.toString());
  }

  Future<void> setHighContrast(bool enabled) async {
    state = state.copyWith(highContrast: enabled);
    await _storage.write(key: _kHighContrastKey, value: enabled.toString());
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _storage.write(key: _kLocaleKey, value: locale.languageCode);
  }

  Future<void> reset() async {
    state = const PreferencesState(isLoading: false);
    await _storage.delete(key: _kFontScaleKey);
    await _storage.delete(key: _kHighContrastKey);
    await _storage.delete(key: _kLocaleKey);
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
final preferencesProvider = StateNotifierProvider<PreferencesNotifier, PreferencesState>(
  (Ref ref) => PreferencesNotifier(),
);

// ─── Helpers d'accès rapide ──────────────────────────────────────────────────
final fontScaleProvider = Provider<double>((ref) {
  return ref.watch(preferencesProvider).fontScale;
});

final highContrastProvider = Provider<bool>((ref) {
  return ref.watch(preferencesProvider).highContrast;
});

final localeProvider = Provider<Locale>((ref) {
  return ref.watch(preferencesProvider).locale;
});
