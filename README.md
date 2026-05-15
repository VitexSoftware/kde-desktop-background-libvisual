# LibVisual Desktop Background

Audio-reactive wallpaper plugin for KDE Plasma 6. Renders real-time visualizations on the desktop background, driven by live microphone or audio input via PulseAudio/PipeWire.

![waveform screenshot](waveform.png?raw=true)

**Version 1.1.5**

## Features

- 19 built-in visualization types, all audio-reactive
- GPU-accelerated Mandelbrot zoom via GLSL shader (NVIDIA/AMD/Intel)
- Real-time FFT spectrum analysis using FFTW3
- PulseAudio/PipeWire integration — reads from any capture source
- Configuration dialog with live audio level meter and per-type animated preview
- Input-only device selector — monitors and loopback sources are excluded
- Color scheme selection (Rainbow, Blue Gradient, Fire, Plasma, Monochrome)
- Status indicator overlay (optional)

## Visualization Types

| # | Name | Description |
|---|------|-------------|
| 0 | Spectrum Analyzer | 64-bar FFT spectrum, height and color driven by frequency magnitude |
| 1 | Waveform | Full-screen dual sine wave, amplitude tracks audio peak |
| 2 | Lissajous | XY oscilloscope Lissajous figures, reactive to bass/treble |
| 3 | Circular Burst | 50 concentric circles pulsing with frequency bands |
| 4 | Circular Spectrum | 64 radial bars arranged in a circle |
| 5 | Plasma | 8 animated colored blobs with sine-driven motion |
| 6 | Starfield | 120 stars flying outward from center, speed scales with peak |
| 7 | Fireworks | Particle bursts spawned on bass beats |
| 8 | Matrix Rain | Falling green characters, speed driven by treble |
| 9 | DNA Helix | Two intertwined sine strands with connecting rungs |
| 10 | Particle Storm | 150 particles orbiting in audio-reactive paths |
| 11 | Ripple Effect | Expanding concentric rings, radius and opacity driven by bass |
| 12 | Tunnel Vision | Rotating nested rectangles converging to center |
| 13 | Spiral Galaxy | 200 dots in three rotating spiral arms |
| 14 | Lightning | Recursive jagged bolts spawned on peaks |
| 15 | Mandelbrot Zoom | GPU-rendered Mandelbrot set, zoom and iterations driven by audio |
| 16 | Geometric Dance | Five rotating polygons (triangle→octagon), scale with audio |
| 17 | Audio Bars 3D | FFT bars rendered in perspective projection |
| 18 | Kaleidoscope | 8-segment radially mirrored animated pattern |

## Dependencies

### Debian/Ubuntu
```bash
sudo apt install cmake qt6-base-dev qt6-declarative-dev \
                 libkf6coreaddons-dev libkf6i18n-dev \
                 libkf6package-dev plasma-workspace-dev \
                 libpulse-dev libfftw3-dev \
                 pipewire-pulse pulseaudio-utils
```

### Fedora
```bash
sudo dnf install cmake qt6-qtbase-devel qt6-qtdeclarative-devel \
                 kf6-kcoreaddons-devel kf6-ki18n-devel \
                 kf6-kpackage-devel plasma-workspace-devel \
                 pulseaudio-libs-devel fftw-devel pipewire-pulseaudio
```

### Arch Linux
```bash
sudo pacman -S cmake qt6-base qt6-declarative \
               kcoreaddons ki18n kpackage plasma-workspace \
               libpulse fftw pipewire-pulse
```

## Build and Install

```bash
git clone https://github.com/VitexSoftware/kde-desktop-background-libvisual
cd kde-desktop-background-libvisual/plasma-wallpapers/org.kde.libvisual
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/.local"
make -j"$(nproc)"
sudo make install
```

Restart Plasma to load the plugin:
```bash
killall plasmashell && plasmashell &
```

### Build Debian package
```bash
sudo apt install debhelper devscripts
./build_deb.sh
sudo dpkg -i ../kde-desktop-background-libvisual_*.deb
```

## Activating the Wallpaper

1. Right-click the desktop → **Configure Desktop and Wallpaper…**
2. In the **Wallpaper Type** dropdown select **LibVisual Background**
3. Click **Apply**

The configuration panel appears below the selector. From there you can:
- **Input Device** — choose from detected microphone/capture sources (output monitors are excluded)
- **Sensitivity / Smoothing** — tune the audio reactivity
- **Visualization Type** — pick from 19 types; the preview updates live
- **Color Scheme** — global color palette used by most visualizations
- **Show Status Indicator** — small overlay showing dB level and backend state

## Audio Level Meter

The level meter in the config dialog reads from the real PulseAudio/PipeWire backend. When a device with no microphone connected is selected (e.g. onboard audio without a mic plugged in), the meter shows −60 dB (silence). It updates in real time as you switch devices or plug in a microphone.

## Testing

```bash
# Full build, install, and diagnostic check
./test.sh

# Config UI and schema validation
bash test_config.sh

# AudioVisualizer QML module install check
bash test_qml_module.sh

# System diagnostics (plugin files, symbols, PulseAudio sources)
./diagnostics.sh
# or quick mode (skip ldd / journal):
./diagnostics.sh --quick
```

## Troubleshooting

### No audio detected / meter stays at −60 dB
1. Check available input sources:
   ```bash
   pactl list short sources | grep -v monitor
   ```
2. Select the correct device in the wallpaper configuration dialog.
3. If the list is empty, ensure a capture device is connected and PipeWire/PulseAudio is running:
   ```bash
   systemctl --user status pipewire pipewire-pulse
   ```

### Wallpaper shows a black or blank screen
1. Verify the plugin was installed correctly:
   ```bash
   ./diagnostics.sh --quick
   ```
2. Check the Plasma journal for QML errors:
   ```bash
   journalctl --user -n 100 | grep -i libvisual
   ```
3. Restart Plasma:
   ```bash
   killall plasmashell && plasmashell &
   ```

### Mandelbrot Zoom shows blank
The Mandelbrot visualization requires a compiled GLSL shader (`mandelbrot.frag.qsb`). This is built automatically when Qt6 ShaderTools is available. Check:
```bash
ls ~/.local/share/plasma/wallpapers/org.kde.libvisual/contents/shaders/
```
If `mandelbrot.frag.qsb` is missing, install `qt6-shader-baker` and rebuild.

## Project Structure

```
plasma-wallpapers/org.kde.libvisual/
├── audiovisualizer.cpp/h   # PulseAudio capture + FFTW spectrum backend (QML element)
├── plugin.cpp/h            # Plasma wallpaper plugin entry point
├── CMakeLists.txt          # Build system
├── metadata.json           # KPackage metadata
└── contents/
    ├── config/main.xml     # KConfig schema (all settings with defaults)
    └── ui/
        ├── main.qml        # Wallpaper rendering – all 19 visualization types
        └── config.qml      # Configuration dialog – device picker, level meter, preview
```

## License

GPL-3.0-or-later — see [LICENSE](LICENSE)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `./test.sh` to verify the build
4. Open a Pull Request
