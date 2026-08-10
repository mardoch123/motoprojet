#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
# RESTORE SCRIPT — Restauration de backup chiffré vers Neon
# ═════════════════════════════════════════════════════════════════════════════
#
# Usage :
#   ./scripts/restore.sh <backup_file>                    # Restaurer un fichier local
#   ./scripts/restore.sh --from-s3 <backup_name>          # Télécharger puis restaurer
#   ./scripts/restore.sh --list                           # Lister les backups disponibles
#   ./scripts/restore.sh --latest                         # Restaurer le dernier backup
#
# Variables d'environnement requises :
#   DATABASE_URL          — Connection string Neon PostgreSQL (cible)
#   BACKUP_ENCRYPTION_KEY — Clé GPG pour le déchiffrement
#   R2_ENDPOINT           — Endpoint S3-compatible
#   R2_ACCESS_KEY         — Access key du bucket
#   R2_SECRET_KEY         — Secret key du bucket
#   R2_BUCKET             — Nom du bucket
#
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

# ─── Fonctions ───────────────────────────────────────────────────────────────

check_dependencies() {
    local deps=(pg_restore gzip gpg aws)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Dépendances manquantes : ${missing[*]}"
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

list_backups() {
    log_info "Liste des backups disponibles dans S3/R2..."
    
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
    
    aws s3 ls "s3://${R2_BUCKET}/backups/" \
        --endpoint-url "$R2_ENDPOINT" \
        --recursive \
        | grep '\.gpg$' \
        | awk '{print $4}' \
        | sort -r
}

download_backup() {
    local backup_name="$1"
    local download_dir="/tmp/motoprojet-restore"
    mkdir -p "$download_dir"
    
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
    
    # Trouver le fichier dans S3
    local s3_path
    s3_path=$(aws s3 ls "s3://${R2_BUCKET}/backups/" \
        --endpoint-url "$R2_ENDPOINT" \
        --recursive \
        | grep "$backup_name" \
        | awk '{print $4}' \
        | head -1)
    
    if [ -z "$s3_path" ]; then
        log_error "Backup non trouvé : $backup_name"
        exit 1
    fi
    
    local local_file="${download_dir}/$(basename "$s3_path")"
    
    log_info "Téléchargement : $s3_path"
    aws s3 cp "s3://${R2_BUCKET}/${s3_path}" "$local_file" \
        --endpoint-url "$R2_ENDPOINT"
    
    echo "$local_file"
}

decrypt_backup() {
    local encrypted_file="$1"
    local decrypted_file="${encrypted_file%.gpg}"
    
    log_info "Déchiffrement : $encrypted_file"
    
    if [ -f "$BACKUP_ENCRYPTION_KEY" ]; then
        gpg --batch --import "$BACKUP_ENCRYPTION_KEY" 2>/dev/null || true
        gpg --batch --yes --pinentry-mode loopback \
            --output "$decrypted_file" \
            --decrypt "$encrypted_file"
    else
        echo "$BACKUP_ENCRYPTION_KEY" | gpg --batch --yes --passphrase-fd 0 \
            --output "$decrypted_file" \
            --decrypt "$encrypted_file"
    fi
    
    if [ ! -f "$decrypted_file" ]; then
        log_error "Échec du déchiffrement"
        exit 1
    fi
    
    echo "$decrypted_file"
}

decompress_backup() {
    local compressed_file="$1"
    local decompressed_file="${compressed_file%.gz}"
    
    log_info "Décompression : $compressed_file"
    gunzip -c "$compressed_file" > "$decompressed_file"
    
    if [ ! -f "$decompressed_file" ]; then
        log_error "Échec de la décompression"
        exit 1
    fi
    
    echo "$decompressed_file"
}

verify_checksum() {
    local backup_file="$1"
    local checksum_file="${backup_file}.sha256"
    
    # Télécharger le checksum si disponible
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
    
    local s3_checksum_path
    s3_checksum_path=$(aws s3 ls "s3://${R2_BUCKET}/backups/" \
        --endpoint-url "$R2_ENDPOINT" \
        --recursive \
        | grep "$(basename "$backup_file").sha256" \
        | awk '{print $4}' \
        | head -1)
    
    if [ -n "$s3_checksum_path" ]; then
        aws s3 cp "s3://${R2_BUCKET}/${s3_checksum_path}" "$checksum_file" \
            --endpoint-url "$R2_ENDPOINT" 2>/dev/null || true
        
        if [ -f "$checksum_file" ]; then
            log_info "Vérification du checksum..."
            local expected_checksum
            expected_checksum=$(cut -d' ' -f1 "$checksum_file")
            local actual_checksum
            actual_checksum=$(sha256sum "$backup_file" | cut -d' ' -f1)
            
            if [ "$expected_checksum" != "$actual_checksum" ]; then
                log_error "Checksum invalide !"
                log_error "Attendu : $expected_checksum"
                log_error "Reçu   : $actual_checksum"
                exit 1
            fi
            
            log_info "Checksum vérifié : $actual_checksum"
            rm -f "$checksum_file"
        fi
    fi
}

restore_backup() {
    local sql_file="$1"
    
    log_step "Connexion à la base cible..."
    
    # Vérifier la connexion
    if ! pg_isready -d "$DATABASE_URL" &>/dev/null; then
        log_error "Impossible de se connecter à la base cible"
        exit 1
    fi
    
    # Déterminer le format du fichier
    local file_type
    file_type=$(file -b "$sql_file")
    
    log_step "Restauration vers la base..."
    
    if [[ "$file_type" == *"PostgreSQL custom archive"* ]]; then
        # Format pg_dump custom
        pg_restore "$DATABASE_URL" \
            --clean \
            --if-exists \
            --no-owner \
            --no-privileges \
            --verbose \
            "$sql_file" 2>&1 | while read -r line; do
                log_info "pg_restore: $line"
            done
    else
        # Format SQL plain
        psql "$DATABASE_URL" \
            --verbose \
            --file="$sql_file" \
            --single-transaction \
            --no-password 2>&1 | while read -r line; do
                log_info "psql: $line"
            done
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Restauration terminée avec succès"
    else
        log_error "Échec de la restauration"
        exit 1
    fi
}

confirm_restore() {
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ATTENTION : Restauration de base de données${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Base cible : ${DATABASE_URL%%@*}@..."
    echo "  Backup     : $1"
    echo ""
    echo -e "${RED}  Cette opération va ÉCRASER les données de la base cible.${NC}"
    echo ""
    read -p "  Tapez 'RESTAURER' pour confirmer : " confirm
    
    if [ "$confirm" != "RESTAURER" ]; then
        log_info "Restauration annulée"
        exit 0
    fi
}

# ─── Arguments ───────────────────────────────────────────────────────────────
ACTION=""
BACKUP_SOURCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list)
            ACTION="list"
            shift
            ;;
        --latest)
            ACTION="latest"
            shift
            ;;
        --from-s3)
            ACTION="from-s3"
            BACKUP_SOURCE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [BACKUP_FILE]"
            echo ""
            echo "Options:"
            echo "  --list               Lister les backups disponibles"
            echo "  --latest             Restaurer le dernier backup"
            echo "  --from-s3 <name>     Télécharger et restaurer depuis S3"
            echo "  --help, -h           Afficher cette aide"
            echo ""
            echo "Exemples:"
            echo "  $0 backup.sql.gz.gpg              # Fichier local"
            echo "  $0 --from-s3 motoprojet-2024      # Depuis S3"
            echo "  $0 --latest                       # Dernier backup"
            exit 0
            ;;
        -*)
            log_error "Option inconnue : $1"
            exit 1
            ;;
        *)
            ACTION="local"
            BACKUP_SOURCE="$1"
            shift
            ;;
    esac
done

# ─── Vérifications ───────────────────────────────────────────────────────────
check_dependencies
check_env_vars

# ─── Exécution ───────────────────────────────────────────────────────────────
case $ACTION in
    list)
        list_backups
        exit 0
        ;;
    
    latest)
        log_info "Recherche du dernier backup..."
        BACKUP_SOURCE=$(list_backups | head -1)
        if [ -z "$BACKUP_SOURCE" ]; then
            log_error "Aucun backup trouvé"
            exit 1
        fi
        log_info "Dernier backup : $BACKUP_SOURCE"
        ACTION="from-s3"
        ;&  # Fall through to from-s3
    
    from-s3)
        if [ -z "$BACKUP_SOURCE" ]; then
            log_error "Nom du backup requis"
            exit 1
        fi
        ENCRYPTED_FILE=$(download_backup "$BACKUP_SOURCE")
        ;&  # Fall through to local
    
    local|"")
        if [ -z "$BACKUP_SOURCE" ] && [ "$ACTION" != "local" ]; then
            log_error "Fichier de backup requis"
            exit 1
        fi
        
        if [ "$ACTION" = "local" ]; then
            ENCRYPTED_FILE="$BACKUP_SOURCE"
        fi
        
        if [ ! -f "$ENCRYPTED_FILE" ]; then
            log_error "Fichier non trouvé : $ENCRYPTED_FILE"
            exit 1
        fi
        
        # Confirmation
        confirm_restore "$(basename "$ENCRYPTED_FILE")"
        
        # Vérification checksum
        verify_checksum "$ENCRYPTED_FILE"
        
        # Déchiffrement
        DECRYPTED_FILE=$(decrypt_backup "$ENCRYPTED_FILE")
        
        # Décompression
        if [[ "$DECRYPTED_FILE" == *.gz ]]; then
            SQL_FILE=$(decompress_backup "$DECRYPTED_FILE")
        else
            SQL_FILE="$DECRYPTED_FILE"
        fi
        
        # Restauration
        restore_backup "$SQL_FILE"
        
        # Nettoyage
        log_info "Nettoyage des fichiers temporaires..."
        rm -f "$ENCRYPTED_FILE" "$DECRYPTED_FILE" "$SQL_FILE"
        
        log_info "═══════════════════════════════════════════════════════════════"
        log_info "RESTAURATION TERMINÉE AVEC SUCCÈS"
        log_info "═══════════════════════════════════════════════════════════════"
        ;;
    
    *)
        log_error "Action inconnue : $ACTION"
        exit 1
        ;;
esac

exit 0
