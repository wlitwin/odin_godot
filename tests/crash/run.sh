#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Crash/panic REPORTING — end-to-end verification. Two deliberately-dying child
# processes, with assertions on their CAPTURED output (the harness sees the child's
# stderr, exactly like a terminal-launched editor would):
#
#  (1) PANIC path — a @(gd_method) panics with a known message. Asserts the native
#      assertion proc (runtime/panic_native.odin) printed ODIN_SCRIPT_PANIC with the
#      message AND the script file:line to stderr, and that the push_error copy (the
#      route that reaches the EDITOR Output dock over the debugger channel) fired
#      (headless prints push_error as an "ERROR:" line).
#
#  (2) SIGNAL path — a @(gd_method) dereferences nil (raw SIGSEGV, zero Odin-side
#      handling before this feature). Asserts the child DIED (non-zero), the
#      fatal-signal reporter (core/crash.odin) printed ODIN_GODOT_CRASH, the faulting
#      frame was SYMBOLIZED to the Odin proc name (crash_target_do_segv), at least one
#      stack frame line was dumped, the push_error one-liner fired, AND Godot's own
#      chained crash handler still ran ("Dumping the backtrace" — verified present in
#      a headless macOS 4.6 run).
#
# THIS script exits 0 and prints CRASH_TEST_OK after asserting on the crashed
# children. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/crash/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/crash"

# Build the scripts dll (CrashTarget + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

LOGDIR="$ROOT/tests/.logs"
mkdir -p "$LOGDIR"

fail() {
    echo "CRASH_TEST_FAIL: $1"
    exit 1
}

# assert_grep <log> <pattern> <what>
assert_grep() {
    if ! grep -Eq "$2" "$1"; then
        echo "    ----- last 25 lines of $1 -----"
        tail -n 25 "$1" | sed 's/^/    /'
        fail "$3 (pattern not found: $2)"
    fi
}

# ---------------------------------------------------------------------------
# (1) PANIC path
# ---------------------------------------------------------------------------
echo "== (1) panic path: @(gd_method) panics with a known message =="
PANIC_LOG="$LOGDIR/crash-panic.log"
rc=0
"$GODOT" --headless --path "$PROJ" --script test_panic.gd >"$PANIC_LOG" 2>&1 || rc=$?
if [[ "$rc" == "0" ]]; then
    fail "panic child exited 0 — the panic did not terminate the process"
fi
grep -q "CRASH_DRIVER_FAIL" "$PANIC_LOG" && fail "panic driver reported failure (see $PANIC_LOG)"
# The assertion proc's stderr line: sentinel + message + the script file:line.
assert_grep "$PANIC_LOG" "ODIN_SCRIPT_PANIC panic: CRASH_TEST_PANIC boom from odin script" \
    "ODIN_SCRIPT_PANIC line with the panic message missing"
assert_grep "$PANIC_LOG" "crash_target\.odin:[0-9]+" \
    "panic report does not carry the script file:line"
# The push_error copy — the channel the editor Output shows (headless: an ERROR: line).
assert_grep "$PANIC_LOG" "ERROR: ODIN_SCRIPT_PANIC" \
    "push_error copy of the panic (editor-visible route) missing"
echo "  panic child died (rc=$rc) with ODIN_SCRIPT_PANIC + file:line + push_error copy"

# ---------------------------------------------------------------------------
# (2) SIGNAL path
# ---------------------------------------------------------------------------
echo "== (2) signal path: @(gd_method) dereferences nil (SIGSEGV) =="
SEGV_LOG="$LOGDIR/crash-segv.log"
rc=0
"$GODOT" --headless --path "$PROJ" --script test_segv.gd >"$SEGV_LOG" 2>&1 || rc=$?
if [[ "$rc" == "0" ]]; then
    fail "segv child exited 0 — the nil deref did not kill the process"
fi
grep -q "CRASH_DRIVER_FAIL" "$SEGV_LOG" && fail "segv driver reported failure (see $SEGV_LOG)"
# The fatal-signal reporter's marker (core/crash.odin).
assert_grep "$SEGV_LOG" "ODIN_GODOT_CRASH: fatal signal SIGSEGV" \
    "ODIN_GODOT_CRASH marker missing"
# The SYMBOLIZED faulting frame (ucontext pc -> dladdr): the Odin proc by name.
assert_grep "$SEGV_LOG" "ODIN_GODOT_CRASH at +pc .*crash_target_do_segv" \
    "faulting frame not symbolized to the Odin proc"
# At least one backtrace frame line from backtrace_symbols_fd ("N  <module>  0x... sym").
assert_grep "$SEGV_LOG" "^[0-9]+ +[^ ]+ +0x[0-9a-f]+" \
    "no backtrace frame lines from backtrace_symbols_fd"
# The best-effort editor-visible one-liner (headless: an ERROR: line).
assert_grep "$SEGV_LOG" "ERROR: Odin: the game CRASHED in native code \(SIGSEGV" \
    "push_error crash one-liner (editor-visible route) missing"
# Chaining: Godot's OWN crash handler still ran after ours re-raised.
assert_grep "$SEGV_LOG" "Dumping the backtrace" \
    "Godot's chained crash handler did not run"
echo "  segv child died (rc=$rc); reporter + symbolized Odin frame + Godot's own handler chained"

echo
echo "CRASH_TEST_OK"
