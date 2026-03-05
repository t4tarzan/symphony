# Symphony Docker Deployment

A production-ready Docker Compose deployment for [OpenAI Symphony](https://github.com/openai/symphony) with automatic OpenRouter fallback via LiteLLM proxy.

Symphony polls your Linear board, creates isolated workspaces per issue, and launches Codex coding agents to implement the work autonomously.

---

## Architecture

```
                        ┌─────────────────────────────────────────┐
                        │           Docker host (VPS)              │
                        │                                          │
  Linear board ────────►│  ┌─────────────┐                        │
  (polling every 30s)   │  │  Symphony   │  port 4000             │
                        │  │ (Elixir/OTP)│◄──────── browser       │
                        │  │             │  Phoenix dashboard      │
                        │  └──────┬──────┘                        │
                        │         │ spawns Codex per issue        │
                        │         ▼                               │
                        │  ┌─────────────────────┐               │
                        │  │  Codex app-server   │               │
                        │  │  (Node.js process)  │               │
                        │  │  per-issue workspace│               │
                        │  └──────────┬──────────┘               │
                        │             │ OPENAI_BASE_URL           │
                        │             ▼                           │
  PROXY MODE:           │  ┌──────────────────┐  port 4001       │
                        │  │   LiteLLM Proxy  │◄────── direct  │
                        │  │  (ghcr.io/berriai)│                 │
                        │  └────┬─────────────┘                  │
                        │       │              │                  │
                        └───────┼──────────────┼──────────────────┘
                                │              │
                    ┌───────────▼──┐    ┌──────▼─────────┐
                    │  OpenAI API  │    │  OpenRouter API  │
                    │ (primary)    │    │ (fallback)       │
                    │ api.openai   │    │ openrouter.ai    │
                    │ .com/v1      │    │ /api/v1          │
                    └──────────────┘    └──────────────────┘

  DIRECT MODE: Codex → OpenAI 
  (set OPENAI_BASE_URL= in .env, or remove it entirely)
```

---

## Quick start

```bash
git clone https://github.com/t4tarzan/symphony.git
cd symphony/deploy
./setup.sh
```

`setup.sh` will:
1. Check prerequisites (Docker, Git)
2. Create `.env` from `.env.example` if missing
3. Prompt you to fill in API keys
4. Ask you to choose direct or proxy mode
5. Build the Docker image
6. Start all containers

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Docker ≥ 24 | With Compose v2 plugin (`docker compose`) |
| Git | For workspace cloning in `after_create` hook |
| OpenAI API key | Required for Codex agents |
| Linear API key | For issue polling |
| GitHub token | For workspace repo cloning and PR creation |
| OpenRouter API key | Optional — only needed for proxy mode fallback |

---

## Configuration

### `.env` file

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
nano .env
```

| Variable | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | Yes | OpenAI API key for Codex |
| `LINEAR_API_KEY` | Yes | Linear API key for issue polling |
| `GH_TOKEN` | Yes | GitHub personal access token |
| `GITHUB_TOKEN` | Yes | Same as `GH_TOKEN` (some tools use this name) |
| `OPENROUTER_API_KEY` | Proxy mode | OpenRouter key for fallback routing |
| `LITELLM_MASTER_KEY` | Proxy mode | LiteLLM admin key (default: `sk-symphony-master`) |
| `OPENAI_BASE_URL` | Proxy mode | Set to `http://litellm:4000/v1` |
| `REPO_OWNER` | Yes | GitHub org/user owning the target repo |
| `REPO_NAME` | Yes | GitHub repo name for workspace cloning |

### `WORKFLOW.md`

The `WORKFLOW.md` file is the prompt template for Codex agents. The top YAML front-matter configures Symphony; the Markdown body is the prompt.

Key settings to customize:

```yaml
tracker:
  project_slug: "YOUR_PROJECT_SLUG"  # Your Linear project slug

codex:
  command: codex --model gpt-5.3-codex app-server  # Codex model/flags

agent:
  max_concurrent_agents: 5  # Tune to your API rate limits
```

---

## Operation modes

### Direct mode

Codex talks directly to OpenAI. Simpler, no fallback.

```
Codex → api.openai.com/v1
```

To use: leave `OPENAI_BASE_URL` unset in `.env`, or run `./setup.sh direct`.

### Proxy mode (recommended)

Codex talks through LiteLLM, which routes to OpenAI first and falls back to OpenRouter if OpenAI fails or rate-limits.

```
Codex → litellm:4000/v1 → OpenAI (primary) → OpenRouter (fallback)
```

To use: set `OPENAI_BASE_URL=http://litellm:4000/v1` in `.env`, or run `./setup.sh proxy`.

---

## Ports

| Port | Service | Description |
|---|---|---|
| `4000` | Symphony | Phoenix LiveView dashboard |
| `4001` | LiteLLM | OpenAI-compatible proxy API |

---

## Directories

```
deploy/
├── Dockerfile           # Multi-stage build (builder → runtime)
├── docker-compose.yml   # Symphony + LiteLLM + Watchtower
├── WORKFLOW.md          # Codex agent prompt template
├── setup.sh             # Setup + launch script
├── .env.example         # Environment variable template
├── .gitignore           # Git ignore rules
├── .dockerignore        # Docker build context ignore rules
├── litellm-config.yaml  # LiteLLM model/routing config
├── Makefile             # Convenience shortcuts
├── README.md            # This file
└── .codex/
    └── skills/
        ├── commit/SKILL.md  # Git commit conventions
        ├── push/SKILL.md    # Branch push procedures
        ├── pull/SKILL.md    # Rebase/merge procedures
        ├── land/SKILL.md    # PR landing procedure
        └── linear/SKILL.md  # Linear GraphQL API helper
```

---

## Codex skills

The `.codex/skills/` directory ships read-only skills that Codex agents read before acting.

| Skill | Purpose |
|---|---|
| `commit` | Conventional commits, atomic changes, commit message format |
| `push` | Branch push, remote sync, force-with-lease |
| `pull` | Rebase against `origin/main`, conflict resolution |
| `land` | PR merge procedure when ticket reaches `Merging` state |
| `linear` | Linear GraphQL API: state transitions, comments, issue creation |

---

## Troubleshooting

### Symphony won't start

```bash
docker compose logs symphony
```

Common causes:
- `WORKFLOW.md` not found — make sure it's bind-mounted at `/app/WORKFLOW.md`
- Missing env vars — check `.env` is populated
- Linear connection failure — verify `LINEAR_API_KEY`

### LiteLLM health check failing

```bash
docker compose logs litellm
curl http://localhost:4001/health
```

Common causes:
- `litellm-config.yaml` not found or invalid YAML
- `OPENAI_API_KEY` not set

### Codex agents not picking up tasks

1. Check `WORKFLOW.md` has correct `project_slug`
2. Verify Linear issues are in `Todo` or `In Progress` state
3. Check `GH_TOKEN` has repo read/write access
4. Check `OPENAI_API_KEY` is valid and has quota

### Docker build fails

```bash
docker compose build --no-cache symphony
```

The build clones Symphony from GitHub, so it needs internet access and the repo must be public (or a token must be configured).

---

## Updating

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose build symphony
docker compose up -d
```

Watchtower handles automatic image updates for LiteLLM. For Symphony itself, rebuild as above.

---

## Security notes

- Never commit `.env` — it's in `.gitignore`
- The `symphony` container runs as a non-root user (uid 1000)
- `WORKFLOW.md` and `.codex/` are bind-mounted read-only
- LiteLLM is only accessible on the internal `symphony-net` network unless you expose port 4001
- Rotate `LITELLM_MASTER_KEY` if you expose LiteLLM externally

---

## License

MIT. See [LICENSE](../LICENSE) in the root of this repository.
