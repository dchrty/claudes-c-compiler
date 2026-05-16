# Slim, pluggable agent image. The factory.yaml `toolchain` section
# is materialized into build-args at image-build time.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Always-on baseline.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates sudo bc jq python3 gettext-base \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# yq (mikefarah/yq v4) — used by every script that reads factory.yaml.
RUN curl -fsSL -o /usr/local/bin/yq \
      https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Project-specific apt packages (rendered from factory.yaml toolchain.apt).
ARG EXTRA_APT=""
RUN if [ -n "$EXTRA_APT" ]; then \
      apt-get update && apt-get install -y --no-install-recommends $EXTRA_APT \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Node + agent CLIs. Both adapters are installed; factory.yaml picks one.
ARG NODE_VERSION=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @openai/codex @anthropic-ai/claude-code

# Non-root agent user with passwordless sudo (in-container apt etc.).
RUN useradd -m -s /bin/bash agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /workspace /factory && chown -R agent:agent /workspace /factory

USER agent
WORKDIR /workspace

# Optional Rust toolchain.
ARG INSTALL_RUST=""
ARG RUST_TOOLCHAIN="stable"
RUN if [ "$INSTALL_RUST" = "true" ]; then \
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain ${RUST_TOOLCHAIN}; \
    fi
ENV PATH="/home/agent/.cargo/bin:${PATH}"

# Identity for commits.
RUN git config --global user.name "Factory Agent" \
    && git config --global user.email "noreply@example.com" \
    && git config --global pull.rebase true

ENTRYPOINT ["/factory/scripts/entrypoint.sh"]
