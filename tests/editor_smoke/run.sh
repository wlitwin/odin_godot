#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Editor-open smoke test.
#
# The milestone tests only ever ran Godot `--headless` at RUNTIME (plus `--import`),
# never `--editor`. The editor exercises FAR more ScriptLanguageExtension/ScriptExtension
# virtuals than runtime, so a class of EDITOR-only bugs (missing required virtuals →
# "must be overridden" → reading uninitialized return memory → signal 11 in the Scene
# dock; `_can_instantiate` instantiating non-tool scripts in edit mode) sailed past the
# whole suite while crashing the moment a user opened the project in the editor.
#
# This test opens the showcase project in a HEADLESS EDITOR (which still builds the Scene
# dock node tree, the exact path that crashed) and asserts:
#   * exit code 0
#   * the output contains NONE of: "signal 11", "must be overridden", "Required virtual"
# Prints EDITOR_SMOKE_OK on success.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/editor_smoke/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/showcase"

# Build the core dll + showcase scripts dll (same pipeline the showcase test uses).
bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# Ensure the extension list / import cache exists so the editor loads the GDExtension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Open the project in a headless editor and let it build the Scene dock tree, then quit.
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$LOG" 2>&1
RC=$?
set -e

echo "----- editor headless output (tail) -----"
tail -n 20 "$LOG"
echo "------------------------------------------"

if [[ "$RC" -ne 0 ]]; then
    echo "EDITOR_SMOKE_FAIL: editor exited non-zero ($RC)"
    exit 1
fi

if grep -qE "signal 11|must be overridden|Required virtual" "$LOG"; then
    echo "EDITOR_SMOKE_FAIL: editor logged a crash / missing-virtual error:"
    grep -nE "signal 11|must be overridden|Required virtual" "$LOG" | head
    exit 1
fi

# The Odin syntax highlighter registers itself on the first editor frame where the
# ScriptEditor exists (OdinLanguage._frame -> ScriptEditor.register_syntax_highlighter).
# Assert that path actually ran (and, per the crash check above, did not crash the editor).
if ! grep -q "Odin syntax highlighter registered" "$LOG"; then
    echo "EDITOR_SMOKE_FAIL: Odin syntax highlighter did not register on the editor _frame"
    exit 1
fi

# Second check: in EDITOR context, scripted nodes must actually expose their @export vars
# in the Inspector (the placeholder-instance property path). A crash-free editor that shows
# NO exports is still broken — assert the content, not just the absence of a crash.
EXLOG="$(mktemp)"
trap 'rm -f "$LOG" "$EXLOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --script test_editor_exports.gd >"$EXLOG" 2>&1
EXRC=$?
set -e
if [[ "$EXRC" -ne 0 ]] || ! grep -q "EDITOR_EXPORTS_OK" "$EXLOG"; then
    echo "EDITOR_SMOKE_FAIL: @export vars not visible in the editor Inspector:"
    grep -nE "EDITOR_EXPORTS_FAIL|signal 11" "$EXLOG" | head
    tail -n 10 "$EXLOG"
    exit 1
fi

echo "EDITOR_SMOKE_OK"
