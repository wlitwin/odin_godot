#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Deterministic target logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
ODIN_BIN="$(command -v "${ODIN:-odin}")"
echo "DUEL_TARGET_HOST os=$(uname -s) arch=$(uname -m)"
"${ODIN:-odin}" test "$ROOT/tests/replay_deterministic" -collection:godot="$ROOT" -out:"$work/math"
"${ODIN:-odin}" build "$ROOT/tests/replay_deterministic/native" -collection:godot="$ROOT" -out:"$work/corpus"
"$work/corpus" >"$work/native.txt"
"$ODIN_BIN" build "$ROOT/tests/replay_deterministic/native" -collection:godot="$ROOT" -o:speed -out:"$work/corpus-speed"
"$work/corpus-speed" >"$work/native-speed.txt"
cmp "$work/native.txt" "$work/native-speed.txt"
echo DUEL_NATIVE_OPTIMIZATIONS_EQUAL
"${ODIN:-odin}" build "$ROOT/tests/replay_deterministic/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/corpus.wasm"
node "$ROOT/tests/replay_deterministic/compare.mjs" "$work/corpus.wasm" "$work/native.txt" wasm-default
"$ODIN_BIN" build "$ROOT/tests/replay_deterministic/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -o:speed -out:"$work/corpus-speed.wasm"
node "$ROOT/tests/replay_deterministic/compare.mjs" "$work/corpus-speed.wasm" "$work/native.txt" wasm-speed
if [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] && /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  for mode in default speed; do
    flags=(); if [[ "$mode" == speed ]]; then flags+=(-o:speed); fi
    # Verify both the produced architecture and execution. Some Nix toolchains
    # warn about an unused arm64 compiler-runtime archive during this cross-link.
    "$ODIN_BIN" build "$ROOT/tests/replay_deterministic/native" -collection:godot="$ROOT" -target:darwin_amd64 "${flags[@]}" -out:"$work/corpus-amd64-$mode"
    file "$work/corpus-amd64-$mode" | tee "$work/amd64-$mode-file.txt"
    rg -q 'Mach-O 64-bit x86_64' "$work/amd64-$mode-file.txt"
    /usr/bin/arch -x86_64 "$work/corpus-amd64-$mode" >"$work/amd64-$mode.txt"
    cmp "$work/native.txt" "$work/amd64-$mode.txt"
    echo "DUEL_TARGET_EQUAL target=darwin-amd64-rosetta optimization=$mode seeds=4 ticks_per_seed=2400"
  done
else
  echo DUEL_AMD64_ROSETTA_UNAVAILABLE
  if [[ "${REPLAY_REQUIRE_ROSETTA:-0}" == 1 ]]; then exit 1; fi
fi
echo REPLAY_DETERMINISTIC_OK
