# Plasma Audio Visualizer Wallpaper Plugin

## Popis

Pokročilá KDE Plasma tapeta s real-time audio spektrum vizualizací pomocí FFTW3. Plně integrovaná do System Settings s konfigurací.

## Funkce

- 🎵 **Real-time audio spektrum** - FFTW3 FFT analýza
- 🎨 **5 barevných schémat** - Rainbow, Blue, Fire, Plasma, Monochrome  
- ⚙️ **Konfigurace v System Settings** - citlivost, vyhlazování, zařízení
- 🚀 **60 FPS rendering** - hardware-accelerated Qt Quick Canvas
- 🔧 **Demo režim** - testování bez audio vstupu
- 📱 **Responsive design** - přizpůsobení všem rozlišením

## Sestavení a instalace

### Požadavky

```bash
# KDE/Plasma development packages
sudo apt install kde-dev-scripts kdelibs5-dev plasma-framework-dev \
    qtdeclarative5-dev qtquickcontrols2-5-dev

# FFTW3 a PulseAudio
sudo apt install libfftw3-dev libpulse-dev libpulse-simple-dev

# Build tools
sudo apt install cmake extra-cmake-modules build-essential
```

### Kompilace pluginu

```bash
cd plasma-wallpaper
mkdir build
cd build

cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
```

### Instalace

```bash
sudo make install

# Restart plasmashell pro načtení pluginu
kquitapp5 plasmashell
plasmashell --replace &
```

### Alternativní instalace (uživatelské)

```bash
# Install do ~/.local/share
cmake .. -DCMAKE_INSTALL_PREFIX=~/.local
make install

# Restart plasmashell
kquitapp5 plasmashell
plasmashell --replace &
```

## Použití

1. **Otevřete System Settings** → `Workspace Behavior` → `Desktop Behavior` → `Wallpaper`
2. **Vyberte typ**: `Audio Visualizer` 
3. **Nakonfigurujte**:
   - Audio Device (výchozí: Default)
   - Sensitivity (0.1 - 5.0)
   - Color Scheme (Rainbow, Blue, Fire, Plasma, Monochrome)
   - Smoothing (0-100%)
4. **Použijte** a užívejte si vizualizaci!

## Konfigurace

### Audio nastavení
- **Audio Device**: Výběr vstupního zařízení (mikrofon, line-in)
- **Sensitivity**: Citlivost na hlasitost (1.0 = normální)
- **Smoothing**: Vyhlazení spektra (80% doporučeno)

### Vizuální efekty
- **Rainbow Spectrum**: Klasická duha podle frekvencí
- **Blue Gradient**: Modrý gradient s intenzitou
- **Fire**: Ohnivé barvy (žlutá→oranžová→červená)  
- **Plasma**: KDE Plasma modrá/fialová
- **Monochrome**: Černobílé spektrum

### Ladění
- **Status Indicator**: Zelená tečka = aktivní, červená = chyba
- **Test Mode**: Umělá data pro testování

## Technické detaily

### Architektura
```
QML Frontend (main.qml)
    ↓ signals/slots
C++ Backend (AudioVisualizerBackend)
    ↓ FFTW3
Audio Input (PulseAudio)
```

### Performance
- **FFT Size**: 512 samples  
- **Spectrum Bars**: 128 frekvencí
- **Processing**: 50 FPS (20ms intervals)
- **Rendering**: 60 FPS (16ms)
- **Memory Usage**: ~5 MB

### Soubory pluginu
```
plasma-wallpaper/
├── metadata.json                    # Plugin metadata
├── contents/ui/
│   ├── main.qml                     # Hlavní wallpaper QML
│   └── config.qml                   # Konfigurace UI
├── src/
│   ├── audiovisualizerbackend.h     # C++ header
│   ├── audiovisualizerbackend.cpp   # Audio processing
│   └── plugin.cpp                   # QML plugin entry
└── CMakeLists.txt                   # Build systém
```

## Odstraňování problémů

### Plugin se neobjevuje v System Settings
```bash
# Zkontrolujte instalaci
ls /usr/share/plasma/wallpapers/ | grep audio
ls /usr/lib/x86_64-linux-gnu/qt5/qml/org/kde/plasma/

# Restartujte plasmashell
kquitapp5 plasmashell && plasmashell --replace &
```

### Žádné audio vstup
```bash
# Zkontrolujte PulseAudio
pactl list sources short
pactl list source-outputs

# Test mikrofonu  
arecord -f S16_LE -r 44100 -c 2 -d 5 test.wav
```

### Debug logování
```bash
# Spusťte plasmashell s debug výstupem
QT_LOGGING_RULES="qt.qml.debug=true" plasmashell --replace
```

## Vývoj a rozšíření

### Přidání nového color scheme
V `main.qml`, funkce `onPaint`, sekce color scheme switch:
```javascript
case 4: // Nové schéma
    hue = vlastní_logika
    saturation = vlastní_logika  
    lightness = vlastní_logika
    break
```

### Nové audio efekty
V `audiovisualizerbackend.cpp`, metoda `processAudio`:
```cpp
// Přidat nové FFT post-processing
for (int i = 0; i < SPECTRUM_BARS; ++i) {
    // Vlastní úprava magnitude
    magnitude = vlastni_efekt(magnitude);
}
```

## 🔧 Troubleshooting

### Plugin se nezobrazuje v System Settings

Pokud se plugin "Audio Visualizer" nezobrazuje v System Settings:

1. **Ověřte instalaci souborů**:
```bash
ls -la ~/.local/share/plasma/wallpapers/org.kde.plasma.audiovisualizer/
ls -la ~/.local/share/qml/org/kde/plasma/audiovisualizer/
```

2. **Restartujte Plasma shell**:
```bash
kquitapp6 plasmashell && sleep 3 && plasmashell &
```

3. **Vyčistěte KDE cache**:
```bash
rm -rf ~/.cache/plasma* ~/.cache/kservice*
```

4. **Ověřte metadata.json**:
Ujistěte se, že obsahuje `"KPackageStructure": "Plasma/Wallpaper"` místo `"KPackage"`

### Instalace do user adresáře (doporučeno)

```bash
# Zkopírujte soubory do user adresáře
mkdir -p ~/.local/share/plasma/wallpapers/org.kde.plasma.audiovisualizer
cp -r contents/* ~/.local/share/plasma/wallpapers/org.kde.plasma.audiovisualizer/

# Zkopírujte QML plugin  
mkdir -p ~/.local/share/qml/org/kde/plasma/audiovisualizer
cp build/libplasma_wallpaper_audiovisualizer.so ~/.local/share/qml/org/kde/plasma/audiovisualizer/
cp build/qmldir ~/.local/share/qml/org/kde/plasma/audiovisualizer/

# Restart Plasma
kquitapp6 plasmashell && sleep 3 && plasmashell &
```

## Licence

GPL-3.0 - VitexSoftware 2025