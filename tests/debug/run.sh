#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Debugging story — end-to-end verification.
#
# Proves the three debugging deliverables actually work on the real artifacts:
#
#  (A) UNIT: backtrace + dladdr + filter mechanism (the engine room of the native
#      `_debug_get_current_stack_info`). tests/debug/bt_probe.odin runs libunwind's
#      _Unwind_Backtrace over its own call chain AND dladdr's the REAL coin_collect
#      symbol out of the showcase scripts dll. Asserts BTPROBE_OK.
#
#  (B) LLDB: launch the REAL Godot under lldb, break on `showcase_scripts::coin_collect`,
#      drive a real PHYSICS coin collect (test_showcase.gd) so the breakpoint FIRES, then
#      `bt` + inspect `self`. Asserts lldb reported "stop reason = breakpoint" and that
#      coin_collect is in the backtrace. Prints DEBUG_LLDB_OK. GATED: if lldb is
#      unavailable the step is SKIPPED (like the browser-gated web tests) so the rest
#      still goes green.
#
#  (C) INTEGRATION (honest): run the showcase with ODIN_DEBUG_STACK_DUMP=1 and report
#      WHETHER Godot actually calls `_debug_get_current_stack_info` in a normal headless
#      run. (Spoiler: it does not outside an active remote-debug session — see the report
#      this prints and docs/debugging.md.)
#
# Prints DEBUG_OK if the required parts (A, and B unless gated) pass. Run in the Nix shell:
#   nix develop --command bash -c 'bash tests/debug/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT"
PROJ="$ROOT/tests/showcase"
SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

if [[ -z "${GODOT:-}" || ! -x "${GODOT:-/nonexistent}" ]]; then
    echo "debug: \$GODOT not set/executable — run inside the Nix dev shell." >&2
    exit 2
fi

# Build the showcase dlls (core with the native stack capture + scripts with coin_collect).
echo "== building showcase (core + scripts) =="
bash "$ROOT/build/build_scripts.sh" "$PROJ" 2>&1 | grep -E "^Built|error" | grep -v "could not find symbol" || true
if [[ ! -f "$SCRIPTS_DLL" ]]; then
    echo "debug: scripts dll not built: $SCRIPTS_DLL" >&2
    exit 1
fi
export ODIN_SCRIPTS_DLL="$SCRIPTS_DLL"

# ---------------------------------------------------------------------------
# (A) UNIT — backtrace + dladdr + filter mechanism.
# ---------------------------------------------------------------------------
echo
echo "== (A) unit: native backtrace + dladdr + filter =="
odin build "$ROOT/tests/debug/bt_probe.odin" -file -debug -out:"$ROOT/tests/debug/bt_probe" 2>&1 \
    | grep -iE "error" | grep -v "could not find symbol" || true
# coin_collect's unslid file address for the probe's part 2: script procs are LOCAL
# symbols since -use-single-module (dlsym can't see them; dladdr can — that's the point
# of the probe), so the address comes from the symbol table via nm.
SYM_ADDR="$(nm "$SCRIPTS_DLL" | grep -F 'showcase_scripts::coin_collect' | head -1 | awk '{print $1}')"
if [[ -z "$SYM_ADDR" ]]; then
    echo "debug: FAIL — coin_collect not in the scripts dll symbol table (nm)"
    exit 1
fi
BT_OUT="$("$ROOT/tests/debug/bt_probe" "$SCRIPTS_DLL" "$SYM_ADDR" 2>&1 || true)"
echo "$BT_OUT"
if ! grep -q "BTPROBE_OK" <<<"$BT_OUT"; then
    echo "debug: FAIL — backtrace/dladdr unit probe did not pass"
    exit 1
fi

# ---------------------------------------------------------------------------
# (B) LLDB — break on coin_collect under a real physics collect. GATED.
# ---------------------------------------------------------------------------
echo
echo "== (B) lldb: break on showcase_scripts::coin_collect, drive a real collect =="

LLDB="${LLDB:-/usr/bin/lldb}"
# nix sets DEVELOPER_DIR to an SDK without lldb, breaking the /usr/bin/lldb xcrun shim.
if ! "$LLDB" --version >/dev/null 2>&1; then
    for d in /Applications/Xcode.app/Contents/Developer /Library/Developer/CommandLineTools; do
        [[ -d "$d" ]] && export DEVELOPER_DIR="$d" && break
    done
fi

LLDB_GATED=0
if ! "$LLDB" --version >/dev/null 2>&1; then
    echo "debug: lldb unavailable — SKIPPING the lldb breakpoint check (gated)."
    LLDB_GATED=1
fi

if [[ "$LLDB_GATED" == "0" ]]; then
    # Re-sign a debuggable Godot copy (system Godot lacks get-task-allow; SIP blocks attach).
    CACHE="${TMPDIR:-/tmp}/odin-godot-lldb"; mkdir -p "$CACHE"
    GDBG="$CACHE/Godot-dbg"
    if [[ ! -x "$GDBG" || "$GODOT" -nt "$GDBG" ]]; then
        ENT="$CACHE/get-task-allow.entitlements"
        cat > "$ENT" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.get-task-allow</key><true/>
</dict></plist>
PLIST
        cp -f "$GODOT" "$GDBG"
        codesign --remove-signature "$GDBG" 2>/dev/null || true
        codesign --force --sign - --entitlements "$ENT" "$GDBG" >/dev/null 2>&1 || true
    fi

    # Ensure the .godot import dir exists so the extension loads under lldb.
    "$GDBG" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

    LLDB_LOG="$ROOT/tests/.logs/debug-lldb.log"; mkdir -p "$ROOT/tests/.logs"
    # Batch mode: bind a REGEX breakpoint (lldb won't bind `b pkg::proc` — `::` parse), run,
    # backtrace + read self (x0) at the hit, continue, quit.
    "$LLDB" -b \
        -o "break set -r coin_collect" \
        -o "run" \
        -o "bt" \
        -o "register read x0" \
        -o "continue" \
        -o "quit" \
        -- "$GDBG" --headless --path "$PROJ" --script test_showcase.gd \
        > "$LLDB_LOG" 2>&1 || true

    echo "---- lldb (key lines) ----"
    grep -E "stop reason = breakpoint|coin_collect|x0 = 0x|Process [0-9]+ exited" "$LLDB_LOG" | head -20 | sed 's/^/    /'
    echo "--------------------------"

    if grep -q "stop reason = breakpoint" "$LLDB_LOG" && grep -q "coin_collect" "$LLDB_LOG"; then
        echo "DEBUG_LLDB_OK"
    else
        echo "debug: FAIL — lldb did not stop at coin_collect (see $LLDB_LOG)"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# (C) INTEGRATION (honest) — does Godot call _debug_get_current_stack_info?
# ---------------------------------------------------------------------------
echo
echo "== (C) integration: does Godot invoke _debug_get_current_stack_info in a normal run? =="
DUMP_LOG="$ROOT/tests/.logs/debug-stackdump.log"
ODIN_DEBUG_STACK_DUMP=1 "$GODOT" --headless --path "$PROJ" --script test_showcase.gd \
    > "$DUMP_LOG" 2>&1 || true
if grep -q "ODIN_STACK_BEGIN" "$DUMP_LOG"; then
    echo "  RESULT: Godot DID call _debug_get_current_stack_info (captured Odin frames):"
    grep "ODIN_STACK_FRAME" "$DUMP_LOG" | head -10 | sed 's/^/    /'
else
    echo "  RESULT: Godot did NOT call _debug_get_current_stack_info in this headless run."
    echo "          (Expected: the virtual is only invoked during an active remote-debug"
    echo "           session. The native capture is verified by (A); the engine simply does"
    echo "           not request it here. Documented as a known limitation in docs/debugging.md.)"
fi

echo
echo "DEBUG_OK"
