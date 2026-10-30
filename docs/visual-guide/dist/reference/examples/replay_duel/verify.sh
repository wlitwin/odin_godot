#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" build "$ROOT/examples/replay_duel/verify" -collection:godot="$ROOT" -out:"$work/duel-verify"
"$work/duel-verify" "$@"
