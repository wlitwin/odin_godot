#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# debug_game.sh — run a Godot project under native lldb with Odin symbols.
#
# Odin scripts are AOT-compiled native code built -debug -use-single-module, so lldb
# gives the FULL treatment: file:line breakpoints in .odin sources, stepping, `bt`,
# `frame variable` (named args + script-struct fields). This launcher removes every
# manual step: it resolves lldb, prepares a debuggable Godot (macOS re-sign), loads
# the Godot-type pretty-printers, pre-sets your breakpoints, and auto-breaks on script
# panics/asserts so a `panic("...")` freezes the session AT the panic site.
#
# The editor's "Project > Tools > Debug Game (LLDB)" items run this for you in a
# terminal window; it works standalone too:
#
#   build/debug_game.sh <project-dir>                       # interactive (lldb) prompt
#   build/debug_game.sh --break player.odin:42 <project-dir>  # break + auto-run
#   build/debug_game.sh --break coin_collect <project-dir>    # symbol regex breakpoint
#
# At the (lldb) prompt:
#   run                        start the game (auto when --break/--run given)
#   b file.odin:NN             set/add line breakpoints (also while running: Ctrl-C first)
#   bt / up / down             backtrace, walk frames
#   frame variable             named args; `frame variable *self` = script struct fields
#   n / s / c                  step over / into / continue
#
# Options:
#   --godot PATH     Godot binary (default: $GODOT, else /Applications/Godot.app/...)
#   --break SPEC     repeatable. 'file.odin:LINE' -> line breakpoint; anything else ->
#                    symbol REGEX ('break set -r' — lldb can't parse Odin's :: names)
#   --run            issue `run` immediately (implied by --break)
#   --batch          non-interactive: `lldb -b`, auto-run, exit when the process ends
#   --cmd CMD        repeatable; extra lldb command appended AFTER run (tests/automation)
#   --no-panic-break skip the automatic breakpoint on script panic/assert
#   --prepare-only   prepare the debuggable Godot copy, print its path, exit (the VS Code
#                    preLaunchTask uses this)
#
# Anything after `--` is passed to Godot (e.g. -- --headless --script test.gd).
#
# macOS notes (all handled here):
#   * the installed Godot is signed WITHOUT get-task-allow, so SIP refuses lldb attach —
#     we debug a cached, ad-hoc re-signed COPY (the install is never touched).
#   * inside a Nix shell, /usr/bin/lldb's xcrun shim breaks (DEVELOPER_DIR points at an
#     SDK with no lldb) — reset it to a real Xcode/CLT install.
# ----------------------------------------------------------------------------
set -euo pipefail

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BREAKS=()
DO_RUN=0
BATCH=0
POST_CMDS=()
PANIC_BREAK=1
PREPARE_ONLY=0
PROJECT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --godot)          GODOT="$2"; shift 2 ;;
        --break)          BREAKS+=("$2"); DO_RUN=1; shift 2 ;;
        --run)            DO_RUN=1; shift ;;
        --batch)          BATCH=1; DO_RUN=1; shift ;;
        --cmd)            POST_CMDS+=("$2"); shift 2 ;;
        --no-panic-break) PANIC_BREAK=0; shift ;;
        --prepare-only)   PREPARE_ONLY=1; shift ;;
        -h|--help)        usage ;;
        --)               shift; break ;;
        -*)               echo "debug_game: unknown option '$1'" >&2; usage ;;
        *)                if [[ -z "$PROJECT" ]]; then PROJECT="$1"; shift
                          else break; fi ;;
    esac
done
# Remaining args go to Godot verbatim.
GODOT_ARGS=("$@")

if [[ ! -x "$GODOT" ]]; then
    echo "debug_game: Godot binary not found/executable: $GODOT (set \$GODOT or --godot)" >&2
    exit 2
fi

# --- debuggable Godot copy (macOS re-sign; other OSes use the binary as-is). Cached,
#     rebuilt only when the source binary is newer.
godot_dbg() {
    if [[ "$(uname)" != "Darwin" ]]; then echo "$GODOT"; return; fi
    local cache="${TMPDIR:-/tmp}/odin-godot-lldb"
    local dbg="$cache/Godot-dbg"
    mkdir -p "$cache"
    if [[ ! -x "$dbg" || "$GODOT" -nt "$dbg" ]]; then
        local ent="$cache/get-task-allow.entitlements"
        cat > "$ent" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.get-task-allow</key><true/>
</dict></plist>
PLIST
        cp -f "$GODOT" "$dbg"
        chmod u+w "$dbg" # a nix-store source copies in read-only; codesign must write
        codesign --remove-signature "$dbg" 2>/dev/null || true
        codesign --force --sign - --entitlements "$ent" "$dbg" >/dev/null 2>&1
        echo "debug_game: prepared debuggable Godot copy at $dbg" >&2
    fi
    echo "$dbg"
}

GDBG="$(godot_dbg)"
if [[ "$PREPARE_ONLY" == "1" ]]; then
    echo "$GDBG"
    exit 0
fi

if [[ -z "$PROJECT" ]]; then
    echo "debug_game: no project directory given" >&2
    usage
fi
PROJECT="$(cd "$PROJECT" && pwd)"

# --- lldb resolution (see header). Linux: plain `lldb` from PATH.
if [[ "$(uname)" == "Darwin" ]]; then
    LLDB="${LLDB:-/usr/bin/lldb}"
    if ! "$LLDB" --version >/dev/null 2>&1; then
        for d in /Applications/Xcode.app/Contents/Developer /Library/Developer/CommandLineTools; do
            if [[ -d "$d" ]]; then export DEVELOPER_DIR="$d"; break; fi
        done
    fi
else
    LLDB="${LLDB:-lldb}"
fi
if ! "$LLDB" --version >/dev/null 2>&1; then
    echo "debug_game: lldb is unavailable (set \$LLDB or install Xcode CLT / the lldb package)." >&2
    exit 3
fi

# --- assemble the lldb command list.
LLDB_OPTS=()

# Godot-type pretty-printers (godot.String / String_Name / Variant readable in
# `frame variable` instead of raw opaque words). Best-effort: skip if not shipped.
if [[ -f "$HERE/godot_lldb.py" ]]; then
    LLDB_OPTS+=(-o "command script import '$HERE/godot_lldb.py'")
fi

# Auto-break on script panic/assert: a `panic("...")`/failed assert stops HERE with the
# whole stack + locals live, instead of printing and killing the process. (Hard crashes
# — SIGSEGV etc. — stop lldb on their own, no breakpoint needed.)
if [[ "$PANIC_BREAK" == "1" ]]; then
    LLDB_OPTS+=(-o "breakpoint set -r native_script_assertion_failure")
fi

# User breakpoints. 'name.odin:123' -> file:line; anything else -> symbol regex
# (NOT `b pkg::proc` — lldb parses :: as C++ scoping and never binds Odin names).
for spec in ${BREAKS[@]+"${BREAKS[@]}"}; do
    case "$spec" in
        *.odin:*)
            f="${spec%%:*}"; l="${spec##*:}"
            LLDB_OPTS+=(-o "breakpoint set -f '$f' -l $l")
            ;;
        *)
            LLDB_OPTS+=(-o "breakpoint set -r '$spec'")
            ;;
    esac
done

if [[ "$DO_RUN" == "1" ]]; then
    LLDB_OPTS+=(-o "run")
fi
for c in ${POST_CMDS[@]+"${POST_CMDS[@]}"}; do
    LLDB_OPTS+=(-o "$c")
done

BATCH_FLAG=()
if [[ "$BATCH" == "1" ]]; then
    BATCH_FLAG=(-b)
fi

echo "debug_game: project '$PROJECT'" >&2
if [[ "$DO_RUN" != "1" ]]; then
    echo "debug_game: at the (lldb) prompt: 'b file.odin:NN' or 'break set -r <proc>', then 'run'" >&2
fi

exec "$LLDB" ${BATCH_FLAG[@]+"${BATCH_FLAG[@]}"} \
    ${LLDB_OPTS[@]+"${LLDB_OPTS[@]}"} \
    -- "$GDBG" --path "$PROJECT" ${GODOT_ARGS[@]+"${GODOT_ARGS[@]}"}
