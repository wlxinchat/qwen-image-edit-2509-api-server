#!/bin/bash

# Monitor script for checking server status and resource usage

echo "================================================"
echo "Qwen Image Edit API Server - Monitor"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if server is running
PORT=${PORT:-8000}
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is running on port $PORT${NC}"
else
    echo -e "${RED}✗ Server is not running${NC}"
fi
echo ""

# Check GPU status
echo -e "${YELLOW}GPU Status:${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    echo "nvidia-smi not available"
fi
echo ""

# Check disk usage
echo -e "${YELLOW}Disk Usage:${NC}"
echo "System disk:"
df -h /root | head -2
echo ""
echo "Data disk:"
df -h /root/autodl-tmp | head -2
echo ""

# Check memory usage
echo -e "${YELLOW}Memory Usage:${NC}"
free -h
echo ""

# Check model directory size
if [ -d "/root/autodl-tmp/models" ]; then
    echo -e "${YELLOW}Model Directory Size:${NC}"
    du -sh /root/autodl-tmp/models
    echo ""
fi

# Check log file
LOG_FILE="/root/autodl-tmp/logs/api_server.log"
if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Recent Logs (last 20 lines):${NC}"
    tail -20 "$LOG_FILE"
    echo ""
fi

# Test API endpoint
echo -e "${YELLOW}Testing API Health Endpoint:${NC}"
if command -v curl &> /dev/null; then
    curl -s http://localhost:$PORT/health | python3 -m json.tool || echo "Failed to reach health endpoint"
else
    echo "curl not available"
fi
echo ""
