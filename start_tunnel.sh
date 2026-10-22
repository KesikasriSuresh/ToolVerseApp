#!/bin/bash
# ToolVerse Backend Tunnel Starter
# Run this whenever you want to expose the backend to toolverse-kesh.web.app
# The domain is PERMANENT — no need to redeploy the Flutter app.

echo "🚀 Starting ToolVerse backend tunnel..."

# Kill any existing ngrok processes
pkill -f "ngrok" 2>/dev/null
sleep 1

# Start backend server if not already running
if ! curl -s http://127.0.0.1:8000/ > /dev/null 2>&1; then
  echo "⚡ Starting FastAPI backend..."
  DIR="$(cd "$(dirname "$0")" && pwd)"
  PYTHONPATH="$DIR" "$DIR/backend/.venv/bin/uvicorn" backend.app.main:app --host 0.0.0.0 --port 8000 &
  sleep 3
fi

# Start ngrok with permanent static domain
echo "🌐 Opening tunnel at https://many-marbled-refute.ngrok-free.dev ..."
ngrok http 8000 --domain=many-marbled-refute.ngrok-free.dev
