#!/usr/bin/env bash
set -euo pipefail

# =========================
# Shush Update Script
# =========================

GITHUB_URL="https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/install_shush.sh"
APP_DIR="$HOME/.shush"
APP_ENTRY="$APP_DIR/index.mjs"
TEMP_FILE="/tmp/install_shush_latest.sh"

echo "🔄 Updating shush..."

# Check if shush is installed
if [ ! -f "$APP_ENTRY" ]; then
    echo "❌ Shush not found at $APP_ENTRY"
    echo "Run the install script first: sh install_shush.sh"
    exit 1
fi

# Download latest install script
echo "📥 Downloading latest install_shush.sh..."
if command -v curl >/dev/null 2>&1; then
    curl -s -L "$GITHUB_URL" -o "$TEMP_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$GITHUB_URL" -O "$TEMP_FILE"
else
    echo "❌ Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Extract React code from the downloaded file
echo "🔧 Extracting React code..."
# Find the line that starts the React code (after "cat > "$APP_ENTRY" <<'EOF'")
START_LINE=$(grep -n "cat > \"\$APP_ENTRY\" <<'EOF'" "$TEMP_FILE" | cut -d: -f1)
if [ -z "$START_LINE" ]; then
    echo "❌ Could not find React code start marker in downloaded file"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Find the line that ends the React code (the line with just "EOF")
END_LINE=$(tail -n +$((START_LINE + 1)) "$TEMP_FILE" | grep -n "^EOF$" | head -n 1 | cut -d: -f1)
if [ -z "$END_LINE" ]; then
    echo "❌ Could not find React code end marker in downloaded file"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Calculate the actual end line number
END_LINE=$((START_LINE + END_LINE))

# Extract the React code (between START_LINE+1 and END_LINE-1)
sed -n "$((START_LINE + 1)),$((END_LINE - 1))p" "$TEMP_FILE" > "$APP_ENTRY"

# Cleanup
rm -f "$TEMP_FILE"

echo "✅ Shush updated successfully!"
echo "📍 Updated: $APP_ENTRY"
echo "🚀 Run 'shush' to use the updated version"