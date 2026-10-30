#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl"
work="$(mktemp -d)"
producer=""
cleanup() { if [[ -n "$producer" ]]; then kill "$producer" 2>/dev/null || true; wait "$producer" 2>/dev/null || true; fi; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_CAVE_ROLE=solo REPLAY_CAVE_SAVE="$work/cave.replay" REPLAY_CAVE_PROFILE="$work/player.token" REPLAY_CAVE_NAME_PATH="$work/display_name"
unset REPLAY_CAVE_TOKEN
REPLAY_CAVE_RESUME=0 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/save.log" 2>&1 &
producer=$!
for _ in {1..250}; do
  if grep -q '^REPLAY_CAVE_SAVE_READY' "$work/save.log"; then break; fi
  if ! kill -0 "$producer" 2>/dev/null; then cat "$work/save.log"; exit 1; fi
  sleep 0.1
done
if ! grep -q '^REPLAY_CAVE_SAVE_READY' "$work/save.log"; then cat "$work/save.log"; exit 1; fi
kill -KILL "$producer"
wait "$producer" 2>/dev/null || true
producer=""
if ! REPLAY_CAVE_RESUME=1 "$GODOT" --headless --path "$PROJ" --script save_test.gd >"$work/resume.log" 2>&1; then cat "$work/resume.log"; exit 1; fi
cat "$work/save.log" "$work/resume.log"
grep -q '^REPLAY_CAVE_SAVE_RESUME_OK' "$work/resume.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_CAVE_FAIL|ObjectDB instances were leaked' "$work/save.log" "$work/resume.log"; then exit 1; fi
