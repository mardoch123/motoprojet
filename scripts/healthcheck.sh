#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
# HEALTHCHECK SCRIPT — Monitoring de disponibilité de l'API
# ═════════════════════════════════════════════════════════════════════════════
#
# Usage :
#   ./scripts/healthcheck.sh                    # Vérification unique
#   ./scripts/healthcheck.sh --watch            # Surveillance continue
#   ./scripts/healthcheck.sh --watch --interval=30  # Intervalle personnalisé
#
# Variables d'environnement :
#   API_URL              — URL de l'API (défaut: https://api.motoprojet.bj)
#   HEALTHCHECK_WEBHOOK  — URL webhook pour notifications (Slack/Discord)
#   HEALTHCHECK_INTERVAL — Intervalle en secondes (défaut: 60)
#   FAILURE_THRESHOLD    — Nombre d'échecs avant notification (défaut: 3)
#
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
API_URL="${API_URL:-https://api.motoprojet.bj}"
HEALTHCHECK_INTERVAL="${HEALTHCHECK_INTERVAL:-60}"
FAILURE_THRESHOLD="${FAILURE_THRESHOLD:-3}"
TIMEOUT=10

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
FAILURE_COUNT=0
SUCCESS_COUNT=0
TOTAL_CHECKS=0
LAST_STATUS="unknown"

log_info() { echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_status() { echo -e "${BLUE}[STATUS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

# ─── Fonctions ───────────────────────────────────────────────────────────────

send_notification() {
    local status="$1"
    local message="$2"
    local color="$3"
    
    if [ -z "${HEALTHCHECK_WEBHOOK:-}" ]; then
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "text": "$message",
    "attachments": [{
        "color": "$color",
        "fields": [
            {"title": "API", "value": "$API_URL", "short": true},
            {"title": "Statut", "value": "$status", "short": true},
            {"title": "Timestamp", "value": "$(date '+%Y-%m-%d %H:%M:%S UTC')", "short": false}
        ]
    }]
}
EOF
)
    
    curl -s -X POST "$HEALTHCHECK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$payload" || true
}

check_endpoint() {
    local endpoint="$1"
    local expected_status="${2:-200}"
    local url="${API_URL}${endpoint}"
    
    local start_time=$(date +%s%N)
    local http_code
    local response_time
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" \
        --max-time "$((TIMEOUT * 2))" \
        "$url" 2>/dev/null) || http_code="000"
    
    local end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [ "$http_code" = "$expected_status" ]; then
        echo "ok|${response_time}|${http_code}"
        return 0
    else
        echo "fail|${response_time}|${http_code}"
        return 1
    fi
}

check_health() {
    local all_ok=true
    local results=()
    
    # ─── Health check principal ────────────────────────────────────────────
    local health_result
    if health_result=$(check_endpoint "/health" "200"); then
        IFS='|' read -r status response_time http_code <<< "$health_result"
        results+=("health:${response_time}ms")
    else
        IFS='|' read -r status response_time http_code <<< "$health_result"
        all_ok=false
        results+=("health:FAIL(${http_code})")
    fi
    
    # ─── Vérifier la base de données ───────────────────────────────────────
    local db_result
    if db_result=$(check_endpoint "/health/db" "200"); then
        IFS='|' read -r status response_time http_code <<< "$db_result"
        results+=("db:${response_time}ms")
    else
        IFS='|' read -r status response_time http_code <<< "$db_result"
        all_ok=false
        results+=("db:FAIL(${http_code})")
    fi
    
    # ─── Vérifier un endpoint métier (optionnel) ───────────────────────────
    local api_result
    if api_result=$(check_endpoint "/api/v1/auth/ping" "200"); then
        IFS='|' read -r status response_time http_code <<< "$api_result"
        results+=("api:${response_time}ms")
    else
        # Pas critique si cet endpoint n'existe pas
        results+=("api:SKIP")
    fi
    
    # ─── Afficher le résultat ──────────────────────────────────────────────
    if [ "$all_ok" = true ]; then
        log_info "✓ API opérationnelle | ${results[*]}"
        return 0
    else
        log_error "✗ API en difficulté | ${results[*]}"
        return 1
    fi
}

run_check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if check_health; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        FAILURE_COUNT=0
        
        # Notification de recovery si on sort d'une panne
        if [ "$LAST_STATUS" = "down" ]; then
            send_notification "RECOVERED" "✅ API MotoProjet récupérée" "good"
            log_status "API RÉCUPÉRÉE après $FAILURE_COUNT échecs"
        fi
        
        LAST_STATUS="up"
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        
        # Notification de panne après seuil
        if [ "$FAILURE_COUNT" -ge "$FAILURE_THRESHOLD" ]; then
            if [ "$LAST_STATUS" != "down" ]; then
                send_notification "DOWN" "🔴 API MotoProjet indisponible ($FAILURE_COUNT échecs consécutifs)" "danger"
                log_error "API INDISPONIBLE - Notification envoyée"
            fi
            LAST_STATUS="down"
        else
            log_warn "Échec $FAILURE_COUNT/$FAILURE_THRESHOLD avant notification"
        fi
    fi
}

print_stats() {
    echo ""
    log_status "═══════════════════════════════════════════════════════════════"
    log_status "Statistiques de monitoring"
    log_status "  Total checks : $TOTAL_CHECKS"
    log_status "  Succès       : $SUCCESS_COUNT"
    log_status "  Échecs       : $((TOTAL_CHECKS - SUCCESS_COUNT))"
    log_status "  Taux succès  : $(( SUCCESS_COUNT * 100 / TOTAL_CHECKS ))%"
    log_status "  Statut actuel: $LAST_STATUS"
    log_status "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ─── Arguments ───────────────────────────────────────────────────────────────
WATCH_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --interval=*)
            HEALTHCHECK_INTERVAL="${1#*=}"
            shift
            ;;
        --threshold=*)
            FAILURE_THRESHOLD="${1#*=}"
            shift
            ;;
        --url=*)
            API_URL="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --watch              Surveillance continue"
            echo "  --interval=SECS      Intervalle entre checks (défaut: 60)"
            echo "  --threshold=N        Échecs avant notification (défaut: 3)"
            echo "  --url=URL            URL de l'API"
            echo "  --help, -h           Afficher cette aide"
            exit 0
            ;;
        *)
            log_error "Option inconnue : $1"
            exit 1
            ;;
    esac
done

# ─── Exécution ───────────────────────────────────────────────────────────────
log_status "Démarrage du monitoring : $API_URL"
log_status "Intervalle : ${HEALTHCHECK_INTERVAL}s, Seuil : $FAILURE_THRESHOLD"

if [ "$WATCH_MODE" = true ]; then
    log_info "Mode surveillance continue activé (Ctrl+C pour arrêter)"
    
    trap print_stats EXIT
    
    while true; do
        run_check
        sleep "$HEALTHCHECK_INTERVAL"
    done
else
    run_check
    exit $?
fi
