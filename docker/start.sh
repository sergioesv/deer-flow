#!/bin/sh
set -e

echo "=== DeerFlow Backend Startup ==="

# Crear directorios necesarios
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
echo "LangGraph PID: $LANGGRAPH_PID"

echo "[2/3] Starting Gateway on port 8001..."
cd /app/backend && PYTHONPATH=. uv run uvicorn app.gateway.app:app \
    --host 0.0.0.0 \
    --port 8001 \
    --workers 2 &

GATEWAY_PID=$!
echo "Gateway PID: $GATEWAY_PID"

# Esperar que los servicios estén listos antes de arrancar nginx
echo "Waiting for services to initialize..."
sleep 5

echo "[3/3] Starting nginx on port 8080..."
nginx -g "daemon off;" &

NGINX_PID=$!
echo "nginx PID: $NGINX_PID"

echo "=== All services running ==="
echo "  nginx   (8080) PID: $NGINX_PID"
echo "  gateway (8001) PID: $GATEWAY_PID"
echo "  langgraph (2024) PID: $LANGGRAPH_PID"

# Mantener el contenedor vivo y propagar señales de parada
trap "kill $NGINX_PID $GATEWAY_PID $LANGGRAPH_PID 2>/dev/null; exit 0" TERM INT

# Monitorear procesos — si alguno muere, matar todo
while true; do
    if ! kill -0 $LANGGRAPH_PID 2>/dev/null; then
        echo "ERROR: LangGraph process died. Exiting."
        kill $NGINX_PID $GATEWAY_PID 2>/dev/null
        exit 1
    fi
    if ! kill -0 $GATEWAY_PID 2>/dev/null; then
        echo "ERROR: Gateway process died. Exiting."
        kill $NGINX_PID $LANGGRAPH_PID 2>/dev/null
        exit 1
    fi
    sleep 10
done
