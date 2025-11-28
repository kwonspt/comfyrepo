#!/usr/bin/env bash
set -e

# Qwen-Image FP8 Model Provisioning Script
# Downloads required models to Network Volume if not present
# Run at worker deploy/startup time

VOLUME_PATH="${RUNPOD_VOLUME_PATH:-/runpod-volume}"
MODELS_DIR="${VOLUME_PATH}/models"

# Model URLs from Comfy-Org/Qwen-Image_ComfyUI
DIFFUSION_URL="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors"
TEXT_ENCODER_URL="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
VAE_URL="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

# Lightning LoRA from lightx2v/Qwen-Image-Lightning
LIGHTNING_LORA_URL="https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-8steps-V2.0.safetensors"

# Target paths
DIFFUSION_PATH="${MODELS_DIR}/diffusion_models/qwen_image_fp8_e4m3fn.safetensors"
TEXT_ENCODER_PATH="${MODELS_DIR}/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
VAE_PATH="${MODELS_DIR}/vae/qwen_image_vae.safetensors"
LIGHTNING_LORA_PATH="${MODELS_DIR}/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors"

log() {
    echo "[provision-qwen] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

get_remote_size() {
    local url="$1"
    local size
    if [ -n "$HF_TOKEN" ]; then
        size=$(wget --spider --header="Authorization: Bearer ${HF_TOKEN}" -S "$url" 2>&1 | grep -i content-length | tail -1 | awk '{print $2}' | tr -d '\r')
    else
        size=$(wget --spider -S "$url" 2>&1 | grep -i content-length | tail -1 | awk '{print $2}' | tr -d '\r')
    fi
    echo "$size"
}

get_local_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null
    else
        echo "0"
    fi
}

download_model() {
    local url="$1"
    local dest="$2"
    local name="$3"

    local dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"

    # Check if file exists and validate size
    if [ -f "$dest" ]; then
        log "$name exists, validating size..."
        local local_size=$(get_local_size "$dest")
        local remote_size=$(get_remote_size "$url")

        if [ -n "$remote_size" ] && [ "$local_size" = "$remote_size" ]; then
            log "$name OK (${local_size} bytes)"
            return 0
        else
            log "$name size mismatch: local=${local_size}, remote=${remote_size}"
            log "Removing corrupted file and re-downloading..."
            rm -f "$dest"
        fi
    fi

    log "Downloading $name..."
    log "  URL: $url"
    log "  Destination: $dest"

    if [ -n "$HF_TOKEN" ]; then
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
             --progress=dot:giga \
             -O "$dest" \
             "$url"
    else
        wget --progress=dot:giga \
             -O "$dest" \
             "$url"
    fi

    if [ $? -eq 0 ]; then
        log "$name downloaded successfully"
    else
        log "ERROR: Failed to download $name"
        rm -f "$dest"
        return 1
    fi
}

main() {
    log "Starting Qwen-Image model provisioning"
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
    mkdir -p "${MODELS_DIR}/loras"
    mkdir -p "${MODELS_DIR}/VLM"

    # Download models
    download_model "$DIFFUSION_URL" "$DIFFUSION_PATH" "Qwen-Image diffusion model (~20GB)"
    download_model "$TEXT_ENCODER_URL" "$TEXT_ENCODER_PATH" "Qwen-Image text encoder (~7GB)"
    download_model "$VAE_URL" "$VAE_PATH" "Qwen-Image VAE (~300MB)"
    download_model "$LIGHTNING_LORA_URL" "$LIGHTNING_LORA_PATH" "Qwen-Image Lightning LoRA (~1.5GB)"

    log "Provisioning complete"

    # List downloaded models
    log "Models in volume:"
    find "$MODELS_DIR" -type f -name "*.safetensors" -exec ls -lh {} \;

    # Note: VLM models (Qwen2.5-VL for captioning) are auto-downloaded
    # by ComfyUI-Qwen2_5-VL node on first use. They're cached in HF_HOME
    # which is set to /runpod-volume/huggingface in start.sh
    log "VLM models will be auto-downloaded on first captioning request"
}

main "$@"
