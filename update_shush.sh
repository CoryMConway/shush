#!/usr/bin/env bash
set -euo pipefail

# =========================
# shush Python Update Script
# =========================

GITHUB_URL="https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/install_shush_python.sh"
APP_DIR="$HOME/.shush"
APP_ENTRY="$APP_DIR/shush.py"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/shush"
TEMP_FILE="/tmp/install_shush_python_latest.sh"

echo "🔄 Updating shush (Python version)..."

# Check if Python shush is installed
if [ ! -f "$APP_ENTRY" ]; then
    echo "❌ Python shush not found at $APP_ENTRY"
    echo "Run the Python install script first: bash install_shush_python.sh"
    exit 1
fi

# Backup current config
CONFIG_BACKUP=""
if [ -f "$CONF_DIR/config.json" ]; then
    CONFIG_BACKUP=$(cat "$CONF_DIR/config.json")
    echo "💾 Backing up configuration..."
fi

# Download latest install script
echo "📥 Downloading latest install_shush_python.sh..."
if command -v curl >/dev/null 2>&1; then
    curl -s -L "$GITHUB_URL" -o "$TEMP_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$GITHUB_URL" -O "$TEMP_FILE"
else
    echo "❌ Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Verify download
if [ ! -f "$TEMP_FILE" ]; then
    echo "❌ Failed to download install script"
    exit 1
fi

# Remove old installation (but preserve config backup)
echo "🗑️  Removing old installation..."
rm -rf "$APP_DIR"

# Run the new installer with preserved config
echo "🔧 Installing updated version..."
if [ -n "$CONFIG_BACKUP" ]; then
    # Create temp script that will restore config after installation
    RESTORE_SCRIPT="/tmp/restore_shush_config.sh"
    cat > "$RESTORE_SCRIPT" <<EOF
#!/bin/bash
# Restore config after installation
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/config.json" <<'CONFIG_EOF'
$CONFIG_BACKUP
CONFIG_EOF
echo "✅ Configuration restored"
EOF
    chmod +x "$RESTORE_SCRIPT"
    
    # Run installer with auto-config restoration
    bash "$TEMP_FILE" <<< "$(echo "$CONFIG_BACKUP" | python3 -c "import sys, json; print(json.loads(sys.stdin.read())['root'])")"
    
    # Clean up
    rm -f "$RESTORE_SCRIPT"
else
    # No config to restore, run installer normally
    bash "$TEMP_FILE"
fi

# Cleanup
rm -f "$TEMP_FILE"

echo "✅ shush Python version updated successfully!"
echo "📍 Updated: $APP_ENTRY"
echo "🚀 Run 'shush' to use the updated version"