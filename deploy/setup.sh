#!/usr/bin/env bash
# =============================================================================
# Symphony Docker Setup Script
#
# Usage:
#   ./setup.sh          — Interactive mode (prompts for direct or proxy)
#   ./setup.sh direct   — Codex talks directly to OpenAI (no litellm)
#   ./setup.sh proxy    — Codex talks through LiteLLM (OpenRouter fallback)
#   ./setup.sh down     — Stop all containers
#   ./setup.sh restart  — Restart all containers
#   ./setup.sh logs     — Follow logs
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[setup]${NC} $*"; }
warn()   { echo -e "${YELLOW}[warn]${NC} $*"; }
error()  { echo -e "${RED}[error]${NC} $*" >&2; }
header() { echo -e "\n${BOLD}${BLUE}=== $* ===${NC}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Utility shortcuts
# ---------------------------------------------------------------------------
down() {
    log "Stopping containers..."
    docker compose down
    exit 0
}

restart_containers() {
    log "Restarting containers..."
    docker compose restart
    exit 0
}

show_logs() {
    docker compose logs -f
    exit 0
}

# Handle simple sub-commands first
case "${1:-}" in
    down)    down ;;
    restart) restart_containers ;;
    logs)    show_logs ;;
esac

# ---------------------------------------------------------------------------
# Step 1: Check prerequisites
# ---------------------------------------------------------------------------
header "Checking prerequisites"

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        error "Required command not found: $1"
        error "Please install $1 and try again."
        exit 1
    fi
    log "  ✓ $1 found ($(command -v "$1"))"
}

check_cmd docker
check_cmd git

# Check Docker Compose (v2 plugin or standalone)
if docker compose version &>/dev/null 2>&1; then
    log "  ✓ docker compose (plugin) found"
elif command -v docker-compose &>/dev/null; then
    log "  ✓ docker-compose (standalone) found"
    # Alias for the rest of the script
    docker() { command docker-compose "$@"; }
else
    error "Docker Compose not found. Install Docker Desktop or 'docker compose' plugin."
    exit 1
fi

# Check Docker daemon is running
if ! docker info &>/dev/null; then
    error "Docker daemon is not running. Start Docker and try again."
    exit 1
fi
log "  ✓ Docker daemon is running"

# ---------------------------------------------------------------------------
# Step 2: Create .env if missing
# ---------------------------------------------------------------------------
header "Environment configuration"

if [[ ! -f .env ]]; then
    if [[ -f .env.example ]]; then
        cp .env.example .env
        warn ".env not found — created from .env.example"
        warn ""
        warn "  IMPORTANT: Edit .env with your actual API keys before continuing:"
        warn "    nano .env   # or your preferred editor"
        warn ""
        read -rp "Press ENTER once you've edited .env, or Ctrl+C to abort: "
    else
        error ".env.example not found. Cannot create .env."
        exit 1
    fi
else
    log ".env already exists — using it"
fi

# Verify required keys are set (not still placeholder values)
check_env_var() {
    local var="$1"
    local val
    val=$(grep "^${var}=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || true)
    if [[ -z "$val" || "$val" == "sk-..." || "$val" == "sk-or-..." || \
          "$val" == "lin_api_..." || "$val" == "ghp_..." || \
          "$val" == "sk-litellm-..." || "$val" == "YOUR_PROJECT_SLUG" ]]; then
        warn "  ⚠  ${var} appears to be unset or still a placeholder"
        return 1
    fi
    log "  ✓ ${var} is set"
    return 0
}

MISSING_VARS=0
check_env_var "OPENAI_API_KEY"  || MISSING_VARS=$((MISSING_VARS + 1))
check_env_var "LINEAR_API_KEY"  || MISSING_VARS=$((MISSING_VARS + 1))
check_env_var "GH_TOKEN"        || MISSING_VARS=$((MISSING_VARS + 1))

if [[ $MISSING_VARS -gt 0 ]]; then
    warn ""
    warn "$MISSING_VARS required variable(s) need attention. You can continue, but Symphony may not work correctly."
    read -rp "Continue anyway? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
fi

# ---------------------------------------------------------------------------
# Step 3: Create runtime directories
# ---------------------------------------------------------------------------
header "Creating runtime directories"

mkdir -p workspaces logs
log "  ✓ workspaces/"
log "  ✓ logs/"

# Make sure .codex dir exists
mkdir -p .codex/skills
log "  ✓ .codex/skills/"

# ---------------------------------------------------------------------------
# Step 4: Choose operation mode
# ---------------------------------------------------------------------------
header "Operation mode"

MODE="${1:-}"

if [[ -z "$MODE" ]]; then
    echo -e "${CYAN}Choose how Codex should talk to the AI API:${NC}"
    echo ""
    echo "  1) ${BOLD}direct${NC} — Codex → OpenAI api.openai.com"
    echo "        Simpler. No fallback. Best if you only use OpenAI."
    echo ""
    echo "  2) ${BOLD}proxy${NC}  — Codex → LiteLLM → OpenAI primary → OpenRouter fallback"
    echo "        Recommended. Automatic failover when OpenAI is down or rate-limited."
    echo ""
    read -rp "Enter choice [1/2, default=2]: " choice
    case "${choice:-2}" in
        1) MODE="direct" ;;
        2) MODE="proxy" ;;
        *) MODE="proxy" ;;
    esac
fi

case "$MODE" in
    direct)
        log "Mode: DIRECT (Codex → OpenAI)"
        # Ensure OPENAI_BASE_URL is commented out in .env
        if grep -qE "^OPENAI_BASE_URL=http://litellm" .env 2>/dev/null; then
            sed -i 's|^OPENAI_BASE_URL=http://litellm|# OPENAI_BASE_URL=http://litellm|g' .env
            log "  Commented out OPENAI_BASE_URL in .env (direct mode)"
        fi
        COMPOSE_PROFILES=""
        ;;
    proxy)
        log "Mode: PROXY (Codex → LiteLLM → OpenAI + OpenRouter fallback)"
        # Ensure OPENAI_BASE_URL is set to litellm
        if grep -qE "^# OPENAI_BASE_URL=http://litellm" .env 2>/dev/null; then
            sed -i 's|^# OPENAI_BASE_URL=http://litellm|OPENAI_BASE_URL=http://litellm|g' .env
            log "  Uncommented OPENAI_BASE_URL=http://litellm:4000/v1 in .env (proxy mode)"
        elif ! grep -qE "^OPENAI_BASE_URL=" .env 2>/dev/null; then
            echo "" >> .env
            echo "OPENAI_BASE_URL=http://litellm:4000/v1" >> .env
            log "  Added OPENAI_BASE_URL=http://litellm:4000/v1 to .env (proxy mode)"
        fi

        # Check for OPENROUTER_API_KEY in proxy mode
        check_env_var "OPENROUTER_API_KEY" || warn "  OPENROUTER_API_KEY not set — OpenRouter fallback won't work"
        check_env_var "LITELLM_MASTER_KEY" || warn "  LITELLM_MASTER_KEY not set — using default (insecure)"
        COMPOSE_PROFILES=""
        ;;
    *)
        error "Unknown mode: $MODE. Use 'direct' or 'proxy'."
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Step 5: Build and start containers
# ---------------------------------------------------------------------------
header "Building and starting Symphony"

log "Building Docker image (this may take a few minutes on first run)..."
docker compose build --progress=plain symphony

if [[ "$MODE" == "proxy" ]]; then
    log "Starting LiteLLM proxy first..."
    docker compose up -d litellm
    log "Waiting for LiteLLM to be healthy..."
    RETRIES=30
    until docker compose exec litellm curl -sf http://localhost:4000/health &>/dev/null; do
        RETRIES=$((RETRIES - 1))
        if [[ $RETRIES -le 0 ]]; then
            warn "LiteLLM did not become healthy in time. Check logs: docker compose logs litellm"
            break
        fi
        sleep 2
    done
    log "  ✓ LiteLLM is up"
fi

log "Starting Symphony..."
docker compose up -d symphony

# Start Watchtower for auto-updates (optional — comment out if unwanted)
docker compose up -d watchtower 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 6: Show status and URLs
# ---------------------------------------------------------------------------
header "Symphony is running"

echo -e "${BOLD}Service status:${NC}"
docker compose ps

echo ""
echo -e "${BOLD}Dashboard:${NC}"
echo -e "  ${CYAN}http://localhost:4000${NC}  — Symphony LiveView dashboard"

if [[ "$MODE" == "proxy" ]]; then
    echo ""
    echo -e "${BOLD}LiteLLM proxy:${NC}"
    echo -e "  ${CYAN}http://localhost:4001${NC}  — LiteLLM API (OpenAI-compatible)"
    echo -e "  ${CYAN}http://localhost:4001/health${NC}  — Health check"
fi

echo ""
echo -e "${BOLD}Useful commands:${NC}"
echo "  ./setup.sh logs     — Follow all container logs"
echo "  ./setup.sh restart  — Restart all containers"
echo "  ./setup.sh down     — Stop all containers"
echo "  make logs           — (if using Makefile)"
echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC} Symphony is monitoring Linear for issues."
echo ""
