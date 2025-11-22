# Qwen Image Edit 2509 API Server

基于Qwen图片编辑模型(Qwen-Image-Edit-2509)的API服务，专为AutoDL环境优化，特别解决了系统盘空间不足的问题。

📖 **快速链接**: [快速开始](QUICKSTART.md) | [详细部署指南](DEPLOY_GUIDE.md) | [API文档](http://localhost:8000/docs)

## ✨ 特性

- 🚀 基于FastAPI的高性能API服务
- 🎨 支持基于文本提示的图片编辑
- 💾 优化的存储策略，模型和缓存存储在数据盘
- 🔧 专为AutoDL RTX 5090环境优化
- 📊 完整的日志和监控支持
- 🔒 API密钥认证（可选）
- 🌐 CORS支持，便于前端集成

## 📋 系统要求

- Python 3.8+
- CUDA 11.8+ (用于GPU加速)
- RTX 5090 GPU (推荐) 或其他NVIDIA GPU
- 至少20GB数据盘空间（用于模型存储）

## 🚀 快速开始

### 一键部署（推荐）

在AutoDL上直接运行一键部署脚本：

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
bash scripts/deploy.sh
```

该脚本会自动完成：
- ✅ 环境检查（Python、磁盘空间、依赖）
- ✅ 自动配置数据盘缓存
- ✅ 安装所有依赖
- ✅ 下载模型
- ✅ 启动服务
- ✅ 验证服务可用性

### 手动部署（高级用户）

#### 1. 克隆项目

```bash
cd /root
git clone https://github.com/wlxinchat/qwen-image-edit-2509-api-server.git
cd qwen-image-edit-2509-api-server
```

#### 2. 运行设置脚本

```bash
bash scripts/setup_autodl.sh
```

脚本会自动完成：
- ✅ 在数据盘创建必要目录
- ✅ 配置pip缓存到数据盘
- ✅ 配置HuggingFace缓存到数据盘
- ✅ 配置PyTorch缓存到数据盘
- ✅ 安装Python依赖

#### 3. 配置环境（可选）

```bash
cp .env.example .env
vim .env  # 根据需要修改
```

#### 4. 下载模型

```bash
bash scripts/download_model.sh
```

#### 5. 启动服务

```bash
bash scripts/start_server.sh
```

## 📖 API 使用

### 健康检查

```bash
curl http://localhost:8000/health
```

### 加载模型

```bash
curl -X POST http://localhost:8000/api/v1/model/load
```

### 编辑图片

```bash
curl -X POST http://localhost:8000/api/v1/edit \
  -F "image=@input.jpg" \
  -F "prompt=把这张图片变成黑白的" \
  -F "output_format=PNG" \
  -o output.png
```

### 使用API密钥认证

如果在配置中设置了API密钥：

```bash
curl -X POST http://localhost:8000/api/v1/edit \
  -H "X-API-Key: your-api-key" \
  -F "image=@input.jpg" \
  -F "prompt=编辑指令" \
  -o output.png
```

### API文档

访问 `http://localhost:8000/docs` 查看完整的交互式API文档。

## 🔧 配置说明

### config.yaml

主要配置项：

```yaml
server:
  host: "0.0.0.0"
  port: 8000

model:
  name: "Qwen/Qwen-Image-Edit-2509"
  cache_dir: "/root/autodl-tmp/models"  # 数据盘路径
  device: "cuda"
  dtype: "bf16"  # 可选: fp32, fp16, bf16
  load_in_8bit: false  # 8bit量化，节省显存
  load_in_4bit: false  # 4bit量化，更省显存

image:
  max_size: 2048  # 最大图片尺寸
  max_upload_size: 10  # 最大上传大小(MB)

api:
  api_key: ""  # 留空则不启用认证
```

### 环境变量

在 `.env` 文件中配置：

```bash
# 服务器配置
HOST=0.0.0.0
PORT=8000

# 模型配置
MODEL_NAME=Qwen/Qwen-Image-Edit-2509
MODEL_CACHE_DIR=/root/autodl-tmp/models
DEVICE=cuda
DTYPE=bf16

# HuggingFace Token (可选，用于私有模型)
HF_TOKEN=

# API安全
API_KEY=
```

## 📊 监控

使用监控脚本检查服务状态：

```bash
bash scripts/monitor.sh
```

这会显示：
- 服务运行状态
- GPU使用情况
- 磁盘使用情况
- 内存使用情况
- 最近的日志

## 💾 存储优化

项目针对AutoDL的系统盘空间限制进行了优化：

| 项目 | 默认路径 | 优化后路径 |
|------|---------|-----------|
| 模型文件 | ~/.cache | /root/autodl-tmp/models |
| pip缓存 | ~/.cache/pip | /root/autodl-tmp/pip_cache |
| HuggingFace缓存 | ~/.cache/huggingface | /root/autodl-tmp/cache |
| PyTorch缓存 | ~/.cache/torch | /root/autodl-tmp/torch |
| 日志文件 | ./logs | /root/autodl-tmp/logs |

## 🐛 故障排除

### 系统盘空间不足

如果遇到空间问题：

1. 检查磁盘使用：
```bash
df -h
```

2. 确认缓存配置：
```bash
echo $HF_HOME
echo $TRANSFORMERS_CACHE
```

3. 清理不必要的缓存：
```bash
rm -rf ~/.cache/*
```

### GPU内存不足

如果GPU内存不足，在 `config.yaml` 中启用量化：

```yaml
model:
  load_in_8bit: true  # 或 load_in_4bit: true
```

### 模型加载失败

1. 检查网络连接
2. 确认模型名称正确
3. 如果是私有模型，设置 `HF_TOKEN`
4. 查看日志文件：`tail -f /root/autodl-tmp/logs/api_server.log`

## 📁 项目结构

```
qwen-image-edit-2509-api-server/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI应用入口
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes.py        # API路由
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py        # 配置管理
│   │   └── model.py         # 模型加载和推理
│   └── utils/
│       ├── __init__.py
│       └── image.py         # 图片处理工具
├── scripts/
│   ├── setup_autodl.sh      # AutoDL环境设置
│   ├── download_model.sh    # 模型下载
│   ├── start_server.sh      # 启动服务
│   └── monitor.sh           # 监控脚本
├── requirements.txt         # Python依赖
├── config.yaml             # 主配置文件
├── .env.example           # 环境变量模板
└── README.md              # 本文件
```

## 🔐 安全建议

1. **生产环境**: 务必设置 `API_KEY` 进行认证
2. **CORS配置**: 根据需要限制 `allow_origins`
3. **防火墙**: 配置防火墙规则限制访问
4. **HTTPS**: 生产环境建议使用反向代理(Nginx)配置HTTPS

## 📝 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交Issue和Pull Request！

贡献指南：
1. Fork 本项目
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 👤 作者

**wlxinchat**

- GitHub: [@wlxinchat](https://github.com/wlxinchat)
- Email: wlxinchat@gmail.com

## 📮 联系方式

如有问题或建议：
- 提交 [Issue](https://github.com/wlxinchat/qwen-image-edit-2509-api-server/issues)
- 发送邮件至: wlxinchat@gmail.com
