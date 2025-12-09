#!/usr/bin/env bash
set -e

# RMBG-2.0 Model Provisioning Script
# Downloads required models to Network Volume if not present

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/download_utils.sh"

VOLUME_PATH="${RUNPOD_VOLUME_PATH:-/runpod-volume}"
MODELS_DIR="${VOLUME_PATH}/models/RMBG/RMBG-2.0"
LOG_PREFIX="provision-rmbg"

# Model URL from briaai/RMBG-2.0
MODEL_URL="https://huggingface.co/briaai/RMBG-2.0/resolve/main/model.pth"
MODEL_PATH="${MODELS_DIR}/model.pth"

log() {
    echo "[${LOG_PREFIX}] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

main() {
    log "Starting RMBG-2.0 model provisioning"
    log "Volume path: $VOLUME_PATH"
    log "Models directory: $MODELS_DIR"

    if [ ! -d "$VOLUME_PATH" ]; then
        log "ERROR: Volume not mounted at $VOLUME_PATH"
        log "Skipping provisioning - models must be on network volume"
        exit 0
    fi

    mkdir -p "$MODELS_DIR"

    download_model "$MODEL_URL" "$MODEL_PATH" "RMBG-2.0 model (~175MB)" "$LOG_PREFIX"

    log "Provisioning complete"
}

main "$@"
