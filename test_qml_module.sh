#!/bin/bash

echo "Testing LibVisualBackend availability..."

# Try to open wallpaper configuration through system settings
echo "Opening wallpaper configuration..."

# Alternative: Use a simpler test
echo "Testing QML import resolution..."

# Create a simple import test
cat > /tmp/test_import.qml << 'EOF'
import QtQuick 2.15
import LibVisualBackend 1.0

Item {
    Component.onCompleted: {
        console.log("SUCCESS: LibVisualBackend imported successfully!")
        Qt.quit()
    }
}
EOF

# Set up environment and test
export QML2_IMPORT_PATH="/home/vitex/.local/lib/qt6/qml:/home/vitex/.local/lib/x86_64-linux-gnu/qml:$QML2_IMPORT_PATH"

# Try to find a QML runner
if command -v qml6 &> /dev/null; then
    echo "Testing with qml6..."
    qml6 /tmp/test_import.qml
elif command -v qmlscene6 &> /dev/null; then
    echo "Testing with qmlscene6..."
    qmlscene6 /tmp/test_import.qml
else
    echo "No QML runner found, opening wallpaper settings instead..."
    systemsettings5 kcm_wallpaper || systemsettings6 kcm_wallpaper || echo "Could not open wallpaper settings"
fi