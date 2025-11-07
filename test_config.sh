#!/bin/bash

echo "=== LibVisual Config UI Test ==="
echo ""

# Check if config.qml exists and is readable
CONFIG_FILE="/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual/contents/ui/config.qml"
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ config.qml exists: $(stat --format='%s bytes' "$CONFIG_FILE")"
    
    # Check for syntax errors by trying to parse the QML
    if command -v qmlsc >/dev/null 2>&1; then
        echo "🔍 Testing QML syntax..."
        qmlsc "$CONFIG_FILE" 2>&1 | head -5
    else
        echo "💡 QML syntax checker not available"
    fi
else
    echo "❌ config.qml NOT found"
fi

# Check main.xml config structure
MAIN_XML="/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual/contents/config/main.xml"
if [ -f "$MAIN_XML" ]; then
    echo "✅ main.xml config exists"
else
    echo "❌ main.xml config NOT found"
fi

echo ""
echo "🎯 TROUBLESHOOTING STEPS:"
echo "1. Look for a small gear/settings icon next to the wallpaper dropdown"
echo "2. Try clicking 'Apply' first, then look for configuration options"
echo "3. Some wallpapers show config after being applied"
echo "4. Check if there's a 'Configure...' button in the wallpaper section"