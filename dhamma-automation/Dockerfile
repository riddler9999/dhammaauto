FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    jq \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY prompts ./prompts
COPY scripts ./scripts
COPY CLAUDE.md ./CLAUDE.md

RUN chmod +x ./scripts/*.sh && mkdir -p /app/workspace /app/config

ENTRYPOINT ["bash"]
CMD ["-lc", "echo 'Container ready. Run scripts from /app/scripts' && bash"]
