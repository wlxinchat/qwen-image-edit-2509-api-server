#!/bin/bash

# Qwen Image Edit 2509 API Server - Autodl Setup Script
# This script handles the special requirements of autodl environment,
# particularly dealing with limited system disk space

set -e  # Exit on error

echo "================================================"
echo "Qwen Image Edit 2509 API Server - Autodl Setup"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DATA_DIR="/root/autodl-tmp"
MODELS_DIR="$DATA_DIR/models"
LOGS_DIR="$DATA_DIR/logs"
CACHE_DIR="$DATA_DIR/cache"
PIP_CACHE_DIR="$DATA_DIR/pip_cache"

echo -e "${YELLOW}Step 1: Checking environment...${NC}"
echo "System disk space:"
df -h /root
echo ""
echo "Data disk space:"
df -h $DATA_DIR
echo ""

# Create necessary directories on data disk
echo -e "${YELLOW}Step 2: Creating directories on data disk...${NC}"
mkdir -p $MODELS_DIR
mkdir -p $LOGS_DIR
mkdir -p $CACHE_DIR
mkdir -p $PIP_CACHE_DIR
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Configure pip to use data disk for cache
echo -e "${YELLOW}Step 3: Configuring pip cache to data disk...${NC}"
mkdir -p ~/.config/pip
cat > ~/.config/pip/pip.conf <<EOF
[global]
cache-dir = $PIP_CACHE_DIR
EOF
echo -e "${GREEN}✓ Pip cache configured to $PIP_CACHE_DIR${NC}"
echo ""

# Set up HuggingFace cache directory
echo -e "${YELLOW}Step 4: Configuring HuggingFace cache...${NC}"
export HF_HOME=$CACHE_DIR
export HUGGINGFACE_HUB_CACHE=$MODELS_DIR
export TRANSFORMERS_CACHE=$MODELS_DIR

# Add to .bashrc for persistence
if ! grep -q "HF_HOME=$CACHE_DIR" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# HuggingFace cache configuration" >> ~/.bashrc
    echo "export HF_HOME=$CACHE_DIR" >> ~/.bashrc
    echo "export HUGGINGFACE_HUB_CACHE=$MODELS_DIR" >> ~/.bashrc
    echo "export TRANSFORMERS_CACHE=$MODELS_DIR" >> ~/.bashrc
fi
echo -e "${GREEN}✓ HuggingFace cache configured${NC}"
echo ""

# Move conda cache to data disk if using conda
echo -e "${YELLOW}Step 5: Configuring conda cache (if applicable)...${NC}"
if command -v conda &> /dev/null; then
    CONDA_CACHE_DIR="$DATA_DIR/conda_cache"
    mkdir -p $CONDA_CACHE_DIR
    conda config --add pkgs_dirs $CONDA_CACHE_DIR
    echo -e "${GREEN}✓ Conda cache configured to $CONDA_CACHE_DIR${NC}"
else
    echo "Conda not found, skipping..."
fi
echo ""

# Set PyTorch cache
echo -e "${YELLOW}Step 6: Configuring PyTorch cache...${NC}"
TORCH_HOME="$DATA_DIR/torch"
mkdir -p $TORCH_HOME
export TORCH_HOME=$TORCH_HOME

if ! grep -q "TORCH_HOME=$TORCH_HOME" ~/.bashrc; then
    echo "export TORCH_HOME=$TORCH_HOME" >> ~/.bashrc
fi
echo -e "${GREEN}✓ PyTorch cache configured to $TORCH_HOME${NC}"
echo ""

# Check Python version
echo -e "${YELLOW}Step 7: Checking Python version...${NC}"
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"
if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
    echo -e "${GREEN}✓ Python version is sufficient${NC}"
else
    echo -e "${RED}✗ Python 3.8 or higher is required${NC}"
    exit 1
fi
echo ""

# Install dependencies
echo -e "${YELLOW}Step 8: Installing Python dependencies...${NC}"
echo "This may take a while as packages will be downloaded..."
pip3 install --upgrade pip
pip3 install -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Create .env file if not exists
echo -e "${YELLOW}Step 9: Setting up environment configuration...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file from template${NC}"
    echo -e "${YELLOW}Please edit .env file to customize your configuration${NC}"
else
    echo ".env file already exists, skipping..."
fi
echo ""

# Display disk usage
echo -e "${YELLOW}Step 10: Final disk space check...${NC}"
echo "System disk:"
df -h /root | grep -E "Filesystem|/dev"
echo ""
echo "Data disk:"
df -h $DATA_DIR | grep -E "Filesystem|/dev"
echo ""

# Display next steps
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Edit config.yaml and .env to customize your configuration"
echo "2. Download the model using: bash scripts/download_model.sh"
echo "3. Start the server using: bash scripts/start_server.sh"
echo ""
echo "Configuration locations:"
echo "  - Models: $MODELS_DIR"
echo "  - Logs: $LOGS_DIR"
echo "  - Cache: $CACHE_DIR"
echo ""
echo "To activate environment variables in current shell, run:"
echo "  source ~/.bashrc"
echo ""
