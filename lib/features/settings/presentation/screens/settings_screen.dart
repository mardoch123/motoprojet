import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/l10n/generated/app_localizations.dart';
import 'package:motoprojet/core/preferences/preferences_provider.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ÉCRAN PARAMÈTRES — Accessibilité & Personnalisation
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Permet à l'utilisateur de :
/// - Ajuster la taille de police (4 niveaux)
/// - Activer le contraste renforcé
/// - Changer la langue de l'application
///
/// Accessibilité :
/// - Semantics sur chaque contrôle
/// - Labels descriptifs pour le lecteur d'écran
/// - Zones tactiles ≥ 48px
/// ═══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    final prefsNotifier = ref.read(preferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ─── APPARENCE ─────────────────────────────────────────────────
          _buildSectionHeader(context, l10n.settingsAppearance, Icons.palette),
          const SizedBox(height: 8),

          // Taille de police
          _buildFontSizeCard(context, ref, prefs.fontScale, prefsNotifier),
          const SizedBox(height: 12),

          // Contraste renforcé
          _buildHighContrastTile(context, prefs.highContrast, prefsNotifier, l10n),
          const SizedBox(height: 24),

          // ─── LANGUE ────────────────────────────────────────────────────
          _buildSectionHeader(context, l10n.settingsLanguage, Icons.language),
          const SizedBox(height: 8),
          _buildLanguageCard(context, prefs.locale, prefsNotifier, l10n),
          const SizedBox(height: 24),

          // ─── ACCESSIBILITÉ (info) ──────────────────────────────────────
          _buildSectionHeader(context, l10n.settingsAccessibility, Icons.accessibility),
          const SizedBox(height: 8),
          _buildAccessibilityInfoCard(context, l10n),
        ],
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.brandGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandGreen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Font Size Card ────────────────────────────────────────────────────────
  Widget _buildFontSizeCard(
    BuildContext context,
    WidgetRef ref,
    double currentScale,
    PreferencesNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final currentOption = FontScaleOption.fromScale(currentScale);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: l10n.settingsFontSize,
              child: Text(
                l10n.settingsFontSize,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Preview text
            Center(
              child: Text(
                'Aperçu du texte — ${_getScaleLabel(currentOption, l10n)}',
                style: TextStyle(
                  fontSize: 16 * currentScale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Slider avec 4 positions
            Semantics(
              label: l10n.settingsFontSize,
              value: _getScaleLabel(currentOption, l10n),
              child: Slider(
                value: currentOption.index.toDouble(),
                min: 0,
                max: FontScaleOption.values.length - 1,
                divisions: FontScaleOption.values.length - 1,
                onChanged: (value) {
                  final option = FontScaleOption.values[value.toInt()];
                  notifier.setFontScale(option.scale);
                },
              ),
            ),

            // Labels sous le slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: FontScaleOption.values.map((option) {
                  final isSelected = option == currentOption;
                  return Text(
                    _getScaleLabel(option, l10n),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? AppColors.brandGreen : AppColors.textSecondaryLight,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getScaleLabel(FontScaleOption option, AppLocalizations l10n) {
    return switch (option) {
      FontScaleOption.small => l10n.settingsFontSizeSmall,
      FontScaleOption.normal => l10n.settingsFontSizeNormal,
      FontScaleOption.large => l10n.settingsFontSizeLarge,
      FontScaleOption.extraLarge => l10n.settingsFontSizeExtraLarge,
    };
  }

  // ─── High Contrast Tile ────────────────────────────────────────────────────
  Widget _buildHighContrastTile(
    BuildContext context,
    bool isEnabled,
    PreferencesNotifier notifier,
    AppLocalizations l10n,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        label: l10n.settingsHighContrast,
        hint: l10n.settingsHighContrastDescription,
        toggled: isEnabled,
        child: SwitchListTile(
          title: Text(
            l10n.settingsHighContrast,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            l10n.settingsHighContrastDescription,
            style: const TextStyle(fontSize: 13),
          ),
          secondary: const Icon(Icons.contrast, color: AppColors.brandGreen),
          value: isEnabled,
          onChanged: (value) => notifier.setHighContrast(value),
          activeThumbColor: AppColors.brandGreen,
        ),
      ),
    );
  }

  // ─── Language Card ─────────────────────────────────────────────────────────
  Widget _buildLanguageCard(
    BuildContext context,
    Locale currentLocale,
    PreferencesNotifier notifier,
    AppLocalizations l10n,
  ) {
    final languages = [
      _LanguageOption(const Locale('fr'), l10n.settingsLanguageFrench, '🇫🇷'),
      _LanguageOption(const Locale('en'), l10n.settingsLanguageEnglish, '🇬🇧'),
      _LanguageOption(const Locale('fon'), l10n.settingsLanguageFon, '🇧🇯'),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: languages.map((lang) {
          final isSelected = currentLocale.languageCode == lang.locale.languageCode;
          return Semantics(
            label: lang.name,
            selected: isSelected,
            child: ListTile(
              leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
              title: Text(
                lang.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.brandGreen : null,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppColors.brandGreen, size: 24)
                  : null,
              onTap: () => notifier.setLocale(lang.locale),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Accessibility Info Card ───────────────────────────────────────────────
  Widget _buildAccessibilityInfoCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.statusInfo, size: 20),
                SizedBox(width: 8),
                Text(
                  'Accessibilité',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.record_voice_over, 'Lecteur d\'écran activé automatiquement'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.touch_app, 'Zones tactiles ≥ 48px pour navigation au pouce'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.text_fields, 'Taille de police ajustable ci-dessus'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.contrast, 'Contraste renforcé disponible'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondaryLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
          ),
        ),
      ],
    );
  }
}

class _LanguageOption {
  const _LanguageOption(this.locale, this.name, this.flag);
  final Locale locale;
  final String name;
  final String flag;
}
