#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_MODERATION_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_authority/run.sh"
bash "$ROOT/tests/replay_provision/run.sh"
bash "$ROOT/tests/replay_net/run.sh"
REPLAY_AUTHORITY_MODERATION_COMPAT_OUT="$work/compat" bash "$ROOT/tests/replay_authority_moderation_compat/run.sh"
odin build "$ROOT/tests/replay_cave_moderation/durable" -collection:godot="$ROOT" -out:"$work/durable-test"
python3 "$ROOT/tests/replay_cave_moderation/durable.py" "$work/durable-test" "$work/durable"
bash "$ROOT/tests/replay_cave_moderation/build.sh" "$work/native"
MODERATION_RENDERED=1 python3 "$ROOT/tests/replay_cave_moderation/direct.py" "$work/native" "$work/direct"
for mode in unsupported planned crash;do python3 "$ROOT/tests/replay_cave_moderation/room.py" "$work/native" "$work/$mode" "$mode";done
MODERATION_DROP_REPLY=1 python3 "$ROOT/tests/replay_cave_moderation/room.py" "$work/native" "$work/lost-reply" planned
bash "$ROOT/tests/replay_cave_moderation/browser_build.sh" "$work/browser-build"
for mode in planned crash;do python3 "$ROOT/tests/replay_cave_moderation/browser_execute.py" "$work/browser-build" "$work/browser-$mode" "$mode";done
python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/native" "$work/campaign" campaign
REPLAY_CAVE_OWNER_OUT="$work/owner-regression" bash "$ROOT/tests/replay_cave_owner/run.sh"
echo REPLAY_CAVE_MODERATION_OK
