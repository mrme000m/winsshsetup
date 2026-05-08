#!/bin/bash

# Main setup script for Windows SSH
# This script reads your public key and calls the expect script to configure the remote machine.

# Configuration
REMOTE_TARGET="j@j.mrme0.store"
REMOTE_PASS="j"
PUBKEY_PATH="$(dirname "$0")/id_ed25519.pub"

# Check if pubkey exists
if [ ! -f "$PUBKEY_PATH" ]; then
    echo "Public key not found at $PUBKEY_PATH"
    echo "Generating a new one..."
    ssh-keygen -t ed25519 -f "${PUBKEY_PATH%.pub}" -N ""
fi

PUBKEY_CONTENT=$(cat "$PUBKEY_PATH")

# Ensure expect script is executable
chmod +x "$(dirname "$0")/automate_win_ssh.expect"

# Run the automation
"$(dirname "$0")/automate_win_ssh.expect" "$REMOTE_TARGET" "$REMOTE_PASS" "$PUBKEY_CONTENT"
