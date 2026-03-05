# =============================================================================
# Symphony Docker Build
# Multi-stage build: builder (Elixir + Mix) -> runtime (Debian + Node + Codex)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Builder
# Build the Symphony escript binary using the official Elixir/Erlang image
# ---------------------------------------------------------------------------
FROM hexpm/elixir:1.19.0-erlang-27.3.4-debian-bookworm-20250428-slim AS builder

# Install build-time system deps
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone the Symphony Elixir source
ARG SYMPHONY_REPO=https://github.com/openai/symphony.git
ARG SYMPHONY_REF=main
RUN git clone --depth 1 --branch ${SYMPHONY_REF} ${SYMPHONY_REPO} . \
    && echo "Cloned symphony @ $(git rev-parse --short HEAD)"

WORKDIR /build/elixir

# Install Hex and Rebar (package managers for Elixir/Erlang)
RUN mix local.hex --force && mix local.rebar --force

# Fetch dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only prod

# Compile and build the escript binary
# `mix setup` installs/compiles deps; `mix build` produces bin/symphony
RUN mix setup && mix build

# Confirm the binary exists
RUN ls -lh bin/symphony

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# Minimal Debian image with Erlang runtime, Node.js (for Codex CLI), and mise
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

# Install runtime system dependencies
RUN apt-get update -y && apt-get install -y \
    # Erlang runtime (BEAM VM — required to run the escript)
    erlang-base \
    erlang-crypto \
    erlang-os-mon \
    erlang-sasl \
    erlang-ssl \
    # Process/shell utilities
    bash \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    procps \
    # Build tools (needed by some Codex npm deps)
    build-essential \
    # Locale support
    locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# Install Node.js 22 (LTS) via NodeSource
# Codex CLI requires Node.js >= 22
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

# ---------------------------------------------------------------------------
# Install Codex CLI globally
# ---------------------------------------------------------------------------
RUN npm install -g @openai/codex \
    && codex --version || true

# ---------------------------------------------------------------------------
# Install mise (polyglot runtime manager — used by Symphony hooks)
# ---------------------------------------------------------------------------
RUN curl https://mise.run | sh \
    && ln -sf /root/.local/bin/mise /usr/local/bin/mise \
    && mise --version

# ---------------------------------------------------------------------------
# Create a non-root user 'symphony' for running the app
# ---------------------------------------------------------------------------
RUN groupadd --gid 1000 symphony \
    && useradd --uid 1000 --gid symphony --shell /bin/bash --create-home symphony

# Make mise available to the symphony user
RUN mkdir -p /home/symphony/.local/bin \
    && cp /root/.local/bin/mise /home/symphony/.local/bin/mise \
    && chown -R symphony:symphony /home/symphony/.local

# Add mise to PATH for symphony user
ENV PATH="/home/symphony/.local/bin:/usr/local/bin:${PATH}"

# ---------------------------------------------------------------------------
# Set up the application directory
# ---------------------------------------------------------------------------
WORKDIR /app

# Copy the built escript binary from builder stage
COPY --from=builder /build/elixir/bin/symphony /app/bin/symphony
RUN chmod +x /app/bin/symphony

# Create runtime directories owned by symphony user
RUN mkdir -p /app/log /app/.codex \
    && chown -R symphony:symphony /app

# Switch to non-root user
USER symphony

# Expose the Phoenix LiveView dashboard port
EXPOSE 4000

# ---------------------------------------------------------------------------
# Default command
# Runs symphony with WORKFLOW.md and the Phoenix dashboard on port 4000
# WORKFLOW.md is expected to be bind-mounted at /app/WORKFLOW.md
# ---------------------------------------------------------------------------
CMD ["/app/bin/symphony", "/app/WORKFLOW.md", "--port", "4000"]
