#!/usr/bin/env bash
# =============================================================================
# Script de versioning sémantique — MotoProjet (Flutter)
#
# Usage :
#   ./scripts/bump-version.sh patch    # 1.0.0 → 1.0.1
#   ./scripts/bump-version.sh minor    # 1.0.0 → 1.1.0
#   ./scripts/bump-version.sh major    # 1.0.0 → 2.0.0
#   ./scripts/bump-version.sh 1.5.0    # Version explicite
#   ./scripts/bump-version.sh 1.5.0 42 # Version + build number explicite
# =============================================================================
set -euo pipefail

PUBSPEC="pubspec.yaml"
BUMP_TYPE="${1:-patch}"
EXPLICIT_VERSION="${2:-}"
EXPLICIT_BUILD="${3:-}"

# Vérifier que le fichier pubspec.yaml existe
if [ ! -f "$PUBSPEC" ]; then
  echo "❌ Fichier $PUBSPEC introuvable. Exécuter depuis la racine du projet."
  exit 1
fi

# Lire la version actuelle
CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | sed 's/version: *//' | tr -d '[:space:]')
CURRENT_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

echo "📌 Version actuelle : $CURRENT_NAME (build $CURRENT_BUILD)"

# Calculer la nouvelle version
if [ -n "$EXPLICIT_VERSION" ]; then
  NEW_VERSION="$EXPLICIT_VERSION"
else
  MAJOR=$(echo "$CURRENT_NAME" | cut -d'.' -f1)
  MINOR=$(echo "$CURRENT_NAME" | cut -d'.' -f2)
  PATCH=$(echo "$CURRENT_NAME" | cut -d'.' -f3)

  case "$BUMP_TYPE" in
    major)
      MAJOR=$((MAJOR + 1))
      MINOR=0
      PATCH=0
      ;;
    minor)
      MINOR=$((MINOR + 1))
      PATCH=0
      ;;
    patch)
      PATCH=$((PATCH + 1))
      ;;
    *)
      echo "❌ Type de bump invalide : $BUMP_TYPE"
      echo "   Usage : $0 [major|minor|patch|X.Y.Z] [build_number]"
      exit 1
      ;;
  esac
  NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

# Calculer le build number
if [ -n "$EXPLICIT_BUILD" ]; then
  NEW_BUILD="$EXPLICIT_BUILD"
else
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

NEW_FULL="${NEW_VERSION}+${NEW_BUILD}"

echo "🆕 Nouvelle version : $NEW_VERSION (build $NEW_BUILD)"

# Mettre à jour pubspec.yaml
sed -i.bak "s/^version:.*/version: ${NEW_FULL}/" "$PUBSPEC"
rm -f "${PUBSPEC}.bak"

# Mettre à jour versionCode et versionName dans le README si nécessaire
echo "✅ pubspec.yaml mis à jour → version: $NEW_FULL"

# Créer un tag Git
read -p "🏷️  Créer un tag git v$NEW_VERSION ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  git add "$PUBSPEC"
  git commit -m "chore: bump version to v$NEW_FULL"
  git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
  echo "🏷️  Tag v$NEW_VERSION créé"
  echo "   git push && git push --tags pour publier"
fi
