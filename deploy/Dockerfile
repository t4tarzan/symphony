# =============================================================================
# Symphony Docker Build
# Multi-stage build: builder (Elixir + Mix) -> runtime (same base + Node + Codex)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Builder — compile the Elixir escript
# ---------------------------------------------------------------------------
FROM hexpm/elixir:1.19.0-erlang-28.4-debian-bookworm-20260223-slim AS builder

RUN apt-get update -y && apt-get install -y \
    build-essential git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG SYMPHONY_REPO=https://github.com/openai/symphony.git
ARG SYMPHONY_REF=main
RUN git clone --depth 1 --branch ${SYMPHONY_REF} ${SYMPHONY_REPO} . \
    && echo "Cloned symphony @ $(git rev-parse --short HEAD)"

WORKDIR /build/elixir

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix setup && mix build
RUN ls -lh bin/symphony

# ---------------------------------------------------------------------------
# Stage 2: Runtime — Elixir base + Node.js 22 + Codex CLI
# ---------------------------------------------------------------------------
FROM hexpm/elixir:1.19.0-erlang-28.4-debian-bookworm-20260223-slim AS runtime

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y \
    bash curl wget git ca-certificates gnupg \
    procps build-essential locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

# Install Codex CLI
RUN npm install -g @openai/codex \
    && codex --version || true

# Install mise
RUN curl https://mise.run | sh \
    && ln -sf /root/.local/bin/mise /usr/local/bin/mise \
    && mise --version

# Create symphony user
RUN groupadd --gid 1000 symphony \
    && useradd --uid 1000 --gid symphony --shell /bin/bash --create-home symphony

RUN mkdir -p /home/symphony/.local/bin \
    && cp /root/.local/bin/mise /home/symphony/.local/bin/mise \
    && chown -R symphony:symphony /home/symphony/.local

ENV PATH="/home/symphony/.local/bin:/usr/local/bin:${PATH}"

WORKDIR /app

# Copy the escript binary from builder
COPY --from=builder /build/elixir/bin/symphony /app/bin/symphony
RUN chmod +x /app/bin/symphony

RUN mkdir -p /app/log /app/.codex \
    && chown -R symphony:symphony /app

USER symphony

EXPOSE 4000

CMD ["/app/bin/symphony", "/app/WORKFLOW.md", "--port", "4000", "--i-understand-that-this-will-be-running-without-the-usual-guardrails"]
