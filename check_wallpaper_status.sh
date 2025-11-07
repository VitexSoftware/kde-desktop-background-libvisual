#!/bin/bash

echo "=== LibVisual Wallpaper Error Resolution Test ==="
echo
echo "Checking wallpaper loading status..."

# Check if wallpaper files are installed
MAIN_QML="/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual/contents/ui/main.qml"
if [ -f "$MAIN_QML" ]; then
    echo "✓ main.qml installed"
    
    # Check import status
    if grep -q "LibVisualBackend" "$MAIN_QML"; then
        echo "⚠ Still contains LibVisualBackend import"
    else
        echo "✓ LibVisualBackend import removed successfully"
    fi
    
    # Check for dynamic loading
    if grep -q "createComponent" "$MAIN_QML"; then
        echo "✓ Dynamic component creation approach implemented"
    fi
    
    # Check for fallback mode
    if grep -q "useRealAudio.*false" "$MAIN_QML"; then
        echo "✓ Real audio disabled by default for compatibility"
    fi
else
    echo "✗ main.qml not found"
fi

echo
echo "Testing wallpaper loading with journalctl..."
echo "Looking for recent plasmashell errors..."

# Check for recent plasmashell errors
journalctl --user -u plasma-plasmashell.service --since="5 minutes ago" --no-pager | grep -i "error\|libvisual" | tail -5

echo
echo "Current Plasma processes:"
ps aux | grep plasmashell | grep -v grep

echo
echo "To test the wallpaper:"
echo "1. Open System Settings → Appearance → Wallpaper"  
echo "2. Select 'LibVisual Wallpaper'"
echo "3. Check if it loads without errors"
echo "4. Look for 'Backend: SIMULATED' in top-left if 'Show Info' is enabled"