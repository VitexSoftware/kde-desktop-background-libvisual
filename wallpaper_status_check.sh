#!/bin/bash

echo "=== LibVisual Background Wallpaper - Status Check ==="
echo ""

echo "1. Wallpaper Package Installation:"
if [ -d "/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual" ]; then
    echo "   ✅ Wallpaper package installed"
    echo "   📂 Contents:"
    find /home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual -name "*.qml" -o -name "*.xml" -o -name "*.json" | sort
else
    echo "   ❌ Wallpaper package not found"
fi

echo ""
echo "2. Configuration UI Test:"
if [ -f "/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual/contents/ui/config.qml" ]; then
    echo "   ✅ config.qml exists"
    echo "   🔍 QML Linting:"
    cd /home/vitex/Projects/VitexSoftware/kde-desktop-background-libvisual/plasma-wallpapers/org.kde.libvisual
    /usr/lib/qt6/bin/qmllint contents/ui/config.qml 2>&1 | grep -E "(Error|error)" || echo "      ✅ No critical errors found"
else
    echo "   ❌ config.qml not found"
fi

echo ""
echo "3. QML Module Status:"
if [ -f "/home/vitex/.local/lib/qt6/qml/LibVisualBackend/libvisual_backendplugin.so" ]; then
    echo "   ✅ LibVisualBackend QML plugin available"
    echo "   📋 Plugin file size: $(du -h /home/vitex/.local/lib/qt6/qml/LibVisualBackend/libvisual_backendplugin.so | cut -f1)"
else
    echo "   ⚠️  LibVisualBackend QML plugin not available (graceful fallback active)"
fi

echo ""
echo "4. Wallpaper Plugin Registration:"
if kpackagetool6 --type Plasma/Wallpaper --list | grep -q "org.kde.libvisual"; then
    echo "   ✅ Wallpaper registered with Plasma"
else
    echo "   ❌ Wallpaper not registered"
fi

echo ""
echo "5. Next Steps:"
echo "   🎯 Right-click desktop → Configure Desktop and Wallpaper"
echo "   🎯 Select wallpaper type → Look for 'LibVisual Audio Visualizer'"  
echo "   🎯 Click Configure to test settings - should now work!"
echo "   🎯 Configuration shows backend status and gracefully handles import failures"
echo ""
echo "=== Status Check Complete ==="