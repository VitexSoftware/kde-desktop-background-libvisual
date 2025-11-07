#!/usr/bin/env bash
# test.sh - Build, install, and validate the LibVisual Plasma wallpaper plugin.
# Usage: ./test.sh [--prefix <path>] [--jobs N] [--quick]
#   --prefix <path>   : Installation prefix (default: $HOME/.local)
#   --jobs N          : Parallel build jobs (default: nproc)
#   --quick           : Faster run (skips ldd & journal in diagnostics)
#   --no-diagnostics  : Skip running diagnostics.sh after install
# Exit codes: propagate build failures or diagnostics code.

set -euo pipefail
SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$SCRIPT_DIR"
PLUGIN_SUBDIR="plasma-wallpapers/org.kde.libvisual"
BUILD_DIR="$ROOT/${PLUGIN_SUBDIR}/build"
PREFIX="$HOME/.local"
JOBS="$(nproc || echo 4)"
RUN_DIAG=1
DIAG_QUICK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2;;
    --jobs) JOBS="$2"; shift 2;;
    --quick) DIAG_QUICK=1; shift;;
    --no-diagnostics) RUN_DIAG=0; shift;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //'; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

bold() { echo -e "\e[1m$*\e[0m"; }
info() { echo -e "[INFO] $*"; }
err()  { echo -e "[ERR ] $*"; }

bold "== Build Configuration =="
echo "Prefix       : $PREFIX"
echo "Build dir    : $BUILD_DIR"
echo "Jobs         : $JOBS"
echo "Diagnostics  : $([[ $RUN_DIAG -eq 1 ]] && echo enabled || echo disabled) (quick=$DIAG_QUICK)"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

info "Configuring (CMake)"
cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" 2>&1 | tee cmake_config.log

info "Building"
cmake --build . -j"$JOBS" 2>&1 | tee build.log

info "Installing"
cmake --install . --prefix "$PREFIX" 2>&1 | tee install.log

# Minimal post-install verification
PLUGIN_SO="$PREFIX/lib/qt6/plugins/plasma/wallpapers/plasma_wallpaper_org.kde.libvisual.so"
if [[ ! -f "$PLUGIN_SO" ]]; then
  # try multiarch fallback
  ALT_SO_GLOB=("$PREFIX"/lib/*/qt6/plugins/plasma/wallpapers/plasma_wallpaper_org.kde.libvisual.so)
  for c in "${ALT_SO_GLOB[@]}"; do
    [[ -f "$c" ]] && PLUGIN_SO="$c" && break
  done
fi
if [[ -f "$PLUGIN_SO" ]]; then
  info "Plugin library present: $PLUGIN_SO"
else
  err "Plugin library NOT found after install"; exit 2
fi

if [[ $RUN_DIAG -eq 1 ]]; then
  info "Running diagnostics.sh"
  DIAG_ARGS=""
  [[ $DIAG_QUICK -eq 1 ]] && DIAG_ARGS="--quick"
  "$ROOT/diagnostics.sh" $DIAG_ARGS || exit $?
fi

bold "== SUCCESS =="
exit 0
