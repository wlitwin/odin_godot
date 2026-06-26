#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SINGLE-PLAYER gate for the unified co-op arena. Proves the ONE gameplay codebase runs SOLO
# as host-with-no-peers: the SAME pawn/bullet/enemy scripts drive the full survivors loop —
# move, auto-fire kills enemies, XP/level-up, contact death — with the network broadcasts
# simply reaching nobody. Prints ARENA_SINGLE_OK.
#
#   nix develop --command bash -c 'bash examples/coop_arena/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/coop_arena"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) editor-open smoke: no missing-virtual / crash from the script-language wiring ----
ELOG="$(mktemp)"; trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "ARENA_SINGLE_FAIL: editor-open smoke logged a crash / missing virtual"
    tail -n 20 "$ELOG"; exit 1
fi
echo "arena: editor-open smoke clean"

# ---- (2) single-player full loop (host-with-no-peers) ----
SLOG="$(mktemp)"; trap 'rm -f "$ELOG" "$SLOG"' EXIT
set +e
COOP_ROLE=single "$GODOT" --headless --path "$PROJ" --quit-after 4000 >"$SLOG" 2>&1
set -e
cat "$SLOG" | grep -vE "resources still in use at exit|ObjectDB instances leaked"

if grep -E "ERROR|SCRIPT ERROR|signal 11|must be overridden" "$SLOG" \
    | grep -qvE "resources still in use at exit|ObjectDB instances leaked"; then
    echo "ARENA_SINGLE_FAIL: single-player run logged an error"
    grep -E "ERROR|SCRIPT ERROR|signal 11|must be overridden" "$SLOG" \
        | grep -vE "resources still in use at exit|ObjectDB instances leaked" | head -n 10
    exit 1
fi

ok=1
grep -q "PLAYERS_OK on=1 count=1" "$SLOG" || { echo "FAIL: lone pawn not spawned"; ok=0; }
grep -q "MOVED on=1"             "$SLOG" || { echo "FAIL: pawn did not move"; ok=0; }
grep -q "BULLET_LOCAL on=1"      "$SLOG" || { echo "FAIL: pawn did not auto-fire locally"; ok=0; }
grep -q "ENEMY_KILLED on=1"      "$SLOG" || { echo "FAIL: auto-fire did not kill an enemy"; ok=0; }
grep -q "LEVELUP on=1"           "$SLOG" || { echo "FAIL: no XP / level-up"; ok=0; }
grep -q "PLAYER_DIED on=1"       "$SLOG" || { echo "FAIL: no contact death"; ok=0; }
grep -q "SINGLE_DONE"            "$SLOG" || { echo "FAIL: did not finish"; ok=0; }

if (( ok == 1 )); then
    echo "ARENA_SINGLE_OK proved: unified codebase solo (host-with-no-peers) — move, auto-fire kills, XP/level, contact death"
    exit 0
fi
echo "ARENA_SINGLE_FAIL"; exit 1
