"""Model loading and inference using Qwen-Image-Edit-2509 Diffusers Pipeline."""

import torch
from loguru import logger
from PIL import Image
from typing import Optional, Union, List
from pathlib import Path

from app.core.config import config


class QwenImageEditModel:
    """Qwen Image Edit model wrapper using Diffusers Pipeline."""

    def __init__(self):
        self.pipeline = None
        self.device = config.model.device
        self.dtype = self._get_dtype()
        self.loaded = False

    def _get_dtype(self) -> torch.dtype:
        """Get PyTorch dtype from config."""
        dtype_map = {
            "fp32": torch.float32,
            "fp16": torch.float16,
            "bf16": torch.bfloat16,
        }
        return dtype_map.get(config.model.dtype, torch.bfloat16)

    def load_model(self):
        """Load the Qwen Image Edit pipeline."""
        if self.loaded:
            logger.info("Model already loaded")
            return

        try:
            logger.info(f"Loading Qwen-Image-Edit-2509 pipeline: {config.model.name}")
            logger.info(f"Cache directory: {config.model.cache_dir}")
            logger.info(f"Device: {self.device}")
            logger.info(f"Dtype: {config.model.dtype}")

            # Import Diffusers pipeline
            from diffusers import QwenImageEditPlusPipeline

            # Load the pipeline
            logger.info("Loading QwenImageEditPlusPipeline...")
            self.pipeline = QwenImageEditPlusPipeline.from_pretrained(
                config.model.name,
                torch_dtype=self.dtype,
                cache_dir=config.model.cache_dir,
            )
            logger.info("Pipeline loaded successfully")

            # Move to device
            self.pipeline.to(self.device)
            logger.info(f"Pipeline moved to {self.device}")

            # Configure progress bar
            self.pipeline.set_progress_bar_config(disable=None)

            self.loaded = True
            logger.info("Qwen-Image-Edit-2509 pipeline loaded and ready")

        except Exception as e:
            logger.error(f"Failed to load pipeline: {e}")
            raise

    def unload_model(self):
        """Unload the pipeline to free memory."""
        if self.loaded:
            del self.pipeline
            self.pipeline = None
            self.loaded = False

            if torch.cuda.is_available():
                torch.cuda.empty_cache()

            logger.info("Pipeline unloaded")

    @torch.inference_mode()
    def edit_image(
        self,
        image: Union[str, Path, Image.Image, List[Union[str, Path, Image.Image]]],
        prompt: str,
        negative_prompt: str = " ",
        num_inference_steps: int = 40,
        guidance_scale: float = 1.0,
        true_cfg_scale: float = 4.0,
        seed: Optional[int] = None,
        **kwargs
    ) -> Image.Image:
        """
        Edit an image (or multiple images) based on the prompt using Qwen-Image-Edit-2509.

        Args:
            image: Input image(s) - single image or list of 1-3 images (path or PIL Image)
            prompt: Editing instruction/prompt
            negative_prompt: Negative prompt (default: " ")
            num_inference_steps: Number of denoising steps (default: 40)
            guidance_scale: Guidance scale (default: 1.0)
            true_cfg_scale: True CFG scale (default: 4.0)
            seed: Random seed for reproducibility (optional)
            **kwargs: Additional generation parameters

        Returns:
            Edited image as PIL Image
        """
        if not self.loaded:
            raise RuntimeError("Pipeline not loaded. Call load_model() first.")

        try:
            # Handle image input - convert to list if single image
            if not isinstance(image, list):
                images = [image]
            else:
                images = image

            # Load images if paths are provided
            loaded_images = []
            for img in images:
                if isinstance(img, (str, Path)):
                    loaded_images.append(Image.open(img).convert("RGB"))
                else:
                    loaded_images.append(img)

            # Limit to 1-3 images as per model documentation
            if len(loaded_images) > 3:
                logger.warning(f"More than 3 images provided ({len(loaded_images)}), using first 3")
                loaded_images = loaded_images[:3]

            logger.info(f"Editing {len(loaded_images)} image(s) with prompt: {prompt}")

            # Prepare pipeline inputs
            generator = None
            if seed is not None:
                generator = torch.Generator(device=self.device).manual_seed(seed)

            inputs = {
                "image": loaded_images,
                "prompt": prompt,
                "negative_prompt": negative_prompt,
                "num_inference_steps": num_inference_steps,
                "guidance_scale": guidance_scale,
                "true_cfg_scale": true_cfg_scale,
                "generator": generator,
                "num_images_per_prompt": kwargs.get("num_images_per_prompt", 1),
            }

            # Add any additional kwargs
            for key, value in kwargs.items():
                if key not in inputs:
                    inputs[key] = value

            # Run the pipeline
            logger.info("Running image editing pipeline...")
            output = self.pipeline(**inputs)

            # Get the first output image
            edited_image = output.images[0]
            logger.info("Image editing completed successfully")

            return edited_image

        except Exception as e:
            logger.error(f"Error during image editing: {e}")
            raise

    def get_model_info(self) -> dict:
        """Get information about the loaded pipeline."""
        info = {
            "model_name": config.model.name,
            "model_type": "Qwen-Image-Edit-2509 (Diffusers Pipeline)",
            "loaded": self.loaded,
            "device": self.device,
            "dtype": str(self.dtype),
        }

        if self.loaded and torch.cuda.is_available():
            info["cuda_memory_allocated"] = torch.cuda.memory_allocated() / 1024**3  # GB
            info["cuda_memory_reserved"] = torch.cuda.memory_reserved() / 1024**3  # GB

        return info


# Global model instance
model_manager = QwenImageEditModel()
