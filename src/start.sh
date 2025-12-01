#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

# Diagnostic: Check extra_model_paths.yaml
if [ -f /comfyui/extra_model_paths.yaml ]; then
    echo "worker-comfyui: extra_model_paths.yaml found at /comfyui/"
    echo "worker-comfyui: extra_model_paths.yaml content:"
    cat /comfyui/extra_model_paths.yaml
else
    echo "worker-comfyui: WARNING - extra_model_paths.yaml NOT found at /comfyui/"
fi

# Diagnostic: Check network volume
if [ -d /runpod-volume ]; then
    echo "worker-comfyui: Network volume mounted at /runpod-volume"
    echo "worker-comfyui: /runpod-volume contents:"
    ls -la /runpod-volume/
    if [ -d /runpod-volume/models ]; then
        echo "worker-comfyui: /runpod-volume/models contents:"
        ls -la /runpod-volume/models/
    else
        echo "worker-comfyui: WARNING - /runpod-volume/models does NOT exist"
    fi
else
    echo "worker-comfyui: INFO - /runpod-volume does not exist (no network volume attached)"
fi

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi