FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG USERNAME=vscode

# ---- 基本ツール ----
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        build-essential \
        jq \
        ripgrep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js (LTS) + Claude Code CLI ----
# NodeSource から Node.js 22 (LTS) を導入し、Claude Code をグローバルインストール
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

# ---- Foundry (forge / cast / anvil / chisel) ----
# vscode ユーザーとして foundryup を実行し、最新の安定版を取得する
USER ${USERNAME}
ENV FOUNDRY_DIR=/home/${USERNAME}/.foundry
ENV PATH=${FOUNDRY_DIR}/bin:${PATH}
RUN curl -L https://foundry.paradigm.xyz | bash \
    && ${FOUNDRY_DIR}/bin/foundryup

USER root
