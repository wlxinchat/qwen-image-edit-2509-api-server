"""Model loading and inference."""

import torch
from loguru import logger
from PIL import Image
from typing import Optional, Union, List
from pathlib import Path

from app.core.config import config


class QwenImageEditModel:
    """Qwen Image Edit model wrapper."""

    def __init__(self):
        self.model = None
        self.processor = None
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
        """Load the model and processor."""
        if self.loaded:
            logger.info("Model already loaded")
            return

        try:
            logger.info(f"Loading model: {config.model.name}")
            logger.info(f"Cache directory: {config.model.cache_dir}")
            logger.info(f"Device: {self.device}")
            logger.info(f"Dtype: {config.model.dtype}")

            # Import required libraries
            from transformers import AutoModelForCausalLM, AutoTokenizer

            # Load tokenizer (Qwen models use AutoTokenizer instead of AutoProcessor)
            logger.info("Loading tokenizer...")
            self.processor = AutoTokenizer.from_pretrained(
                config.model.name,
                cache_dir=config.model.cache_dir,
                trust_remote_code=True,
            )

            # Prepare model loading kwargs
            model_kwargs = {
                "cache_dir": config.model.cache_dir,
                "trust_remote_code": True,
                "device_map": "auto" if self.device == "cuda" else None,
            }

            # Add quantization settings if enabled
            if config.model.load_in_8bit:
                logger.info("Using 8-bit quantization")
                model_kwargs["load_in_8bit"] = True
            elif config.model.load_in_4bit:
                logger.info("Using 4-bit quantization")
                model_kwargs["load_in_4bit"] = True
            else:
                model_kwargs["torch_dtype"] = self.dtype

            # Load model
            logger.info("Loading model...")
            self.model = AutoModelForCausalLM.from_pretrained(
                config.model.name,
                **model_kwargs
            )

            # Move to device if not using device_map="auto"
            # When device_map="auto", model is already distributed, don't move
            if not (self.device == "cuda" and model_kwargs.get("device_map") == "auto"):
                self.model = self.model.to(self.device)

            # Set to evaluation mode
            self.model.eval()

            # Optional: compile model for better performance
            if config.performance.compile_model and hasattr(torch, "compile"):
                logger.info("Compiling model for better performance...")
                self.model = torch.compile(self.model)

            self.loaded = True
            logger.info("Model loaded successfully")

        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise

    def unload_model(self):
        """Unload the model to free memory."""
        if self.loaded:
            del self.model
            del self.processor
            self.model = None
            self.processor = None
            self.loaded = False

            if torch.cuda.is_available():
                torch.cuda.empty_cache()

            logger.info("Model unloaded")

    @torch.no_grad()
    def edit_image(
        self,
        image: Union[str, Path, Image.Image],
        prompt: str,
        **kwargs
    ) -> Image.Image:
        """
        Edit an image based on the prompt.

        Args:
            image: Input image (path or PIL Image)
            prompt: Editing instruction
            **kwargs: Additional generation parameters

        Returns:
            Edited image as PIL Image
        """
        if not self.loaded:
            raise RuntimeError("Model not loaded. Call load_model() first.")

        try:
            # Load image if path is provided
            if isinstance(image, (str, Path)):
                image = Image.open(image).convert("RGB")

            # Prepare inputs
            # Note: Actual implementation depends on the specific model API
            # This is a template that needs to be adapted to the real model

            # Example implementation (adjust based on actual model):
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "image", "image": image},
                        {"type": "text", "text": prompt},
                    ],
                }
            ]

            # Process inputs
            text = self.processor.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )

            inputs = self.processor(
                text=[text],
                images=[image],
                return_tensors="pt",
            ).to(self.device)

            # Generate
            generation_kwargs = {
                "max_new_tokens": kwargs.get("max_new_tokens", 512),
                "do_sample": kwargs.get("do_sample", False),
            }

            outputs = self.model.generate(**inputs, **generation_kwargs)

            # Decode output
            generated_text = self.processor.batch_decode(
                outputs, skip_special_tokens=True
            )[0]

            logger.info(f"Generated text: {generated_text}")

            # Note: For image editing models, you may need different processing
            # This is a placeholder - adapt to your specific model's API

            return image  # Replace with actual edited image

        except Exception as e:
            logger.error(f"Error during image editing: {e}")
            raise

    def get_model_info(self) -> dict:
        """Get information about the loaded model."""
        info = {
            "model_name": config.model.name,
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
