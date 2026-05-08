#!/bin/bash

# ==============================================================================
# SSH Remote Connection Helper
# Supports both Cloudflare tunnel and LAN direct access
# ==============================================================================

REMOTE_HOST="${REMOTE_HOST:-j.mrme0.store}"
REMOTE_USER="${REMOTE_USER:-m}"
REMOTE_IP="${REMOTE_IP:-}"  # Optional: Windows machine's LAN IP
USE_CLOUDFLARE="${USE_CLOUDFLARE:-true}"  # Set to false for LAN-only

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST     Remote host (default: j.mrme0.store)"
    echo "  -u, --user USER     Remote user (default: m)"
    echo "  -i, --ip IP         Direct LAN IP for direct SSH (bypasses Cloudflare)"
    echo "  --lan               Force LAN mode (requires -i option)"
    echo "  --cloudflare        Force Cloudflare tunnel mode"
    echo "  --help              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Use Cloudflare tunnel"
    echo "  $0 --lan -i 192.168.1.100       # Direct LAN SSH"
    echo "  $0 -h j.mrme0.store -u j        # Custom host/user"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -i|--ip)
            REMOTE_IP="$2"
            shift 2
            ;;
        --lan)
            USE_CLOUDFLARE="false"
            shift
            ;;
        --cloudflare)
            USE_CLOUDFLARE="true"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"

# Recommended SSH config (add to ~/.ssh/config)
show_ssh_config() {
    echo ""
    echo "Recommended ~/.ssh/config entry:"
    echo "---"
    if [ "$USE_CLOUDFLARE" = "true" ]; then
        echo "Host ${REMOTE_HOST}"
        echo "    User ${REMOTE_USER}"
        echo "    ProxyCommand cloudflared access ssh --hostname %h"
    else
        if [ -n "$REMOTE_IP" ]; then
            echo "Host ${REMOTE_IP}"
            echo "    User ${REMOTE_USER}"
            echo "    HostName ${REMOTE_IP}"
        fi
    fi
    echo "---"
}

echo "Connecting to ${REMOTE_TARGET}..."

if [ "$USE_CLOUDFLARE" = "true" ]; then
    echo "Using Cloudflare tunnel..."
    ssh -o ProxyCommand="cloudflared access ssh --hostname %h" "$REMOTE_TARGET"
else
    if [ -z "$REMOTE_IP" ]; then
        echo "Error: LAN mode requires -i/--ip option"
        usage
        exit 1
    fi
    echo "Using direct LAN connection to ${REMOTE_IP}..."
    ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP"
fi
