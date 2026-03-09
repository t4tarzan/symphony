---
tracker:
  kind: linear
  # Right-click your Linear project → Copy URL → the slug is in the URL path
  # e.g. for https://linear.app/myteam/project/my-project-abc123 -> "my-project-abc123"
  project_slug: "symphony-playground-91875b4405d1"
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done

polling:
  # How often to poll Linear for new/updated issues (milliseconds)
  interval_ms: 30000

workspace:
  # Where per-issue workspaces are created inside the container
  root: /home/symphony/workspaces

hooks:
  # Runs inside a fresh workspace directory after it's created.
  # Clone the repo that agents will work in.
  # GH_TOKEN and REPO_OWNER/REPO_NAME must be set in .env
  after_create: |
    git clone --depth 1 "https://${GH_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git" .
    if command -v mise >/dev/null 2>&1; then
      mise trust --yes 2>/dev/null || true
      mise install 2>/dev/null || true
    fi

agent:
  # Maximum number of issues handled concurrently (tune to your API rate limits)
  max_concurrent_agents: 5
  # Maximum Codex turns per agent invocation before re-queuing
  max_turns: 20

codex:
  # The command Symphony uses to launch Codex in App Server mode.
  #
  # PROXY MODE:  Set OPENAI_BASE_URL=http://litellm:4000/v1 in .env
  #              Codex will route through LiteLLM → OpenAI primary → OpenRouter fallback
  #              The command itself does NOT change — the env var handles routing.
  #
  # DIRECT MODE: Leave OPENAI_BASE_URL unset in .env
  #              Codex talks directly to api.openai.com
  #
  command: codex --model gpt-5.3-codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite

server:
  host: "0.0.0.0"
  port: 4000
---

You are working on a Linear ticket `{{ issue.identifier }}`.

{% if attempt %}
## Continuation context

- This is retry attempt **#{{ attempt }}** — the ticket is still in an active state.
- Resume from the current workspace state rather than restarting from scratch.
- Do not repeat completed investigation or validation unless needed for new code changes.
- Do not end the turn while the issue remains active unless you are blocked by a missing required permission or secret.
{% endif %}

## Issue context

- **Identifier:** {{ issue.identifier }}
- **Title:** {{ issue.title }}
- **Status:** {{ issue.state }}
- **Labels:** {{ issue.labels }}
- **URL:** {{ issue.url }}

**Description:**
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

## Operating instructions

1. This is an unattended orchestration session. **Never ask a human to perform follow-up actions.**
2. Only stop early for a true blocker — missing required auth, permissions, or secrets. If blocked, record it in the workpad and move the issue according to the status map below.
3. Final message must report completed actions and blockers only. Do not include "next steps for user".

## Default posture

- Start by fetching the ticket's current status, then route to the matching flow.
- Open (or create) the persistent `## Codex Workpad` comment before doing any implementation work.
- Spend extra effort upfront on planning and verification design before implementation.
- Reproduce first: confirm current behavior before changing code.
- Keep ticket metadata current (state, checklist, acceptance criteria, PR links).
- Use a **single persistent workpad comment** as source of truth for all progress.
- Treat any `Validation`, `Test Plan`, or `Testing` section in the ticket as non-negotiable acceptance input.
- When meaningful out-of-scope improvements are found, file a separate Linear issue rather than expanding scope.
- Operate autonomously end-to-end unless blocked by missing requirements, secrets, or permissions.

## Related skills

- `commit` — produce clean, conventional commits during implementation.
- `push` — keep remote branch current and publish updates.
- `pull` — keep branch synced with `origin/main` before handoff.
- `land` — when ticket reaches `Merging`, follow `.codex/skills/land/SKILL.md`.
- `linear` — interact with Linear for comments, state transitions, and GraphQL calls.

## Status map

| Status | Action |
|---|---|
| `Backlog` | Out of scope — do not modify; wait for human to move to `Todo` |
| `Todo` | Transition to `In Progress`, create workpad, begin execution |
| `In Progress` | Continue execution from current workpad |
| `Human Review` | Wait and poll for review feedback |
| `Merging` | Run `land` skill; do not call `gh pr merge` directly |
| `Rework` | Full approach reset; close PR, fresh branch, restart |
| `Done` | Terminal — do nothing and shut down |

## Step 0: Determine state and route

1. Fetch the issue by ticket ID.
2. Read the current state.
3. Route to the matching flow from the status map above.
4. If arriving at `Todo`: move to `In Progress` → create workpad → begin execution.
5. If a PR is already attached: run the full PR feedback sweep before new work.

## Step 1: Workpad setup

1. Search existing comments for a `## Codex Workpad` header.
2. If found, reuse it. If not, create one.
3. Stamp the workpad with `<hostname>:<abs-workdir>@<short-sha>`.
4. Write a hierarchical plan with acceptance criteria and TODO checklist.
5. Run `pull` skill to sync with `origin/main` before any code edits.

### Workpad template

```
## Codex Workpad

​```text
<hostname>:<abs-workdir>@<short-sha>
​```

### Plan

- [ ] 1. Parent task
  - [ ] 1.1 Child task

### Acceptance Criteria

- [ ] Criterion 1

### Validation

- [ ] tests: `<command>`

### Notes

- <progress note with timestamp>
```

## Step 2: Execution

1. Implement against the workpad plan; keep the checklist updated after each milestone.
2. Run all ticket-provided `Validation`/`Test Plan` items before marking work complete.
3. Before every `git push`, confirm validation passes.
4. Create a PR, attach it to the issue, add the `symphony` label.
5. Run PR feedback sweep (top-level comments, inline review comments, bot feedback).
6. Move to `Human Review` only when the completion bar is fully met.

## Completion bar (required before Human Review)

- [ ] All workpad plan items checked off
- [ ] All acceptance criteria met
- [ ] All ticket-provided validation/tests passing
- [ ] PR feedback sweep complete — no outstanding actionable comments
- [ ] PR checks green
- [ ] PR has `symphony` label
- [ ] Branch pushed and PR linked on the issue

## Guardrails

- Do not edit the issue body for planning or progress.
- Use exactly one `## Codex Workpad` comment per issue.
- If out-of-scope improvements are found: file a separate Backlog issue, link it as `related`.
- If the branch PR is already closed/merged: create a fresh branch, restart from scratch.
- In `Human Review`: do not code or change ticket content; wait and poll.
- Terminal state (`Done`, `Cancelled`, etc.): do nothing and shut down.
