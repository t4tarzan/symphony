#!/usr/bin/env bash
set -euo pipefail

# This script is called by the Playground Bridge's install_cmd
# Working directory: /home/Ubuntu/apps/symphony (repo root)

cd deploy

# Create .env if missing
if [ ! -f .env ]; then
    cp .env.example .env
    echo "[deploy] Created .env from template"
fi

# Create runtime dirs
mkdir -p workspaces logs .codex/skills

# Build the Symphony image
docker compose build symphony 2>&1 || echo "[warn] Build may have failed — check logs"

# Pull external images
docker compose pull litellm watchtower 2>&1 || true

# Start the stack
docker compose up -d

echo "[deploy] Symphony stack started"
docker compose ps
