# LibVisual Desktop Background

Application for rendering audio visualizations on KDE desktop environment background using libvisual library.

![waveform screenshot](waveform.png?raw=true)

## Features

- Rendering libvisual visualizations directly on desktop background
- Support for various audio inputs (PulseAudio/ALSA)
- GUI control via system tray
- Automatic switching between visualization plugins
- Settings saved to configuration file
- Support for various libvisual plugins (fractals, waves, etc.)

## Dependencies

### Debian/Ubuntu:
```bash
sudo apt install build-essential cmake qt6-base-dev qt6-tools-dev \
                 libvisual-0.4-dev libpulse-dev libx11-dev \
                 libxrender-dev pkg-config
```

### Fedora/CentOS:
```bash
sudo dnf install gcc-c++ cmake qt6-qtbase-devel qt6-qttools-devel \
                 libvisual-devel pulseaudio-libs-devel libX11-devel \
                 libXrender-devel pkgconfig
```

### Arch Linux:
```bash
sudo pacman -S base-devel cmake qt6-base qt6-tools libvisual \
               pulseaudio libx11 libxrender pkgconf
```

## Build

### Quick dependency installation:
```bash
# Automatic distribution detection and dependency installation
./install_deps.sh
```

### Build from source code:
```bash
# Clone repository
git clone <repository-url>
cd kde-desktop-background-libvisual

# Build using included script
./build.sh

# Or manually:
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
```

### Build Debian package:
```bash
# Instalace build závislostí pro Debian/Ubuntu
sudo apt install debhelper devscripts

# Sestavení .deb balíčku
./build_deb.sh

# Instalace balíčku
sudo dpkg -i ../kde-desktop-background-libvisual_*.deb
sudo apt install -f  # oprava závislostí pokud potřeba
```

### Testování základní funkčnosti:
```bash
# Sestavení zjednodušené verze pro testování
make simple_visualizer
./simple_visualizer
```

## Usage

### Run application:
```bash
./libvisual-bg
```

### Run with automatic visualization start:
```bash
./libvisual-bg --autostart
```

### Controls:
1. Application starts minimized in system tray
2. Double-click tray icon to open control panel
3. In the control panel you can:
   - Select audio device
   - Select visualization plugin
   - Set automatic switching interval
   - Start/stop visualization

## Configuration

Settings are automatically saved to `~/.config/libvisual-bg.conf`:

```ini
[audio]
device=default

[visual]
plugin=gforce
auto_switch_interval=30

[window]
width=1920
height=1080
```

## Available libvisual plugins

Application automatically detects installed libvisual plugins. Common plugins:
- `gforce` - Abstract effects
- `infinite` - Infinite fractals
- `jakdaw` - Spectral analyzer
- `lv_scope` - Oscilloscope
- `nebulus` - Nebula effects

## Troubleshooting

### Application won't start:
1. Check that all dependencies are installed
2. Verify that libvisual plugins are available:
   ```bash
   ls /usr/lib/libvisual-0.4/actor/
   ```

### No audio is detected:
1. Check PulseAudio settings:
   ```bash
   pactl list sources short
   ```
2. Select correct audio input in GUI
3. Ujistěte se, že aplikace má přístup k audio

### Vizualizace se nezobrazuje:
1. Zkontrolujte, zda běží X11 (ne Wayland)
2. Ověřte oprávnění pro desktop rendering
3. Zkuste spustit s jinými window manager vlastnostmi

## Vývoj

### Struktura projektu:
```
src/
├── main.cpp           # Hlavní aplikace a event loop
├── visualizer.cpp/h   # Wrapper pro libvisual API
├── audio_input.cpp/h  # PulseAudio input handling
├── desktop_renderer.cpp/h # X11 desktop rendering
├── settings.cpp/h     # Konfigurace a nastavení
└── gui.cpp/h         # Qt GUI a systémový tray
```

### Přidání nového audio backendu:
1. Implementujte rozhraní v `audio_input.h`
2. Přidejte detekci do `AudioInput::getAvailableDevices()`
3. Aktualizujte GUI pro výběr backendu

### Přidání nových rendering možností:
1. Rozšiřte `DesktopRenderer` pro různé kompozitory
2. Implementujte Wayland backend
3. Přidejte podporu pro více monitorů

## Licence

[Určete licenci podle vašich požadavků]

## Přispívání

1. Forkněte repozitář
2. Vytvořte feature branch
3. Commitněte změny
4. Pushněte do branch
5. Vytvořte Pull Request