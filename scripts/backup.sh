#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
# BACKUP SCRIPT — Export périodique chiffré de la base Neon
# ═════════════════════════════════════════════════════════════════════════════
#
# Usage :
#   ./scripts/backup.sh                    # Backup complet
#   ./scripts/backup.sh --schema-only      # Schema seulement
#   BACKUP_RETENTION_DAYS=30 ./scripts/backup.sh
#
# Variables d'environnement requises :
#   DATABASE_URL          — Connection string Neon PostgreSQL
#   BACKUP_ENCRYPTION_KEY — Clé GPG pour le chiffrement (ou fichier contenant la clé)
#   R2_ENDPOINT           — Endpoint S3-compatible (Cloudflare R2, etc.)
#   R2_ACCESS_KEY         — Access key du bucket
#   R2_SECRET_KEY         — Secret key du bucket
#   R2_BUCKET             — Nom du bucket (défaut: motoprojet-backups)
#
# Sortie :
#   Fichier chiffré uploadé dans le bucket S3/R2
#   Format : motoprojet-YYYY-MM-DD-HHMMSS.sql.gz.gpg
#
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ─── Fonctions utilitaires ───────────────────────────────────────────────────

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

check_dependencies() {
    local deps=(pg_dump gzip gpg aws)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Dépendances manquantes : ${missing[*]}"
        log_error "Installer avec : apt-get install postgresql-client gnupg awscli"
        exit 1
    fi
}

check_env_vars() {
    local required_vars=(DATABASE_URL BACKUP_ENCRYPTION_KEY R2_ENDPOINT R2_ACCESS_KEY R2_SECRET_KEY)
    local missing=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing+=("$var")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Variables d'environnement manquantes : ${missing[*]}"
        exit 1
    fi
}

# ─── Configuration par défaut ────────────────────────────────────────────────
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
R2_BUCKET="${R2_BUCKET:-motoprojet-backups}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/motoprojet-backups}"
TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
BACKUP_NAME="motoprojet-${TIMESTAMP}"
SCHEMA_ONLY=false

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --schema-only)
            SCHEMA_ONLY=true
            shift
            ;;
        --retention=*)
            BACKUP_RETENTION_DAYS="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --schema-only        Export schema seulement (pas de données)"
            echo "  --retention=DAYS     Jours de rétention (défaut: 30)"
            echo "  --help, -h           Afficher cette aide"
            exit 0
            ;;
        *)
            log_error "Option inconnue : $1"
            exit 1
            ;;
    esac
done

# ─── Vérifications ───────────────────────────────────────────────────────────
check_dependencies
check_env_vars

# ─── Créer le répertoire temporaire ──────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

log_info "Démarrage du backup : $BACKUP_NAME"

# ─── Export de la base ───────────────────────────────────────────────────────
BACKUP_FILE="${BACKUP_NAME}.sql"

if [ "$SCHEMA_ONLY" = true ]; then
    log_info "Export schema uniquement..."
    pg_dump "$DATABASE_URL" \
        --schema-only \
        --no-owner \
        --no-privileges \
        --file="$BACKUP_FILE"
else
    log_info "Export complet (schema + données)..."
    pg_dump "$DATABASE_URL" \
        --format=custom \
        --compress=0 \
        --no-owner \
        --no-privileges \
        --file="$BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Échec de l'export SQL"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_info "Export terminé : $BACKUP_FILE ($BACKUP_SIZE)"

# ─── Compression ─────────────────────────────────────────────────────────────
log_info "Compression du backup..."
gzip "$BACKUP_FILE"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

if [ ! -f "$COMPRESSED_FILE" ]; then
    log_error "Échec de la compression"
    exit 1
fi

COMPRESSED_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
log_info "Compression terminée : $COMPRESSED_FILE ($COMPRESSED_SIZE)"

# ─── Chiffrement GPG ─────────────────────────────────────────────────────────
log_info "Chiffrement du backup..."
ENCRYPTED_FILE="${COMPRESSED_FILE}.gpg"

# Importer la clé si c'est un fichier
if [ -f "$BACKUP_ENCRYPTION_KEY" ]; then
    gpg --batch --import "$BACKUP_ENCRYPTION_KEY" 2>/dev/null || true
    KEY_ID=$(gpg --list-keys --keyid-format short | grep -oP '(?<=/)[A-F0-9]+' | head -1)
    gpg --batch --yes --trust-model always \
        --recipient "$KEY_ID" \
        --output "$ENCRYPTED_FILE" \
        --encrypt "$COMPRESSED_FILE"
else
    # Utiliser une passphrase symétrique
    echo "$BACKUP_ENCRYPTION_KEY" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --cipher-algo AES256 \
        --output "$ENCRYPTED_FILE" \
        "$COMPRESSED_FILE"
fi

if [ ! -f "$ENCRYPTED_FILE" ]; then
    log_error "Échec du chiffrement"
    exit 1
fi

ENCRYPTED_SIZE=$(du -h "$ENCRYPTED_FILE" | cut -f1)
log_info "Chiffrement terminé : $ENCRYPTED_FILE ($ENCRYPTED_SIZE)"

# ─── Calcul du checksum ──────────────────────────────────────────────────────
CHECKSUM_FILE="${ENCRYPTED_FILE}.sha256"
sha256sum "$ENCRYPTED_FILE" > "$CHECKSUM_FILE"
CHECKSUM=$(cut -d' ' -f1 "$CHECKSUM_FILE")
log_info "Checksum SHA-256 : $CHECKSUM"

# ─── Upload vers S3/R2 ───────────────────────────────────────────────────────
log_info "Upload vers S3/R2..."

# Configuration AWS CLI pour R2
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"

S3_PATH="s3://${R2_BUCKET}/backups/$(date '+%Y/%m')/${ENCRYPTED_FILE}"

aws s3 cp "$ENCRYPTED_FILE" "$S3_PATH" \
    --endpoint-url "$R2_ENDPOINT" \
    --storage-class STANDARD_IA

aws s3 cp "$CHECKSUM_FILE" "${S3_PATH}.sha256" \
    --endpoint-url "$R2_ENDPOINT"

if [ $? -eq 0 ]; then
    log_info "Upload terminé : $S3_PATH"
else
    log_error "Échec de l'upload vers S3"
    exit 1
fi

# ─── Nettoyage local ─────────────────────────────────────────────────────────
log_info "Nettoyage des fichiers temporaires..."
rm -f "$BACKUP_FILE" "$COMPRESSED_FILE" "$ENCRYPTED_FILE" "$CHECKSUM_FILE"

# ─── Suppression des anciens backups (rétention) ─────────────────────────────
log_info "Suppression des backups de plus de $BACKUP_RETENTION_DAYS jours..."

CUTOFF_DATE=$(date -d "-${BACKUP_RETENTION_DAYS} days" '+%Y-%m-%d' 2>/dev/null || \
              date -v-${BACKUP_RETENTION_DAYS}d '+%Y-%m-%d' 2>/dev/null || \
              echo "")

if [ -n "$CUTOFF_DATE" ]; then
    # Lister et supprimer les vieux backups
    aws s3 ls "s3://${R2_BUCKET}/backups/" \
        --endpoint-url "$R2_ENDPOINT" \
        --recursive | while read -r line; do
        
        file_date=$(echo "$line" | awk '{print $1}')
        file_path=$(echo "$line" | awk '{print $4}')
        
        if [[ "$file_date" < "$CUTOFF_DATE" ]] && [[ -n "$file_path" ]]; then
            log_info "Suppression : $file_path"
            aws s3 rm "s3://${R2_BUCKET}/${file_path}" \
                --endpoint-url "$R2_ENDPOINT" || true
        fi
    done
fi

# ─── Notification de succès ──────────────────────────────────────────────────
log_info "═══════════════════════════════════════════════════════════════"
log_info "BACKUP TERMINÉ AVEC SUCCÈS"
log_info "  Fichier : $ENCRYPTED_FILE"
log_info "  Taille  : $ENCRYPTED_SIZE"
log_info "  Checksum: $CHECKSUM"
log_info "  Stockage: $S3_PATH"
log_info "═══════════════════════════════════════════════════════════════"

# Webhook optionnel (Slack, Discord, etc.)
if [ -n "${BACKUP_WEBHOOK_URL:-}" ]; then
    curl -s -X POST "$BACKUP_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"✅ Backup MotoProjet terminé\",
            \"attachments\": [{
                \"color\": \"good\",
                \"fields\": [
                    {\"title\": \"Fichier\", \"value\": \"$ENCRYPTED_FILE\", \"short\": true},
                    {\"title\": \"Taille\", \"value\": \"$ENCRYPTED_SIZE\", \"short\": true},
                    {\"title\": \"Checksum\", \"value\": \"$CHECKSUM\", \"short\": false}
                ]
            }]
        }" || log_warn "Échec de la notification webhook"
fi

exit 0
