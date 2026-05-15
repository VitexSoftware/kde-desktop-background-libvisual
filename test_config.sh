#!/bin/bash
# test_config.sh – Validate the installed org.kde.libvisual config UI and config schema.
# Exit code: number of failed checks (0 = all pass).

set -euo pipefail

INSTALL_ROOT="${HOME}/.local/share/plasma/wallpapers/org.kde.libvisual"
CONFIG_QML="${INSTALL_ROOT}/contents/ui/config.qml"
MAIN_QML="${INSTALL_ROOT}/contents/ui/main.qml"
MAIN_XML="${INSTALL_ROOT}/contents/config/main.xml"

PASS=0; FAIL=0
ok()  { echo "  PASS: $*"; ((PASS++)) || true; }
fail(){ echo "  FAIL: $*"; ((FAIL++)) || true; }
section(){ echo; echo "=== $* ==="; }

section "Installed files"
[[ -f "$CONFIG_QML" ]] && ok "config.qml present" || fail "config.qml missing"
[[ -f "$MAIN_QML"   ]] && ok "main.qml present"   || fail "main.qml missing"
[[ -f "$MAIN_XML"   ]] && ok "main.xml present"    || fail "main.xml missing"

section "config.qml – AudioVisualizer backend"
grep -q "import AudioVisualizer 1.0"           "$CONFIG_QML" && ok "imports AudioVisualizer 1.0"          || fail "missing 'import AudioVisualizer 1.0'"
grep -q "AudioVisualizer {"                     "$CONFIG_QML" && ok "AudioVisualizer instance present"     || fail "no AudioVisualizer instance in config"
grep -q "configAudio.decibels"                  "$CONFIG_QML" && ok "level bound to real decibels"         || fail "level not bound to configAudio.decibels"
grep -q "getInputSources"                       "$CONFIG_QML" && ok "calls getInputSources()"              || fail "does not call getInputSources()"
! grep -q "updateAudioLevel\|baseTime\|Math.sin.*activity" "$CONFIG_QML" \
                                                && ok "fake simulation removed"                             || fail "fake audio simulation still present"

section "config.qml – input device filtering"
grep -q "paSourceNames"                         "$CONFIG_QML" && ok "paSourceNames parallel list present"  || fail "no paSourceNames in config"
grep -q "sources\[i\].description"             "$CONFIG_QML" && ok "shows source descriptions"            || fail "does not display source descriptions"
grep -q "sources\[i\].name"                    "$CONFIG_QML" && ok "stores source names"                  || fail "does not store source names"

section "config.qml – 20 visualization types"
VIZ_TYPES=(
    "Spectrum Analyzer" "Waveform" "Lissajous" "Circular Burst"
    "Circular Spectrum" "Plasma" "Starfield" "Fireworks"
    "Matrix Rain" "DNA Helix" "Particle Storm" "Ripple Effect"
    "Tunnel Vision" "Spiral Galaxy" "Lightning" "Mandelbrot Zoom"
    "Geometric Dance" "Audio Bars 3D" "Kaleidoscope" "ProjectM Visualizer"
)
for vt in "${VIZ_TYPES[@]}"; do
    grep -q "$vt" "$CONFIG_QML" && ok "viz type present: $vt" || fail "viz type missing: $vt"
done

section "config.qml – per-type preview"
grep -q "type === 0"  "$CONFIG_QML" && ok "preview case: Spectrum (0)"          || fail "preview missing case 0"
grep -q "type === 15" "$CONFIG_QML" && ok "preview case: Mandelbrot (15)"        || fail "preview missing case 15"
grep -q "type === 18" "$CONFIG_QML" && ok "preview case: Kaleidoscope (18)"      || fail "preview missing case 18"
grep -q "type === 19" "$CONFIG_QML" && ok "preview case: ProjectM (19)"          || fail "preview missing case 19"
grep -q "previewCanvas"             "$CONFIG_QML" && ok "single previewCanvas present" || fail "previewCanvas not found"
! grep -q "children\[0\].children\[" "$CONFIG_QML" \
                                    && ok "no fragile children[] indexing"            || fail "fragile children[] indexing still present"

section "main.qml – all 20 viz types implemented"
for type_id in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do
    grep -q "visualizationType === ${type_id}" "$MAIN_QML" \
        && ok "type ${type_id} handled in main.qml" \
        || fail "type ${type_id} NOT handled in main.qml"
done
! grep -q "Visualization Not Yet Implemented" "$MAIN_QML" \
    && ok "no 'Not Yet Implemented' placeholder"  || fail "'Not Yet Implemented' placeholder still present"

section "main.xml – config schema entries"
for key in visualizationType audioSensitivity colorScheme showStatusIndicator smoothing audioSource; do
    grep -q "name=\"$key\"" "$MAIN_XML" && ok "schema key: $key" || fail "schema key missing: $key"
done

section "System – pactl availability (needed for device enumeration)"
command -v pactl >/dev/null && ok "pactl found: $(pactl --version 2>/dev/null | head -1)" || fail "pactl not found — device enumeration will fall back to 'default' only"

section "System – PulseAudio input sources (no monitors)"
if command -v pactl >/dev/null; then
    INPUT_COUNT=$(pactl list short sources 2>/dev/null | grep -cv "\.monitor" || true)
    if [[ "$INPUT_COUNT" -gt 0 ]]; then
        ok "$INPUT_COUNT input source(s) found (no monitors)"
        pactl list short sources 2>/dev/null | grep -v "\.monitor" | while IFS=$'\t' read -r idx name rest; do
            echo "       $idx  $name"
        done
    else
        fail "no input sources found (is a capture device connected?)"
    fi
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
exit "$FAIL"
