"""Main FastAPI application."""

import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

from app.api.routes import router
from app.core import config, model_manager


# Configure logging
def setup_logging():
    """Setup loguru logging."""
    # Remove default handler
    logger.remove()

    # Add console handler
    logger.add(
        sys.stderr,
        format=config.logging.format,
        level=config.logging.level,
        colorize=True,
    )

    # Add file handler
    log_file = Path(config.logging.file)
    log_file.parent.mkdir(parents=True, exist_ok=True)

    logger.add(
        config.logging.file,
        format=config.logging.format,
        level=config.logging.level,
        rotation=config.logging.rotation,
        retention=config.logging.retention,
        compression="zip",
    )

    logger.info("Logging configured")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info("Starting Qwen Image Edit API Server")
    logger.info(f"Configuration: {config.model_dump()}")

    # Optionally load model on startup
    # Uncomment the following lines to auto-load the model
    # try:
    #     logger.info("Loading model on startup...")
    #     model_manager.load_model()
    # except Exception as e:
    #     logger.error(f"Failed to load model on startup: {e}")

    yield

    # Shutdown
    logger.info("Shutting down Qwen Image Edit API Server")
    if model_manager.loaded:
        logger.info("Unloading model...")
        model_manager.unload_model()


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    setup_logging()

    app = FastAPI(
        title="Qwen Image Edit 2509 API",
        description="API server for Qwen Image Edit 2509 model",
        version="0.1.0",
        lifespan=lifespan,
    )

    # Configure CORS
    if config.api.cors.enabled:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=config.api.cors.allow_origins,
            allow_credentials=True,
            allow_methods=config.api.cors.allow_methods,
            allow_headers=config.api.cors.allow_headers,
        )
        logger.info("CORS enabled")

    # Include routers
    app.include_router(router, prefix="/api/v1", tags=["Image Edit"])

    @app.get("/")
    async def root():
        return {
            "name": "Qwen Image Edit 2509 API",
            "version": "0.1.0",
            "status": "running",
            "docs": "/docs",
        }

    return app


# Create app instance
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=config.server.host,
        port=config.server.port,
        workers=config.server.workers,
        reload=config.server.reload,
        log_level=config.server.log_level,
    )
