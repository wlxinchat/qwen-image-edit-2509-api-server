"""API routes for image editing."""

import time
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, Header
from fastapi.responses import Response
from loguru import logger

from app.core import config, model_manager
from app.utils.image import (
    validate_image,
    load_image_from_bytes,
    resize_image,
    image_to_bytes,
    get_image_info,
)

router = APIRouter()


def verify_api_key(x_api_key: Optional[str] = Header(None)):
    """Verify API key if configured."""
    if config.api.api_key and config.api.api_key != "":
        if not x_api_key or x_api_key != config.api.api_key:
            raise HTTPException(status_code=401, detail="Invalid or missing API key")


@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model_loaded": model_manager.loaded,
        "timestamp": time.time(),
    }


@router.get("/model/info")
async def get_model_info(x_api_key: Optional[str] = Header(None)):
    """Get model information."""
    verify_api_key(x_api_key)
    return model_manager.get_model_info()


@router.post("/model/load")
async def load_model(x_api_key: Optional[str] = Header(None)):
    """Load the model into memory."""
    verify_api_key(x_api_key)

    try:
        model_manager.load_model()
        return {
            "status": "success",
            "message": "Model loaded successfully",
            "model_info": model_manager.get_model_info(),
        }
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/model/unload")
async def unload_model(x_api_key: Optional[str] = Header(None)):
    """Unload the model from memory."""
    verify_api_key(x_api_key)

    try:
        model_manager.unload_model()
        return {
            "status": "success",
            "message": "Model unloaded successfully",
        }
    except Exception as e:
        logger.error(f"Failed to unload model: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/edit")
async def edit_image(
    image: UploadFile = File(...),
    prompt: str = Form(...),
    max_new_tokens: int = Form(512),
    do_sample: bool = Form(False),
    output_format: str = Form("PNG"),
    x_api_key: Optional[str] = Header(None),
):
    """
    Edit an image based on the prompt.

    Args:
        image: Input image file
        prompt: Editing instruction
        max_new_tokens: Maximum number of tokens to generate
        do_sample: Whether to use sampling
        output_format: Output image format (PNG, JPEG, WEBP)
        x_api_key: API key for authentication

    Returns:
        Edited image
    """
    verify_api_key(x_api_key)

    if not model_manager.loaded:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please call /model/load first."
        )

    try:
        # Read and validate image
        image_data = await image.read()

        # Check file size
        size_mb = len(image_data) / (1024 * 1024)
        if size_mb > config.image.max_upload_size:
            raise HTTPException(
                status_code=413,
                detail=f"Image too large. Max size: {config.image.max_upload_size}MB"
            )

        # Validate image
        if not validate_image(image_data):
            raise HTTPException(status_code=400, detail="Invalid image file")

        # Load image
        input_image = load_image_from_bytes(image_data)
        logger.info(f"Input image info: {get_image_info(input_image)}")

        # Resize if needed
        input_image = resize_image(input_image)

        # Edit image
        logger.info(f"Editing image with prompt: {prompt}")
        start_time = time.time()

        edited_image = model_manager.edit_image(
            image=input_image,
            prompt=prompt,
            max_new_tokens=max_new_tokens,
            do_sample=do_sample,
        )

        elapsed_time = time.time() - start_time
        logger.info(f"Image editing completed in {elapsed_time:.2f}s")

        # Convert to bytes
        output_format = output_format.upper()
        if output_format not in ["PNG", "JPEG", "WEBP"]:
            output_format = "PNG"

        output_bytes = image_to_bytes(edited_image, format=output_format)

        # Return image
        media_type = f"image/{output_format.lower()}"
        return Response(
            content=output_bytes,
            media_type=media_type,
            headers={
                "X-Processing-Time": str(elapsed_time),
                "X-Output-Format": output_format,
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during image editing: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
