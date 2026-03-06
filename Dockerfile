FROM node:22-slim

ARG CLAUDE_VERSION=latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}"

ENTRYPOINT ["claude"]
