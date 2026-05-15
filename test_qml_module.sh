#!/bin/bash
# test_qml_module.sh – Verify the AudioVisualizer QML module is installed and loadable.
# Exit code: 0 = all pass, >0 = failures.

set -euo pipefail

QML_BASE="${HOME}/.local/lib/qt6/qml/AudioVisualizer"
QML_BASE_ALT="${HOME}/.local/lib/x86_64-linux-gnu/qml/AudioVisualizer"
LIB_BASE="${HOME}/.local/lib/x86_64-linux-gnu/libaudiovisualizer_probe.so"
IMPORT_PATH="${HOME}/.local/lib/qt6/qml:${HOME}/.local/lib/x86_64-linux-gnu/qml"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }
section(){ echo; echo "=== $* ==="; }

# Locate the installed QML module directory
QML_DIR=""
for d in "$QML_BASE" "$QML_BASE_ALT"; do
    [[ -d "$d" ]] && QML_DIR="$d" && break
done

section "AudioVisualizer QML module files"
if [[ -n "$QML_DIR" ]]; then
    ok "Module directory: $QML_DIR"
    [[ -f "$QML_DIR/qmldir" ]]                         && ok "qmldir present"                  || fail "qmldir missing"
    [[ -f "$QML_DIR/audiovisualizer_probeplugin.so" ]] && ok "plugin .so present"              || fail "plugin .so missing"
    [[ -f "$QML_DIR/audiovisualizer_probe.qmltypes" ]] && ok "qmltypes present"               || fail "qmltypes missing"

    section "qmldir content"
    grep -q "module AudioVisualizer"   "$QML_DIR/qmldir" && ok "module URI: AudioVisualizer"   || fail "wrong module URI in qmldir"

    section "Backing library symbols (libaudiovisualizer_probe.so)"
    # The implementation lives in the backing library, not the thin plugin wrapper.
    # Symbols are local (Qt -fvisibility=hidden), so nm without -D is required.
    if [[ -f "$LIB_BASE" ]]; then
        ok "Backing library present: $LIB_BASE"
        if command -v nm >/dev/null; then
            _syms=$(nm "$LIB_BASE" 2>/dev/null | c++filt || true)
            grep -q 'AudioVisualizer' <<< "$_syms" \
                && ok "AudioVisualizer symbol found in backing library" \
                || fail "AudioVisualizer symbol not found in backing library"
            grep -q 'getInputSources' <<< "$_syms" \
                && ok "getInputSources() compiled in backing library — input-device filtering available" \
                || fail "getInputSources() not found in backing library — rebuild required"
        else
            echo "  SKIP: nm not available"
        fi
    else
        fail "Backing library not found: $LIB_BASE"
    fi

    section "Library linkage"
    if command -v ldd >/dev/null; then
        MISSING=$(ldd "$QML_DIR/audiovisualizer_probeplugin.so" 2>/dev/null | grep "not found" || true)
        [[ -z "$MISSING" ]] && ok "no missing shared libraries" || fail "missing libs: $MISSING"
    else
        echo "  SKIP: ldd not available"
    fi
else
    fail "AudioVisualizer module directory not found (looked in $QML_BASE and $QML_BASE_ALT)"
fi

section "QML runtime import test"
# Force user-local library to take precedence over system-installed package
TMPFILE=$(mktemp /tmp/test_av_import_XXXXXX.qml)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE" <<'QML'
import QtQuick
import AudioVisualizer 1.0

Item {
    AudioVisualizer {
        id: av
        Component.onCompleted: {
            var sources = av.getInputSources()
            console.log("AudioVisualizer loaded. getInputSources() returned", sources.length, "source(s).")
            Qt.quit()
        }
    }
}
QML

QML_RUNNER=""
for bin in qml6 qml qmlscene6 qmlscene; do
    command -v "$bin" >/dev/null 2>&1 && QML_RUNNER="$bin" && break
done

if [[ -n "$QML_RUNNER" ]]; then
    export QML_IMPORT_PATH="$IMPORT_PATH"
    export QML2_IMPORT_PATH="$IMPORT_PATH"
    # Preload user-local backing library so it takes precedence over system package
    export LD_LIBRARY_PATH="${HOME}/.local/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
    OUTPUT=$("$QML_RUNNER" "$TMPFILE" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "AudioVisualizer loaded"; then
        ok "QML runtime: AudioVisualizer imported and getInputSources() executed"
        echo "$OUTPUT" | grep -E "source\(s\)|WARN|ERROR" | sed 's/^/       /'
    else
        fail "QML runtime: AudioVisualizer import or getInputSources() failed"
        echo "$OUTPUT" | head -10 | sed 's/^/       /'
    fi
else
    echo "  SKIP: no QML runner found (qml6/qml/qmlscene6/qmlscene)"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
exit "$FAIL"
