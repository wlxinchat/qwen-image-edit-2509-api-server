#!/bin/bash

################################################################################
# Qwen Image Edit 2509 API Server - 一键部署脚本 (AutoDL优化版)
#
# 功能:
#   - 全面的环境检查和验证
#   - 自动配置数据盘以避免系统盘空间不足
#   - 自动安装依赖
#   - 自动下载模型
#   - 启动并验证服务
#   - 提供详细的错误诊断
#
# 作者: wlxinchat
# 邮箱: wlxinchat@gmail.com
################################################################################

set -e  # Exit on error

# ============================================================================
# 确定脚本和项目目录
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 切换到项目根目录
cd "$PROJECT_ROOT"
echo "Working directory: $PROJECT_ROOT"

# ============================================================================
# 颜色和样式定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# 配置变量
# ============================================================================
DATA_DIR="/root/autodl-tmp"
MODELS_DIR="$DATA_DIR/models"
LOGS_DIR="$DATA_DIR/logs"
CACHE_DIR="$DATA_DIR/cache"
PIP_CACHE_DIR="$DATA_DIR/pip_cache"
LOG_FILE="$LOGS_DIR/deploy.log"
API_PORT=8000
MAX_RETRIES=3

# 错误标志
HAS_ERROR=0
ERROR_MESSAGES=()

# ============================================================================
# 工具函数
# ============================================================================

# 打印带时间戳的日志
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

# 打印步骤标题
print_step() {
    echo ""
    echo -e "${BOLD}${BLUE}================================================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}================================================================${NC}"
    log "STEP: $1"
}

# 打印成功消息
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# 打印警告消息
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

# 打印错误消息
print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
    HAS_ERROR=1
    ERROR_MESSAGES+=("$1")
}

# 打印信息消息
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    log "INFO: $1"
}

# 执行命令并捕获错误
run_command() {
    local cmd="$1"
    local description="$2"

    log "Executing: $cmd"
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        print_success "$description"
        return 0
    else
        print_error "$description failed"
        return 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 重试执行命令
retry_command() {
    local cmd="$1"
    local description="$2"
    local retries="${3:-$MAX_RETRIES}"

    for i in $(seq 1 $retries); do
        if [ $i -gt 1 ]; then
            print_warning "Retry $((i-1))/$((retries-1)): $description"
            sleep $((2 ** (i-1)))  # 指数退避
        fi

        if run_command "$cmd" "$description"; then
            return 0
        fi
    done

    return 1
}

# ============================================================================
# 检查函数
# ============================================================================

check_python_version() {
    print_step "[1/10] 检查Python环境"

    if ! command_exists python3; then
        print_error "Python3 not found"
        return 1
    fi

    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    print_info "Python version: $python_version"

    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
        print_success "Python version is compatible (>= 3.8)"
        return 0
    else
        print_error "Python 3.8+ required, found $python_version"
        return 1
    fi
}

check_disk_space() {
    print_step "[2/10] 检查磁盘空间"

    # 检查系统盘
    local root_available=$(df -BG /root | tail -1 | awk '{print $4}' | sed 's/G//')
    print_info "System disk (/root): ${root_available}GB available"

    if [ "$root_available" -lt 5 ]; then
        print_warning "System disk space low (< 5GB), will use data disk for all caches"
    else
        print_success "System disk space sufficient"
    fi

    # 检查数据盘
    if [ -d "$DATA_DIR" ]; then
        local data_available=$(df -BG "$DATA_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
        print_info "Data disk ($DATA_DIR): ${data_available}GB available"

        if [ "$data_available" -lt 30 ]; then
            print_error "Data disk space insufficient (< 30GB). Need at least 30GB for models and cache."
            return 1
        else
            print_success "Data disk space sufficient (${data_available}GB)"
            return 0
        fi
    else
        print_error "Data directory $DATA_DIR not found. Is this an AutoDL environment?"
        return 1
    fi
}

check_gpu() {
    print_step "[3/10] 检查GPU环境"

    if command_exists nvidia-smi; then
        print_info "GPU Information:"
        nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv,noheader | while read line; do
            print_info "  $line"
        done
        print_success "GPU available"
        return 0
    else
        print_warning "nvidia-smi not found, GPU might not be available"
        print_warning "Service will run but might be slow without GPU"
        return 0  # 不是致命错误
    fi
}

setup_environment() {
    print_step "[4/10] 配置环境和目录结构"

    # 创建必要的目录
    print_info "Creating directories on data disk..."
    mkdir -p "$MODELS_DIR" "$LOGS_DIR" "$CACHE_DIR" "$PIP_CACHE_DIR"
    print_success "Directories created"

    # 配置pip缓存
    print_info "Configuring pip cache..."
    mkdir -p ~/.config/pip
    cat > ~/.config/pip/pip.conf <<EOF
[global]
cache-dir = $PIP_CACHE_DIR
EOF
    print_success "Pip cache configured to data disk"

    # 配置HuggingFace缓存
    print_info "Configuring HuggingFace cache..."
    export HF_HOME="$CACHE_DIR"
    export HUGGINGFACE_HUB_CACHE="$MODELS_DIR"
    export TRANSFORMERS_CACHE="$MODELS_DIR"
    export TORCH_HOME="$DATA_DIR/torch"

    # 添加到bashrc（如果尚未添加）
    if ! grep -q "HF_HOME=$CACHE_DIR" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc <<EOF

# Qwen Image Edit API Server - Cache Configuration
export HF_HOME=$CACHE_DIR
export HUGGINGFACE_HUB_CACHE=$MODELS_DIR
export TRANSFORMERS_CACHE=$MODELS_DIR
export TORCH_HOME=$DATA_DIR/torch
EOF
        print_success "Environment variables added to ~/.bashrc"
    else
        print_info "Environment variables already in ~/.bashrc"
    fi

    # 创建.env文件
    if [ ! -f .env ]; then
        cp .env.example .env
        print_success "Created .env file from template"
    else
        print_info ".env file already exists"
    fi

    return 0
}

install_dependencies() {
    print_step "[5/10] 安装Python依赖"

    print_info "Upgrading pip..."
    if ! retry_command "python3 -m pip install --upgrade pip --ignore-installed" "Upgrade pip"; then
        print_warning "Failed to upgrade pip, but continuing (current version should work)"
        print_info "Current pip version:"
        pip3 --version | tee -a "$LOG_FILE"
    fi

    print_info "Installing dependencies (this may take 5-10 minutes)..."
    print_info "Progress will be logged to: $LOG_FILE"

    if retry_command "pip3 install -r requirements.txt" "Install dependencies"; then
        print_success "All dependencies installed successfully"
        return 0
    else
        print_error "Failed to install dependencies. Check $LOG_FILE for details."
        return 1
    fi
}

verify_dependencies() {
    print_step "[6/10] 验证依赖安装"

    local missing_deps=0
    local packages=("fastapi" "uvicorn" "torch" "transformers" "PIL" "yaml" "loguru")

    for package in "${packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            print_success "$package installed"
        else
            print_error "$package not found"
            missing_deps=1
        fi
    done

    if [ $missing_deps -eq 0 ]; then
        print_success "All required packages verified"
        return 0
    else
        print_error "Some packages are missing"
        return 1
    fi
}

download_model() {
    print_step "[7/10] 下载模型"

    # 检查模型是否已存在
    local model_name=$(grep "MODEL_NAME=" .env 2>/dev/null | cut -d= -f2 || echo "Qwen/Qwen-Image-Edit-2509")
    model_name=${model_name:-"Qwen/Qwen-Image-Edit-2509"}

    # 智能检查：检查是否有完整的模型文件
    local model_exists=false
    if [ -d "$MODELS_DIR" ]; then
        # 检查关键文件：config.json 和模型权重文件
        local has_config=$(find "$MODELS_DIR" -name "config.json" -type f 2>/dev/null | head -1)
        local has_model=$(find "$MODELS_DIR" \( -name "*.bin" -o -name "*.safetensors" \) -type f 2>/dev/null | head -1)

        if [ -n "$has_config" ] && [ -n "$has_model" ]; then
            model_exists=true
            print_success "Model appears to be already downloaded in: $MODELS_DIR"
            print_info "Found config.json and model files"
            print_info "To force re-download, delete $MODELS_DIR"
            return 0
        elif [ "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
            print_warning "Model directory has files but appears incomplete"
            print_info "Cleaning up incomplete download and retrying..."
            rm -rf "$MODELS_DIR"/*
        fi
    fi

    print_info "Downloading model: $model_name"
    print_info "This may take 10-30 minutes depending on your network speed..."
    print_info "Model will be saved to: $MODELS_DIR"

    # 使用download_model.sh脚本
    if [ -f "scripts/download_model.sh" ]; then
        # 自动回答yes
        if echo "y" | bash scripts/download_model.sh >> "$LOG_FILE" 2>&1; then
            print_success "Model downloaded successfully"
            return 0
        else
            print_error "Model download failed. Check $LOG_FILE for details."
            print_info "You can manually download later using: bash scripts/download_model.sh"
            return 1
        fi
    else
        print_warning "download_model.sh not found, skipping model download"
        print_info "Please download model manually later"
        return 0
    fi
}

check_port_availability() {
    print_step "[8/10] 检查端口可用性"

    if lsof -Pi :$API_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port $API_PORT is already in use"
        print_info "Attempting to stop existing service..."

        local pid=$(lsof -Pi :$API_PORT -sTCP:LISTEN -t)
        if [ -n "$pid" ]; then
            kill -15 $pid 2>/dev/null || true
            sleep 2

            if lsof -Pi :$API_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
                print_error "Failed to free port $API_PORT"
                print_info "Please manually stop the service on port $API_PORT"
                return 1
            else
                print_success "Port $API_PORT freed"
            fi
        fi
    else
        print_success "Port $API_PORT is available"
    fi

    return 0
}

start_service() {
    print_step "[9/10] 启动服务"

    print_info "Starting API server on port $API_PORT..."

    # 后台启动服务
    nohup bash scripts/start_server.sh > "$LOGS_DIR/server.log" 2>&1 &
    local server_pid=$!

    print_info "Server PID: $server_pid"
    echo $server_pid > "$LOGS_DIR/server.pid"

    # 等待服务启动
    print_info "Waiting for service to start (max 60 seconds)..."
    local waited=0
    while [ $waited -lt 60 ]; do
        sleep 2
        waited=$((waited + 2))

        if lsof -Pi :$API_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_success "Service started successfully"
            return 0
        fi

        # 检查进程是否还在运行
        if ! kill -0 $server_pid 2>/dev/null; then
            print_error "Service process died unexpectedly"
            print_info "Check logs at: $LOGS_DIR/server.log"
            return 1
        fi

        echo -n "."
    done

    echo ""
    print_error "Service failed to start within 60 seconds"
    print_info "Check logs at: $LOGS_DIR/server.log"
    return 1
}

verify_service() {
    print_step "[10/10] 验证服务"

    print_info "Testing health endpoint..."

    local max_attempts=5
    for i in $(seq 1 $max_attempts); do
        if [ $i -gt 1 ]; then
            print_info "Attempt $i/$max_attempts..."
            sleep 3
        fi

        local response=$(curl -s -w "\n%{http_code}" http://localhost:$API_PORT/health 2>/dev/null)
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | head -1)

        if [ "$http_code" = "200" ]; then
            print_success "Health check passed!"
            print_info "Response: $body"

            # 测试API文档
            if curl -s http://localhost:$API_PORT/docs >/dev/null 2>&1; then
                print_success "API documentation accessible at: http://localhost:$API_PORT/docs"
            fi

            return 0
        fi
    done

    print_error "Health check failed after $max_attempts attempts"
    return 1
}

# ============================================================================
# 部署摘要和清理
# ============================================================================

print_summary() {
    echo ""
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                    部署完成摘要${NC}"
    echo -e "${BOLD}${MAGENTA}================================================================${NC}"

    if [ $HAS_ERROR -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ 部署成功！${NC}"
        echo ""
        echo -e "${BOLD}服务信息:${NC}"
        echo -e "  • API地址: ${CYAN}http://localhost:$API_PORT${NC}"
        echo -e "  • API文档: ${CYAN}http://localhost:$API_PORT/docs${NC}"
        echo -e "  • 健康检查: ${CYAN}http://localhost:$API_PORT/health${NC}"
        echo ""
        echo -e "${BOLD}重要路径:${NC}"
        echo -e "  • 模型目录: ${CYAN}$MODELS_DIR${NC}"
        echo -e "  • 日志目录: ${CYAN}$LOGS_DIR${NC}"
        echo -e "  • 部署日志: ${CYAN}$LOG_FILE${NC}"
        echo -e "  • 服务日志: ${CYAN}$LOGS_DIR/server.log${NC}"
        echo ""
        echo -e "${BOLD}测试API:${NC}"
        echo -e "  ${CYAN}curl http://localhost:$API_PORT/health${NC}"
        echo ""
        echo -e "${BOLD}停止服务:${NC}"
        echo -e "  ${CYAN}kill \$(cat $LOGS_DIR/server.pid)${NC}"
        echo ""
        echo -e "${BOLD}查看日志:${NC}"
        echo -e "  ${CYAN}tail -f $LOGS_DIR/server.log${NC}"
        echo ""
    else
        echo -e "${RED}${BOLD}✗ 部署失败${NC}"
        echo ""
        echo -e "${BOLD}错误列表:${NC}"
        for error in "${ERROR_MESSAGES[@]}"; do
            echo -e "  ${RED}• $error${NC}"
        done
        echo ""
        echo -e "${BOLD}诊断信息:${NC}"
        echo -e "  • 部署日志: ${CYAN}$LOG_FILE${NC}"
        echo -e "  • 查看日志: ${CYAN}tail -100 $LOG_FILE${NC}"
        echo ""
        echo -e "${BOLD}获取帮助:${NC}"
        echo -e "  • GitHub: ${CYAN}https://github.com/wlxinchat/qwen-image-edit-2509-api-server/issues${NC}"
        echo -e "  • Email: ${CYAN}wlxinchat@gmail.com${NC}"
        echo ""
    fi

    echo -e "${BOLD}${MAGENTA}================================================================${NC}"
}

cleanup_on_error() {
    if [ $HAS_ERROR -ne 0 ]; then
        print_warning "Cleaning up due to errors..."

        # 停止可能正在运行的服务
        if [ -f "$LOGS_DIR/server.pid" ]; then
            local pid=$(cat "$LOGS_DIR/server.pid")
            if kill -0 $pid 2>/dev/null; then
                kill -15 $pid 2>/dev/null || true
                print_info "Stopped server process"
            fi
            rm -f "$LOGS_DIR/server.pid"
        fi
    fi
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    # 打印横幅
    clear
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   Qwen Image Edit 2509 API Server - 一键部署脚本                ║
║                                                                  ║
║   Author: wlxinchat                                             ║
║   Email:  wlxinchat@gmail.com                                   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # 创建日志目录
    mkdir -p "$LOGS_DIR"

    # 开始部署
    log "================================"
    log "Deployment started"
    log "================================"

    # 执行各个步骤
    check_python_version || true
    check_disk_space || exit 1
    check_gpu || true
    setup_environment || exit 1
    install_dependencies || exit 1
    verify_dependencies || exit 1
    download_model || true  # 模型下载失败不致命，可以后续手动下载
    check_port_availability || exit 1
    start_service || exit 1
    verify_service || exit 1

    # 打印摘要
    print_summary

    # 清理
    cleanup_on_error

    # 返回状态
    if [ $HAS_ERROR -eq 0 ]; then
        log "Deployment completed successfully"
        return 0
    else
        log "Deployment failed with errors"
        return 1
    fi
}

# 捕获退出信号
trap cleanup_on_error EXIT

# 运行主程序
main "$@"
exit $?
