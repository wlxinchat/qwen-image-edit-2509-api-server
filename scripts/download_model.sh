#!/bin/bash

# Download Qwen Image Edit Model
# This script downloads the model to the data disk to avoid filling system disk

set -e

# Ensure we're in the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "================================================"
echo "Qwen Image Edit Model Downloader"
echo "================================================"
echo ""
echo "Working directory: $PROJECT_ROOT"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
MODEL_NAME=${MODEL_NAME:-"Qwen/qwen-image-edit-2509"}
MODELS_DIR=${MODELS_DIR:-"/root/autodl-tmp/models"}
HF_TOKEN=${HF_TOKEN:-""}

# Set environment variables
export HF_HOME="/root/autodl-tmp/cache"
export HUGGINGFACE_HUB_CACHE=$MODELS_DIR
export TRANSFORMERS_CACHE=$MODELS_DIR

echo -e "${YELLOW}Configuration:${NC}"
echo "  Model: $MODEL_NAME"
echo "  Download location: $MODELS_DIR"
echo ""

# Check disk space
echo -e "${YELLOW}Checking disk space...${NC}"
available_space=$(df $MODELS_DIR | tail -1 | awk '{print $4}')
echo "Available space: $(df -h $MODELS_DIR | tail -1 | awk '{print $4}')"
echo ""

# Warning about model size
echo -e "${YELLOW}Note: Model size may be several GB to tens of GB${NC}"
echo "Make sure you have enough space on the data disk"
echo ""
read -p "Continue with download? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled"
    exit 0
fi

# Create download script
echo -e "${YELLOW}Downloading model...${NC}"
python3 << EOF
import os
from transformers import AutoModelForCausalLM, AutoTokenizer

# Set cache directories
os.environ['HF_HOME'] = '$HF_HOME'
os.environ['HUGGINGFACE_HUB_CACHE'] = '$MODELS_DIR'
os.environ['TRANSFORMERS_CACHE'] = '$MODELS_DIR'

model_name = '$MODEL_NAME'
cache_dir = '$MODELS_DIR'
token = '$HF_TOKEN' if '$HF_TOKEN' else None

print(f"Downloading {model_name}...")
print(f"Cache directory: {cache_dir}")

try:
    # Download tokenizer (Qwen uses AutoTokenizer instead of AutoProcessor)
    print("\nDownloading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(
        model_name,
        cache_dir=cache_dir,
        trust_remote_code=True,
        token=token
    )
    print("✓ Tokenizer downloaded")

    # Download model
    print("\nDownloading model...")
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        cache_dir=cache_dir,
        trust_remote_code=True,
        token=token
    )
    print("✓ Model downloaded")

    print("\n" + "="*50)
    print("Download completed successfully!")
    print("="*50)

except Exception as e:
    print(f"\n✗ Error during download: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Model downloaded successfully!${NC}"
    echo ""
    echo "Model location: $MODELS_DIR"
    echo ""
    echo "Disk usage:"
    du -sh $MODELS_DIR
    echo ""
    echo "You can now start the server with: bash scripts/start_server.sh"
else
    echo -e "${RED}Failed to download model${NC}"
    exit 1
fi
