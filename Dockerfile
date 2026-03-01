# syntax=docker/dockerfile:1

########################################
# Stage 1: Base System
########################################
FROM node:20-bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore

# Core packages + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    lsof \
    openssl \
    ca-certificates \
    gnupg \
    ripgrep fd-find fzf bat \
    pandoc \
    poppler-utils \
    ffmpeg \
    imagemagick \
    graphviz \
    sqlite3 \
    pass \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# CRITICAL FIX (native modules)
ENV PYTHON=/usr/bin/python3 \
    npm_config_python=/usr/bin/python3

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    npm install -g node-gyp

########################################
# Stage 2: Runtimes
########################################
FROM base AS runtimes

ENV BUN_INSTALL="/data/.bun" \
    PATH="/usr/local/go/bin:/data/.bun/bin:/data/.bun/install/global/bin:$PATH"

# Install Bun (allow bun to manage compatible node)
RUN curl -fsSL https://bun.sh/install | bash

# Python tools
RUN pip3 install ipython csvkit openpyxl python-docx pypdf botasaurus browser-use playwright --break-system-packages && \
    playwright install-deps

ENV XDG_CACHE_HOME="/data/.cache"

########################################
# Stage 3: Dependencies
########################################
FROM runtimes AS dependencies

ARG OPENCLAW_BETA=false
ENV OPENCLAW_BETA=${OPENCLAW_BETA} \
    OPENCLAW_NO_ONBOARD=1 \
    NPM_CONFIG_UNSAFE_PERM=true

# Bun global installs (with cache)
RUN --mount=type=cache,target=/data/.bun/install/cache \
    bun install -g vercel @marp-team/marp-cli https://github.com/tobi/qmd && \
    bun pm -g untrusted && \
    bun install -g @openai/codex @google/gemini-cli opencode-ai @steipete/summarize @hyperbrowser/agent clawhub

# Ensure global npm bin is in PATH
ENV PATH="/usr/local/bin:/usr/local/lib/node_modules/.bin:${PATH}"

# OpenClaw (npm install) - FIXED for npm 9+
RUN --mount=type=cache,target=/data/.npm \
    if [ "$OPENCLAW_BETA" = "true" ]; then \
        npm install -g openclaw@beta --legacy-peer-deps; \
    else \
        npm install -g openclaw --legacy-peer-deps; \
    fi && \
    echo "=== Verifying openclaw installation ===" && \
    which openclaw && openclaw --version

# Verify openclaw binary exists and create symlink if needed
RUN OPENCLAW_BIN=$(npm root -g)/../bin/openclaw && \
    if [ -f "$OPENCLAW_BIN" ]; then \
    ln -sf "$OPENCLAW_BIN" /usr/local/bin/openclaw; \
    echo "✅ OpenClaw binary linked to /usr/local/bin/openclaw"; \
    elif command -v openclaw &> /dev/null; then \
    echo "✅ OpenClaw already in PATH at $(which openclaw)"; \
    else \
    echo "⚠️ OpenClaw binary not found, checking npm global..." && \
    ls -la $(npm root -g)/../bin/ 2>/dev/null || true; \
    fi

# Install uv explicitly (FIXED: using astral-sh official installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Claude only (Kimi removed - script was failing)
RUN curl -fsSL https://claude.ai/install.sh | bash || true

# Make sure uv and other local bins are available
ENV PATH="/root/.local/bin:/root/.cargo/bin:${PATH}"

########################################
# Stage 4: Final
########################################
FROM dependencies AS final

WORKDIR /app
COPY . .

# Symlinks and ensure openclaw is accessible
RUN ln -sf /data/.claude/bin/claude /usr/local/bin/claude || true && \
    chmod +x /app/scripts/*.sh && \
    # Ensure openclaw binary is linked from npm global to /usr/local/bin
    OPENCLAW_BIN=$(npm root -g)/../bin/openclaw; \
    if [ -f "$OPENCLAW_BIN" ]; then \
        ln -sf "$OPENCLAW_BIN" /usr/local/bin/openclaw; \
        echo "✅ OpenClaw linked: /usr/local/bin/openclaw -> $OPENCLAW_BIN"; \
    fi

# Include npm global bin in PATH
ENV PATH="/root/.local/bin:/root/.cargo/bin:/usr/local/go/bin:/usr/local/bin:/usr/local/lib/node_modules/.bin:/usr/bin:/bin:/data/.bun/bin:/data/.bun/install/global/bin:/data/.claude/bin:$(npm root -g)/../bin"

# Verify openclaw is available - FAIL BUILD IF MISSING
RUN which openclaw && openclaw --version || (echo "❌ OPENCLAW INSTALLATION FAILED - BUILD ABORTED" && exit 1)

EXPOSE 18789
CMD ["bash", "/app/scripts/bootstrap.sh"]