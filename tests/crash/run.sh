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
#  Both dying children ALSO write their report to bin/.odin_crash.log (the artifact
#  that survives an editor-launched child, whose stderr goes nowhere): (1) asserts the
#  panic line landed in the file; (2) asserts the file holds a FRESH signal report
#  (marker + symbolized frame + a backtrace line, and no stale panic line — O_TRUNC).
#
#  (3) EDITOR-side surfacing — with (2)'s crash file on disk, a HEADLESS EDITOR pass
#      over the project must notice it (core/crash_watch.odin, polled from the
#      lv_frame pump every ~30 frames), push the FULL framed report into the editor
#      Output ("the game process CRASHED"), and rename the file to
#      .odin_crash.prev.log (one-shot; artifact preserved).
#
# THIS script exits 0 and prints CRASH_TEST_OK after asserting on the crashed
# children. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/crash/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/crash"
# The export phase (5) runs the headless EDITOR, whose OdinExportPlugin resolves the
# odin_godot collection from this env (repo test projects have no addons/ dir).
export ODIN_GODOT_ROOT="$ROOT"

# Build the scripts dll (CrashTarget + boot) + the core dll.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

LOGDIR="$ROOT/tests/.logs"
mkdir -p "$LOGDIR"

# The crash-report file the dying children write (editor-feature runs -> res://bin) and
# the watcher's rename target. Clean both so every assertion below is about THIS run.
CRASH_FILE="$PROJ/bin/.odin_crash.log"
CRASH_PREV="$PROJ/bin/.odin_crash.prev.log"
rm -f "$CRASH_FILE" "$CRASH_PREV"

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
# The crash-report FILE: the panic hook writes the same line to bin/.odin_crash.log
# BEFORE trapping (core/crash.odin crash_file_note_panic) — required because on darwin
# arm64 the trap raises SIGTRAP, which the fatal-signal handler does not catch.
[[ -f "$CRASH_FILE" ]] || fail "crash-report file missing after the panic child"
assert_grep "$CRASH_FILE" "ODIN_SCRIPT_PANIC panic: CRASH_TEST_PANIC boom from odin script" \
    "crash-report file lacks the panic line"
# The post-panic trap (arm64: SIGTRAP; x86: ud2 -> SIGILL) is a HANDLED signal, and the
# handler must APPEND its report after the panic line (the g_crash_file_panic O_APPEND
# coordination), never clobber it — assert both halves of the coherent file.
assert_grep "$CRASH_FILE" "ODIN_GODOT_CRASH" \
    "trap-after-panic signal report missing from the crash file (SIGTRAP/SIGILL handling)"
if ! grep -q "ODIN_SCRIPT_PANIC" "$CRASH_FILE"; then
    fail "panic line clobbered by the trap report — O_APPEND coordination broken"
fi
echo "  panic child died (rc=$rc) with ODIN_SCRIPT_PANIC + file:line + push_error copy + coherent crash file"

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
# The crash-report FILE: the handler mirrors every chunk into bin/.odin_crash.log —
# a FRESH report (O_TRUNC: the panic line from (1) must be gone) with the marker, the
# symbolized faulting frame, and at least one backtrace_symbols_fd frame line.
[[ -f "$CRASH_FILE" ]] || fail "crash-report file missing after the segv child"
assert_grep "$CRASH_FILE" "ODIN_GODOT_CRASH: fatal signal SIGSEGV" \
    "crash-report file lacks the ODIN_GODOT_CRASH marker"
assert_grep "$CRASH_FILE" "ODIN_GODOT_CRASH at +pc .*crash_target_do_segv" \
    "crash-report file lacks the symbolized faulting frame"
assert_grep "$CRASH_FILE" "^[0-9]+ +[^ ]+ +0x[0-9a-f]+" \
    "crash-report file lacks backtrace frame lines"
if grep -q "ODIN_SCRIPT_PANIC" "$CRASH_FILE"; then
    fail "stale panic line survived in the crash file — handler did not truncate a fresh report"
fi
echo "  segv child died (rc=$rc); reporter + symbolized Odin frame + Godot's own handler chained + crash file"

# ---------------------------------------------------------------------------
# (3) EDITOR-side surfacing: a headless editor pass over the project must notice the
#     crash file from (2), push the FULL framed report into the editor Output, and
#     rename the file to .odin_crash.prev.log (one-shot, artifact preserved).
# ---------------------------------------------------------------------------
echo "== (3) editor-side surfacing: headless editor notices bin/.odin_crash.log =="
ED_LOG="$LOGDIR/crash-editor.log"
rc=0
"$GODOT" --editor --headless --path "$PROJ" --quit-after 60 >"$ED_LOG" 2>&1 || rc=$?
if [[ "$rc" != "0" ]]; then
    tail -n 25 "$ED_LOG" | sed 's/^/    /'
    fail "headless editor pass exited non-zero ($rc)"
fi
# The framed push_error (headless prints push_error as an ERROR: line) + the report body.
assert_grep "$ED_LOG" "odin_godot: the game process CRASHED — report" \
    "editor watcher did not surface the crash report (framed push_error missing)"
assert_grep "$ED_LOG" "ODIN_GODOT_CRASH: fatal signal SIGSEGV" \
    "surfaced report does not carry the full crash-file contents"
assert_grep "$ED_LOG" "crash_target_do_segv" \
    "surfaced report does not carry the symbolized faulting frame"
# One-shot semantics: surfaced report renamed away, artifact preserved as .prev.
[[ ! -f "$CRASH_FILE" ]] || fail "crash file was not renamed after surfacing (would refire)"
[[ -f "$CRASH_PREV" ]] || fail ".odin_crash.prev.log missing — the surfaced artifact was lost"
echo "  editor pass surfaced the report into the Output and renamed the file to .prev"

# ---------------------------------------------------------------------------
# (4) STACK OVERFLOW: unbounded recursion faults on the guard page — a SIGSEGV whose
#     thread has NO usable stack. The report below exists at all only because the
#     handler runs on a sigaltstack.
# ---------------------------------------------------------------------------
echo "== (4) stack overflow: report survives via sigaltstack =="
rm -f "$CRASH_FILE" "$CRASH_PREV"
OVF_LOG="$LOGDIR/crash-overflow.log"
rc=0
"$GODOT" --headless --path "$PROJ" --script test_overflow.gd >"$OVF_LOG" 2>&1 || rc=$?
if [[ "$rc" == "0" ]]; then
    fail "overflow child exited 0 — the recursion did not kill the process"
fi
grep -q "CRASH_DRIVER_FAIL" "$OVF_LOG" && fail "overflow driver reported failure (see $OVF_LOG)"
assert_grep "$OVF_LOG" "ODIN_GODOT_CRASH: fatal signal (SIGSEGV|SIGBUS)" \
    "no crash report from the stack overflow — sigaltstack handling broken"
[[ -f "$CRASH_FILE" ]] || fail "crash-report file missing after the overflow child"
assert_grep "$CRASH_FILE" "ODIN_GODOT_CRASH: fatal signal" \
    "crash-report file lacks the overflow report"
echo "  overflow child died (rc=$rc) and the sigaltstack handler still reported"

# ---------------------------------------------------------------------------
# (5) EXPORTED game: a real .app export whose autoload self-crashes at startup
#     (ODIN_CRASH_TEST=segv — see crash_target_ready). The reporter must land the
#     post-mortem at user://odin_crash.log (the res://bin path is editor-feature-only),
#     the artifact a player can send in. Darwin-only (the export preset is macOS).
# ---------------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    echo "== (5) exported game: crash report lands at user://odin_crash.log =="
    APP="$PROJ/out/OdinGodotCrash.app"
    EXE="$APP/Contents/MacOS/OdinGodotCrash"
    USER_LOG="$HOME/Library/Application Support/Godot/app_userdata/OdinGodotCrash/odin_crash.log"
    rm -rf "$PROJ/out" "$PROJ/.export_build"
    rm -f "$USER_LOG"
    mkdir -p "$PROJ/out"
    "$GODOT" --headless --path "$PROJ" --export-release "macOS" "$APP" 2>&1 \
        | grep -E "odin export:" || true
    [[ -x "$EXE" ]] || fail "exported executable missing ($EXE) — export templates installed?"
    rc=0
    env -u ODIN_SCRIPTS_DLL ODIN_CRASH_TEST=segv "$EXE" --headless >"$LOGDIR/crash-export.log" 2>&1 || rc=$?
    if [[ "$rc" == "0" ]]; then
        fail "exported app exited 0 — ODIN_CRASH_TEST=segv did not crash it"
    fi
    [[ -f "$USER_LOG" ]] || fail "user:// crash log missing after the exported-app crash ($USER_LOG)"
    assert_grep "$USER_LOG" "ODIN_GODOT_CRASH: fatal signal SIGSEGV" \
        "user:// crash log lacks the report marker"
    # The RELEASE export inlines do_segv into the generated _ready trampoline — assert
    # the faulting frame symbolizes into the script's code at all (crash_target*), not
    # a specific proc name.
    assert_grep "$USER_LOG" "ODIN_GODOT_CRASH at +pc .*crash_target" \
        "user:// crash log lacks a faulting frame symbolized into the script"
    rm -f "$USER_LOG"
    echo "  exported app crashed and left a symbolized post-mortem at user://odin_crash.log"
fi

echo
echo "CRASH_TEST_OK"
