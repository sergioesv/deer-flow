# DeerFlow Backend - Railway Self-Contained Dockerfile
# Todo embebido: nginx + gateway + langgraph en un solo contenedor
FROM python:3.12-slim

ARG NODE_MAJOR=22

# Instalar dependencias del sistema + Node.js + nginx
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

# Instalar Docker CLI
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

# Instalar uv
COPY --from=ghcr.io/astral-sh/uv:0.7.20 /uv /uvx /usr/local/bin/

WORKDIR /app

# Copiar backend
COPY . ./backend

# Instalar dependencias Python
RUN sh -c "cd backend && uv sync"

# Escribir nginx.conf directamente (sin COPY externo)
RUN cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}
pid /tmp/nginx.pid;
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    access_log /dev/stdout;
    error_log /dev/stderr;

    upstream gateway {
        server 127.0.0.1:8001;
    }
    upstream langgraph {
        server 127.0.0.1:2024;
    }

    server {
        listen 8080 default_server;
        server_name _;

        proxy_hide_header 'Access-Control-Allow-Origin';
        proxy_hide_header 'Access-Control-Allow-Methods';
        proxy_hide_header 'Access-Control-Allow-Headers';
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' '*' always;

        if ($request_method = 'OPTIONS') {
            return 204;
        }

        location /api/langgraph/ {
            rewrite ^/api/langgraph/(.*) /$1 break;
            proxy_pass http://langgraph;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header Connection '';
            proxy_buffering off;
            proxy_cache off;
            proxy_set_header X-Accel-Buffering no;
            proxy_connect_timeout 600s;
            proxy_send_timeout 600s;
            proxy_read_timeout 600s;
            chunked_transfer_encoding on;
        }

        location /api/ {
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            client_max_body_size 100M;
        }

        location /docs {
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }

        location /health {
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }

        location /openapi.json {
            proxy_pass http://gateway;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }
    }
}
NGINX_EOF

# Escribir script de arranque directamente
RUN cat > /start.sh << 'START_EOF'
#!/bin/sh
set -e

echo "=== DeerFlow Backend Startup ==="

mkdir -p /app/backend/.deer-flow/threads
mkdir -p /app/backend/.langgraph_api
mkdir -p /tmp/nginx

echo "[1/3] Starting LangGraph Server on port 2024..."
cd /app/backend && uv run langgraph dev \
    --no-browser \
    --allow-blocking \
    --no-reload \
    --host 0.0.0.0 \
    --port 2024 &
LANGGRAPH_PID=$!

echo "[2/3] Starting Gateway on port 8001..."
cd /app/backend && PYTHONPATH=. uv run uvicorn app.gateway.app:app \
    --host 0.0.0.0 \
    --port 8001 \
    --workers 2 &
GATEWAY_PID=$!

echo "Waiting for services to initialize..."
sleep 8

echo "[3/3] Starting nginx on port 8080..."
nginx -g "daemon off;" &
NGINX_PID=$!

echo "=== All services running ==="

trap "kill $NGINX_PID $GATEWAY_PID $LANGGRAPH_PID 2>/dev/null; exit 0" TERM INT

while true; do
    if ! kill -0 $LANGGRAPH_PID 2>/dev/null; then
        echo "ERROR: LangGraph died. Exiting."
        kill $NGINX_PID $GATEWAY_PID 2>/dev/null
        exit 1
    fi
    if ! kill -0 $GATEWAY_PID 2>/dev/null; then
        echo "ERROR: Gateway died. Exiting."
        kill $NGINX_PID $LANGGRAPH_PID 2>/dev/null
        exit 1
    fi
    sleep 10
done
START_EOF

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
