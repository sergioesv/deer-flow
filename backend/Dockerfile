# DeerFlow Backend - Railway Unified Dockerfile
# Runs: nginx (port 8080) + gateway (8001) + langgraph (2024) in one container
FROM python:3.12-slim

ARG NODE_MAJOR=22

# Install system dependencies + Node.js + nginx
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    gnupg \
    ca-certificates \
    nginx \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.7.20 /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy backend source
COPY backend ./backend

# Install Python dependencies
RUN sh -c "cd backend && uv sync"

# Copy nginx config
COPY docker/nginx/nginx.railway.conf /etc/nginx/nginx.conf

# Copy startup script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

# Railway exposes one port — nginx listens here and enruta internamente
EXPOSE 8080

CMD ["/start.sh"]
