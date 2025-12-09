#!/usr/bin/env bash
# Shared download utilities for model provisioning scripts

# Get remote file size from URL
# Strategy:
#   1. Try X-Linked-Size header (HuggingFace LFS) - available in initial 302 response
#   2. If not present, follow redirects (-L) and get Content-Length from final response
#
# Usage: get_remote_size "https://example.com/file.bin"
get_remote_size() {
    local url="$1"
    local size
    local headers

    # First try: get headers without following redirects (for HF X-Linked-Size)
    if [ -n "$HF_TOKEN" ]; then
        headers=$(curl -sI -H "Accept-Encoding: identity" -H "Authorization: Bearer ${HF_TOKEN}" "$url" 2>/dev/null)
    else
        headers=$(curl -sI -H "Accept-Encoding: identity" "$url" 2>/dev/null)
    fi

    # Try X-Linked-Size first (HuggingFace LFS)
    # Use ^ anchor to avoid matching access-control-expose-headers which lists X-Linked-Size
    size=$(echo "$headers" | grep -i "^x-linked-size:" | awk '{print $2}' | tr -d '\r')

    # Fallback: follow redirects and get Content-Length from final response
    if [ -z "$size" ]; then
        if [ -n "$HF_TOKEN" ]; then
            headers=$(curl -sLI -H "Accept-Encoding: identity" -H "Authorization: Bearer ${HF_TOKEN}" "$url" 2>/dev/null)
        else
            headers=$(curl -sLI -H "Accept-Encoding: identity" "$url" 2>/dev/null)
        fi
        size=$(echo "$headers" | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
    fi

    echo "$size"
}

# Get local file size (cross-platform)
#
# Usage: get_local_size "/path/to/file"
get_local_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Download model with size validation
# Skips download if file exists and size matches remote
# Removes corrupted files (size mismatch) and re-downloads
#
# Usage: download_model "URL" "/dest/path" "Description" "log_prefix"
download_model() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local log_prefix="${4:-download}"

    local dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"

    # Check if file exists and validate size
    if [ -f "$dest" ]; then
        echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') $name exists, validating size..."
        local local_size=$(get_local_size "$dest")
        local remote_size=$(get_remote_size "$url")

        if [ -n "$remote_size" ] && [ "$local_size" = "$remote_size" ]; then
            echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') $name OK (${local_size} bytes)"
            return 0
        else
            echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') $name size mismatch: local=${local_size}, remote=${remote_size}"
            echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') Removing corrupted file and re-downloading..."
            rm -f "$dest"
        fi
    fi

    echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') Downloading $name..."
    echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S')   URL: $url"
    echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S')   Destination: $dest"

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
        echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') $name downloaded successfully"
    else
        echo "[${log_prefix}] $(date '+%Y-%m-%d %H:%M:%S') ERROR: Failed to download $name"
        rm -f "$dest"
        return 1
    fi
}
