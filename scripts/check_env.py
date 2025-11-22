#!/usr/bin/env python3
"""
Environment validation script for Qwen Image Edit API Server.
Run this before deployment to check if everything is ready.
"""

import sys
import subprocess
from pathlib import Path


def print_status(message, status="info"):
    """Print colored status message."""
    colors = {
        "ok": "\033[0;32m✓",
        "error": "\033[0;31m✗",
        "warning": "\033[1;33m⚠",
        "info": "\033[1;34mℹ",
    }
    reset = "\033[0m"
    print(f"{colors.get(status, '')} {message}{reset}")


def check_python_version():
    """Check Python version."""
    version = sys.version_info
    if version >= (3, 8):
        print_status(f"Python {version.major}.{version.minor}.{version.micro}", "ok")
        return True
    else:
        print_status(f"Python {version.major}.{version.minor} (requires 3.8+)", "error")
        return False


def check_import(module_name, package_name=None):
    """Check if a Python module can be imported."""
    try:
        __import__(module_name)
        print_status(f"{package_name or module_name} installed", "ok")
        return True
    except ImportError:
        print_status(f"{package_name or module_name} not installed", "error")
        return False


def check_cuda():
    """Check CUDA availability."""
    try:
        import torch
        if torch.cuda.is_available():
            device_count = torch.cuda.device_count()
            device_name = torch.cuda.get_device_name(0) if device_count > 0 else "Unknown"
            print_status(f"CUDA available - {device_name}", "ok")
            return True
        else:
            print_status("CUDA not available", "warning")
            return False
    except ImportError:
        print_status("PyTorch not installed, cannot check CUDA", "error")
        return False


def check_disk_space(path, min_gb=20):
    """Check available disk space."""
    try:
        stat = subprocess.run(
            ["df", "-BG", str(path)],
            capture_output=True,
            text=True
        )
        if stat.returncode == 0:
            lines = stat.stdout.strip().split("\n")
            if len(lines) > 1:
                parts = lines[1].split()
                available = int(parts[3].replace("G", ""))
                if available >= min_gb:
                    print_status(f"{path}: {available}GB available", "ok")
                    return True
                else:
                    print_status(f"{path}: {available}GB available (need {min_gb}GB)", "warning")
                    return False
    except Exception as e:
        print_status(f"Could not check disk space: {e}", "warning")
    return True


def check_directories():
    """Check if required directories exist."""
    data_dir = Path("/root/autodl-tmp")
    if data_dir.exists():
        print_status(f"Data directory exists: {data_dir}", "ok")

        # Check subdirectories
        for subdir in ["models", "logs", "cache"]:
            path = data_dir / subdir
            if path.exists():
                print_status(f"  {subdir}/ exists", "ok")
            else:
                print_status(f"  {subdir}/ missing (will be created)", "info")
        return True
    else:
        print_status(f"Data directory not found: {data_dir}", "warning")
        return False


def check_config_files():
    """Check if configuration files exist."""
    config_files = [
        ("config.yaml", True),
        (".env", False),
        ("requirements.txt", True),
    ]

    all_ok = True
    for filename, required in config_files:
        path = Path(filename)
        if path.exists():
            print_status(f"{filename} exists", "ok")
        else:
            if required:
                print_status(f"{filename} missing", "error")
                all_ok = False
            else:
                print_status(f"{filename} missing (optional)", "info")

    return all_ok


def main():
    """Run all checks."""
    print("=" * 60)
    print("Qwen Image Edit API Server - Environment Check")
    print("=" * 60)
    print()

    results = []

    # Check Python version
    print("[1/7] Checking Python version...")
    results.append(check_python_version())
    print()

    # Check configuration files
    print("[2/7] Checking configuration files...")
    results.append(check_config_files())
    print()

    # Check required Python packages
    print("[3/7] Checking Python packages...")
    packages = [
        ("fastapi", "FastAPI"),
        ("uvicorn", "Uvicorn"),
        ("torch", "PyTorch"),
        ("transformers", "Transformers"),
        ("PIL", "Pillow"),
        ("yaml", "PyYAML"),
        ("loguru", "Loguru"),
    ]
    package_results = [check_import(mod, pkg) for mod, pkg in packages]
    results.append(all(package_results))
    print()

    # Check CUDA
    print("[4/7] Checking CUDA...")
    check_cuda()  # Warning only, not required
    print()

    # Check directories
    print("[5/7] Checking directories...")
    results.append(check_directories())
    print()

    # Check disk space
    print("[6/7] Checking disk space...")
    check_disk_space("/root", min_gb=5)
    check_disk_space("/root/autodl-tmp", min_gb=20)
    print()

    # Summary
    print("[7/7] Summary")
    print("=" * 60)
    if all(results):
        print_status("All critical checks passed! ✓", "ok")
        print()
        print("You can now:")
        print("  1. Configure .env file (copy from .env.example)")
        print("  2. Run: bash scripts/download_model.sh")
        print("  3. Run: bash scripts/start_server.sh")
        return 0
    else:
        print_status("Some checks failed. Please fix the issues above.", "error")
        print()
        print("Common solutions:")
        print("  - Install dependencies: pip install -r requirements.txt")
        print("  - Run setup script: bash scripts/setup_autodl.sh")
        return 1


if __name__ == "__main__":
    sys.exit(main())
