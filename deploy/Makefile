# =============================================================================
# Makefile — Symphony Docker shortcuts
# =============================================================================
# Usage: make <target>
# Run `make help` to list all available targets.

.PHONY: help up down restart logs build rebuild ps shell shell-litellm \
        clean clean-volumes status proxy direct open

# Default compose command
DC := docker compose

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help: ## Show this help message
	@echo "Symphony Docker Makefile"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "%-20s %s\n", "Target", "Description\n"} \
	      /^[a-zA-Z_-]+:.*?##/ { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ---------------------------------------------------------------------------
# Core lifecycle
# ---------------------------------------------------------------------------
up: ## Start all services (detached)
	$(DC) up -d

down: ## Stop and remove containers
	$(DC) down

restart: ## Restart all containers
	$(DC) restart

restart-symphony: ## Restart only the symphony container
	$(DC) restart symphony

restart-litellm: ## Restart only the litellm container
	$(DC) restart litellm

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build: ## Build (or rebuild) Docker images
	$(DC) build

rebuild: ## Force rebuild without cache
	$(DC) build --no-cache

pull-images: ## Pull latest upstream images (litellm, watchtower)
	$(DC) pull litellm watchtower

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------
logs: ## Follow logs for all services
	$(DC) logs -f

logs-symphony: ## Follow Symphony logs only
	$(DC) logs -f symphony

logs-litellm: ## Follow LiteLLM logs only
	$(DC) logs -f litellm

logs-watchtower: ## Follow Watchtower logs only
	$(DC) logs -f watchtower

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
ps: ## Show container status
	$(DC) ps

status: ps ## Alias for ps

# ---------------------------------------------------------------------------
# Shell access
# ---------------------------------------------------------------------------
shell: ## Open bash shell in symphony container
	$(DC) exec symphony bash

shell-litellm: ## Open bash shell in litellm container
	$(DC) exec litellm bash

# ---------------------------------------------------------------------------
# Setup shortcuts
# ---------------------------------------------------------------------------
proxy: ## Start in proxy mode (Codex → LiteLLM → OpenAI + OpenRouter fallback)
	./setup.sh proxy

direct: ## Start in direct mode (Codex → OpenAI directly)
	./setup.sh direct

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
clean: ## Stop containers and remove images
	$(DC) down --rmi local

clean-volumes: ## Stop containers and remove ALL volumes (WARNING: deletes workspaces!)
	@echo "WARNING: This will delete all workspace data. Press Ctrl+C to cancel."
	@sleep 5
	$(DC) down -v

clean-workspaces: ## Remove all per-issue workspace directories (safe cleanup)
	@echo "Removing workspace directories..."
	@rm -rf workspaces/*/
	@echo "Done. workspaces/ directory is now empty."

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
open: ## Open the Symphony dashboard in browser (macOS/Linux)
	@which xdg-open &>/dev/null && xdg-open http://localhost:4000 || \
	 which open &>/dev/null && open http://localhost:4000 || \
	 echo "Open: http://localhost:4000"

health: ## Check health of all services
	@echo "--- symphony ---"
	@curl -sf http://localhost:4000/ &>/dev/null && echo "UP" || echo "DOWN / not responding"
	@echo "--- litellm ---"
	@curl -sf http://localhost:4001/health &>/dev/null && echo "UP" || echo "DOWN / not responding"

config: ## Show effective docker compose configuration
	$(DC) config
