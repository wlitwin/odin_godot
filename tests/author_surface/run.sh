#!/usr/bin/env bash
# The public multiplayer vocabulary is intentionally singular. This gate proves
# retired spellings fail with migration diagnostics and scans authored source so
# compatibility aliases cannot quietly return.
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ODIN="${ODIN:-odin}"
SGEN="${SGEN_BIN:-}"
tmp_sgen=""

if [[ -z "$SGEN" || ! -x "$SGEN" ]]; then
	tmp_sgen="$(mktemp -d)"
	SGEN="$tmp_sgen/scriptgen"
	"$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$SGEN" -debug >/dev/null 2>&1 || {
		echo "AUTHOR_SURFACE_FAIL: scriptgen build failed"
		exit 1
	}
fi

work="$(mktemp -d)"
cleanup() {
	rm -rf "$work"
	[[ -z "$tmp_sgen" ]] || rm -rf "$tmp_sgen"
}
trap cleanup EXIT
fail() { echo "AUTHOR_SURFACE_FAIL: $1"; exit 1; }

out="$("$SGEN" "$work" -res:"$work/removed" -godot:"$ROOT" 2>&1)"
[[ $? -eq 2 ]] || fail "the removed -res option was accepted"
echo "$out" | grep -qF -- '-res was removed' \
	|| fail "the removed -res option lacks a migration diagnostic"

# Presentation has one declaration: gd_event. Both retired attributes are
# recognized only to produce this migration error; neither reaches generation.
mkdir -p "$work/events"
cat >"$work/events/game.odin" <<'ODIN'
//gd:extends Node
//gd:class OldEvents
package old_events
import gd "godot:godot"
OldEvents :: struct {owner: gd.Node}
@(gd_cue) old_cue_fx :: proc(g: ^OldEvents, mine: bool) {}
@(gd_fact) old_fact_fx :: proc(g: ^OldEvents, mine: bool) {}
ODIN
out="$("$SGEN" "$work/events" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "gd_cue/gd_fact were accepted"
echo "$out" | grep -qF 'gd_cue and gd_fact were removed' \
	|| fail "retired event attributes lack a gd_event migration diagnostic"

# Command configuration has one typed vocabulary; quoted token strings are not
# parsed or normalized anymore.
mkdir -p "$work/policy"
cat >"$work/policy/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class OldPolicy
package old_policy
import gd "godot:godot"
import knet "godot:kit/net"
OldPolicy :: struct {owner: gd.Node, net_id: knet.Net_Id, hp: i32 `gd:"replicate"`}
@(gd_command = "predict") old_policy_hit :: proc(self: ^OldPolicy) -> bool {return true}
ODIN
out="$("$SGEN" "$work/policy" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a quoted command policy was accepted"
echo "$out" | grep -qF 'quoted command policies were removed' \
	|| fail "quoted policy lacks a typed knet.Action_Policy migration diagnostic"

# Continuous owner fields interpolate by definition; bare interp is no longer a
# second spelling for the same resolved schema.
mkdir -p "$work/interp"
cat >"$work/interp/avatar.odin" <<'ODIN'
//gd:extends Node2D
//gd:class OldInterp
package old_interp
import gd "godot:godot"
import knet "godot:kit/net"
OldInterp :: struct {owner: gd.Node2d, net_id: knet.Net_Id, x: f32 `gd:"owner,interp"`}
ODIN
out="$("$SGEN" "$work/interp" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail 'gd:"owner,interp" was accepted'
echo "$out" | grep -qF 'bare `interp` is redundant on the owner lane and was removed' \
	|| fail "redundant owner interpolation lacks a drop-interp diagnostic"

production=("$ROOT/build" "$ROOT/core" "$ROOT/decl" "$ROOT/docs" "$ROOT/examples" "$ROOT/kit" "$ROOT/play" "$ROOT/scriptgen")
if rg -n '@\(gd_(cue|fact)' "${production[@]}" --glob '!*.gen.odin' --glob '!one-way-author-surface-todo.md'; then
	fail "a retired presentation attribute remains in production source or docs"
fi
if rg -n '@\(gd_command\s*=\s*["`]' "${production[@]}" --glob '!*.gen.odin'; then
	fail "a quoted command policy remains in production source or docs"
fi
if rg -n 'gd:"owner,interp(?:,|"|`)' "${production[@]}" --glob '!*.gen.odin'; then
	fail "a redundant owner interpolation spelling remains in production source or docs"
fi
if rg -n '\b(Command_Access|command_issue_checked|command_execute_reason|command_result_write_reason|registry_host_command_checked|lane_command_checked|exec_checked)\b' \
	"$ROOT/kit" "$ROOT/scriptgen" "$ROOT/docs" --glob '!*.gen.odin' --glob '!one-way-author-surface-todo.md'; then
	fail "an obsolete action alias remains public"
fi
if rg -n 'gen_ids|boot_entity_ids|%s_ids :: proc' "$ROOT/kit" "$ROOT/scriptgen" --glob '!*.gen.odin'; then
	fail "the ID-only entity census compatibility path returned"
fi
if rg -n 'gd_cue|gd_fact' "$ROOT/build" "$ROOT/core" "$ROOT/decl" "$ROOT/docs" "$ROOT/scriptgen/shared.odin" \
	--glob '!one-way-author-surface-todo.md'; then
	fail "retired attributes remain registered or documented"
fi

echo "AUTHOR_SURFACE_OK"
