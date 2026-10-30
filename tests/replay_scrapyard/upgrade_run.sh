#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"
work="${REPLAY_UPGRADE_OUT:-$(mktemp -d)}"; mkdir -p "$work"
cleanup() {
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 || -n "${REPLAY_UPGRADE_OUT:-}" ]]; then echo "Upgrade logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
"${ODIN:-odin}" build "$PROJ/tools/upgrade_run" -collection:godot="$ROOT" -out:"$work/upgrade_run" >"$work/cli-build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
  "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
python3 "$ROOT/tests/replay_scrapyard/upgrade.py" --converter "$work/upgrade_run" --work "$work" --project "$PROJ" --godot "$GODOT"
