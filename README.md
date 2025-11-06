# LibVisual Desktop Background

Aplikace pro vykreslování audio vizualizací na pozadí KDE desktopového prostředí pomocí knihovny libvisual.

## Funkce

- Vykreslování libvisual vizualizací přímo na desktop pozadí
- Podpora různých audio vstupů (PulseAudio/ALSA)
- GUI pro ovládání přes systémový tray
- Automatické přepínání mezi vizualizačními pluginy
- Ukládání nastavení do konfiguračního souboru
- Podpora pro různé libvisual pluginy (fraktály, vlny, atd.)

## Závislosti

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

## Sestavení

### Rychlá instalace závislostí:
```bash
# Automatická detekce distribuce a instalace závislostí
./install_deps.sh
```

### Sestavení ze zdrojových kódů:
```bash
# Klonování repozitáře
git clone <repository-url>
cd kde-desktop-background-libvisual

# Sestavení pomocí přiloženého skriptu
./build.sh

# Nebo manuálně:
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
```

### Sestavení Debian balíčku:
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

## Použití

### Spuštění aplikace:
```bash
./libvisual-bg
```

### Spuštění s automatickým startem vizualizace:
```bash
./libvisual-bg --autostart
```

### Ovládání:
1. Aplikace se spustí minimalizovaná v systémovém tray
2. Dvojklik na ikonu v tray otevře ovládací panel
3. V ovládacím panelu můžete:
   - Vybrat audio zařízení
   - Vybrat vizualizační plugin
   - Nastavit interval automatického přepínání
   - Spustit/zastavit vizualizaci

## Konfigurace

Nastavení se automaticky ukládá do `~/.config/libvisual-bg.conf`:

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

## Dostupné libvisual pluginy

Aplikace automaticky detekuje nainstalované libvisual pluginy. Běžné pluginy:
- `gforce` - Abstraktní efekty
- `infinite` - Nekonečné fraktály
- `jakdaw` - Spektrální analýzer
- `lv_scope` - Osciloskop
- `nebulus` - Mlhovina efekty

## Řešení problémů

### Aplikace se nespustí:
1. Zkontrolujte, zda jsou nainstalovány všechny závislosti
2. Ověřte, že libvisual pluginy jsou dostupné:
   ```bash
   ls /usr/lib/libvisual-0.4/actor/
   ```

### Žádný zvuk není detekován:
1. Zkontrolujte PulseAudio nastavení:
   ```bash
   pactl list sources short
   ```
2. Vyberte správný audio vstup v GUI
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