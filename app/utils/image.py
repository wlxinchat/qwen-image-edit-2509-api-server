"""Image processing utilities."""

import io
from pathlib import Path
from typing import Union

from PIL import Image
from loguru import logger

from app.core.config import config


def validate_image(image_data: bytes) -> bool:
    """
    Validate if the uploaded data is a valid image.

    Args:
        image_data: Raw image bytes

    Returns:
        True if valid, False otherwise
    """
    try:
        img = Image.open(io.BytesIO(image_data))
        img.verify()
        return True
    except Exception as e:
        logger.warning(f"Invalid image: {e}")
        return False


def load_image_from_bytes(image_data: bytes) -> Image.Image:
    """
    Load PIL Image from bytes.

    Args:
        image_data: Raw image bytes

    Returns:
        PIL Image object
    """
    try:
        img = Image.open(io.BytesIO(image_data))
        return img.convert("RGB")
    except Exception as e:
        logger.error(f"Failed to load image: {e}")
        raise


def resize_image(
    image: Image.Image,
    max_size: int = None
) -> Image.Image:
    """
    Resize image if it exceeds max_size while maintaining aspect ratio.

    Args:
        image: PIL Image
        max_size: Maximum dimension size

    Returns:
        Resized PIL Image
    """
    if max_size is None:
        max_size = config.image.max_size

    width, height = image.size

    if width <= max_size and height <= max_size:
        return image

    # Calculate new dimensions
    if width > height:
        new_width = max_size
        new_height = int(height * (max_size / width))
    else:
        new_height = max_size
        new_width = int(width * (max_size / height))

    logger.info(f"Resizing image from {width}x{height} to {new_width}x{new_height}")
    return image.resize((new_width, new_height), Image.Resampling.LANCZOS)


def image_to_bytes(
    image: Image.Image,
    format: str = "PNG",
    quality: int = None
) -> bytes:
    """
    Convert PIL Image to bytes.

    Args:
        image: PIL Image
        format: Output format (PNG, JPEG, etc.)
        quality: Quality for JPEG (1-100)

    Returns:
        Image as bytes
    """
    if quality is None:
        quality = config.image.output_quality

    buffer = io.BytesIO()

    if format.upper() == "JPEG":
        image.save(buffer, format=format, quality=quality, optimize=True)
    else:
        image.save(buffer, format=format)

    return buffer.getvalue()


def get_image_info(image: Image.Image) -> dict:
    """
    Get information about an image.

    Args:
        image: PIL Image

    Returns:
        Dictionary with image information
    """
    return {
        "width": image.size[0],
        "height": image.size[1],
        "format": image.format,
        "mode": image.mode,
    }
