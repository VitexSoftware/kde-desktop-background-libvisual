#!/usr/bin/env bash
# diagnostics.sh - Collect diagnostics for the LibVisual Plasma wallpaper plugin
# Usage: ./diagnostics.sh [--no-color] [--quick]
#  --no-color  : disable ANSI colors
#  --quick     : skip slower checks (ldd, journal tail, qml lint)
# Exit codes: 0 success, >0 issues detected

set -euo pipefail

PROJECT_ROOT="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
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

section "Backend Singleton Check (heuristic)"
# We can't instantiate QML headless easily; we just check that the plugin exported symbol count > 0.
if [[ $FOUND_SO -eq 1 ]]; then
  nm -D --defined-only "${PLUGIN_SO_GLOB[0]}" 2>/dev/null | grep -q 'LibVisualWallpaper' && ok "Symbol LibVisualWallpaper present" || warn "LibVisualWallpaper symbol not found in first .so"
fi

if [[ $QUICK -eq 0 ]]; then
  section "Recent plasmashell log (libvisual lines)"
  # Tail last 200 user journal lines for libvisual
  if command -v journalctl >/dev/null; then
    journalctl --user -n 200 2>/dev/null | grep -i libvisual || echo "(no recent libvisual log lines)"
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
