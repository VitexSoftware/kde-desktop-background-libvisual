#!/bin/bash

echo "=== LibVisual Audio Visualizer - Fresh Deployment Test ==="
echo ""

# Check if wallpaper is registered
echo "1. Wallpaper Registration:"
kpackagetool6 --list --type Plasma/Wallpaper | grep -q libvisual
if [ $? -eq 0 ]; then
    echo "   ✅ org.kde.libvisual is registered with kpackagetool6"
else
    echo "   ❌ org.kde.libvisual NOT found in kpackagetool6 listing"
fi

echo ""
echo "2. Plugin Files:"

# Check plugin .so files
if [ -f "/home/vitex/.local/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_org.kde.libvisual.so" ]; then
    echo "   ✅ Main plugin installed: $(stat --format='%s bytes' /home/vitex/.local/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_org.kde.libvisual.so)"
else
    echo "   ❌ Main plugin NOT found"
fi

echo ""
echo "3. Wallpaper Package:"

# Check wallpaper package contents
if [ -d "/home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual" ]; then
    echo "   ✅ Package directory exists"
    echo "   📁 Contents:"
    find /home/vitex/.local/share/plasma/wallpapers/org.kde.libvisual -name "*.qml" -o -name "*.json" | sed 's/^/      /'
else
    echo "   ❌ Package directory NOT found"
fi

echo ""
echo "4. QML Modules:"

# Check QML modules
if [ -d "/home/vitex/.local/lib/qt6/qml/LibVisualBackend" ]; then
    echo "   ✅ LibVisualBackend QML module installed"
else
    echo "   ❌ LibVisualBackend QML module NOT found"
fi

if [ -d "/home/vitex/.local/lib/qt6/qml/LibVisualProbe" ]; then
    echo "   ✅ LibVisualProbe QML module installed"
else
    echo "   ❌ LibVisualProbe QML module NOT found"
fi

echo ""
echo "5. Environment Paths:"
echo "   QT_PLUGIN_PATH: ${QT_PLUGIN_PATH:-not set}"
echo "   QML2_IMPORT_PATH: ${QML2_IMPORT_PATH:-not set}"

echo ""
echo "=== Fresh Deployment Test Complete ==="
echo ""
echo "🎯 NEXT STEPS:"
echo "   1. Right-click desktop → Configure Desktop and Wallpaper"
echo "   2. Select wallpaper type → Look for 'LibVisual Audio Visualizer'"
echo "   3. Click Configure to test backend functionality"
echo "   4. Play music to test spectrum visualization"