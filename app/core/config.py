"""Configuration management for the API server."""

import os
from pathlib import Path
from typing import List, Optional

import yaml
from pydantic import Field
from pydantic_settings import BaseSettings


class ServerConfig(BaseSettings):
    """Server configuration."""

    host: str = Field(default="0.0.0.0")
    port: int = Field(default=8000)
    workers: int = Field(default=1)
    reload: bool = Field(default=False)
    log_level: str = Field(default="info")


class ModelConfig(BaseSettings):
    """Model configuration."""

    name: str = Field(default="Qwen/Qwen-Image-Edit-2509")
    cache_dir: str = Field(default="/root/autodl-tmp/models")
    device: str = Field(default="cuda")
    dtype: str = Field(default="bf16")
    load_in_8bit: bool = Field(default=False)
    load_in_4bit: bool = Field(default=False)
    max_batch_size: int = Field(default=1)
    max_memory: Optional[int] = Field(default=None)


class ImageConfig(BaseSettings):
    """Image processing configuration."""

    allowed_formats: List[str] = Field(default=["jpg", "jpeg", "png", "webp"])
    max_size: int = Field(default=2048)
    max_upload_size: int = Field(default=10)
    output_quality: int = Field(default=95)


class APIConfig(BaseSettings):
    """API configuration."""

    api_key: str = Field(default="")

    class RateLimit(BaseSettings):
        enabled: bool = Field(default=False)
        requests_per_minute: int = Field(default=60)

    class CORS(BaseSettings):
        enabled: bool = Field(default=True)
        allow_origins: List[str] = Field(default=["*"])
        allow_methods: List[str] = Field(default=["GET", "POST"])
        allow_headers: List[str] = Field(default=["*"])

    rate_limit: RateLimit = Field(default_factory=RateLimit)
    cors: CORS = Field(default_factory=CORS)


class LoggingConfig(BaseSettings):
    """Logging configuration."""

    level: str = Field(default="INFO")
    format: str = Field(
        default="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
    )
    file: str = Field(default="/root/autodl-tmp/logs/api_server.log")
    rotation: str = Field(default="500 MB")
    retention: str = Field(default="10 days")


class PerformanceConfig(BaseSettings):
    """Performance configuration."""

    compile_model: bool = Field(default=False)
    use_xformers: bool = Field(default=False)
    num_threads: int = Field(default=4)


class Config(BaseSettings):
    """Main configuration class."""

    server: ServerConfig = Field(default_factory=ServerConfig)
    model: ModelConfig = Field(default_factory=ModelConfig)
    image: ImageConfig = Field(default_factory=ImageConfig)
    api: APIConfig = Field(default_factory=APIConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    performance: PerformanceConfig = Field(default_factory=PerformanceConfig)

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

    @classmethod
    def load_from_yaml(cls, yaml_path: str = "config.yaml") -> "Config":
        """Load configuration from YAML file."""
        if not Path(yaml_path).exists():
            return cls()

        with open(yaml_path, "r", encoding="utf-8") as f:
            config_dict = yaml.safe_load(f)

        return cls(**config_dict)

    def ensure_directories(self):
        """Ensure all required directories exist."""
        Path(self.model.cache_dir).mkdir(parents=True, exist_ok=True)

        log_dir = Path(self.logging.file).parent
        log_dir.mkdir(parents=True, exist_ok=True)


# Global config instance
config = Config.load_from_yaml()
config.ensure_directories()
