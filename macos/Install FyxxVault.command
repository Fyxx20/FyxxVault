#!/usr/bin/env bash
# ══════════════════════════════════════════
#  FyxxVault — Double-click installer macOS
# ══════════════════════════════════════════
cd "$(dirname "$0")"
curl -fsSL https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/macos/install.sh | bash
echo ""
echo "Press any key to close..."
read -rsn1
