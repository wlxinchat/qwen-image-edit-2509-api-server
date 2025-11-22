# ✅ 部署前检查清单

本清单用于在AutoDL环境部署前进行最后确认。

## 📋 环境要求

- [ ] AutoDL实例已创建
- [ ] GPU: RTX 5090 (或其他NVIDIA GPU)
- [ ] 系统镜像: PyTorch 2.1.0 / Python 3.10+ / CUDA 11.8
- [ ] 数据盘空间: ≥50GB
- [ ] 系统盘空间: ≥5GB

## 🔍 部署前验证

### 1. 登录AutoDL实例

```bash
ssh root@your-autodl-ip -p your-port
```

### 2. 检查环境

```bash
# 检查Python版本 (需要 >= 3.8)
python3 --version

# 检查磁盘空间
df -h

# 检查GPU
nvidia-smi
```

### 3. 克隆项目

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
```

### 4. 快速检查

```bash
# 验证项目文件
ls -la

# 应该看到:
# - README.md
# - QUICKSTART.md
# - DEPLOY_GUIDE.md
# - requirements.txt
# - config.yaml
# - scripts/
# - app/
```

## 🚀 执行部署

### 一键部署 (推荐)

```bash
bash scripts/deploy.sh
```

### 分步部署 (可选)

如果需要更多控制:

```bash
# 1. 环境设置
bash scripts/setup_autodl.sh
source ~/.bashrc

# 2. 配置环境变量 (可选)
cp .env.example .env
vim .env

# 3. 下载模型
bash scripts/download_model.sh

# 4. 启动服务
bash scripts/start_server.sh
```

## ✅ 部署后验证

### 1. 检查服务状态

```bash
# 检查进程
ps aux | grep uvicorn

# 检查端口
lsof -i :8000
```

### 2. 测试API

```bash
# 健康检查
curl http://localhost:8000/health

# 应该返回:
# {"status":"healthy","model_loaded":false,"timestamp":...}
```

### 3. 加载模型

```bash
curl -X POST http://localhost:8000/api/v1/model/load
```

### 4. 查看日志

```bash
# 服务日志
tail -f /root/autodl-tmp/logs/server.log

# 部署日志
tail -f /root/autodl-tmp/logs/deploy.log
```

### 5. 访问API文档

在AutoDL控制台配置端口映射 8000 -> 8000，然后访问:
```
http://your-autodl-ip:8000/docs
```

## 🔧 常见问题

### 问题1: 端口被占用

```bash
# 查看占用端口的进程
lsof -i :8000

# 停止进程
kill -15 <PID>
```

### 问题2: 磁盘空间不足

```bash
# 检查空间
df -h /root/autodl-tmp

# 清理缓存
rm -rf /root/autodl-tmp/cache/*
rm -rf /root/autodl-tmp/pip_cache/*
```

### 问题3: 模型下载失败

```bash
# 使用国内镜像
export HF_ENDPOINT=https://hf-mirror.com
bash scripts/download_model.sh
```

### 问题4: GPU不可用

```bash
# 检查CUDA
nvidia-smi
python3 -c "import torch; print(torch.cuda.is_available())"

# 如果返回False，检查环境变量
echo $CUDA_VISIBLE_DEVICES
```

## 📊 监控和维护

### 查看服务状态

```bash
bash scripts/monitor.sh
```

### 重启服务

```bash
# 停止服务
kill $(cat /root/autodl-tmp/logs/server.pid)

# 启动服务
bash scripts/start_server.sh
```

### 查看GPU使用

```bash
watch -n 1 nvidia-smi
```

## 📝 部署成功标志

部署成功后，你应该看到:

```
✓ 部署成功！

服务信息:
  • API地址: http://localhost:8000
  • API文档: http://localhost:8000/docs
  • 健康检查: http://localhost:8000/health

重要路径:
  • 模型目录: /root/autodl-tmp/models
  • 日志目录: /root/autodl-tmp/logs
  • 部署日志: /root/autodl-tmp/logs/deploy.log
  • 服务日志: /root/autodl-tmp/logs/server.log
```

## 🎯 下一步

- [ ] 配置API密钥 (编辑 .env)
- [ ] 配置AutoDL端口映射
- [ ] 测试图片编辑功能
- [ ] 设置开机自启动 (可选)
- [ ] 配置Nginx反向代理 (可选)

## 📮 获取帮助

如果遇到问题:

1. 查看日志文件
2. 参考 QUICKSTART.md 中的常见问题
3. 提交 GitHub Issue: https://github.com/wlxinchat/qwen-image-edit-2509-api-server/issues
4. 发送邮件: wlxinchat@gmail.com

---

**预计总部署时间**: 15-30分钟
**项目状态**: ✅ 已验证，就绪部署
