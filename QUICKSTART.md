# 快速开始指南

一分钟了解如何部署Qwen Image Edit 2509 API服务。

## 🚀 一键部署

在AutoDL实例上运行以下命令：

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
bash scripts/deploy.sh
```

等待15-30分钟，即可完成部署！

## ✅ 部署成功标志

看到以下信息表示部署成功：

```
✓ 部署成功！

服务信息:
  • API地址: http://localhost:8000
  • API文档: http://localhost:8000/docs
  • 健康检查: http://localhost:8000/health
```

## 🧪 测试API

### 1. 健康检查

```bash
curl http://localhost:8000/health
```

预期输出：
```json
{
  "status": "healthy",
  "model_loaded": false,
  "timestamp": 1234567890.123
}
```

### 2. 查看API文档

在浏览器中打开（需要配置AutoDL端口映射）：
```
http://your-autodl-ip:8000/docs
```

### 3. 加载模型

```bash
curl -X POST http://localhost:8000/api/v1/model/load
```

### 4. 编辑图片

准备一张测试图片 `test.jpg`，然后：

```bash
curl -X POST http://localhost:8000/api/v1/edit \
  -F "image=@test.jpg" \
  -F "prompt=将这张图片转换为黑白色" \
  -F "output_format=PNG" \
  -o result.png
```

## 📊 查看服务状态

### 查看进程

```bash
ps aux | grep uvicorn
```

### 查看日志

```bash
# 实时查看服务日志
tail -f /root/autodl-tmp/logs/server.log

# 查看部署日志
tail -f /root/autodl-tmp/logs/deploy.log
```

### 查看GPU使用

```bash
nvidia-smi
```

## 🛑 停止服务

```bash
kill $(cat /root/autodl-tmp/logs/server.pid)
```

或者：

```bash
# 找到进程ID
ps aux | grep uvicorn

# 停止进程
kill -15 <PID>
```

## 🔄 重启服务

```bash
# 停止服务
kill $(cat /root/autodl-tmp/logs/server.pid) 2>/dev/null || true

# 启动服务
bash scripts/start_server.sh
```

## ❌ 常见问题

### 问题1：部署脚本失败

**检查日志**：
```bash
tail -100 /root/autodl-tmp/logs/deploy.log
```

**常见原因**：
- 磁盘空间不足：检查 `df -h /root/autodl-tmp`
- 网络问题：重试 `bash scripts/deploy.sh`
- Python版本：确保 Python >= 3.8

### 问题2：端口已被占用

```bash
# 查看占用端口的进程
lsof -i :8000

# 停止该进程
kill -15 <PID>

# 重新部署
bash scripts/deploy.sh
```

### 问题3：模型下载失败

如果网络不稳定，可以单独下载模型：

```bash
bash scripts/download_model.sh
```

国内用户可以使用镜像：
```bash
export HF_ENDPOINT=https://hf-mirror.com
bash scripts/download_model.sh
```

### 问题4：GPU不可用

检查CUDA：
```bash
nvidia-smi
python3 -c "import torch; print(torch.cuda.is_available())"
```

如果没有GPU，服务仍可运行，但速度较慢。

### 问题5：服务启动后无法访问

检查防火墙和端口映射：
1. 在AutoDL控制台添加端口映射：8000 -> 8000
2. 检查服务是否真的在运行：`lsof -i :8000`
3. 查看服务日志：`tail -f /root/autodl-tmp/logs/server.log`

## 🔧 高级配置

### 自定义端口

编辑 `.env` 文件：
```bash
vim .env
```

修改：
```
PORT=8080
```

然后重启服务。

### 启用API认证

编辑 `.env` 文件：
```bash
# 生成随机密钥
API_KEY=$(openssl rand -hex 32)
echo "API_KEY=$API_KEY" >> .env
```

使用API时带上密钥：
```bash
curl -H "X-API-Key: your-api-key" http://localhost:8000/api/v1/model/info
```

### 使用量化节省显存

编辑 `config.yaml`：
```yaml
model:
  load_in_8bit: true  # 或 load_in_4bit: true
```

## 📚 更多文档

- [完整部署指南](DEPLOY_GUIDE.md) - AutoDL详细部署步骤
- [README](README.md) - 项目概览和功能介绍
- [API文档](http://localhost:8000/docs) - 交互式API文档

## 📮 获取帮助

- GitHub Issues: https://github.com/wlxinchat/qwen-image-edit-2509-api-server/issues
- Email: wlxinchat@gmail.com
