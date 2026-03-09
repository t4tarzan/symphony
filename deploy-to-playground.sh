#!/usr/bin/env bash
set -euo pipefail

# Deploy Symphony on Playground server
# Runs Docker build in background to avoid Bridge timeout

LOG="/home/Ubuntu/apps/symphony/deploy/deploy.log"
DEPLOY_DIR="/home/Ubuntu/apps/symphony/deploy"

cd "$DEPLOY_DIR"

# Create .env if missing
if [ ! -f .env ]; then
    cp .env.example .env
    echo "[deploy] Created .env from template" | tee -a "$LOG"
fi

# Create runtime dirs
mkdir -p workspaces logs .codex/skills

# Launch the full build + start in background
nohup bash -c '
  LOG="/home/Ubuntu/apps/symphony/deploy/deploy.log"
  cd /home/Ubuntu/apps/symphony/deploy
  
  echo "[$(date)] Starting Docker build..." >> "$LOG"
  
  # Pull external images first
  docker compose pull litellm watchtower >> "$LOG" 2>&1 || true
  echo "[$(date)] External images pulled" >> "$LOG"
  
  # Build Symphony image (this takes several minutes)
  docker compose build symphony >> "$LOG" 2>&1
  BUILD_EXIT=$?
  echo "[$(date)] Build completed with exit code: $BUILD_EXIT" >> "$LOG"
  
  if [ $BUILD_EXIT -eq 0 ]; then
    # Start all services
    docker compose up -d >> "$LOG" 2>&1
    echo "[$(date)] Services started" >> "$LOG"
    docker compose ps >> "$LOG" 2>&1
  else
    echo "[$(date)] BUILD FAILED — check log" >> "$LOG"
  fi
  
  echo "[$(date)] Deploy script finished" >> "$LOG"
' > /dev/null 2>&1 &

BGPID=$!
echo "[deploy] Background build started (PID: $BGPID)"
echo "[deploy] Monitor with: tail -f $LOG"
echo "[deploy] Build PID: $BGPID" > "$DEPLOY_DIR/build.pid"
