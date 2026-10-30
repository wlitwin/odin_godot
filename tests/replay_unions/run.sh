#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_UNION_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Union target logs: $work"' EXIT
odin build "$ROOT/tests/replay_unions/native" -collection:godot="$ROOT" -out:"$work/native"
"$work/native" >"$work/native.txt"
odin build "$ROOT/tests/replay_unions/native" -collection:godot="$ROOT" -o:speed -out:"$work/native-speed"
"$work/native-speed" >"$work/native-speed.txt";cmp "$work/native.txt" "$work/native-speed.txt"
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_unions/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_unions/compare.mjs" "$work/$mode.wasm" "$work/native.txt"
done
if [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] && /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null;then
 odin build "$ROOT/tests/replay_unions/native" -collection:godot="$ROOT" -target:darwin_amd64 -out:"$work/amd64"
 /usr/bin/arch -x86_64 "$work/amd64" >"$work/amd64.txt";cmp "$work/native.txt" "$work/amd64.txt"
 echo REPLAY_UNION_AMD64_EQUAL
fi
echo REPLAY_UNIONS_OK
