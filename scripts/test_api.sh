#!/bin/bash

# API Testing Script

set -e

echo "================================================"
echo "Qwen Image Edit API - Test Script"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
API_BASE_URL=${API_BASE_URL:-"http://localhost:8000"}
API_KEY=${API_KEY:-""}

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
response=$(curl -s "$API_BASE_URL/health")
if echo "$response" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "Response: $response"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Response: $response"
    exit 1
fi
echo ""

# Test 2: Root Endpoint
echo -e "${YELLOW}Test 2: Root Endpoint${NC}"
response=$(curl -s "$API_BASE_URL/")
if echo "$response" | grep -q "Qwen Image Edit"; then
    echo -e "${GREEN}✓ Root endpoint working${NC}"
    echo "Response: $response"
else
    echo -e "${RED}✗ Root endpoint failed${NC}"
    echo "Response: $response"
fi
echo ""

# Test 3: API Documentation
echo -e "${YELLOW}Test 3: API Documentation${NC}"
docs_status=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL/docs")
if [ "$docs_status" -eq 200 ]; then
    echo -e "${GREEN}✓ API docs accessible${NC}"
    echo "Docs URL: $API_BASE_URL/docs"
else
    echo -e "${RED}✗ API docs not accessible${NC}"
fi
echo ""

# Test 4: Model Info
echo -e "${YELLOW}Test 4: Model Info${NC}"
if [ -n "$API_KEY" ]; then
    response=$(curl -s -H "X-API-Key: $API_KEY" "$API_BASE_URL/api/v1/model/info")
else
    response=$(curl -s "$API_BASE_URL/api/v1/model/info")
fi
echo "Response: $response"
echo ""

# Test 5: Load Model
echo -e "${YELLOW}Test 5: Load Model${NC}"
echo "This may take a few minutes..."
if [ -n "$API_KEY" ]; then
    response=$(curl -s -X POST -H "X-API-Key: $API_KEY" "$API_BASE_URL/api/v1/model/load")
else
    response=$(curl -s -X POST "$API_BASE_URL/api/v1/model/load")
fi

if echo "$response" | grep -q "success"; then
    echo -e "${GREEN}✓ Model loaded successfully${NC}"
    echo "Response: $response"
else
    echo -e "${YELLOW}⚠ Model load response: $response${NC}"
fi
echo ""

# Test 6: Image Edit (if test image exists)
if [ -f "test.jpg" ] || [ -f "test.png" ]; then
    echo -e "${YELLOW}Test 6: Image Edit${NC}"

    TEST_IMAGE="test.jpg"
    if [ ! -f "$TEST_IMAGE" ]; then
        TEST_IMAGE="test.png"
    fi

    echo "Using test image: $TEST_IMAGE"

    if [ -n "$API_KEY" ]; then
        curl -X POST "$API_BASE_URL/api/v1/edit" \
            -H "X-API-Key: $API_KEY" \
            -F "image=@$TEST_IMAGE" \
            -F "prompt=Convert to grayscale" \
            -F "output_format=PNG" \
            -o test_output.png
    else
        curl -X POST "$API_BASE_URL/api/v1/edit" \
            -F "image=@$TEST_IMAGE" \
            -F "prompt=Convert to grayscale" \
            -F "output_format=PNG" \
            -o test_output.png
    fi

    if [ -f "test_output.png" ]; then
        echo -e "${GREEN}✓ Image edit successful${NC}"
        echo "Output saved to: test_output.png"
    else
        echo -e "${RED}✗ Image edit failed${NC}"
    fi
else
    echo -e "${YELLOW}Test 6: Image Edit - Skipped (no test image found)${NC}"
    echo "Create a test.jpg or test.png to test image editing"
fi
echo ""

echo "================================================"
echo -e "${GREEN}Testing completed!${NC}"
echo "================================================"
echo ""
echo "To test image editing, place a test.jpg or test.png in the current directory and run again."
echo ""
