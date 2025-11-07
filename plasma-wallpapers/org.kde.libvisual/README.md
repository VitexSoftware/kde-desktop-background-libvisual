# LibVisual Plasma Wallpaper Plugin

Minimal Plasma 6 wallpaper plugin prepared for future LibVisual / audio-reactive integration.

## 🏗️ Build & User Install (no sudo)

```bash
cd plasma-wallpapers/org.kde.libvisual
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$HOME/.local ..
cmake --build . --parallel
cmake --install .

# Clear KDE caches (optional if not first install)
rm -rf ~/.cache/ksycoca* ~/.cache/plasma* ~/.cache/kservice*

# Restart Plasma shell
kquitapp6 plasmashell && sleep 2 && plasmashell &
```

After install you should have:

```text
~/.local/share/plasma/wallpapers/org.kde.libvisual/metadata.json
~/.local/share/plasma/wallpapers/org.kde.libvisual/contents/ui/main.qml
~/.local/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_org.kde.libvisual.so
```

## 🎯 Testing

1. Open System Settings → Appearance → Wallpaper.
2. In wallpaper type list look for “LibVisual Background”.
3. Apply it: you should see a solid color background (#004477) from `main.qml`.

If it does not appear, verify paths above and ensure Plasma 6 session was restarted.

## 📁 Structure

```text
org.kde.libvisual/
├── metadata.json        # Plugin metadata (Plasma 6 format)
├── plugin.cpp           # C++ QObject plugin exposing future backend
├── plugin.h             # Header
├── contents/
│   ├── ui/
│   │   ├── main.qml     # Minimal wallpaper (solid color)
│   │   └── config.qml   # Placeholder config UI
│   └── config/
│       └── main.xml     # KConfigXT schema
└── CMakeLists.txt       # Build & install logic
```

Optional legacy `metadata.desktop` file is not required for Plasma 6 wallpapers and can be removed.

## 🔧 Preparing LibVisual / Audio Integration

Uncomment in `CMakeLists.txt` when ready:

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBVISUAL REQUIRED libvisual-0.4)
```

Example initialization stub (future):

```cpp
#include <libvisual/libvisual.h>

void LibVisualWallpaper::initializeLibVisual() {
    visual_init(nullptr, nullptr);
    // Configure actor, video/audio sources, and schedule frameReady() signals
}
```

Audio path (alternative to libvisual): PulseAudio capture → FFTW3 transform → expose spectrum via Q_PROPERTY for QML bars.

## ✅ Current Status

- ✅ Minimal Plasma 6 wallpaper package & plugin library
- ✅ Correct user-level install procedure (no root, no DESTDIR)
- ✅ Metadata JSON ServiceTypes registered
- ✅ KConfig schema & placeholder config QML
- 🔄 Pending: audio + libvisual / FFTW integration
- 🔄 Pending: expose properties (e.g. spectrum array, peak levels) to QML

## 🚀 Next Steps (Suggested)

1. Confirm visibility in System Settings.
2. Add simple timer-driven color change to validate repaint flow.
3. Integrate audio capture thread (PulseAudio simple API).
4. Publish spectrum via Q_PROPERTY (`QVector<float>`) to QML.
5. Replace solid color with bar visualization in `main.qml`.

## 🧪 Troubleshooting

| Issue | Check |
|-------|-------|
| Not listed in wallpaper types | Ensure install paths match those above; restart plasmashell |
| Old version persists | Clear caches and restart plasmashell |
| Crash on load after adding LibVisual | Verify libvisual pkg-config flags and initialize only once |

## 📜 License

GPL-3.0-or-later
