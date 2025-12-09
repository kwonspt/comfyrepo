#!/usr/bin/env bash
set -e

# Z-Image-Turbo FP8 Model Provisioning Script
# Downloads required models to Network Volume if not present
# Run at worker deploy/startup time

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/download_utils.sh"

VOLUME_PATH="${RUNPOD_VOLUME_PATH:-/runpod-volume}"
MODELS_DIR="${VOLUME_PATH}/models"
LOG_PREFIX="provision-z-image"

# Model URLs from Comfy-Org/z_image_turbo
DIFFUSION_URL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors"
TEXT_ENCODER_URL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"
VAE_URL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"

# Target paths
DIFFUSION_PATH="${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors"
TEXT_ENCODER_PATH="${MODELS_DIR}/text_encoders/qwen_3_4b.safetensors"
VAE_PATH="${MODELS_DIR}/vae/ae.safetensors"

log() {
    echo "[${LOG_PREFIX}] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

main() {
    log "Starting Z-Image-Turbo model provisioning"
    log "Volume path: $VOLUME_PATH"
    log "Models directory: $MODELS_DIR"

    # Check if volume is mounted
    if [ ! -d "$VOLUME_PATH" ]; then
        log "ERROR: Volume not mounted at $VOLUME_PATH"
        log "Skipping provisioning - models must be on network volume"
        exit 0
    fi

    # Create model directories
    mkdir -p "${MODELS_DIR}/diffusion_models"
    mkdir -p "${MODELS_DIR}/text_encoders"
    mkdir -p "${MODELS_DIR}/vae"

    # Download models
    download_model "$DIFFUSION_URL" "$DIFFUSION_PATH" "Z-Image-Turbo BF16 diffusion model (~12GB)" "$LOG_PREFIX"
    download_model "$TEXT_ENCODER_URL" "$TEXT_ENCODER_PATH" "Qwen 3.4B text encoder (~8GB)" "$LOG_PREFIX"
    download_model "$VAE_URL" "$VAE_PATH" "Z-Image VAE (~300MB)" "$LOG_PREFIX"

    log "Provisioning complete"

    # List downloaded models
    log "Z-Image models in volume:"
    find "$MODELS_DIR" -type f \( -name "*z_image*" -o -name "qwen_3_4b*" -o -name "ae.safetensors" \) -exec ls -lh {} \; 2>/dev/null || true
}

main "$@"
