# KDE Plasma Wallpaper Plugin Approach

Based on KDE documentation analysis, here's a better approach for integrating audio visualization with KDE Plasma:

## Current Status Summary

### ✅ Working Components
- X11 desktop rendering (proven with minimal_test)
- Qt6 application framework with system tray
- CMake build system 
- PulseAudio integration setup
- Complete modular architecture

### ❌ Current Issues  
- libvisual 0.4.2 memory allocation problems
- Direct X11 approach may conflict with Plasma desktop management

## Better Approach: Plasma Wallpaper Plugin

Instead of direct X11 manipulation, create a **Plasma Wallpaper Plugin**:

### Advantages:
1. **Official Integration**: Works within Plasma's desktop management
2. **User Friendly**: Appears in System Settings > Wallpaper
3. **Proper Integration**: Respects Plasma's activity/desktop model
4. **No Conflicts**: Plasma manages the desktop, we provide content

### Plugin Structure:
```
plasma-wallpaper-libvisual/
├── metadata.json           # Plugin metadata
├── contents/
│   └── ui/
│       ├── config.qml      # Configuration UI
│       └── main.qml        # Main wallpaper QML
└── src/
    ├── libvisual-wallpaper.cpp  # C++ backend
    └── libvisual-wallpaper.h    # Plugin interface
```

### Implementation Plan:

#### 1. Plasma Wallpaper Plugin (QML + C++)
- **main.qml**: Canvas for rendering visualization
- **config.qml**: Settings UI (plugin selection, audio device)
- **C++ backend**: LibVisual integration, audio processing

#### 2. Alternative to libvisual
Given libvisual issues, consider:
- **FFTW3**: Direct FFT analysis + custom visualization
- **Qt Quick**: Hardware-accelerated rendering with QML
- **OpenGL**: Direct GPU rendering for performance

#### 3. Example Implementation:
```qml
// main.qml
import QtQuick 2.15
import org.kde.plasma.core 2.0

Item {
    id: wallpaper
    
    Canvas {
        id: visualizer
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d")
            // Render visualization from C++ backend
            backend.render(ctx, width, height)
        }
    }
    
    Timer {
        running: true
        interval: 16  // 60 FPS
        repeat: true
        onTriggered: visualizer.requestPaint()
    }
}
```

#### 4. Configuration Integration:
```json
{
    "KPlugin": {
        "Id": "org.kde.plasma.libvisual",
        "Name": "Audio Visualization Wallpaper",
        "Category": "Wallpaper",
        "License": "GPL-3.0"
    },
    "X-Plasma-API": "declarativeappletscript",
    "X-Plasma-MainScript": "ui/main.qml",
    "X-KDE-PlasmaImageWallpaper-AccentColor": "#3498db"
}
```

### Migration Path:
1. **Keep current code**: Use as reference for audio/visualization logic
2. **Create Plasma plugin**: New approach with QML frontend
3. **Reuse components**: AudioInput, Settings classes can be adapted
4. **Better libvisual alternative**: Implement custom visualization engine

This approach would be:
- More KDE-native
- User-friendly (appears in system settings)
- Conflict-free with desktop management
- Potentially more performant (Qt Quick GPU acceleration)

## Next Steps:
1. Resolve current libvisual issues OR implement alternative
2. Study Plasma wallpaper plugin examples  
3. Create minimal QML-based wallpaper plugin
4. Port audio visualization logic to Qt Quick/OpenGL