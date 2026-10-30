#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_comms" -collection:godot="$ROOT" -out:"$work/comms"
odin check "$ROOT/replay/comms" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
# Internal storage and unchecked mutation helpers must not become author APIs.
# Compile from another package so this checks Odin visibility, not source spelling.
mkdir -p "$work/api_probe"
for entry in \
  'comms|issue' 'comms|newer' 'comms|record' 'comms|broadcast' \
  'comms|consume_token' 'comms|settle' 'comms|send' 'comms|same_binding' \
  'comms|Packet' 'comms|Wire_Kind' 'comms|Peer' 'comms|Delivery' 'comms|PACKET_KIND' \
  'view|Once_Key' 'view|Once_Batch' \
  'net|Input_Sent' 'net|Input_Timing' 'net|Batch_Before_Authority'; do
  IFS='|' read -r package_path symbol <<<"$entry"
  printf 'package api_probe\nimport api "godot:replay/%s"\nLeak :: api.%s\n' \
    "$package_path" "$symbol" >"$work/api_probe/probe.odin"
  if odin check "$work/api_probe" -collection:godot="$ROOT" -no-entry-point >"$work/api_probe.log" 2>&1; then
    echo "Unexpected public Replay API: $package_path.$symbol" >&2
    exit 1
  fi
  if ! grep -Fq "'$symbol' is not exported" "$work/api_probe.log"; then
    cat "$work/api_probe.log" >&2
    exit 1
  fi
done
echo REPLAY_COMMS_OK
