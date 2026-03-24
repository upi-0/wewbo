#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
BIN_NAME="wewbo"
URL="https://github.com/upi-0/wewbo/releases/latest/download/$BIN_NAME"

echo "[*] Installing $BIN_NAME..."

# Check dependency
if ! command -v curl >/dev/null 2>&1; then
    echo "[!] curl is required"
    exit 1
fi

mkdir -p "$INSTALL_DIR"

curl -fsSL "$URL" -o "$INSTALL_DIR/$BIN_NAME"
chmod +x "$INSTALL_DIR/$BIN_NAME"

echo "[+] Installed to $INSTALL_DIR/$BIN_NAME"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "[!] $INSTALL_DIR not in PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
fi

echo "[✔] Done!"
echo ""
$INSTALL_DIR/$BIN_NAME
