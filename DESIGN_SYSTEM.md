# Design System — MotoProjet

> Conçu pour un usage terrain au Bénin : connexion lente, lisibilité en extérieur, saisie au pouce.

---

## Architecture des fichiers

```
lib/
├── core/
│   └── theme/
│       └── app_theme.dart          # Tokens + ThemeData (light/dark)
└── shared/
    └── widgets/
        ├── kpi_widgets.dart        # KpiCard, KpiCompact, GaugeProgress, MiniSparkline
        ├── status_badge.dart       # StatusBadge, StatusCountBadge
        ├── dual_progress_bar.dart  # DualProgressBar, SingleProgressBar
        ├── montant_field.dart      # MontantField, MontantDisplay
        └── primary_action_button.dart  # PrimaryActionButton, SecondaryActionButton
```

---

## Tokens de design

### Couleurs (`AppColors`)

| Token | Usage | Hex |
|-------|-------|-----|
| `brandGreen` | Couleur primaire, actions principales | `#1B5E20` |
| `brandAmber` | Couleur secondaire, accent | `#FF8F00` |
| `statusSuccess` | À jour, payé, validé | `#2E7D32` |
| `statusWarning` | Retard léger, en attente | `#E65100` |
| `statusError` | Défaut, impayé, critique | `#C62828` |
| `statusInfo` | Information, en cours | `#1565C0` |

**Règle sémantique** :
- **Vert** = à jour / succès / positif
- **Orange** = retard léger / avertissement
- **Rouge** = défaut / erreur / critique
- **Bleu** = information / en cours

### Espacements (`AppSpacing`)

| Token | Valeur | Usage |
|-------|--------|-------|
| `xs` | 4 px | Marges internes très serrées |
| `sm` | 8 px | Espacement entre éléments liés |
| `md` | 16 px | Padding standard, espacement inter-éléments |
| `lg` | 24 px | Espacement entre sections |
| `xl` | 32 px | Marges de page |
| `screenPaddingH` | 16 px | Padding horizontal des écrans |
| `sectionGap` | 20 px | Espacement vertical entre sections |
| `cardInnerGap` | 12 px | Espacement interne des cartes |
| `cardGap` | 12 px | Espacement entre cartes |

### Rayons de bordure (`AppRadius`)

| Token | Valeur | Usage |
|-------|--------|-------|
| `chip` | 8 px | Chips, tags |
| `button` | 12 px | Boutons |
| `input` | 12 px | Champs de saisie |
| `card` | 16 px | Cartes |
| `badge` | 20 px | Badges de statut |

### Typographie (`AppTypography`)

| Token | Taille | Poids | Usage |
|-------|--------|-------|-------|
| `displayLg` | 34 px | w800 | Titre hero |
| `headingXl` | 28 px | w800 | Titre de page |
| `headingLg` | 20 px | w700 | Titre de section |
| `headingMd` | 16 px | w700 | Sous-titre, AppBar |
| `bodyLg` | 16 px | w500 | Corps de texte principal |
| `bodyMd` | 14 px | w500 | Corps de texte secondaire |
| `bodySm` | 12 px | w500 | Texte petit, légendes |
| `kpiValue` | 28 px | w800 | Chiffre KPI grand format |
| `kpiValueCompact` | 20 px | w700 | Chiffre KPI compact |
| `montantInput` | 24 px | w700 | Montant dans un champ |
| `labelMd` | 13 px | w600 | Label de champ |
| `labelSm` | 11 px | w600 | Petit label |
| `labelCaps` | 12 px | w700 | Label tout-caps (en-têtes) |

### Tailles tactiles (`AppTouch`)

| Token | Valeur | Usage |
|-------|--------|-------|
| `minTarget` | 48 px | Hauteur minimale boutons (Material) |
| `comfortableTarget` | 56 px | Hauteur confortable (recommandé) |
| `largeTarget` | 64 px | Boutons d'action principaux |

---

## Composants réutilisables

### StatusBadge

Badge de statut avec code couleur sémantique.

```dart
// Badge standard
StatusBadge(label: 'À jour', type: StatusType.success)
StatusBadge(label: '3j retard', type: StatusType.warning, icon: Icons.warning_amber)

// Variantes
StatusBadge(label: 'Impayé', type: StatusType.error, variant: StatusBadgeVariant.filled)
StatusBadge(label: 'En cours', type: StatusType.info, variant: StatusBadgeVariant.outlined)

// Pastille + texte
StatusBadge.dot(label: 'En ligne', type: StatusType.success)

// Depuis un statut backend
StatusBadge(label: 'À jour', type: StatusType.fromStatusString('a_jour'))
```

### DualProgressBar

Barre de progression double pour le compteur prochain achat.

```dart
DualProgressBar(
  headerLabel: 'PROCHAIN ACHAT',
  moto: ProgressBarData(
    current: 800000,
    target: 1200000,
    label: 'Prochaine moto',
    icon: Icons.two_wheeler,
  ),
  voiture: ProgressBarData(
    current: 2000000,
    target: 5000000,
    label: 'Prochaine voiture',
    icon: Icons.directions_car,
  ),
)
```

### MontantField

Champ de saisie de montant optimisé terrain.

```dart
MontantField(
  label: 'Montant payé',
  initialValue: 5000,
  quickAmounts: [500, 1000, 2000, 5000, 10000],
  minAmount: 100,
  onChanged: (value) => print('Montant: $value'),
  onSubmitted: (value) => _save(value),
)
```

### PrimaryActionButton

Bouton d'action principal large (saisie au pouce).

```dart
// Bouton principal
PrimaryActionButton(
  label: 'Enregistrer paiement',
  icon: Icons.check,
  onPressed: () => _save(),
)

// État de chargement
PrimaryActionButton.loading()

// Variante destructive
PrimaryActionButton.destructive(
  label: 'Supprimer',
  icon: Icons.delete,
  onPressed: () => _delete(),
)
```

### KpiCard

Carte de KPI pour dashboard.

```dart
KpiCard(
  label: 'Véhicules actifs',
  value: '42',
  subtitle: '+3 cette semaine',
  icon: Icons.directions_car,
  color: AppColors.statusSuccess,
  onTap: () => context.push('/admin/vehicules'),
)
```

---

## Conventions de nommage

### Widgets

| Type | Convention | Exemple |
|------|------------|---------|
| Widget public | PascalCase, nom descriptif | `StatusBadge`, `KpiCard` |
| Widget privé | Préfixe `_` | `_SingleProgressBar`, `_GaugePainter` |
| Variante | Suffixe ou constructeur nommé | `StatusBadge.dot()`, `PrimaryActionButton.loading()` |
| Écran | Suffixe `Screen` | `DashboardScreen`, `PaiementScreen` |
| Provider | Suffixe `Provider` | `dashboardProvider`, `authProvider` |

### Fichiers

| Type | Convention | Exemple |
|------|------------|---------|
| Widget réutilisable | snake_case | `status_badge.dart`, `kpi_widgets.dart` |
| Écran | snake_case + `_screen` | `dashboard_screen.dart` |
| Provider | snake_case + `_provider` | `dashboard_provider.dart` |
| Modèle | snake_case + `_model` | `vehicule_model.dart` |

### Couleurs

```dart
// ✅ Correct : utiliser les tokens
Container(color: AppColors.statusSuccess)
TextStyle(color: AppColors.textPrimaryLight)

// ❌ Incorrect : valeurs magiques
Container(color: Color(0xFF2E7D32))
TextStyle(color: Colors.green)
```

### Espacements

```dart
// ✅ Correct : utiliser les tokens
Padding(padding: EdgeInsets.all(AppSpacing.md))
SizedBox(height: AppSpacing.sectionGap)

// ❌ Incorrect : valeurs magiques
Padding(padding: EdgeInsets.all(16))
SizedBox(height: 20)
```

---

## Ajouter un nouveau composant

### 1. Créer le fichier

```
lib/shared/widgets/mon_composant.dart
```

### 2. Structure du fichier

```dart
import 'package:flutter/material.dart';
import 'package:motoprojet/core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MON COMPOSANT — Description courte
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Description détaillée et cas d'usage.
///
/// Usage :
///   MonComposant(param: value)
///
class MonComposant extends StatelessWidget {
  final String param;

  const MonComposant({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // Utiliser les tokens du design system
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        param,
        style: AppTypography.bodyLg.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}
```

### 3. Checklist

- [ ] Utiliser les tokens (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`)
- [ ] Supporter le mode sombre (`Theme.of(context).brightness`)
- [ ] Documentation avec exemple d'usage en commentaire
- [ ] Taille tactile ≥ 48 px pour les éléments interactifs
- [ ] Contraste suffisant pour lisibilité en extérieur

---

## Mode sombre

Le mode sombre est activé automatiquement selon les préférences système :

```dart
// main.dart
MaterialApp.router(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.system,
)
```

Pour adapter un widget :

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final color = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
```

---

## Icônes

Utiliser les icônes Material avec une taille adaptée :

| Contexte | Taille | Exemple |
|----------|--------|---------|
| Navigation (AppBar) | 24 px | `Icons.menu` |
| Liste d'items | 20-22 px | `Icons.person` |
| Bouton d'action | 22-24 px | `Icons.add` |
| KPI / statut | 16-20 px | `Icons.check_circle` |
| Illustration vide | 64-96 px | `Icons.inbox` |

### Icônes pour statuts (littératie faible)

| Statut | Icône recommandée |
|--------|-------------------|
| À jour / succès | `Icons.check_circle` |
| Retard / attention | `Icons.warning_amber` |
| Défaut / erreur | `Icons.error` |
| En cours / info | `Icons.info` |
| Paiement | `Icons.payments` |
| Véhicule | `Icons.two_wheeler` / `Icons.directions_car` |
| Téléphone | `Icons.phone` |
| Localisation | `Icons.location_on` |

---

## Principes de design terrain

### 1. Lisibilité en plein soleil

- Contraste élevé (texte sombre sur fond clair)
- Pas de gris trop clair pour le texte (minimum `#5F6360`)
- Titres en `FontWeight.w800` pour le contraste

### 2. Saisie au pouce

- Zones tactiles ≥ 48×48 px (recommandé : 56 px)
- Espacement suffisant entre éléments cliquables
- Boutons d'action principaux en bas de l'écran

### 3. Connexion lente

- Pas d'animations lourdes (max 300 ms)
- Skeleton screens plutôt que spinners
- Formatage des montants côté client

### 4. Hiérarchie visuelle

- Un seul élément focal par écran
- Gros chiffres pour les KPI
- Code couleur cohérent (vert/orange/rouge)

---

## Migration depuis l'ancien système

Les constantes legacy sont maintenues pour rétrocompatibilité :

```dart
// ✅ Ancien système (déprécié mais fonctionnel)
AppTheme.primaryColor    // → AppColors.brandGreen
AppTheme.successColor    // → AppColors.statusSuccess
AppTheme.textPrimary     // → AppColors.textPrimaryLight

// ✅ Nouveau système (recommandé)
AppColors.brandGreen
AppColors.statusSuccess
AppColors.textPrimaryLight
```

Migration progressive : remplacer au fil des modifications de fichiers.
