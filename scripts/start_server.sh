#!/bin/bash

# Start Qwen Image Edit API Server

set -e

# Ensure we're in the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "================================================"
echo "Starting Qwen Image Edit API Server"
echo "================================================"
echo ""
echo "Working directory: $PROJECT_ROOT"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Set environment variables for cache directories
export HF_HOME="/root/autodl-tmp/cache"
export HUGGINGFACE_HUB_CACHE="/root/autodl-tmp/models"
export TRANSFORMERS_CACHE="/root/autodl-tmp/models"
export TORCH_HOME="/root/autodl-tmp/torch"

# Load .env file if exists
if [ -f .env ]; then
    echo -e "${YELLOW}Loading .env file...${NC}"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Get configuration
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
WORKERS=${WORKERS:-1}

echo "Server configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Workers: $WORKERS"
echo ""

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}Port $PORT is already in use!${NC}"
    echo "Please stop the existing service or use a different port"
    exit 1
fi

# Check GPU availability
echo -e "${YELLOW}Checking GPU...${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv
    echo ""
else
    echo -e "${YELLOW}nvidia-smi not found, GPU info unavailable${NC}"
    echo ""
fi

# Start server
echo -e "${GREEN}Starting server...${NC}"
echo ""
echo "Access the API at: http://$HOST:$PORT"
echo "API documentation: http://$HOST:$PORT/docs"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run with uvicorn directly
python3 -m uvicorn app.main:app \
    --host $HOST \
    --port $PORT \
    --workers $WORKERS \
    --log-level info
