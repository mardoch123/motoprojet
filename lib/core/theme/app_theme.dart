import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DESIGN SYSTEM — MotoProjet
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Conçu pour un usage terrain au Bénin :
/// - Lisibilité en plein soleil (contraste élevé)
/// - Saisie au pouce (cibles tactiles ≥ 48 px)
/// - Connexion lente (pas d'animations lourdes)
/// - Utilisateurs pressés (hiérarchie visuelle claire)
///
/// ─── TOKENS ────────────────────────────────────────────────────────────────
/// Les tokens sont les valeurs atomiques du design system.
/// Ils ne doivent JAMAIS être contournés dans les écrans.
///
/// Usage :
///   AppColors.statusSuccess  // vert = à jour
///   AppSpacing.md            // 16 px
///   AppRadius.card           // 16 px
///   AppTypography.headingLg  // TextStyle pour titre de section
/// ═══════════════════════════════════════════════════════════════════════════

// ─── Palette de couleurs ─────────────────────────────────────────────────────
///
/// Règles sémantiques :
///   • Vert   = à jour / succès / positif
///   • Orange = retard léger / avertissement
///   • Rouge  = défaut / erreur / critique
///   • Bleu   = information / en cours
///
/// Chaque couleur a une variante `Subtle` (fond très clair)
/// pour les badges et les cartes de statut.
///
class AppColors {
  AppColors._();

  // ─── Marque — Premium Teal ─────────────────────────────────────────────
  static const Color brandGreen      = Color(0xFF00897B); // Teal — primaire premium
  static const Color brandGreenLight = Color(0xFF26A69A); // Teal clair
  static const Color brandGreenDark  = Color(0xFF00695C); // Teal foncé (accent)
  static const Color brandAmber      = Color(0xFFF57C00); // Orange profond — secondaire
  static const Color brandAmberLight = Color(0xFFFFB74D); // Orange clair

  // ─── Statuts (sémantique universelle) ────────────────────────────────────
  /// À jour, paiement effectué, objectif atteint
  static const Color statusSuccess       = Color(0xFF2E7D32);
  static const Color statusSuccessSubtle = Color(0xFFE8F5E9);
  static const Color statusSuccessOn     = Color(0xFFFFFFFF);

  /// Retard léger, en attente, attention
  static const Color statusWarning       = Color(0xFFEF6C00);
  static const Color statusWarningSubtle = Color(0xFFFFF3E0);
  static const Color statusWarningOn     = Color(0xFFFFFFFF);

  /// Défaut, impayé, critique, erreur
  static const Color statusError         = Color(0xFFD32F2F);
  static const Color statusErrorSubtle   = Color(0xFFFFEBEE);
  static const Color statusErrorOn       = Color(0xFFFFFFFF);

  /// Information, en cours, neutre actif
  static const Color statusInfo          = Color(0xFF1976D2);
  static const Color statusInfoSubtle    = Color(0xFFE3F2FD);
  static const Color statusInfoOn        = Color(0xFFFFFFFF);

  // ─── Surfaces — Thème clair (premium) ──────────────────────────────────
  static const Color surfaceLight        = Color(0xFFFFFFFF);
  static const Color surfaceLightVariant = Color(0xFFF7F9FC); // gris-bleu très clair
  static const Color backgroundLight     = Color(0xFFF5F7FA); // fond général premium
  static const Color dividerLight        = Color(0xFFE8ECF0);

  // ─── Surfaces — Thème sombre ─────────────────────────────────────────────
  static const Color surfaceDark         = Color(0xFF1E1E1E);
  static const Color surfaceDarkVariant  = Color(0xFF2A2A2A);
  static const Color backgroundDark      = Color(0xFF121212);
  static const Color dividerDark         = Color(0xFF3A3A3A);

  // ─── Textes — Thème clair ────────────────────────────────────────────────
  static const Color textPrimaryLight    = Color(0xFF1A2332); // Bleu-gris très foncé
  static const Color textSecondaryLight  = Color(0xFF5F6B7A); // Gris-bleu moyen
  static const Color textTertiaryLight   = Color(0xFF94A3B8); // Gris clair
  static const Color textOnBrandLight    = Color(0xFFFFFFFF);

  // ─── Textes — Thème sombre ───────────────────────────────────────────────
  static const Color textPrimaryDark     = Color(0xFFE8E8E8);
  static const Color textSecondaryDark   = Color(0xFFB0B0B0);
  static const Color textTertiaryDark    = Color(0xFF757575);
  static const Color textOnBrandDark     = Color(0xFFFFFFFF);

  // ─── Utilitaires ─────────────────────────────────────────────────────────
  static const Color overlay40 = Color(0x66000000); // 40% noir
  static const Color overlay20 = Color(0x33000000); // 20% noir
  static const Color scrim     = Color(0x99000000); // 60% noir (scrim modal)
}

// ─── Espacements ─────────────────────────────────────────────────────────────
///
/// Échelle en paliers de 4 px. Toujours utiliser ces tokens
/// plutôt que des valeurs magiques dans les écrans.
///
class AppSpacing {
  AppSpacing._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  /// Padding horizontal standard d'un écran
  static const double screenPaddingH = 16.0;

  /// Espacement vertical entre sections
  static const double sectionGap = 20.0;

  /// Espacement vertical entre éléments d'une carte
  static const double cardInnerGap = 12.0;

  /// Espacement entre deux cartes adjacentes
  static const double cardGap = 12.0;
}

// ─── Rayons de bordure ───────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double chip   = 8.0;
  static const double card   = 16.0;
  static const double button = 12.0;
  static const double input  = 12.0;
  static const double badge  = 20.0;
  static const double circle = 999.0;
}

// ─── Ombres ──────────────────────────────────────────────────────────────────
///
/// Ombres subtiles, pas de drop shadows lourds.
/// En dark mode, on réduit encore l'élévation.
///
class AppShadows {
  AppShadows._();

  /// Ombre subtile pour cartes — effet flottant premium
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000), // 5% noir
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000), // 3% noir
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Ombre élevée pour cartes interactives / modales
  static const List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Color(0x14000000), // 8% noir
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% noir
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Ombre subtile pour AppBar
  static const List<BoxShadow> appBar = [
    BoxShadow(
      color: Color(0x0A000000), // 4% noir
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> none = [];
}

// ─── Typographie ─────────────────────────────────────────────────────────────
///
/// Hiérarchie premium — élégance et lisibilité :
/// - Titres en FontWeight.w700 (Bold) pour un look premium
/// - Corps de texte en w400 (Regular) pour la légèreté
/// - Tailles en paliers clairs : 12 / 14 / 16 / 20 / 26 / 32
///
class AppTypography {
  AppTypography._();

  // ─── Titres ──────────────────────────────────────────────────────────────
  static const TextStyle displayLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle headingXl = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle headingLg = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static const TextStyle headingMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // ─── Corps ───────────────────────────────────────────────────────────────
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─── Chiffres (KPI, montants) ────────────────────────────────────────────
  /// Chiffre KPI grand format — utilisé dans les cartes dashboard
  static const TextStyle kpiValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Chiffre KPI compact
  static const TextStyle kpiValueCompact = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Montant dans un champ de saisie
  static const TextStyle montantInput = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.3,
  );

  // ─── Labels ──────────────────────────────────────────────────────────────
  static const TextStyle labelMd = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.3,
  );

  /// Label tout-caps pour en-têtes de section
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 1.0,
  );
}

// ─── Tailles tactiles ────────────────────────────────────────────────────────
///
/// Tailles minimales des zones tactiles pour une utilisation au pouce.
/// Recommandation Material : 48×48 px minimum.
///
class AppTouch {
  AppTouch._();

  static const double minTarget = 48.0;
  static const double comfortableTarget = 56.0;
  static const double largeTarget = 64.0;
}

// ─── Thème Material ──────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ─── Couleurs legacy (rétrocompatibilité) ────────────────────────────────
  // TODO: migrer progressivement vers AppColors.*
  static const Color primaryColor    = AppColors.brandGreen;
  static const Color secondaryColor  = AppColors.brandAmber;
  static const Color errorColor      = AppColors.statusError;
  static const Color successColor    = AppColors.statusSuccess;
  static const Color warningColor    = AppColors.statusWarning;
  static const Color backgroundColor = AppColors.backgroundLight;
  static const Color surfaceColor    = AppColors.surfaceLight;
  static const Color textPrimary     = AppColors.textPrimaryLight;
  static const Color textSecondary   = AppColors.textSecondaryLight;

  // ═════════════════════════════════════════════════════════════════════════
  // THÈME CLAIR
  // ═════════════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandGreen,
      secondary: AppColors.brandAmber,
      error: AppColors.statusError,
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // ─── AppBar — Blanc premium avec ombre subtile ─────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppColors.textPrimaryLight,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // ─── Cartes — Blanches avec ombres douces ─────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        shadowColor: const Color(0x0D000000),
        surfaceTintColor: Colors.transparent,
      ),

      // ─── Boutons ───────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: AppColors.textOnBrandLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandGreen,
          side: const BorderSide(color: AppColors.brandGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, AppTouch.minTarget),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ─── Champs de saisie ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dividerLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dividerLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.statusError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.statusError, width: 2),
        ),
        labelStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textTertiaryLight),
        errorStyle: AppTypography.bodySm.copyWith(color: AppColors.statusError),
      ),

      // ─── Navigation inférieure ─────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.brandGreen,
        unselectedItemColor: AppColors.textTertiaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),

      // ─── Onglets ────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.brandGreen,
        unselectedLabelColor: AppColors.textSecondaryLight,
        indicatorColor: AppColors.brandGreen,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),

      // ─── Chips ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLightVariant,
        selectedColor: AppColors.statusSuccessSubtle,
        disabledColor: AppColors.surfaceLightVariant,
        labelStyle: AppTypography.bodySm,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        side: const BorderSide(color: AppColors.dividerLight),
      ),

      // ─── Dividers ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // ─── Snackbar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.textOnBrandLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Dialog ─────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        titleTextStyle: AppTypography.headingLg.copyWith(color: AppColors.textPrimaryLight),
        contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
      ),

      // ─── Bottom Sheet ───────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.dividerLight,
      ),

      // ─── Progress indicators ────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandGreen,
        linearTrackColor: AppColors.dividerLight,
        circularTrackColor: AppColors.dividerLight,
      ),

      // ─── Thème de texte global ──────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLg,
        headlineLarge: AppTypography.headingXl,
        headlineMedium: AppTypography.headingLg,
        titleLarge: AppTypography.headingMd,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelLarge: AppTypography.labelMd,
        labelSmall: AppTypography.labelSm,
      ).apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // THÈME SOMBRE
  // ═════════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandGreen,
      secondary: AppColors.brandAmberLight,
      error: AppColors.statusError,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        surfaceTintColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreenLight,
          foregroundColor: AppColors.textOnBrandDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandGreenLight,
          side: const BorderSide(color: AppColors.brandGreenLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dividerDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dividerDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.brandGreenLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.statusError, width: 1.5),
        ),
        labelStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.textSecondaryDark,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textTertiaryDark),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.brandGreenLight,
        unselectedItemColor: AppColors.textTertiaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDarkVariant,
        contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        titleTextStyle: AppTypography.headingLg.copyWith(color: AppColors.textPrimaryDark),
        contentTextStyle: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryDark),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.dividerDark,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandGreenLight,
        linearTrackColor: AppColors.dividerDark,
        circularTrackColor: AppColors.dividerDark,
      ),

      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLg,
        headlineLarge: AppTypography.headingXl,
        headlineMedium: AppTypography.headingLg,
        titleLarge: AppTypography.headingMd,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelLarge: AppTypography.labelMd,
        labelSmall: AppTypography.labelSm,
      ).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // THÈME CONTRASTE RENFORCÉ — CLAIR
  // ═════════════════════════════════════════════════════════════════════════
  ///
  /// Optimisé pour la lisibilité en plein soleil et les utilisateurs
  /// ayant des difficultés visuelles. Contrastes WCAG AAA.
  ///
  static ThemeData get highContrastLightTheme {
    final base = lightTheme;
    return base.copyWith(
      // Couleurs à très haut contraste
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        secondary: AppColors.brandAmber,
        error: AppColors.statusError,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        iconTheme: IconThemeData(color: Colors.black),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black),
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black),
        labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 3),
        ),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // THÈME CONTRASTE RENFORCÉ — SOMBRE
  // ═════════════════════════════════════════════════════════════════════════
  static ThemeData get highContrastDarkTheme {
    final base = darkTheme;
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        secondary: AppColors.brandAmberLight,
        error: AppColors.statusError,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreenLight,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          minimumSize: const Size(0, AppTouch.minTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.brandGreenLight, width: 3),
        ),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
      ),
    );
  }
}
