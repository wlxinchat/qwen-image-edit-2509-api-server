# AutoDL RTX 5090 部署指南

本指南专门针对AutoDL平台RTX 5090 GPU环境的详细部署步骤。

## ⚡ 快速开始（推荐）

### 一键部署

最简单的部署方式，适合大多数用户：

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
bash scripts/deploy.sh
```

该脚本会自动完成：
- ✅ 检查Python环境和版本
- ✅ 检查磁盘空间（系统盘和数据盘）
- ✅ 检查GPU可用性
- ✅ 配置数据盘缓存路径
- ✅ 安装所有Python依赖
- ✅ 验证依赖安装
- ✅ 下载模型到数据盘
- ✅ 检查端口可用性
- ✅ 启动API服务
- ✅ 验证服务正常运行

**部署时间**: 约15-30分钟（取决于网络速度）

部署完成后，你会看到类似如下的摘要信息：
```
✓ 部署成功！

服务信息:
  • API地址: http://localhost:8000
  • API文档: http://localhost:8000/docs
  • 健康检查: http://localhost:8000/health
```

---

## 📋 前置准备

### 1. AutoDL实例配置推荐

- **GPU**: RTX 5090 (24GB显存)
- **系统盘**: 默认即可（本方案不会占用太多系统盘空间）
- **数据盘**: 至少50GB（用于存储模型和缓存）
- **镜像**: PyTorch 2.1.0 / Python 3.10 / CUDA 11.8

### 2. 登录实例

通过AutoDL控制台登录到你的实例，或使用SSH：

```bash
ssh root@your-instance-ip -p your-port
```

---

## 🚀 手动部署（高级用户）

如果你想要更多控制，可以按以下步骤手动部署：

### 步骤 1: 克隆项目

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
```

### 步骤 2: 检查磁盘空间

```bash
df -h
```

确认 `/root/autodl-tmp` 有足够的空间（至少30GB）。

### 步骤 3: 运行环境检查（可选）

```bash
python3 scripts/check_env.py
```

### 步骤 4: 运行自动设置脚本

```bash
bash scripts/setup_autodl.sh
```

这个脚本会：
- ✅ 检查环境（Python版本、磁盘空间）
- ✅ 在数据盘创建目录结构
- ✅ 配置pip缓存到数据盘
- ✅ 配置HuggingFace缓存到数据盘
- ✅ 配置PyTorch缓存到数据盘
- ✅ 安装所有Python依赖包

**预计时间**: 5-10分钟（取决于网络速度）

### 步骤 4: 激活环境变量

```bash
source ~/.bashrc
```

### 步骤 5: 配置服务

#### 方式A: 使用环境变量（推荐）

编辑 `.env` 文件：

```bash
vim .env
```

修改必要的配置：

```bash
# 如果需要认证，设置API密钥
API_KEY=your-secret-key

# 如果需要HuggingFace Token（私有模型）
HF_TOKEN=your-hf-token

# 其他配置通常使用默认值即可
```

#### 方式B: 使用配置文件

编辑 `config.yaml`：

```bash
vim config.yaml
```

### 步骤 6: 下载模型

```bash
bash scripts/download_model.sh
```

这会下载Qwen模型到数据盘。根据网络速度，这可能需要10-30分钟。

**注意**: 模型大小约为10-20GB，请确保有足够的磁盘空间。

### 步骤 7: 测试启动

```bash
bash scripts/start_server.sh
```

如果一切正常，你会看到：

```
INFO:     Started server process [xxxxx]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 步骤 8: 测试API

打开新的终端，测试健康检查：

```bash
curl http://localhost:8000/health
```

应该返回：

```json
{
  "status": "healthy",
  "model_loaded": false,
  "timestamp": 1234567890.123
}
```

### 步骤 9: 加载模型

```bash
curl -X POST http://localhost:8000/api/v1/model/load
```

**注意**: 首次加载模型可能需要几分钟。

### 步骤 10: 测试图片编辑

准备一张测试图片，然后：

```bash
curl -X POST http://localhost:8000/api/v1/edit \
  -F "image=@test.jpg" \
  -F "prompt=将这张图片转换为黑白" \
  -F "output_format=PNG" \
  -o result.png
```

## 🔧 高级配置

### 1. 显存优化

如果遇到显存不足（OOM）错误，可以启用量化：

编辑 `config.yaml`:

```yaml
model:
  load_in_8bit: true  # 8bit量化，约节省50%显存
  # 或
  load_in_4bit: true  # 4bit量化，约节省75%显存（但可能影响质量）
```

### 2. 后台运行

使用 `screen` 或 `tmux` 在后台运行：

```bash
# 使用screen
screen -S qwen-api
bash scripts/start_server.sh
# 按 Ctrl+A, D 分离会话

# 重新连接
screen -r qwen-api
```

或使用 `nohup`:

```bash
nohup bash scripts/start_server.sh > server.log 2>&1 &
```

### 3. 设置开机自启动

创建systemd服务（可选）：

```bash
sudo tee /etc/systemd/system/qwen-api.service << EOF
[Unit]
Description=Qwen Image Edit API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/qwen-image-edit-2509-api-server
Environment="HF_HOME=/root/autodl-tmp/cache"
Environment="TRANSFORMERS_CACHE=/root/autodl-tmp/models"
Environment="TORCH_HOME=/root/autodl-tmp/torch"
ExecStart=/usr/bin/bash scripts/start_server.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable qwen-api
sudo systemctl start qwen-api
```

### 4. 配置防火墙

AutoDL默认需要在控制台开放端口。在AutoDL控制台：

1. 进入实例详情
2. 找到"端口映射"或"自定义服务"
3. 添加端口映射：8000 -> 8000
4. 保存并获取外部访问地址

## 📊 监控和维护

### 查看服务状态

```bash
bash scripts/monitor.sh
```

### 查看日志

```bash
tail -f /root/autodl-tmp/logs/api_server.log
```

### 重启服务

如果使用screen:
```bash
screen -r qwen-api
# Ctrl+C 停止服务
bash scripts/start_server.sh
```

如果使用systemd:
```bash
sudo systemctl restart qwen-api
```

## 🐛 常见问题

### Q1: 提示"No module named 'xxx'"

**解决方案**:
```bash
pip3 install -r requirements.txt
```

### Q2: 下载模型时连接超时

**解决方案**:
```bash
# 设置HuggingFace镜像（国内）
export HF_ENDPOINT=https://hf-mirror.com
bash scripts/download_model.sh
```

### Q3: GPU不可用

**解决方案**:
```bash
# 检查GPU
nvidia-smi

# 检查PyTorch是否识别GPU
python3 -c "import torch; print(torch.cuda.is_available())"
```

### Q4: 系统盘空间仍然不足

**解决方案**:
```bash
# 清理系统缓存
rm -rf ~/.cache/*

# 清理pip缓存
pip3 cache purge

# 检查是否正确配置了环境变量
echo $HF_HOME
echo $TRANSFORMERS_CACHE
```

### Q5: 端口被占用

**解决方案**:
```bash
# 查找占用端口的进程
lsof -i :8000

# 杀死进程
kill -9 <PID>

# 或更改端口
export PORT=8001
bash scripts/start_server.sh
```

## 📈 性能优化建议

### 1. RTX 5090优化

```yaml
# config.yaml
performance:
  compile_model: true  # PyTorch 2.0+ 编译优化
  use_xformers: true   # 使用xformers优化attention
```

### 2. 批处理（如果支持）

```yaml
model:
  max_batch_size: 4  # 根据显存调整
```

### 3. 推理精度

对于RTX 5090，推荐使用 `bf16`:

```yaml
model:
  dtype: "bf16"  # BFloat16，RTX 5090原生支持，速度快且精度好
```

## 🔒 安全配置

### 1. 启用API认证

```bash
# 在.env中设置
API_KEY=$(openssl rand -hex 32)
echo "API_KEY=$API_KEY" >> .env
```

### 2. 限制CORS

编辑 `config.yaml`:

```yaml
api:
  cors:
    enabled: true
    allow_origins:
      - "https://your-frontend-domain.com"
```

### 3. 使用Nginx反向代理（可选）

安装Nginx:
```bash
apt-get update
apt-get install nginx
```

配置示例：
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # 增加超时时间（图片处理可能需要较长时间）
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

## 📝 检查清单

部署完成后，确认以下各项：

- [ ] 服务能够正常启动
- [ ] 健康检查端点返回正常
- [ ] 模型加载成功
- [ ] 能够成功编辑测试图片
- [ ] 日志文件正常写入
- [ ] GPU正在被使用（nvidia-smi查看）
- [ ] 磁盘空间充足
- [ ] API文档可访问 (http://localhost:8000/docs)

## 🎉 完成

恭喜！你已经成功在AutoDL RTX 5090上部署了Qwen Image Edit API服务。

## 📮 获取帮助

如有问题：
- 查看日志文件：`/root/autodl-tmp/logs/api_server.log`
- 提交 [Issue](https://github.com/wlxinchat/qwen-image-edit-2509-api-server/issues)
- 发送邮件至：wlxinchat@gmail.com
