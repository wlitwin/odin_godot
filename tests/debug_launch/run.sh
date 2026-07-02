#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Editor-launched native debugging — end-to-end verification of the lldb pipeline the
# Project > Tools debugger items ride (build/debug_game.sh), in lldb BATCH mode:
#
#  (1) FILE:LINE breakpoint — `--break player.odin:<line>` on the showcase, driven by
#      its real game script. Asserts the pending breakpoint BINDS across the scripts
#      dll dlopen, the process STOPS at that exact source line, `frame variable` shows
#      the NAMED, TYPED proc args (self: ^Player, delta: f64), and the godot_lldb.py
#      pretty-printer renders a live String_Name as StringName("ui_left").
#      This is the regression net for -use-single-module in atomic_odin_dll: with the
#      default separate-modules debug build, macOS ld emits a broken one-entry debug
#      map, dsymutil produces an empty .dSYM, and NONE of the above works.
#
#  (2) PANIC auto-break — the crash project's do_panic under the launcher's automatic
#      breakpoint on native_script_assertion_failure: a script `panic("...")` must
#      FREEZE the debugger at the panic site (stack live, inspectable) instead of
#      printing and dying.
#
# Gated: needs macOS + a working lldb (SKIP sentinel otherwise — mirrors the
# launcher's own DEVELOPER_DIR fallback when probing).
#
#   nix develop --command bash -c 'bash tests/debug_launch/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
    echo "DEBUG_LAUNCH_FAIL: $1"
    exit 1
}

# --- gate: darwin + a usable lldb (same resolution debug_game.sh performs).
if [[ "$(uname)" != "Darwin" ]]; then
    echo "DEBUG_LAUNCH_SKIP (darwin-only: the launcher's re-sign + lldb path is untested elsewhere)"
    exit 0
fi
LLDB="${LLDB:-/usr/bin/lldb}"
if ! "$LLDB" --version >/dev/null 2>&1; then
    for d in /Applications/Xcode.app/Contents/Developer /Library/Developer/CommandLineTools; do
        if [[ -d "$d" ]]; then export DEVELOPER_DIR="$d"; break; fi
    done
fi
if ! "$LLDB" --version >/dev/null 2>&1; then
    echo "DEBUG_LAUNCH_SKIP (no working lldb — install Xcode CLT)"
    exit 0
fi

LOGDIR="$ROOT/tests/.logs"
mkdir -p "$LOGDIR"

# assert_grep <log> <pattern> <what>
assert_grep() {
    if ! grep -Eq "$2" "$1"; then
        echo "    ----- last 30 lines of $1 -----"
        tail -n 30 "$1" | sed 's/^/    /'
        fail "$3 (pattern not found: $2)"
    fi
}

# ---------------------------------------------------------------------------
# (1) file:line breakpoint + named args + pretty-printers (showcase project)
# ---------------------------------------------------------------------------
echo "== (1) file:line breakpoint binds across dlopen; args + printers live =="
PROJ="$ROOT/tests/showcase"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Anchor the breakpoint to the marker line's CONTENT, not a hardcoded number, so edits
# to player.odin don't silently break this test.
BP_LINE="$(grep -n 'dy := f32' "$PROJ/scripts/player.odin" | head -1 | cut -d: -f1)"
[[ -n "$BP_LINE" ]] || fail "marker line 'dy := f32' not found in showcase player.odin"

BP_LOG="$LOGDIR/debug_launch-bp.log"
GODOT="$GODOT" bash "$ROOT/build/debug_game.sh" \
    --batch --break "player.odin:$BP_LINE" \
    --cmd "frame variable" \
    --cmd "target variable left_name" \
    --cmd "kill" \
    "$PROJ" -- --headless --script test_showcase.gd >"$BP_LOG" 2>&1 || true

assert_grep "$BP_LOG" "stop reason = breakpoint" \
    "process did not stop at the line breakpoint"
assert_grep "$BP_LOG" "player\.odin:$BP_LINE" \
    "stop is not at the requested source line"
assert_grep "$BP_LOG" "\(showcase_scripts::Player \*\) self = 0x" \
    "frame variable lacks the named, typed self argument"
assert_grep "$BP_LOG" "\(f64\) delta = " \
    "frame variable lacks the named delta argument"
assert_grep "$BP_LOG" 'StringName\("ui_left"\)' \
    "godot_lldb.py String_Name summary did not render the live value"
echo "  stopped at player.odin:$BP_LINE with typed args + StringName(\"ui_left\")"

# ---------------------------------------------------------------------------
# (2) panic auto-break (crash project): panic freezes the debugger at the site
# ---------------------------------------------------------------------------
echo "== (2) script panic freezes the session at native_script_assertion_failure =="
CPROJ="$ROOT/tests/crash"
bash "$ROOT/build/build_scripts.sh" "$CPROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$CPROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$CPROJ" --import >/dev/null 2>&1 || true

PANIC_LOG="$LOGDIR/debug_launch-panic.log"
GODOT="$GODOT" bash "$ROOT/build/debug_game.sh" \
    --batch \
    --cmd "bt 8" \
    --cmd "kill" \
    "$CPROJ" -- --headless --script test_panic.gd >"$PANIC_LOG" 2>&1 || true
unset ODIN_SCRIPTS_DLL

assert_grep "$PANIC_LOG" "stop reason = breakpoint" \
    "the panic did not stop the session (auto panic breakpoint missing?)"
assert_grep "$PANIC_LOG" "native_script_assertion_failure" \
    "stop is not at the script assertion proc"
assert_grep "$PANIC_LOG" "crash_target_do_panic" \
    "backtrace does not reach the panicking script proc"
echo "  panic stopped the debugger with the script frame on the stack"

echo
echo "DEBUG_LAUNCH_OK"
