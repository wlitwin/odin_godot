#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# lldb-godot.sh — debug an Odin script under native lldb.
#
# Odin scripts are AOT-compiled native code with full symbols (built with -debug), so
# `lldb` debugs them like any C library: set a breakpoint on a script proc, run, and the
# debugger stops INSIDE your Odin code with a real backtrace and inspectable args.
# (Godot's in-editor breakpoints / step / expression-eval do NOT work for Odin — there is
# no interpreter. lldb + prints are the real tools. See docs/debugging.md.)
#
# Usage:
#   tools/lldb-godot.sh <symbol-regex> <project-dir> [extra godot args...]
#
# Examples:
#   # Break on Coin.collect in the showcase, run headless, drive it, inspect:
#   tools/lldb-godot.sh coin_collect tests/showcase --headless --script test_showcase.gd
#   # Break on any proc whose name matches, run the editor/game window:
#   tools/lldb-godot.sh player_process tests/showcase
#
# At the (lldb) prompt:  run | bt | continue (c) | register read x0  (x0 = `self`)
#   p (void*)$x0                 # the script instance pointer
#   memory read --size 8 --format x --count 4 $x0   # peek struct fields
#   frame variable              # (often empty at the prologue — Odin emits limited local
#                               #  DWARF; read args from registers instead, see docs)
#
# NOTES on macOS:
#  * The breakpoint MUST be a REGEX (`break set -r`), not `b showcase_scripts::coin_collect`
#    — lldb parses `::` as a C++ qualified name and fails to bind it. This script uses the
#    regex form for you.
#  * The system Godot is code-signed WITHOUT `get-task-allow`, so SIP refuses to let lldb
#    attach ("Not allowed to attach to process"). This script makes a re-signed, debuggable
#    COPY of the Godot binary (ad-hoc signature + get-task-allow) and debugs THAT. The copy
#    is cached; the original install is never modified.
# ----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -lt 2 ]]; then
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi

SYMBOL="$1"; shift
PROJECT="$1"; shift
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
    echo "lldb-godot: \$GODOT not found/executable: $GODOT" >&2
    exit 2
fi
PROJECT="$(cd "$PROJECT" && pwd)"

# --- lldb resolution: nix sets DEVELOPER_DIR to an SDK that has no lldb, which breaks the
#     /usr/bin/lldb xcrun shim. Point it at a real Xcode/CLT install if the shim is broken.
LLDB="${LLDB:-/usr/bin/lldb}"
if ! "$LLDB" --version >/dev/null 2>&1; then
    for d in /Applications/Xcode.app/Contents/Developer /Library/Developer/CommandLineTools; do
        if [[ -d "$d" ]]; then export DEVELOPER_DIR="$d"; break; fi
    done
fi
if ! "$LLDB" --version >/dev/null 2>&1; then
    echo "lldb-godot: lldb is unavailable (set \$LLDB or install Xcode/Command Line Tools)." >&2
    exit 3
fi

# --- debuggable Godot copy: re-sign the binary with get-task-allow so SIP permits attach.
#     Cached and only rebuilt when the source Godot is newer.
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
        codesign --remove-signature "$dbg" 2>/dev/null || true
        codesign --force --sign - --entitlements "$ent" "$dbg" >/dev/null 2>&1
        echo "lldb-godot: prepared debuggable Godot copy at $dbg" >&2
    fi
    echo "$dbg"
}

GDBG="$(godot_dbg)"

echo "lldb-godot: breakpoint regex '$SYMBOL'  project '$PROJECT'" >&2
echo "lldb-godot: (at the prompt: 'run', then 'bt', 'continue', 'register read x0')" >&2

exec "$LLDB" \
    -o "break set -r $SYMBOL" \
    -- "$GDBG" --path "$PROJECT" "$@"
