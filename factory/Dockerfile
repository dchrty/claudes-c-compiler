# Slim, pluggable agent image. The factory.yaml `toolchain` section
# is materialized into build-args at image-build time.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Always-on baseline: git, curl, node (for claude-code), python (for judge),
# build-essential (most projects need it).
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates sudo bc jq python3 python3-pip \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# Project-specific apt packages (rendered from factory.yaml toolchain.apt).
ARG EXTRA_APT=""
RUN if [ -n "$EXTRA_APT" ]; then \
      apt-get update && apt-get install -y --no-install-recommends $EXTRA_APT \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Node + Claude Code CLI.
ARG NODE_VERSION=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

RUN pip3 install --no-cache-dir anthropic pyyaml

# Non-root agent user with passwordless sudo (needed for in-container apt etc.).
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
RUN git config --global user.name "Claude Agent" \
    && git config --global user.email "noreply@anthropic.com" \
    && git config --global pull.rebase true

# Factory scripts mount in at /factory; entrypoint lives there.
ENTRYPOINT ["/factory/scripts/entrypoint.sh"]
