#!/bin/bash

# Simple helper to SSH into the remote machine using Cloudflare Access
# This command uses the standard ssh client with cloudflared as a proxy.

REMOTE_TARGET="j@j.mrme0.store"

# Optional: Add to ~/.ssh/config for even easier access
# Host j.mrme0.store
#     ProxyCommand cloudflared access ssh --hostname %h

echo "Connecting to $REMOTE_TARGET via Cloudflare Tunnel..."
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" "$REMOTE_TARGET"
