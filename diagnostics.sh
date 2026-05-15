#!/usr/bin/env bash
# diagnostics.sh - Collect diagnostics for the LibVisual Plasma wallpaper plugin
# Usage: ./diagnostics.sh [--no-color] [--quick]
#  --no-color  : disable ANSI colors
#  --quick     : skip slower checks (ldd, journal tail, qml lint)
# Exit codes: 0 success, >0 issues detected

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="org.kde.libvisual"
PKG_DIR="$HOME/.local/share/plasma/wallpapers/${PLUGIN_ID}"
PLUGIN_SO_GLOB=(
  "$HOME/.local/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_${PLUGIN_ID}.so"
  "$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins/plasma/wallpapers/plasma_wallpaper_${PLUGIN_ID}.so"
)
PLUGIN_JSON_GLOB=(
  "$HOME/.local/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_${PLUGIN_ID}.json"
  "$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins/plasma/wallpapers/plasma_wallpaper_${PLUGIN_ID}.json"
)
COLOR=1
QUICK=0
for a in "$@"; do
  case "$a" in
    --no-color) COLOR=0 ;;
    --quick) QUICK=1 ;;
  esac
done

if [[ $COLOR -eq 1 ]]; then
  BOLD='\e[1m'; RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; RESET='\e[0m'
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; RESET=''
fi

section(){ echo -e "\n${BOLD}== $1 ==${RESET}"; }
kv(){ printf '%-28s %s\n' "$1" "$2"; }
warn(){ echo -e "${YELLOW}WARN${RESET}: $*"; }
err(){ echo -e "${RED}ERROR${RESET}: $*"; }
ok(){ echo -e "${GREEN}OK${RESET}: $*"; }

ISSUES=0

section "System"
kv "Kernel" "$(uname -sr)"
kv "Distro" "$(grep -E '^(ID|VERSION_ID)=' /etc/os-release 2>/dev/null | tr '\n' ' ')"
kv "Plasma version" "$(plasmashell --version 2>/dev/null || echo 'plasmashell not in PATH')"
kv "Qt version" "$(qtpaths6 --qt-version 2>/dev/null || qmake -v 2>/dev/null | head -1 || echo 'qtpaths6/qmake not found')"

section "Environment Variables"
for v in QT_PLUGIN_PATH QML2_IMPORT_PATH XDG_DATA_DIRS PATH; do
  kv "$v" "${!v-}" || true
done

section "Wallpaper Package"
if [[ -d "$PKG_DIR" ]]; then
  ok "Package directory present: $PKG_DIR"
  if [[ -f "$PKG_DIR/metadata.json" ]]; then
    grep -q '"KPackageStructure".*Plasma/Wallpaper' "$PKG_DIR/metadata.json" && ok "metadata.json contains KPackageStructure" || { err "metadata.json missing/invalid KPackageStructure"; ((ISSUES++)); }
  else
    err "metadata.json missing"
    ((ISSUES++))
  fi
  ls -1 "$PKG_DIR/contents/ui" 2>/dev/null | sed 's/^/  ui: /'
else
  err "Package directory missing: $PKG_DIR"
  ((ISSUES++))
fi

section "CoreAddons Plugin Artifacts"
FOUND_SO=0
for f in "${PLUGIN_SO_GLOB[@]}"; do
  if [[ -f "$f" ]]; then
    FOUND_SO=1
    sha=$(sha256sum "$f" | cut -d' ' -f1)
    sz=$(stat -c %s "$f")
    ok "Plugin .so: $f (size=${sz} sha256=${sha:0:12}…)"
    if [[ $QUICK -eq 0 ]]; then
      if ldd "$f" | grep -F 'not found' >/dev/null; then
        err "Unresolved libs in $f"; ldd "$f" | grep -F 'not found'; ((ISSUES++))
      fi
    fi
  fi
done
[[ $FOUND_SO -eq 1 ]] || { err "No plugin .so found in expected paths"; ((ISSUES++)); }

FOUND_JSON=0
for j in "${PLUGIN_JSON_GLOB[@]}"; do
  if [[ -f "$j" ]]; then
    FOUND_JSON=1
    grep -q '"Id" *: *"org.kde.libvisual"' "$j" && ok "Plugin JSON: $j" || { warn "JSON present but Id mismatch: $j"; }
  fi
done
[[ $FOUND_JSON -eq 1 ]] || warn "No standalone plugin JSON (embedded metadata may still exist)"

section "kpackagetool6 Listing"
if command -v kpackagetool6 >/dev/null; then
  if kpackagetool6 --type Plasma/Wallpaper --list 2>/dev/null | grep -E "^${PLUGIN_ID}$| ${PLUGIN_ID}$" >/dev/null; then
    ok "Wallpaper listed by kpackagetool6"
  else
    err "Wallpaper NOT listed by kpackagetool6"
    ((ISSUES++))
  fi
else
  warn "kpackagetool6 not installed"
fi

section "DBus / plasmashell"
SERVICE_LOWER="org.kde.plasmashell"
SERVICE_UPPER="org.kde.PlasmaShell"
HAVE_QDBUS=0
if command -v qdbus >/dev/null; then HAVE_QDBUS=1; fi
if [[ -x /usr/lib/qt6/bin/qdbus ]]; then HAVE_QDBUS=1; alias qdbus=/usr/lib/qt6/bin/qdbus; fi
if [[ $HAVE_QDBUS -eq 1 ]]; then
  if qdbus $SERVICE_LOWER /PlasmaShell >/dev/null 2>&1; then
    ok "DBus service $SERVICE_LOWER reachable"
  elif qdbus $SERVICE_UPPER /PlasmaShell >/dev/null 2>&1; then
    ok "DBus service $SERVICE_UPPER reachable"
  else
    warn "plasmashell DBus interface not reachable"
  fi
else
  warn "qdbus not available"
fi

section "AudioVisualizer backend symbols"
# The implementation lives in libaudiovisualizer_probe.so (the backing library).
# The QML plugin loader is audiovisualizer_probeplugin.so (just registers types).
AV_LIB_PATHS=(
  "$HOME/.local/lib/x86_64-linux-gnu/libaudiovisualizer_probe.so"
  "$HOME/.local/lib/qt6/qml/AudioVisualizer/audiovisualizer_probeplugin.so"
  "$HOME/.local/lib/x86_64-linux-gnu/qml/AudioVisualizer/audiovisualizer_probeplugin.so"
)
FOUND_AV=0
FOUND_AV_SYM=0
FOUND_GIS=0
for f in "${AV_LIB_PATHS[@]}"; do
  [[ -f "$f" ]] || continue
  FOUND_AV=1
  if command -v nm >/dev/null; then
    # Capture to variable first — avoids SIGPIPE with set -o pipefail when grep exits early
    _syms=$(nm "$f" 2>/dev/null | c++filt || true)
    grep -q 'AudioVisualizer' <<< "$_syms" \
      && { ok "Symbol AudioVisualizer present in $(basename "$f")"; FOUND_AV_SYM=1; } \
      || true
    if grep -q 'getInputSources' <<< "$_syms"; then
      ok "getInputSources() compiled in $(basename "$f") — input-device filtering available"
      FOUND_GIS=1
    fi
  fi
done
if command -v nm >/dev/null; then
  [[ $FOUND_GIS -eq 1 ]] \
    || { err "getInputSources not found in any AudioVisualizer library — rebuild required"; ((ISSUES++)); }
fi
if [[ $QUICK -eq 0 ]]; then
  for f in "${AV_LIB_PATHS[@]}"; do
    [[ -f "$f" ]] || continue
    MISSING=$(ldd "$f" 2>/dev/null | grep "not found" || true)
    [[ -z "$MISSING" ]] && ok "No missing libs in $(basename "$f")" \
                        || { err "Missing libs in $(basename "$f"): $MISSING"; ((ISSUES++)); }
  done
fi
[[ $FOUND_AV -eq 1 ]] || { err "AudioVisualizer library not found in expected paths"; ((ISSUES++)); }

section "config.qml feature checks"
CONFIG_QML="$PKG_DIR/contents/ui/config.qml"
if [[ -f "$CONFIG_QML" ]]; then
  grep -q 'import AudioVisualizer 1.0' "$CONFIG_QML" \
    && ok "config.qml imports AudioVisualizer 1.0" \
    || { err "config.qml missing AudioVisualizer import"; ((ISSUES++)); }
  grep -q 'configAudio.decibels' "$CONFIG_QML" \
    && ok "audio level bound to real backend" \
    || { err "audio level not bound to real backend (fake simulation?)"; ((ISSUES++)); }
  grep -q 'getInputSources' "$CONFIG_QML" \
    && ok "device combo calls getInputSources()" \
    || { err "device combo does not call getInputSources()"; ((ISSUES++)); }
  # Count visualization types
  VIZ_COUNT=$(grep -c 'i18n("' "$CONFIG_QML" | head -1 || true)
  TYPE_COUNT=$(grep -o 'type === [0-9]*' "$CONFIG_QML" 2>/dev/null | sort -u | wc -l)
  ok "Preview canvas handles $TYPE_COUNT distinct visualization type(s)"
  [[ "$TYPE_COUNT" -ge 19 ]] || warn "Expected 19 viz types in preview, found $TYPE_COUNT"
else
  err "config.qml not found at $CONFIG_QML"; ((ISSUES++))
fi

section "main.qml – visualization completeness"
MAIN_QML="$PKG_DIR/contents/ui/main.qml"
if [[ -f "$MAIN_QML" ]]; then
  IMPL_COUNT=$(grep -o 'visualizationType === [0-9]*' "$MAIN_QML" 2>/dev/null | sort -u | wc -l)
  ok "main.qml handles $IMPL_COUNT visualization type(s)"
  [[ "$IMPL_COUNT" -ge 19 ]] || warn "Expected ≥19 handled types, found $IMPL_COUNT"
  ! grep -q 'Visualization Not Yet Implemented' "$MAIN_QML" \
    && ok "No 'Not Yet Implemented' placeholder" \
    || { err "'Not Yet Implemented' placeholder still present"; ((ISSUES++)); }
else
  err "main.qml not found"; ((ISSUES++))
fi

section "PulseAudio / PipeWire input sources"
if command -v pactl >/dev/null; then
  kv "pactl version" "$(pactl --version 2>/dev/null | head -1)"
  INPUT_SOURCES=$(pactl list short sources 2>/dev/null | grep -v '\.monitor' || true)
  INPUT_COUNT=$(echo "$INPUT_SOURCES" | grep -c . || true)
  if [[ "$INPUT_COUNT" -gt 0 ]]; then
    ok "$INPUT_COUNT capture source(s) available (monitors excluded)"
    echo "$INPUT_SOURCES" | while IFS=$'\t' read -r idx name rest; do
      printf '  %3s  %s\n' "$idx" "$name"
    done
  else
    warn "No capture sources found (is a microphone connected?)"
  fi
  MONITOR_COUNT=$(pactl list short sources 2>/dev/null | grep -c '\.monitor' || true)
  ok "$MONITOR_COUNT monitor source(s) correctly excluded from device combo"
else
  err "pactl not found — install pulseaudio-utils or pipewire-pulse"; ((ISSUES++))
fi

if [[ $QUICK -eq 0 ]]; then
  section "Recent plasmashell log (libvisual / AudioVisualizer lines)"
  if command -v journalctl >/dev/null; then
    journalctl --user -n 300 2>/dev/null \
      | grep -iE 'libvisual|audiovisualizer|org\.kde\.libvisual' \
      || echo "(no recent relevant log lines)"
  else
    warn "journalctl unavailable"
  fi
fi

section "Summary"
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}All diagnostics passed${RESET}"
else
  echo -e "${RED}$ISSUES issue(s) detected${RESET}"
fi
exit $ISSUES
