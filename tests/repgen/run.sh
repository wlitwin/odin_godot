#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# repgen — the gd:"replicate" codegen contract (friendslop toolkit, phase 0).
#
# Asserts, end to end:
#   (1) scriptgen turns `gd:"replicate[,interp][,owner]"` fields into a
#       knet.Entity_Desc table + public `<snake>_net_desc` in the *.gen.odin,
#       with multi-name fields expanded and option flags carried — AND turns
#       @(gd_command[="predict"]) procs into decode thunks, a Command_Desc
#       table + `<snake>_command_set`, and typed `<proc>_cmd` issue wrappers
#       (the generated wrapper holds the only role branch).
#   (2) The generated package COMPILES (odin check) — descriptor, command set,
#       conditional kit/net import, and the POD #asserts are all well-formed.
#   (3) The POD contract is ENFORCED: a string field tagged replicate generates
#       a #assert that FAILS the consumer compile, naming the field.
#   (4) An unknown replicate option is a scriptgen-time error.
#   (5) Command contract violations are scriptgen-time errors: no net_id field /
#       no replicated fields, platform-width int args, non-bool-first returns,
#       mispaired `<verb>_then` consequences (the shape is validated at build
#       time — a consequence can never silently not fire), and wire args wearing
#       the reserved issuer name `by` (the framework fills the declared
#       `by: knet.Player_Id`; a client-claimed one is the spoofable-side wart).
#
# Prints REPGEN_OK. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/repgen/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/build/common.sh"

build_scriptgen

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- (1)+(2): the good fixture generates a descriptor and compiles ----
GOOD="$TMP/good"
mkdir -p "$GOOD"
cp "$ROOT/tests/repgen/fixture/"*.odin "$GOOD/"
run_scriptgen "$GOOD"

GEN="$GOOD/pawn.gen.odin"
[ -f "$GEN" ] || { echo "REPGEN_FAIL: scriptgen produced no pawn.gen.odin"; exit 1; }
for needle in \
	'import knet "godot:kit/net"' \
	'_pawn_net_fields' \
	'offset_of(Pawn, hp)' \
	'offset_of(Pawn, x)' \
	'offset_of(Pawn, y)' \
	'{.Interp, .Owner_Stream}' \
	'{.Interp, .Predicted}' \
	'{.Predicted}' \
	'offset_of(Pawn, px)' \
	'offset_of(Pawn, fuel)' \
	'offset_of(Pawn, chill) + offset_of(type_of(Pawn{}.chill), left)' \
	'offset_of(Pawn, warm) + offset_of(type_of(Pawn{}.warm), left)' \
	'lerp = .F32' \
	'lerp = .Quat' \
	'lerp = .Custom, blend = pawn_blend_aim' \
	'wire = .F16' \
	'wire = .Custom, codec = pawn_charge_codec' \
	'slack = 0.5' \
	'glide = 0.1' \
	'cut = 32' \
	'pawn_net_desc := knet.Entity_Desc' \
	'intrinsics.type_is_nearly_simple_compare' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing: $needle"
		exit 1
	fi
done
# The untagged field must NOT be in the descriptor.
if grep -qF 'offset_of(Pawn, local)' "$GEN"; then
	echo "REPGEN_FAIL: untagged field leaked into the descriptor"
	exit 1
fi
echo "  ok  descriptor generated (fields, multi-name expansion, flags, POD asserts)"

# @(gd_command) artifacts on a TICKING class: the verbs route through the sim
# lane (tick-scheduled — kit/sim command.odin), not the knet command loop.
# Exec thunks decode-check-call with the authority-gated `_then` inside;
# wrappers take the lane and schedule via lane_command; the knet set stays
# desc-only (the two replay mechanisms never share a baseline).
for needle in \
	'_pawn_simcmd_hit :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool' \
	'_a0 := knet.read_i32(&r)' \
	'if r.err {return false}' \
	'{name = "mark", id = PAWN_CMD_MARK, exec = _pawn_simcmd_mark}' \
	'pawn_command_set := knet.Command_Set{entity_desc = &pawn_net_desc' \
	'pawn_hit_cmd :: proc(b: ^kboot.Boot, self: ^Pawn, amount: i32) -> knet.Command_Outcome' \
	'pawn_mark_cmd :: proc(b: ^kboot.Boot, self: ^Pawn, label: string, who: knet.Player_Id) -> knet.Command_Outcome' \
	'_ok := pawn_salute(self, by, _a0)' \
	'pawn_salute_cmd :: proc(b: ^kboot.Boot, self: ^Pawn, style: u8) -> knet.Command_Outcome' \
	'knet.write_player_id(&_w, who)' \
	'if ksim.lane_command(b.lane, self.net_id, PAWN_CMD_HIT, knet.writer_bytes(&_w)) {return .Predicted}' \
	'_ok, _p0 := pawn_loot(self, _a0)' \
	'if _ok && ksim.lane_is_authority(lane) {' \
	'pawn_loot_then(self, by, _a0, _p0)' \
	'if _ok {pawn_hit_apply(self, _a0)}' \
	'_pawn_simcmd_hit_apply :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane)' \
	'{name = "hit", id = PAWN_CMD_HIT, exec = _pawn_simcmd_hit, apply = _pawn_simcmd_hit_apply}' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing sim-command artifact: $needle"
		exit 1
	fi
done
# ...and the knet loop's artifacts must NOT appear beside them: one arbiter.
for stale in '_pawn_cmd_hit' 'invoke = ' 'ctx.is_authority' 'commands = _pawn_commands'; do
	if grep -qF "$stale" "$GEN"; then
		echo "REPGEN_FAIL: a ticking class still emits knet command artifact: $stale"
		exit 1
	fi
done
# Commands are NOT Godot methods: they must not leak into the method tables.
if grep -qF '_pawn_m_hit' "$GEN"; then
	echo "REPGEN_FAIL: a @(gd_command) proc leaked into the method trampolines"
	exit 1
fi
echo "  ok  sim-command thunks, table, lane wrappers generated; knet loop skipped"

# A coop @(gd_command) on a NON-ticking class (chest.odin): its wrapper returns a
# knet.Command_Outcome — .Applied (host accept) / .Predicted (client in-flight) /
# .Rejected (predicate said no) — the SAME meaning on every peer, replacing the
# old role-ambiguous bool. (Pawn/Turret tick, so theirs are sim-scheduled bools.)
CGEN="$GOOD/chest.gen.odin"
[ -f "$CGEN" ] || { echo "REPGEN_FAIL: scriptgen produced no chest.gen.odin"; exit 1; }
for needle in \
	'chest_open_cmd :: proc(b: ^kboot.Boot, self: ^Chest, amount: i32) -> knet.Command_Outcome' \
	'ctx := &b.ses.ctx' \
	'if _ok {return .Applied}' \
	'if knet.command_issue(ctx, self, &chest_command_set, CHEST_CMD_OPEN) {return .Predicted}' \
	'return .Rejected' \
	'chest_seal_cmd :: proc(b: ^kboot.Boot, self: ^Chest) -> knet.Command_Outcome' \
	'_ = knet.command_issue(ctx, self, &chest_command_set, CHEST_CMD_SEAL)' \
	'CHEST_CMD_OPEN :: knet.Cmd_Id(0x' \
	'id = CHEST_CMD_OPEN, predict = true' \
	'_ok := chest_claim(self, env.by)' \
	'chest_claim_then(self, env.by)' \
	'chest_claim_cmd :: proc(b: ^kboot.Boot, self: ^Chest) -> knet.Command_Outcome' \
	'_ok := chest_claim(self, ctx.me)' \
	'chest_claim_then(self, ctx.me)' \
; do
	if ! grep -qF "$needle" "$CGEN"; then
		echo "REPGEN_FAIL: coop command wrapper missing Command_Outcome artifact: $needle"
		exit 1
	fi
done
echo "  ok  coop @(gd_command) wrapper returns knet.Command_Outcome; issuer param framework-filled (env.by in the thunk, ctx.me on the host's own issue, absent from the wrapper signature)"

# @(gd_tick) artifacts: the ksim import, the input POD assert, the rawptr
# thunk (nil input coasts; the author call stays typed), and the Sim_Set the
# game hands to lane_track_set. Never a Godot method.
for needle in \
	'import ksim "godot:kit/sim"' \
	'intrinsics.type_is_nearly_simple_compare(Pawn_Input)' \
	'_pawn_tick_step :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id)' \
	'if input == nil {return}' \
	'_p0 := pawn_tick(self, (cast(^Pawn_Input)input)^, lane)' \
	'if ksim.lane_is_authority(lane) {' \
	'pawn_tick_then(self, owner, _p0)' \
	'if owner == ksim.lane_me(lane) && !lane.resimming {' \
	'pawn_tick_fx(self, _p0)' \
	'pace_tick(&self.pace)' \
	'import play_sim "godot:play/sim"' \
	'play_sim.cool_tick(&self.chill)' \
	'pawn_sim_set := ksim.Sim_Set{entity_desc = &pawn_net_desc, tick = _pawn_tick_step, input_size = size_of(Pawn_Input), commands = _pawn_sim_cmds[:]}' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing tick artifact: $needle"
		exit 1
	fi
done
if grep -qF '_pawn_m_tick' "$GEN"; then
	echo "REPGEN_FAIL: the @(gd_tick) proc leaked into the method trampolines"
	exit 1
fi
# `gd:"manual"` (the `warm` block): the two-state hybrid. Its predict field
# STILL flattens into the descriptor (asserted above), but its tick is NOT
# auto-hoisted — the wielder drives it. So the auto `chill` call is present
# (asserted above) while the manual `warm` call must be ABSENT.
if grep -qF 'play_sim.cool_tick(&self.warm)' "$GEN"; then
	echo "REPGEN_FAIL: a gd:\"manual\" block's tick was auto-hoisted (should be wielder-driven)"
	exit 1
fi
echo "  ok  tick thunk + sim set generated (POD-asserted input, coast-on-nil, imported-shelf block hoisted; gd:\"manual\" flattens but does NOT hoist)"

# The EVERY-SCREEN _fx (scout.odin): `mine: bool` after `self` flips the fx
# from owner-live-only to every screen — the thunk gates on the bool facts
# (the event trigger), the authority broadcasts the tuple (lane_fact), the
# live pass fires inline with _mine computed (owner=true, authority's view of
# everyone else=false), and the decode thunk + `fx =` wiring hand watchers
# the same half at watch-clock time. Pawn's old-form fx (asserted above) must
# keep its owner-live shape untouched.
SCOUT_GEN="$GOOD/scout.gen.odin"
[ -f "$SCOUT_GEN" ] || { echo "REPGEN_FAIL: scriptgen produced no scout.gen.odin"; exit 1; }
for needle in \
	'_p0, _p1 := scout_tick(self)' \
	'if _p0 { // an event tick: the facts present' \
	'if ksim.lane_is_authority(lane) {' \
	'knet.write_bool(&_fw, _p0)' \
	'knet.write_f32(&_fw, _p1)' \
	'ksim.lane_fact(lane, entity, knet.writer_bytes(&_fw))' \
	'if !lane.resimming {' \
	'_mine := owner == ksim.lane_me(lane)' \
	'if _mine || ksim.lane_is_authority(lane) {' \
	'scout_tick_fx(self, _mine, _p0, _p1)' \
	'_scout_fx :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8)' \
	'_p0 := knet.read_bool(&r)' \
	'_p1 := knet.read_f32(&r)' \
	'if r.err {return}' \
	'scout_tick_fx(self, mine, _p0, _p1)' \
	'scout_sim_set := ksim.Sim_Set{entity_desc = &scout_net_desc, tick = _scout_tick_step, input_size = 0, fx = _scout_fx}' \
; do
	if ! grep -qF "$needle" "$SCOUT_GEN"; then
		echo "REPGEN_FAIL: generated file is missing every-screen fx artifact: $needle"
		exit 1
	fi
done
# The old owner-live gate must NOT wrap the mine-form call…
if grep -qF 'if owner == ksim.lane_me(lane) && !lane.resimming {' "$SCOUT_GEN"; then
	echo "REPGEN_FAIL: the mine-form fx still emits the owner-live-only gate"
	exit 1
fi
# …and the old-form fx (pawn) must NOT grow any fact machinery.
for stale in 'lane_fact' '_pawn_fx' 'fx = _pawn_fx'; do
	if grep -qF "$stale" "$GEN"; then
		echo "REPGEN_FAIL: the old-form fx sprouted every-screen machinery: $stale"
		exit 1
	fi
done
echo "  ok  every-screen _fx: event gate, authority broadcast, inline _mine call, decode thunk, Sim_Set fx wiring (old form untouched)"

# The `<field>_edge` half (pawn_hp_edge): the thunk casts and derefs old, the
# Edge_Desc table indexes the descriptor FIELD, and the command set carries it
# — the session's per-frame pass does the rest.
for needle in \
	'_pawn_edge_hp :: proc(entity: rawptr, game: rawptr, old: rawptr)' \
	'pawn_hp_edge(self, (cast(^type_of(self.hp))old)^, self.hp)' \
	'{field = 0, fire = _pawn_edge_hp}' \
	'edges = _pawn_edges[:]' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing edge artifact: $needle"
		exit 1
	fi
done
echo "  ok  edge half generated (thunk, field-indexed Edge_Desc, command-set wiring)"

# gd:"backup" — the host-local migration/save codec. All three kinds (POD scalar,
# map[POD]POD, [dynamic]POD) plus a NESTED field (pace.beat, proving the walk
# rides embeds like replicate) ride ONE version-hashed write/read pair, each POD
# #asserted. The declared replacement for hand-matched write_u8/read_u8 blob
# lists that silently corrupt a takeover when they drift (session.md's split).
for needle in \
	'PAWN_BACKUP_VERSION :: u32(0x' \
	'pawn_backup_write :: proc(self: ^Pawn, w: ^knet.Writer)' \
	'knet.write_u32(w, PAWN_BACKUP_VERSION)' \
	'knet.write_pod(w, self.pace.beat)' \
	'knet.write_pod(w, self.save_seed)' \
	'for k, v in self.save_seen {knet.write_pod(w, k); knet.write_pod(w, v)}' \
	'for e in self.save_log {knet.write_pod(w, e)}' \
	'pawn_backup_read :: proc(self: ^Pawn, r: ^knet.Reader) -> bool' \
	'if knet.read_u32(r) != PAWN_BACKUP_VERSION {return false}' \
	'self.save_seed = knet.read_pod(r, type_of(self.save_seed))' \
	'k := knet.read_pod(r, knet.Net_Id)' \
	'append(&self.save_log, e)' \
	'return !r.err' \
	'gd:\"backup\" fields must be POD' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing backup-codec artifact: $needle"
		exit 1
	fi
done
echo "  ok  gd:\"backup\" codec generated (POD scalar / map / dynamic + nested, version-hashed write+read)"

# Entity-table artifacts (board.odin's `entity=Pawn:7` scene tag): the TYPE
# const, the kboot.Entity_Kind row reading the scene THROUGH the field
# offset, and the typed dispatch for the name-paired census hooks.
BGEN="$GOOD/board.gen.odin"
[ -f "$BGEN" ] || { echo "REPGEN_FAIL: scriptgen produced no board.gen.odin"; exit 1; }
for needle in \
	'PAWN_TYPE :: ksess.Entity_Type(7)' \
	'board_entity_kinds := [?]kboot.Entity_Kind' \
	'scene_offset = offset_of(Board, pawn_scene)' \
	'spawned = _board_ent_spawned_pawn' \
	'freed = _board_ent_freed_pawn' \
	'sim_set = &pawn_sim_set' \
	'return rt.script_of(node, Pawn)' \
	'pawn_of :: proc(b: ^kboot.Boot, id: knet.Net_Id) -> (^Pawn, bool)' \
	'pawn_owned_by :: proc(b: ^kboot.Boot, owner: knet.Player_Id) -> (^Pawn, bool)' \
	'my_pawn :: proc(b: ^kboot.Boot) -> (^Pawn, bool)' \
	'pawn_ids :: proc(b: ^kboot.Boot, allocator := context.temp_allocator) -> []knet.Net_Id' \
	'pawn_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID) -> (^Pawn, knet.Net_Id)' \
	'kboot.boot_fire_spawn(b, PAWN_TYPE, owner)' \
	'chest_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID) -> (^Chest, knet.Net_Id)' \
	'ksess.session_spawn_make(b.ses, CHEST_TYPE, owner)' \
; do
	if ! grep -qF "$needle" "$BGEN"; then
		echo "REPGEN_FAIL: generated file is missing entity artifact: $needle"
		exit 1
	fi
done
echo "  ok  entity table generated (TYPE const, kinds row, typed census hooks)"

# @(gd_sample)/@(gd_step) artifacts (board.odin's lane game half): a rawptr
# thunk PER input class holding the typed cast, and `board_lane_init` carrying
# the primary class's size + sample and registering the extra class (the
# turret) with lane_add_input_class — the wiring nobody writes. Types sort
# Pawn_Input < Turret_Input, so the pawn is the primary class 0.
for needle in \
	'_board_lane_sample_0 :: proc(user: rawptr, tick: u64, dst: rawptr)' \
	'board_sample(cast(^Board)user, tick, cast(^Pawn_Input)dst)' \
	'_board_lane_sample_1 :: proc(user: rawptr, tick: u64, dst: rawptr)' \
	'board_sample_turret(cast(^Board)user, tick, cast(^Turret_Input)dst)' \
	'_board_lane_step :: proc(user: rawptr, tick: u64)' \
	'board_contact(cast(^Board)user, tick)' \
	'_board_lane_step_auth :: proc(user: rawptr, tick: u64)' \
	'board_step(cast(^Board)user, tick)' \
	'board_lane_init :: proc(self: ^Board, l: ^ksim.Lane, ses: ^ksess.Session, tag := ksim.SIM_TAG, cfg := ksim.Lane_Config{})' \
	'ksim.lane_init(l, ses, size_of(Pawn_Input), tag, cfg)' \
	'ksim.lane_set_sim(l, self, _board_lane_sample_0, _board_lane_step, _board_lane_step_auth)' \
	'ksim.lane_add_input_class(l, 1, size_of(Turret_Input), _board_lane_sample_1)' \
; do
	if ! grep -qF "$needle" "$BGEN"; then
		echo "REPGEN_FAIL: generated file is missing lane-wiring artifact: $needle"
		exit 1
	fi
done
echo "  ok  lane wiring generated (per-class typed samples, primary + lane_add_input_class, board_lane_init)"

# @(gd_fact) artifacts (the declared world-pass facts): a stable FNV id const
# per event, the announce DOOR under the bare event name holding every gate
# (authority broadcast via lane_fact with the kind; anchored = owner-derived
# `mine` on the live pass; anchorless = the authority's live pass alone), the
# decode thunk per event, the package fact table, and its install inside
# board_lane_init. The doors compile with the package (the odin check above).
for needle in \
	'FACT_PAWN_BUMPED :: u16(0x' \
	'FACT_BOARD_HORN :: u16(0x' \
	'pawn_bumped :: proc(l: ^ksim.Lane, p: ^Pawn, force: f32)' \
	'board_horn :: proc(l: ^ksim.Lane, side: u8)' \
	'ksim.lane_fact(l, p, knet.writer_bytes(&_fw), FACT_PAWN_BUMPED)' \
	'ksim.lane_fact(l, nil, knet.writer_bytes(&_fw), FACT_BOARD_HORN)' \
	'_owner := ksim.lane_owner_of(l, p)' \
	'_mine := _owner != knet.PLAYER_ID_INVALID && _owner == ksim.lane_me(l)' \
	'if ksim.lane_is_authority(l) && ksim.lane_live(l) {' \
	'_board_fact_pawn_bumped :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8)' \
	'pawn_bumped_fx(cast(^Board)ksim.lane_game(lane), cast(^Pawn)entity, mine, _a0)' \
	'_board_fact_table := [?]ksim.Fact_Desc{' \
	'ksim.lane_set_facts(l, _board_fact_table[:])' \
; do
	if ! grep -qF "$needle" "$BGEN"; then
		echo "REPGEN_FAIL: generated file is missing fact artifact: $needle"
		exit 1
	fi
done
# The tick-fact skip law, inverted for provenance: both authority-only `_then`
# wraps mark in_auth so a door announced there INCLUDES the anchor's owner.
if ! grep -qF 'lane.in_auth = true' "$GEN"; then
	echo "REPGEN_FAIL: the tick _then wrap is missing the in_auth provenance mark"
	exit 1
fi
echo "  ok  fact doors generated (FNV ids, gates, decode thunks, table installed in lane_init)"

# ---- @(gd_fact) contract violations are scriptgen-time errors ----
# Five misuses in one lane-carrying package, plus the no-lane package: each
# must surface as a teaching error, never a half that silently can't fire.
FBAD="$TMP/factbad"
mkdir -p "$FBAD"
cat > "$FBAD/fgame.odin" <<'EOF'
//gd:extends Node
//gd:class FGame
package repgen_factbad

import gd "godot:godot"

FGame :: struct {
	owner: gd.Node,
}

F_In :: struct {
	ax: i8,
}

@(gd_sample)
fgame_sample :: proc(self: ^FGame, tick: u64, input: ^F_In) {
}

@(gd_fact)
f_bad_name :: proc(g: ^FGame, mine: bool, v: f32) { // not `_fx`-named
}

@(gd_fact)
f_nomine_fx :: proc(g: ^FGame, v: f32) { // the mine-form marker missing
}

@(gd_fact)
f_struct_fx :: proc(g: ^FGame, mine: bool, v: F_In) { // not a wire primitive
}

@(gd_fact)
f_verdict_fx :: proc(g: ^FGame, mine: bool) -> bool { // a fact decides nothing
	return false
}

@(gd_fact)
f_taken_fx :: proc(g: ^FGame, mine: bool) { // the door's name is claimed below
}

f_taken :: proc() {
}
EOF
cat > "$FBAD/fpawn.odin" <<'EOF'
//gd:extends Node2D
//gd:class FPawn
package repgen_factbad

import gd "godot:godot"
import knet "godot:kit/net"

FPawn :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	x:      f32 `gd:"predict"`,
}

@(gd_tick)
fpawn_tick :: proc(self: ^FPawn, input: F_In) {
}
EOF
set +e
FBAD_OUT="$(run_scriptgen "$FBAD" 2>&1)"
FBAD_RC=$?
set -e
if [ "$FBAD_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: the @(gd_fact) misuse package was accepted by scriptgen"
	exit 1
fi
for want in \
	"a declared fact IS a presentation half" \
	"the every-screen law" \
	"not a wire primitive" \
	"a fact presents, it decides nothing" \
	"GENERATED announce door's name" \
; do
	if ! echo "$FBAD_OUT" | grep -qF "$want"; then
		echo "REPGEN_FAIL: fact misuse error missing: $want"
		echo "$FBAD_OUT" | tail -20
		exit 1
	fi
done

FNOLANE="$TMP/factnolane"
mkdir -p "$FNOLANE"
cat > "$FNOLANE/ngame.odin" <<'EOF'
//gd:extends Node
//gd:class NGame
package repgen_factnolane

import gd "godot:godot"

NGame :: struct {
	owner: gd.Node,
}

@(gd_fact)
n_horn_fx :: proc(g: ^NGame, mine: bool) {
}
EOF
set +e
FNOLANE_OUT="$(run_scriptgen "$FNOLANE" 2>&1)"
FNOLANE_RC=$?
set -e
if [ "$FNOLANE_RC" -eq 0 ] || ! echo "$FNOLANE_OUT" | grep -qF "this package has no lane"; then
	echo "REPGEN_FAIL: a @(gd_fact) in a laneless package must error (facts ride the watch clock)"
	echo "$FNOLANE_OUT" | tail -10
	exit 1
fi
echo "  ok  fact misuses rejected: bad name, no mine, non-wire arg, results, taken door, laneless package"

# ---- the silent paths, closed: each of these compiled and silently never
# ---- worked before — now each is a build error naming the fix ----
SP="$TMP/silent"
mkdir -p "$SP"
cat > "$SP/silent.odin" <<'EOF'
//gd:extends Node
//gd:class Silent
package repgen_silent

import gd "godot:godot"
import ksess "godot:kit/session"

Row :: struct {
	look: u8,
}

Embedded_Misprofile :: struct {
	ses: ksess.Session `gd:"profile=Row"`, // NESTED profile= — silently never installed
}

Silent :: struct {
	owner:      gd.Node,
	using gone: Ghost_Bundle, // a `using` embed that resolves to nothing
	sub:        Embedded_Misprofile,
}

Helper :: struct {
	n: int,
}

// A method on a receiver that is neither a script class nor an embedded
// block — it used to register nowhere, silently.
@(gd_method)
helper_poke :: proc(h: ^Helper) {
}

// gd_connect without gd_method — it used to compile and never connect.
@(gd_connect = "pressed")
silent_click :: proc(self: ^Silent) {
}
EOF
set +e
SP_OUT="$(run_scriptgen "$SP" 2>&1)"
SP_RC=$?
set -e
if [ "$SP_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: the silent-path package was accepted by scriptgen"
	exit 1
fi
for want in \
	"silently never connect" \
	"registers NOWHERE" \
	"silently never installs" \
	"doesn't resolve to a struct in this package" \
; do
	if ! echo "$SP_OUT" | grep -qF "$want"; then
		echo "REPGEN_FAIL: silent-path error missing: $want"
		echo "$SP_OUT" | tail -20
		exit 1
	fi
done

# The unresolved-embed trap's import half: a struct behind a RELATIVE import
# (scriptgen can't see inside it) must refuse, not silently drop its tags.
SB="$TMP/silentgear"
mkdir -p "$SB/gear"
cat > "$SB/gear/gear.odin" <<'EOF'
package silent_gear

Gear :: struct {
	ammo: i32 `gd:"replicate"`,
}
EOF
cat > "$SB/robot.odin" <<'EOF'
//gd:extends Node
//gd:class SilentRobot
package repgen_silentgear

import gd "godot:godot"
import sg "gear"

SilentRobot :: struct {
	owner: gd.Node,
	gun:   sg.Gear, // the gun that never replicated — now a loud refusal
}
EOF
set +e
SB_OUT="$(run_scriptgen "$SB" 2>&1)"
SB_RC=$?
set -e
if [ "$SB_RC" -eq 0 ] || ! echo "$SB_OUT" | grep -qF "cannot see inside"; then
	echo "REPGEN_FAIL: a relative-import embed must refuse loudly (the gun that never replicated)"
	echo "$SB_OUT" | tail -10
	exit 1
fi
echo "  ok  silent paths closed: bare gd_connect, orphan receiver, nested profile=, unresolved using, relative-import embed"

# The second entity's Sim_Set carries its wire class (input_class = 1); the
# primary pawn's omits it (class 0). Turret's own gen file holds the set.
TGEN="$GOOD/turret.gen.odin"
[ -f "$TGEN" ] || { echo "REPGEN_FAIL: scriptgen produced no turret.gen.odin"; exit 1; }
if ! grep -qF 'turret_sim_set := ksim.Sim_Set{entity_desc = &turret_net_desc, tick = _turret_tick_step, input_size = size_of(Turret_Input), input_class = 1}' "$TGEN"; then
	echo "REPGEN_FAIL: turret Sim_Set missing its input_class = 1"
	exit 1
fi
if grep -qF 'input_class' "$GEN"; then
	echo "REPGEN_FAIL: the primary pawn Sim_Set should omit input_class (class 0)"
	exit 1
fi
echo "  ok  second input class routed (turret input_class = 1, primary pawn omits it)"

# The standard transport forwards (board.odin's kboot.Boot field): generated
# bodies wired through the boot's own pointers — and hand-written wins, name
# by name (board_on_net_down suppresses only its own).
for needle in \
	'_board_std_on_packet :: proc(self: ^Board, id: gd.Int, packet: gd.Packed_Byte_Array)' \
	'netgd.wire_receive(&self.boot.wire, id, packet)' \
	'_board_std_on_peer_left :: proc(self: ^Board, id: gd.Int)' \
	'ksess.session_peer_disconnected(self.boot.ses, ksess.Peer_Id(id))' \
	'_board_std_on_net_up :: proc(self: ^Board)' \
	'ksess.session_client_join(self.boot.ses)' \
; do
	if ! grep -qF "$needle" "$BGEN"; then
		echo "REPGEN_FAIL: generated file is missing transport-forward artifact: $needle"
		exit 1
	fi
done
if grep -qF '_board_std_on_net_down' "$BGEN"; then
	echo "REPGEN_FAIL: hand-written on_net_down did not suppress the generated forward"
	exit 1
fi
echo "  ok  standard transport forwards generated; hand-written wins name by name"

"$ODIN" check "$GOOD" -collection:godot="$ROOT" -no-entry-point \
	${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"}
echo "  ok  generated package compiles (odin check)"

# ---- the STALENESS GUARD: a source edited after scriptgen fails the compile ----
# odin_godot_guard.gen.odin carries one compile-time #load_hash assert per
# authored source; a bare `odin build` against stale *.gen.odin must fail
# NAMING the drifted file, and a scriptgen re-run must clear it.
GUARD="$GOOD/odin_godot_guard.gen.odin"
[ -f "$GUARD" ] || { echo "REPGEN_FAIL: scriptgen produced no staleness guard"; exit 1; }
for needle in \
	'#load_hash("pawn.odin", "crc32")' \
	'#load_hash("chest.odin", "crc32")' \
	'#load_hash("scout.odin", "crc32")' \
	'NET_FINGERPRINT :: u64(0x' \
; do
	if ! grep -qF "$needle" "$GUARD"; then
		echo "REPGEN_FAIL: staleness guard is missing: $needle"
		exit 1
	fi
done
FP_BEFORE=$(grep 'NET_FINGERPRINT ::' "$GUARD")
if grep -qF '.gen.odin"' "$GUARD"; then
	echo "REPGEN_FAIL: the staleness guard hashes generated files (circular)"
	exit 1
fi
printf '\n// drifted after generation\n' >> "$GOOD/pawn.odin"
set +e
STALE_OUT="$("$ODIN" check "$GOOD" -collection:godot="$ROOT" -no-entry-point \
	${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} 2>&1)"
STALE_RC=$?
set -e
if [ "$STALE_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a stale gen (edited pawn.odin, no scriptgen re-run) compiled clean"
	exit 1
fi
if ! echo "$STALE_OUT" | grep -q "pawn.odin changed after scriptgen ran"; then
	echo "REPGEN_FAIL: the stale-build failure doesn't name the drifted file:"
	echo "$STALE_OUT" | tail -3
	exit 1
fi
run_scriptgen "$GOOD"
"$ODIN" check "$GOOD" -collection:godot="$ROOT" -no-entry-point \
	${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"}
echo "  ok  staleness guard: drifted source fails the compile by name; scriptgen re-run clears it"

# ---- NET_FINGERPRINT: the wire contract, hashed — comment-blind, type-aware ----
# The drift above was a COMMENT: the wire didn't change, so the fingerprint
# must not move (a comment edit refusing joins would be over-refusal). A
# replicated field's TYPE changing (i32 -> i64: a different wire) must move
# it — that under-refusal is the silent-garbage disaster the check prevents.
FP_AFTER=$(grep 'NET_FINGERPRINT ::' "$GUARD")
if [ "$FP_BEFORE" != "$FP_AFTER" ]; then
	echo "REPGEN_FAIL: a comment edit moved the fingerprint (over-refusal): $FP_BEFORE vs $FP_AFTER"
	exit 1
fi
FPW="$TMP/fpw"
mkdir -p "$FPW"
cp "$ROOT/tests/repgen/fixture/"*.odin "$FPW/"
# state, not hp: hp carries an _edge half whose (old, new) types would then
# mismatch — a different (also-correct) failure that would mask this one.
sed -i.bak 's/state:  u8 `gd:"replicate"`,/state:  u16 `gd:"replicate"`,/' "$FPW/pawn.odin" && rm -f "$FPW/pawn.odin.bak"
run_scriptgen "$FPW"
FP_TYPED=$(grep 'NET_FINGERPRINT ::' "$FPW/odin_godot_guard.gen.odin")
if [ "$FP_BEFORE" = "$FP_TYPED" ]; then
	echo "REPGEN_FAIL: a replicated field's type change did NOT move the fingerprint"
	exit 1
fi
FPI="$TMP/fpi"
mkdir -p "$FPI"
cp "$ROOT/tests/repgen/fixture/"*.odin "$FPI/"
sed -i.bak 's/buttons: u8,/buttons: u16,/' "$FPI/pawn.odin" && rm -f "$FPI/pawn.odin.bak"
run_scriptgen "$FPI"
FP_INPUT=$(grep 'NET_FINGERPRINT ::' "$FPI/odin_godot_guard.gen.odin")
if [ "$FP_BEFORE" = "$FP_INPUT" ]; then
	echo "REPGEN_FAIL: an input-struct field change did NOT move the fingerprint (the blob memcpys — its layout IS the wire)"
	exit 1
fi
# Declaring the ISSUER param must NOT move it: `by` is framework-filled, never
# wire bytes — a peer that added `by` to a predicate still interoperates.
FPB="$TMP/fpb"
mkdir -p "$FPB"
cp "$ROOT/tests/repgen/fixture/"*.odin "$FPB/"
sed -i.bak 's/chest_open :: proc(self: ^Chest, amount: i32)/chest_open :: proc(self: ^Chest, by: knet.Player_Id, amount: i32)/' "$FPB/chest.odin" && rm -f "$FPB/chest.odin.bak"
run_scriptgen "$FPB"
if ! grep -qF 'return chest_open(self, env.by, _a0)' "$FPB/chest.gen.odin"; then
	echo "REPGEN_FAIL: the added issuer param didn't reach the thunk (sed no-op, or the splice order broke)"
	exit 1
fi
FP_BY=$(grep 'NET_FINGERPRINT ::' "$FPB/odin_godot_guard.gen.odin")
if [ "$FP_BEFORE" != "$FP_BY" ]; then
	echo "REPGEN_FAIL: declaring the issuer param moved the fingerprint (by never rides the wire): $FP_BEFORE vs $FP_BY"
	exit 1
fi
echo "  ok  NET_FINGERPRINT: stable across comments and issuer-param declarations, moves on replicated-type and input-struct changes"

# ---- (3a): engine handle/heap types are a SCRIPTGEN-time error ----
ENG="$TMP/eng"
mkdir -p "$ENG"
cat > "$ENG/named.odin" <<'EOF'
//gd:extends Node
//gd:class Named
package repgen_eng

import gd "godot:godot"

Named :: struct {
	owner: gd.Node,
	label: gd.String `gd:"replicate"`, // heap-backed engine type: rejected by name
}

named_ready :: proc(self: ^Named) {}
EOF
set +e
ENG_OUT="$(run_scriptgen "$ENG" 2>&1)"
ENG_RC=$?
set -e
if [ "$ENG_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a replicated gd.String was accepted by scriptgen"
	exit 1
fi
if ! echo "$ENG_OUT" | grep -q "cannot be a replicated field"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the engine-type rejection:"
	echo "$ENG_OUT" | tail -3
	exit 1
fi
echo "  ok  engine handle/heap type rejected at scriptgen time (gd.String)"

# ---- (3b): the COLLECTIONS stance — variable-length replicate fields are a
# scriptgen-time error that TEACHES the three-way fork (bounded -> fixed
# array; rare-change -> entity blob; live elements -> entities).
COLL="$TMP/collections"
mkdir -p "$COLL"
cat > "$COLL/hoard.odin" <<'EOF'
//gd:extends Node
//gd:class Hoard
package repgen_collections

import gd "godot:godot"
import knet "godot:kit/net"

Hoard :: struct {
	owner: gd.Node,
	loot:  [dynamic]u16 `gd:"replicate"`, // the [dynamic] ask the stance answers
	view:  []u8 `gd:"replicate"`, // a slice is the same answer
	tally: map[knet.Net_Id]u16 `gd:"replicate"`, // and a map
}

hoard_ready :: proc(self: ^Hoard) {}
EOF
set +e
COLL_OUT="$(run_scriptgen "$COLL" 2>&1)"
COLL_RC=$?
set -e
if [ "$COLL_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a variable-length replicate field was accepted by scriptgen"
	exit 1
fi
for want in "Hoard.loot" "Hoard.view" "Hoard.tally" "the registry is the diffed collection"; do
	if ! echo "$COLL_OUT" | grep -qF "$want"; then
		echo "REPGEN_FAIL: the collections-stance error is missing: $want"
		echo "$COLL_OUT" | tail -4
		exit 1
	fi
done
echo "  ok  collections stance held at scriptgen time: [dynamic]/slice/map rejected with the three-way fork spelled out"

# ---- (3b2): a DEEP non-POD type scriptgen can't judge fails the CONSUMER
# compile — the syntactic gate above can't see inside a named struct, so the
# generated #assert stays the backstop, naming the field.
BAD="$TMP/bad"
mkdir -p "$BAD"
cat > "$BAD/chatty.odin" <<'EOF'
//gd:extends Node
//gd:class Chatty
package repgen_bad

import gd "godot:godot"

Notes :: struct {
	text: string, // heap-backed, hidden behind a named struct
}

Chatty :: struct {
	owner: gd.Node,
	data:  Notes `gd:"replicate"`, // scriptgen sees "Notes"; only the #assert can judge it
}

chatty_ready :: proc(self: ^Chatty) {}
EOF
run_scriptgen "$BAD" # scriptgen succeeds — the deep type check is the consumer compiler's
set +e
CHECK_OUT="$("$ODIN" check "$BAD" -collection:godot="$ROOT" -no-entry-point 2>&1)"
CHECK_RC=$?
set -e
if [ "$CHECK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a replicated string-bearing struct COMPILED — the POD assert is not enforcing"
	exit 1
fi
if ! echo "$CHECK_OUT" | grep -q "Chatty.data"; then
	echo "REPGEN_FAIL: the POD failure does not name the offending field (Chatty.data):"
	echo "$CHECK_OUT" | tail -5
	exit 1
fi
echo "  ok  deep non-POD replicate field fails the build, naming Chatty.data"

# ---- (4): unknown option is a scriptgen-time error ----
OPT="$TMP/opt"
mkdir -p "$OPT"
cat > "$OPT/typo.odin" <<'EOF'
//gd:extends Node
//gd:class Typo
package repgen_opt

import gd "godot:godot"

Typo :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"replicate,interpolate"`, // not an option (it's `interp`)
}

typo_ready :: proc(self: ^Typo) {}
EOF
set +e
SGEN_OUT="$(run_scriptgen "$OPT" 2>&1)"
SGEN_RC=$?
set -e
if [ "$SGEN_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: unknown replicate option was accepted by scriptgen"
	exit 1
fi
if ! echo "$SGEN_OUT" | grep -q 'unknown `replicate` option'; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the unknown option:"
	echo "$SGEN_OUT" | tail -3
	exit 1
fi
echo "  ok  unknown replicate option rejected at scriptgen time"

# ---- (4a): two LANE tokens on one field — two writers, one field, an error ----
# This used to be `gd:"replicate,owner,predict"` caught by a pairwise
# owner-xor-predict rule at the bottom of the parser. With the lane as the FIRST
# token the rule is gone: a second lane token is diagnosed AS a lane, at the
# point it appears, and the delta-lane-with-options spellings that needed the
# matrix are simply unspellable.
LANES="$TMP/lanes"
mkdir -p "$LANES"
cat > "$LANES/torn.odin" <<'EOF'
//gd:extends Node
//gd:class Torn
package repgen_lanes

import gd "godot:godot"

Torn :: struct {
	owner: gd.Node,
	x:     f32 `gd:"owner,predict"`, // two writers, one field: refused
}

torn_ready :: proc(self: ^Torn) {}
EOF
set +e
LANES_OUT="$(run_scriptgen "$LANES" 2>&1)"
LANES_RC=$?
set -e
if [ "$LANES_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: two lane tokens on one field was accepted by scriptgen"
	exit 1
fi
if ! echo "$LANES_OUT" | grep -q "is a LANE, not an option"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the lane conflict:"
	echo "$LANES_OUT" | tail -3
	exit 1
fi
echo "  ok  two lane tokens on one field rejected at scriptgen time"

# ---- (4a0): the OLD lane-as-option grammar is refused, naming the rewrite ----
# Three games build against a vendored copy of this addon; the migration error
# is the whole of their upgrade experience, so it is asserted here as a wire
# contract would be.
OLDL="$TMP/oldlane"
mkdir -p "$OLDL"
cat > "$OLDL/legacy.odin" <<'EOF'
//gd:extends Node
//gd:class Legacy
package repgen_oldlane

import gd "godot:godot"

Legacy :: struct {
	owner: gd.Node,
	x, y:  f32 `gd:"replicate,interp,owner,wire=f16"`,
}

legacy_ready :: proc(self: ^Legacy) {}
EOF
set +e
OLDL_OUT="$(run_scriptgen "$OLDL" 2>&1)"
OLDL_RC=$?
set -e
if [ "$OLDL_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: the old lane-as-option grammar was silently accepted"
	exit 1
fi
if ! echo "$OLDL_OUT" | grep -q 'write `gd:"owner,interp,wire=f16"`'; then
	echo "REPGEN_FAIL: the old-form refusal must spell the replacement tag:"
	echo "$OLDL_OUT" | tail -3
	exit 1
fi
echo "  ok  old lane-as-option form refused with its exact rewrite"

# ---- (4a1b): gd:"backup" on a non-restorable type (a slice) is refused ----
BADBK="$TMP/badbackup"
mkdir -p "$BADBK"
cat > "$BADBK/leaky.odin" <<'EOF'
//gd:extends Node
//gd:class Leaky
package repgen_badbackup

import gd "godot:godot"

Leaky :: struct {
	owner: gd.Node,
	log:   []u8 `gd:"backup"`, // a slice: no owned storage to restore into — refused
}

leaky_ready :: proc(self: ^Leaky) {}
EOF
set +e
BADBK_OUT="$(run_scriptgen "$BADBK" 2>&1)"
BADBK_RC=$?
set -e
if [ "$BADBK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: gd:\"backup\" on a slice was accepted by scriptgen"
	exit 1
fi
if ! echo "$BADBK_OUT" | grep -q "slice"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the backup slice rejection:"
	echo "$BADBK_OUT" | tail -3
	exit 1
fi
echo "  ok  gd:\"backup\" on a slice rejected at scriptgen time"

# ---- (4a1c): two verbs colliding on one wire id (FNV-1a-16) are refused ----
# "aapy" and "aaym" genuinely collide at 0xe032 — astronomically rare in real
# sets, deterministic at build time, fatal on the wire, so it's a named error.
COLL="$TMP/cmdcollide"
mkdir -p "$COLL"
cat > "$COLL/vault.odin" <<'EOF'
//gd:extends Node
//gd:class Vault
package repgen_cmdcollide

import gd "godot:godot"
import knet "godot:kit/net"

Vault :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	n:      i32 `gd:"replicate"`,
}

@(gd_command)
vault_aapy :: proc(self: ^Vault) -> bool {
	self.n += 1
	return true
}

@(gd_command)
vault_aaym :: proc(self: ^Vault) -> bool {
	self.n -= 1
	return true
}

vault_ready :: proc(self: ^Vault) {}
EOF
set +e
COLL_OUT="$(run_scriptgen "$COLL" 2>&1)"
COLL_RC=$?
set -e
if [ "$COLL_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: colliding command wire ids were accepted by scriptgen"
	exit 1
fi
if ! echo "$COLL_OUT" | grep -q "collide"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the wire-id collision:"
	echo "$COLL_OUT" | tail -3
	exit 1
fi
echo "  ok  colliding command wire ids rejected at scriptgen time"

# ---- (4a1d): a wire arg wearing the reserved issuer name `by` is refused ----
# Misplaced (not right after the receiver) or mistyped, either way it would be
# a client-claimed identity — the spoofable-`side` wart the issuer param
# deletes. A player the verb TARGETS stays legal as `who`/`target` (pawn_mark).
BYR="$TMP/byreserved"
mkdir -p "$BYR"
cat > "$BYR/spoof.odin" <<'EOF'
//gd:extends Node
//gd:class Spoof
package repgen_byr

import gd "godot:godot"
import knet "godot:kit/net"

Spoof :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	n:      i32 `gd:"replicate"`,
}

@(gd_command)
spoof_late :: proc(self: ^Spoof, amount: i32, by: knet.Player_Id) -> bool { // issuer NOT after the receiver
	self.n = amount
	return true
}

@(gd_command)
spoof_typed :: proc(self: ^Spoof, by: u64) -> bool { // reserved name, wrong type
	self.n = i32(by)
	return true
}
EOF
set +e
BYR_OUT="$(run_scriptgen "$BYR" 2>&1)"
BYR_RC=$?
set -e
if [ "$BYR_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a wire arg named \`by\` was accepted by scriptgen (client-claimed identity)"
	exit 1
fi
if ! echo "$BYR_OUT" | grep -q 'spoof_late.*reserved issuer param' || \
   ! echo "$BYR_OUT" | grep -q 'spoof_typed.*reserved issuer param'; then
	echo "REPGEN_FAIL: scriptgen didn't flag BOTH \`by\` misuses (misplaced + mistyped):"
	echo "$BYR_OUT" | tail -4
	exit 1
fi
echo "  ok  reserved issuer name: a wire arg named \`by\` rejected (misplaced and mistyped)"

# ---- (4a1e): the COOP game shell — boot-routed authority step + event halves ----
# A tickless package's @(gd_step="authority") rides the boot accumulator:
# generated `<snake>_step` holds the role gate + the same-frame edge pass (the
# crossfire lesson, encoded). Session event halves pair by name; the generated
# `<snake>_events` dispatch holds the switch AND every role gate (authority
# `_then`, the client-only gate that kills a stale post-takeover re-fire).
SHELL_FIX="$TMP/coopshell"
mkdir -p "$SHELL_FIX"
cat > "$SHELL_FIX/camp.odin" <<'EOF'
//gd:extends Node
//gd:class Camp
package repgen_coopshell

import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

Camp :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	fires: i32,
}

@(gd_step = "authority")
camp_host_tick :: proc(self: ^Camp) {
	self.fires += 1
}

camp_player_joined :: proc(self: ^Camp, id: knet.Player_Id, rejoin: bool) {
	_ = id; _ = rejoin
}

camp_player_joined_then :: proc(self: ^Camp, id: knet.Player_Id, rejoin: bool) {
	_ = id; _ = rejoin
}

camp_kicked :: proc(self: ^Camp) {
}

camp_entity_spawned :: proc(self: ^Camp, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = id; _ = type; _ = owner
}

// NEGATIVE CONTROL: shares the `_kicked` tail but is a genuinely different
// name (a query, cavecrawl's real case) — must stay silent, not reserved.
camp_was_kicked :: proc(self: ^Camp) -> bool {
	return false
}

camp_ready :: proc(self: ^Camp) {}
EOF
run_scriptgen "$SHELL_FIX"
SHELL_GEN="$SHELL_FIX/camp.gen.odin"
for needle in \
	'camp_step :: proc(self: ^Camp, ticks: int)' \
	'if self.boot.ses == nil || !self.boot.ses.is_host {return}' \
	'camp_host_tick(self)' \
	'ksess.session_run_edges(self.boot.ses)' \
	'camp_events :: proc(self: ^Camp, events: []ksess.Event)' \
	'camp_player_joined(self, e.id, e.rejoin)' \
	'camp_player_joined_then(self, e.id, e.rejoin)' \
	'if self.boot.ses != nil && !self.boot.ses.is_host {' \
	'camp_entity_spawned(self, e.id, e.type, e.owner)' \
; do
	if ! grep -qF "$needle" "$SHELL_GEN"; then
		echo "REPGEN_FAIL: coop-shell gen is missing: $needle"
		exit 1
	fi
done
# ...and it must NOT sprout lane wiring: the step is boot-routed.
for stale in 'lane_init' 'import ksim'; do
	if grep -qF "$stale" "$SHELL_GEN"; then
		echo "REPGEN_FAIL: a boot-routed authority step emitted lane wiring: $stale"
		exit 1
	fi
done
"$ODIN" check "$SHELL_FIX" -collection:godot="$ROOT" -no-entry-point \
	${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"}
echo "  ok  coop shell generated: boot-routed authority step (role gate + edge pass), event dispatch (authority _then, client-only gate); compiles"

# The contract violations, each with its fix spelled out: a lane-tick param on
# the boot-routed step, `_then` on a client-only and on a host-only event, a
# one-edit-typo'd half prefix, and a wrong-shaped half.
SHELL_BAD="$TMP/coopshellbad"
mkdir -p "$SHELL_BAD"
cat > "$SHELL_BAD/camp.odin" <<'EOF'
//gd:extends Node
//gd:class Camp
package repgen_coopshellbad

import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

Camp :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	fires: i32,
}

@(gd_step = "authority")
camp_host_tick :: proc(self: ^Camp, tick: u64) { // boot-routed: no lane tick exists
	self.fires = i32(tick)
}

camp_kicked_then :: proc(self: ^Camp) { // client-only event: no authority half
}

camp_backup_target_then :: proc(self: ^Camp, player: knet.Player_Id) { // already authority-only
	_ = player
}

cmp_player_joined :: proc(self: ^Camp, id: knet.Player_Id, rejoin: bool) { // one-edit prefix typo
	_ = id; _ = rejoin
}

camp_owner_changed :: proc(self: ^Camp, id: knet.Net_Id) { // wrong shape (missing owner, prev)
	_ = id
}

camp_ready :: proc(self: ^Camp) {}
EOF
set +e
SHELL_OUT="$(run_scriptgen "$SHELL_BAD" 2>&1)"
SHELL_RC=$?
set -e
if [ "$SHELL_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: the coop-shell contract violations were accepted by scriptgen"
	exit 1
fi
for want in \
	"no lane tick in the coop loop" \
	"never reaches the authority" \
	"already authority-only" \
	"looks like a session event half" \
	"the shape is (self: ^Camp, id: knet.Net_Id, owner: knet.Player_Id, prev: knet.Player_Id)" \
; do
	if ! echo "$SHELL_OUT" | grep -qF "$want"; then
		echo "REPGEN_FAIL: coop-shell violations missing the error: $want"
		echo "$SHELL_OUT" | tail -6
		exit 1
	fi
done
# A tickless authority step on a BOOTLESS class has nothing to gate on.
STEPB="$TMP/stepboot"
mkdir -p "$STEPB"
cat > "$STEPB/drift.odin" <<'EOF'
//gd:extends Node
//gd:class Drift
package repgen_stepboot

import gd "godot:godot"

Drift :: struct {
	owner: gd.Node,
	n:     i32,
}

@(gd_step = "authority")
drift_host_tick :: proc(self: ^Drift) {
	self.n += 1
}
EOF
set +e
STEPB_OUT="$(run_scriptgen "$STEPB" 2>&1)"
STEPB_RC=$?
set -e
if [ "$STEPB_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a bootless coop authority step was accepted by scriptgen"
	exit 1
fi
if ! echo "$STEPB_OUT" | grep -q "needs a kboot.Boot field"; then
	echo "REPGEN_FAIL: the bootless-step error doesn't name the missing field:"
	echo "$STEPB_OUT" | tail -3
	exit 1
fi
echo "  ok  coop-shell violations rejected: lane-tick param, _then on client-only/host-only events, typo'd prefix, wrong shape, bootless step"

# ---- (4a2): @(gd_tick) contract violations — mispaired _then / no predict fields ----
TIK="$TMP/tik"
mkdir -p "$TIK"
cat > "$TIK/spinny.odin" <<'EOF'
//gd:extends Node
//gd:class Spinny
package repgen_tik

import gd "godot:godot"

Spinny :: struct {
	owner: gd.Node,
	angle: f32 `gd:"predict"`,
}

@(gd_tick)
spinny_tick :: proc(self: ^Spinny) -> (spun: bool) {
	self.angle += 1
	return true
}

spinny_tick_then :: proc(self: ^Spinny, spun: bool) { // missing `by` — the driving seat
	_ = spun
}
EOF
set +e
TIK_OUT="$(run_scriptgen "$TIK" 2>&1)"
TIK_RC=$?
set -e
if [ "$TIK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a mispaired tick _then (no issuer param) was accepted by scriptgen"
	exit 1
fi
if ! echo "$TIK_OUT" | grep -q "driving seat"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the tick-then shape:"
	echo "$TIK_OUT" | tail -3
	exit 1
fi
NOP="$TMP/nop"
mkdir -p "$NOP"
cat > "$NOP/stately.odin" <<'EOF'
//gd:extends Node
//gd:class Stately
package repgen_nop

import gd "godot:godot"

Stately :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"replicate"`, // delta lane only — nothing for a tick to reconcile
}

@(gd_tick)
stately_tick :: proc(self: ^Stately) {
	self.hp += 1
}
EOF
set +e
NOP_OUT="$(run_scriptgen "$NOP" 2>&1)"
NOP_RC=$?
set -e
if [ "$NOP_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: @(gd_tick) without predict fields was accepted by scriptgen"
	exit 1
fi
if ! echo "$NOP_OUT" | grep -q 'gd:"predict" fields'; then
	echo "REPGEN_FAIL: scriptgen error doesn't point at the missing predict tag:"
	echo "$NOP_OUT" | tail -3
	exit 1
fi
echo "  ok  tick contract violations rejected: mispaired _then, no predict fields"

# ---- (4a2c): the mine-form _fx contract — facts cross the wire ----
# A non-wire fact type behind `mine` must be a scriptgen error (watchers
# decode the tuple from bytes), and a mine-form fx on a tick with no bool
# fact has no event trigger — also an error, spelled out.
FXW="$TMP/fxw"
mkdir -p "$FXW"
cat > "$FXW/blip.odin" <<'EOF'
//gd:extends Node
//gd:class Blip
package repgen_fxw

import gd "godot:godot"

Blip :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
blip_tick :: proc(self: ^Blip) -> (hit: bool, spot: [2]f32) {
	self.x += 1
	return true, {self.x, 0}
}

blip_tick_fx :: proc(self: ^Blip, mine: bool, hit: bool, spot: [2]f32) {
	_ = mine; _ = hit; _ = spot
}
EOF
set +e
FXW_OUT="$(run_scriptgen "$FXW" 2>&1)"
FXW_RC=$?
set -e
if [ "$FXW_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a mine-form fx with a non-wire fact type was accepted by scriptgen"
	exit 1
fi
if ! echo "$FXW_OUT" | grep -q "wire primitive"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the non-wire fact:"
	echo "$FXW_OUT" | tail -3
	exit 1
fi
FXB="$TMP/fxb"
mkdir -p "$FXB"
cat > "$FXB/hum.odin" <<'EOF'
//gd:extends Node
//gd:class Hum
package repgen_fxb

import gd "godot:godot"

Hum :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
hum_tick :: proc(self: ^Hum) -> (level: f32) {
	self.x += 1
	return self.x
}

hum_tick_fx :: proc(self: ^Hum, mine: bool, level: f32) {
	_ = mine; _ = level
}
EOF
set +e
FXB_OUT="$(run_scriptgen "$FXB" 2>&1)"
FXB_RC=$?
set -e
if [ "$FXB_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a mine-form fx with no bool fact was accepted by scriptgen"
	exit 1
fi
if ! echo "$FXB_OUT" | grep -q "event trigger"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the missing event trigger:"
	echo "$FXB_OUT" | tail -3
	exit 1
fi
echo "  ok  mine-form fx contract violations rejected: non-wire fact, no bool trigger"

# ---- (4a2c2): `_edge` lane contract — the delta lane only ----
# An edge on a PREDICTED field would fire on every mispredict scrub; on an
# OWNER-STREAMED field it would fire every interpolated frame. Both rejected,
# each pointing at that lane's real presentation tool.
EDG="$TMP/edg"
mkdir -p "$EDG"
cat > "$EDG/comet.odin" <<'EOF'
//gd:extends Node
//gd:class Comet
package repgen_edg

import gd "godot:godot"

Comet :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
	tail:  f32 `gd:"owner"`,
}

@(gd_tick)
comet_tick :: proc(self: ^Comet) {
	self.x += 1
}

comet_x_edge :: proc(self: ^Comet, old, new: f32) { // predicted: resims scrub it
	_ = old; _ = new
}

comet_tail_edge :: proc(self: ^Comet, old, new: f32) { // owner stream: it interpolates
	_ = old; _ = new
}
EOF
set +e
EDG_OUT="$(run_scriptgen "$EDG" 2>&1)"
EDG_RC=$?
set -e
if [ "$EDG_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: edges on predict/owner fields were accepted by scriptgen"
	exit 1
fi
if ! echo "$EDG_OUT" | grep -q "mine-form"; then
	echo "REPGEN_FAIL: the predicted-field edge error doesn't point at the mine-form fx:"
	echo "$EDG_OUT" | tail -3
	exit 1
fi
if ! echo "$EDG_OUT" | grep -q 'is on the `gd:"owner"` lane'; then
	echo "REPGEN_FAIL: the owner-field edge error doesn't explain the stream lane:"
	echo "$EDG_OUT" | tail -3
	exit 1
fi
echo "  ok  edge lane contract: predict and owner fields rejected, each pointing at its lane's tool"

# ---- (4a2d): RESERVED PAIRING SUFFIXES — an unclaimed half is an ERROR ----
# A typo'd pairing name used to be a proc that silently never fired (_fx and
# _apply didn't even warn). Now: a suffix-named proc TOUCHING a script struct
# must pair or the build fails, with the expected name spelled out. A helper
# touching no script struct keeps the old behavior (warn for _then).
UNC="$TMP/unc"
mkdir -p "$UNC"
cat > "$UNC/wisp.odin" <<'EOF'
//gd:extends Node
//gd:class Wisp
package repgen_unc

import gd "godot:godot"

Wisp :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
wisp_tick :: proc(self: ^Wisp) -> (blinked: bool) {
	self.x += 1
	return true
}

wisp_tikc_fx :: proc(self: ^Wisp, mine: bool, blinked: bool) { // typo'd tick prefix
	_ = mine; _ = blinked
}
EOF
set +e
UNC_OUT="$(run_scriptgen "$UNC" 2>&1)"
UNC_RC=$?
set -e
if [ "$UNC_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a typo'd unclaimed _fx was accepted (it would silently never fire)"
	exit 1
fi
if ! echo "$UNC_OUT" | grep -q 'wisp_tick_fx'; then
	echo "REPGEN_FAIL: the unclaimed-_fx error doesn't spell the expected name:"
	echo "$UNC_OUT" | tail -3
	exit 1
fi
UNT="$TMP/unt"
mkdir -p "$UNT"
cat > "$UNT/gate.odin" <<'EOF'
//gd:extends Node
//gd:class Gate
package repgen_unt

import gd "godot:godot"
import knet "godot:kit/net"

Gate :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	open:   u8 `gd:"replicate"`,
}

@(gd_command)
gate_toggle :: proc(self: ^Gate) -> bool {
	self.open = 1 - self.open
	return true
}

gate_togle_then :: proc(self: ^Gate, by: knet.Player_Id) { // typo'd verb
	_ = by
}

gate_opn_edge :: proc(self: ^Gate, old, new: u8) { // typo'd field
	_ = old; _ = new
}
EOF
set +e
UNT_OUT="$(run_scriptgen "$UNT" 2>&1)"
UNT_RC=$?
set -e
if [ "$UNT_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a typo'd unclaimed _then was accepted (it would silently never fire)"
	exit 1
fi
if ! echo "$UNT_OUT" | grep -q 'gate_toggle_then'; then
	echo "REPGEN_FAIL: the unclaimed-_then error doesn't list the class's pairings:"
	echo "$UNT_OUT" | tail -3
	exit 1
fi
if ! echo "$UNT_OUT" | grep -q 'gate_open_edge'; then
	echo "REPGEN_FAIL: the unclaimed-_edge error doesn't spell the expected field pairing:"
	echo "$UNT_OUT" | tail -3
	exit 1
fi
UNH="$TMP/unh"
mkdir -p "$UNH"
cat > "$UNH/den.odin" <<'EOF'
//gd:extends Node
//gd:class Den
package repgen_unh

import gd "godot:godot"
import knet "godot:kit/net"

Den :: struct {
	owner:     gd.Node,
	mob_scene: ^gd.Resource `gd:"entity=Mob:1"`,
}
EOF
cat > "$UNH/mob.odin" <<'EOF'
//gd:extends Node2D
//gd:class Mob
package repgen_unh

import gd "godot:godot"
import knet "godot:kit/net"

Mob :: struct {
	owner: gd.Node2d,
	hp:    i32 `gd:"replicate"`,
}

mbo_spawned :: proc(game: ^Den, self: ^Mob, id: knet.Net_Id, owner: knet.Player_Id) { // typo'd prefix
}
EOF
set +e
UNH_OUT="$(run_scriptgen "$UNH" 2>&1)"
UNH_RC=$?
set -e
if [ "$UNH_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a typo'd unclaimed _spawned hook was accepted (it would silently never fire)"
	exit 1
fi
if ! echo "$UNH_OUT" | grep -q 'mob_spawned'; then
	echo "REPGEN_FAIL: the unclaimed-hook error doesn't spell the expected name:"
	echo "$UNH_OUT" | tail -3
	exit 1
fi
# The negative control: a `_then` helper touching NO script struct stays a
# WARNING — the build passes, the note prints.
UNW="$TMP/unw"
mkdir -p "$UNW"
cat > "$UNW/plain.odin" <<'EOF'
//gd:extends Node
//gd:class Plain
package repgen_unw

import gd "godot:godot"

Plain :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"replicate"`,
}

load_then :: proc(data: []u8) { // innocent helper: no script struct touched
	_ = data
}
EOF
set +e
UNW_OUT="$(run_scriptgen "$UNW" 2>&1)"
UNW_RC=$?
set -e
if [ "$UNW_RC" -ne 0 ]; then
	echo "REPGEN_FAIL: an innocent _then helper (no script-struct param) failed the build"
	exit 1
fi
if ! echo "$UNW_OUT" | grep -q "will never fire"; then
	echo "REPGEN_FAIL: the innocent _then helper lost its warning:"
	echo "$UNW_OUT" | tail -3
	exit 1
fi
echo "  ok  reserved pairing suffixes: typo'd _fx/_then/_spawned error with the fix named; script-free helpers keep the warning"

# ---- (4a2b): @(gd_sample)/@(gd_step) contract violations ----
# A sample writing a struct the lane's ticks don't read is the silent-desync
# bug the attribute exists to kill — scriptgen must name both structs.
MIS="$TMP/mis"
mkdir -p "$MIS"
cat > "$MIS/racer.odin" <<'EOF'
//gd:extends Node
//gd:class Racer
package repgen_mis

import gd "godot:godot"

Racer :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

Racer_Input :: struct {
	steer: i8,
}

Wrong_Input :: struct {
	steer: i8,
}

@(gd_tick)
racer_tick :: proc(self: ^Racer, input: Racer_Input) {
	self.x += f32(input.steer)
}

@(gd_sample)
racer_sample :: proc(self: ^Racer, tick: u64, input: ^Wrong_Input) {
}
EOF
set +e
MIS_OUT="$(run_scriptgen "$MIS" 2>&1)"
MIS_RC=$?
set -e
if [ "$MIS_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a @(gd_sample) writing an input struct no tick reads was accepted by scriptgen"
	exit 1
fi
if ! echo "$MIS_OUT" | grep -q "the sample would feed nobody"; then
	echo "REPGEN_FAIL: scriptgen error doesn't name the orphan-sample mismatch:"
	echo "$MIS_OUT" | tail -3
	exit 1
fi

# Two @(gd_sample) procs writing the SAME input struct — multiple samples are
# allowed (one per input CLASS), but two filling the same class is the ambiguity
# the parser rejects by name.
DUP="$TMP/dupsample"
mkdir -p "$DUP"
cat > "$DUP/dally.odin" <<'EOF'
//gd:extends Node
//gd:class Dally
package repgen_dupsample

import gd "godot:godot"

Dally :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

Dally_Input :: struct {
	go: i8,
}

@(gd_tick)
dally_tick :: proc(self: ^Dally, input: Dally_Input) {
	self.x += f32(input.go)
}

@(gd_sample)
dally_sample :: proc(self: ^Dally, tick: u64, input: ^Dally_Input) {
}

@(gd_sample)
dally_sample_again :: proc(self: ^Dally, tick: u64, input: ^Dally_Input) {
}
EOF
set +e
DUP_OUT="$(run_scriptgen "$DUP" 2>&1)"
DUP_RC=$?
set -e
if [ "$DUP_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: two @(gd_sample) filling the same input class was accepted by scriptgen"
	exit 1
fi
if ! echo "$DUP_OUT" | grep -q "one sample per input TYPE"; then
	echo "REPGEN_FAIL: scriptgen error doesn't name the duplicate-sample-per-class violation:"
	echo "$DUP_OUT" | tail -3
	exit 1
fi

STK="$TMP/stk"
mkdir -p "$STK"
cat > "$STK/refy.odin" <<'EOF'
//gd:extends Node
//gd:class Refy
package repgen_stk

import gd "godot:godot"

Refy :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
refy_tick :: proc(self: ^Refy) {
	self.x += 1
}

@(gd_step = "host_only")
refy_step :: proc(self: ^Refy, tick: u64) {
}
EOF
set +e
STK_OUT="$(run_scriptgen "$STK" 2>&1)"
STK_RC=$?
set -e
if [ "$STK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: an unknown @(gd_step) config token was accepted by scriptgen"
	exit 1
fi
if ! echo "$STK_OUT" | grep -q 'expected `authority`'; then
	echo "REPGEN_FAIL: scriptgen error doesn't name the step token contract:"
	echo "$STK_OUT" | tail -3
	exit 1
fi
echo "  ok  lane-wiring violations rejected: orphan sample, duplicate sample per class, unknown step token"

# ---- (4a2c): a <verb>_apply on a class that doesn't tick ----
# The apply half is the resim's property; a coop-loop verb reverts whole.
APL="$TMP/apl"
mkdir -p "$APL"
cat > "$APL/still.odin" <<'EOF'
//gd:extends Node
//gd:class Still
package repgen_apl

import gd "godot:godot"
import knet "godot:kit/net"

Still :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
still_poke :: proc(self: ^Still, amount: i32) -> bool {
	if self.hp <= 0 {return false}
	self.hp -= amount
	return true
}

still_poke_apply :: proc(self: ^Still, amount: i32) {
}
EOF
set +e
APL_OUT="$(run_scriptgen "$APL" 2>&1)"
APL_RC=$?
set -e
if [ "$APL_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a _apply half on a non-ticking class was accepted by scriptgen"
	exit 1
fi
if ! echo "$APL_OUT" | grep -q "doesn't tick"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the _apply/tick contract:"
	echo "$APL_OUT" | tail -3
	exit 1
fi
echo "  ok  a _apply half on a non-ticking class rejected at scriptgen time"

# ---- (4a2d): slack= misuse, in the TWO shapes the lane-first grammar leaves ----
# On a DISCRETE predicted field slack would be silently ignored (discrete state
# reconciles exactly), so that stays a real per-lane type check. Off the predict
# lane entirely it is no longer a "knob without its lane" — `slack=` is simply
# not in the delta lane's option set, and the refusal names what that lane takes.
# That swap is the whole point of hoisting the lane: a cross-token implication
# became a membership question.
SLK="$TMP/slk"
mkdir -p "$SLK"
cat > "$SLK/loosy.odin" <<'EOF'
//gd:extends Node
//gd:class Loosy
package repgen_slk

import gd "godot:godot"

Loosy :: struct {
	owner: gd.Node,
	flag:  u8 `gd:"predict,slack=0.5"`, // discrete: slack is meaningless
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
loosy_tick :: proc(self: ^Loosy) {
	self.x += 1
}
EOF
set +e
SLK_OUT="$(run_scriptgen "$SLK" 2>&1)"
SLK_RC=$?
set -e
if [ "$SLK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: slack= on a discrete predicted field was accepted by scriptgen"
	exit 1
fi
if ! echo "$SLK_OUT" | grep -q "float predicted field"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the slack/float contract:"
	echo "$SLK_OUT" | tail -3
	exit 1
fi
SLK2="$TMP/slk2"
mkdir -p "$SLK2"
cat > "$SLK2/coldy.odin" <<'EOF'
//gd:extends Node
//gd:class Coldy
package repgen_slk2

import gd "godot:godot"

Coldy :: struct {
	owner: gd.Node,
	x:     f32 `gd:"replicate,interp,slack=0.5"`, // delta lane: slack isn't one of its options
}
EOF
set +e
SLK2_OUT="$(run_scriptgen "$SLK2" 2>&1)"
SLK2_RC=$?
set -e
if [ "$SLK2_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: slack= on a non-predict field was accepted by scriptgen"
	exit 1
fi
if ! echo "$SLK2_OUT" | grep -q 'unknown `replicate` option'; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the slack/predict contract:"
	echo "$SLK2_OUT" | tail -3
	exit 1
fi
echo "  ok  slack= misuse rejected at scriptgen time (discrete field, non-predict field)"

# ---- (4a2d2): glide= on a non-interp predicted field — render-error needs interp ----
# The glide/cut knobs shape a reconcile correction's SMOOTHING; a non-interp
# predicted field snaps on reconcile, so there is no glide to shape — reject it.
GLD="$TMP/gld"
mkdir -p "$GLD"
cat > "$GLD/snappy.odin" <<'EOF'
//gd:extends Node
//gd:class Snappy
package repgen_gld

import gd "godot:godot"

Snappy :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict,glide=0.1"`, // predicted but not interp: snaps, no glide
}

@(gd_tick)
snappy_tick :: proc(self: ^Snappy) {
	self.x += 1
}
EOF
set +e
GLD_OUT="$(run_scriptgen "$GLD" 2>&1)"
GLD_RC=$?
set -e
if [ "$GLD_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: glide= on a non-interp predicted field was accepted by scriptgen"
	exit 1
fi
if ! echo "$GLD_OUT" | grep -q "render-error smoothing"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the glide/interp contract:"
	echo "$GLD_OUT" | tail -3
	exit 1
fi
echo "  ok  glide= on a non-interp predicted field rejected at scriptgen time"

# ---- (4a2g): more than 64 replicated fields — the dirty mask is one u64 ----
# The 65th field's dirty bit would shift out of the mask and silently stop
# replicating; scriptgen must refuse the build, naming the class.
BIG="$TMP/big"
mkdir -p "$BIG"
{
	echo '//gd:extends Node'
	echo '//gd:class Bloaty'
	echo 'package repgen_big'
	echo ''
	echo 'import gd "godot:godot"'
	echo ''
	echo 'Bloaty :: struct {'
	echo '	owner: gd.Node,'
	for i in $(seq 1 65); do
		echo "	f$i: u8 \`gd:\"replicate\"\`,"
	done
	echo '}'
} > "$BIG/bloaty.odin"
set +e
BIG_OUT="$(run_scriptgen "$BIG" 2>&1)"
BIG_RC=$?
set -e
if [ "$BIG_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: an entity with 65 replicated fields was accepted by scriptgen"
	exit 1
fi
if ! echo "$BIG_OUT" | grep -q "at most 64"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the 64-field ceiling:"
	echo "$BIG_OUT" | tail -3
	exit 1
fi
echo "  ok  more than 64 replicated fields rejected at scriptgen time"

# ---- (4a2e): two @(gd_step) of the same kind — one everywhere + one authority ----
DUP="$TMP/dup"
mkdir -p "$DUP"
cat > "$DUP/twicey.odin" <<'EOF'
//gd:extends Node
//gd:class Twicey
package repgen_dup

import gd "godot:godot"

Twicey :: struct {
	owner: gd.Node,
	x:     f32 `gd:"predict"`,
}

@(gd_tick)
twicey_tick :: proc(self: ^Twicey) {
	self.x += 1
}

@(gd_step)
twicey_a :: proc(self: ^Twicey, tick: u64) {
}

@(gd_step)
twicey_b :: proc(self: ^Twicey, tick: u64) {
}
EOF
set +e
DUP_OUT="$(run_scriptgen "$DUP" 2>&1)"
DUP_RC=$?
set -e
if [ "$DUP_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: two @(gd_step) everywhere passes were accepted by scriptgen"
	exit 1
fi
if ! echo "$DUP_OUT" | grep -q "everywhere pass"; then
	echo "REPGEN_FAIL: scriptgen error doesn't name the duplicate everywhere pass:"
	echo "$DUP_OUT" | tail -3
	exit 1
fi
echo "  ok  a duplicate everywhere @(gd_step) rejected at scriptgen time"

# ---- (4a3): a block tick with an input param — blocks are INPUTLESS ----
BTK="$TMP/btk"
mkdir -p "$BTK"
cat > "$BTK/wheel.odin" <<'EOF'
//gd:extends Node
//gd:class Wheel
package repgen_btk

import gd "godot:godot"

Hub :: struct {
	spin: f32 `gd:"predict"`,
}

Hub_In :: struct {
	torque: i8,
}

@(gd_tick)
hub_tick :: proc(h: ^Hub, input: Hub_In) { // blocks read intent from FIELDS
	h.spin += f32(input.torque)
}

Wheel :: struct {
	owner: gd.Node,
	hub:   Hub,
}

wheel_ready :: proc(self: ^Wheel) {}
EOF
set +e
BTK_OUT="$(run_scriptgen "$BTK" 2>&1)"
BTK_RC=$?
set -e
if [ "$BTK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a block tick with an input param was accepted by scriptgen"
	exit 1
fi
if ! echo "$BTK_OUT" | grep -q "INPUTLESS"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the inputless-block rule:"
	echo "$BTK_OUT" | tail -3
	exit 1
fi
echo "  ok  block ticks are inputless — a value param is a build error"

# ---- (4a4): THE SHELF LINT — blocks must sit on the lane their shelf names ----
# A fabricated godot: root stands in for the real shelves (the lint keys on
# the block's dir under -godot:, exactly play / play/sim): a predict-tagged
# block on the root shelf errors toward play/sim, and a sim-shelf block with
# no predict fields errors back. Game-local blocks stay out of scope.
SHF="$TMP/shf"
mkdir -p "$SHF/root/play/sim" "$SHF/hot" "$SHF/flat"
cat > "$SHF/root/play/heat.odin" <<'EOF'
package play

Heat :: struct {
	warmth: u16 `gd:"predict"`,
}

@(gd_tick)
heat_tick :: proc(h: ^Heat) {
	if h.warmth > 0 {h.warmth -= 1}
}
EOF
cat > "$SHF/root/play/sim/tally.odin" <<'EOF'
package play_sim

Tally :: struct {
	score: u8 `gd:"replicate"`,
}
EOF
cat > "$SHF/hot/carrier.odin" <<'EOF'
//gd:extends Node
//gd:class Carrier
package repgen_shf_hot

import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Carrier :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	heat:   play.Heat, // predict-tagged block on the ROOT shelf: rejected
}

carrier_ready :: proc(self: ^Carrier) {}
EOF
set +e
SHF_OUT="$("$SGEN" "$SHF/hot" -godot:"$SHF/root" 2>&1)"
SHF_RC=$?
set -e
if [ "$SHF_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a predict-tagged block on the root play shelf was accepted"
	exit 1
fi
if ! echo "$SHF_OUT" | grep -q "move it to play/sim"; then
	echo "REPGEN_FAIL: scriptgen error doesn't point the predicted block at play/sim:"
	echo "$SHF_OUT" | tail -3
	exit 1
fi
cat > "$SHF/flat/keeper.odin" <<'EOF'
//gd:extends Node
//gd:class Keeper
package repgen_shf_flat

import gd "godot:godot"
import knet "godot:kit/net"
import psim "godot:play/sim"

Keeper :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	x:      f32 `gd:"predict"`,
	tally:  psim.Tally, // no predict fields on the SIM shelf: rejected
}

@(gd_tick)
keeper_tick :: proc(self: ^Keeper) {
	self.x += 1
}
EOF
set +e
SHF2_OUT="$("$SGEN" "$SHF/flat" -godot:"$SHF/root" 2>&1)"
SHF2_RC=$?
set -e
if [ "$SHF2_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a predict-free block on the play/sim shelf was accepted"
	exit 1
fi
if ! echo "$SHF2_OUT" | grep -q "timeline-free and coop blocks live on godot:play"; then
	echo "REPGEN_FAIL: scriptgen error doesn't point the flat block back at play:"
	echo "$SHF2_OUT" | tail -3
	exit 1
fi
echo "  ok  shelf lint: predicted blocks belong in play/sim, flat ones in play — both directions rejected"

# ---- (4b): interp on a non-float + interp= with no proc — both errors ----
LRP="$TMP/lrp"
mkdir -p "$LRP"
cat > "$LRP/steppy.odin" <<'EOF'
//gd:extends Node
//gd:class Steppy
package repgen_lrp

import gd "godot:godot"

Steppy :: struct {
	owner: gd.Node,
	rate:  i32 `gd:"replicate,interp"`, // ints can't lerp: loud error, not silent stutter
	turn:  f32 `gd:"replicate,interp="`, // custom blend with no proc named
}

steppy_ready :: proc(self: ^Steppy) {}
EOF
set +e
LRP_OUT="$(run_scriptgen "$LRP" 2>&1)"
LRP_RC=$?
set -e
if [ "$LRP_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: interp on an i32 / empty interp= was accepted by scriptgen"
	exit 1
fi
if ! echo "$LRP_OUT" | grep -q "can only snap between samples"; then
	echo "REPGEN_FAIL: missing the interp-needs-floats error:"
	echo "$LRP_OUT" | tail -4
	exit 1
fi
if ! echo "$LRP_OUT" | grep -q "needs .angle. or a blend proc name"; then
	echo "REPGEN_FAIL: missing the empty interp= error:"
	echo "$LRP_OUT" | tail -4
	exit 1
fi
echo "  ok  interp on a non-float and empty interp= rejected, both spelled out"

# ---- (4c): wire=f16 on a non-f32 type + empty wire= — both errors ----
WIR="$TMP/wir"
mkdir -p "$WIR"
cat > "$WIR/halved.odin" <<'EOF'
//gd:extends Node
//gd:class Halved
package repgen_wir

import gd "godot:godot"

Halved :: struct {
	owner: gd.Node,
	kills: i32 `gd:"replicate,wire=f16"`, // nothing to halve: loud error
	score: f32 `gd:"replicate,wire="`, // wire= with no codec named
}

halved_ready :: proc(self: ^Halved) {}
EOF
set +e
WIR_OUT="$(run_scriptgen "$WIR" 2>&1)"
WIR_RC=$?
set -e
if [ "$WIR_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: wire=f16 on an i32 / empty wire= was accepted by scriptgen"
	exit 1
fi
if ! echo "$WIR_OUT" | grep -q "needs f32 elements"; then
	echo "REPGEN_FAIL: missing the wire=f16-needs-floats error:"
	echo "$WIR_OUT" | tail -4
	exit 1
fi
if ! echo "$WIR_OUT" | grep -q "needs \`f16\` or a codec name"; then
	echo "REPGEN_FAIL: missing the empty wire= error:"
	echo "$WIR_OUT" | tail -4
	exit 1
fi
echo "  ok  wire=f16 on a non-float and empty wire= rejected, both spelled out"

# ---- (5a): a command without net_id AND without replicated fields — both errors ----
CMD1="$TMP/cmd1"
mkdir -p "$CMD1"
cat > "$CMD1/bare.odin" <<'EOF'
//gd:extends Node
//gd:class Bare
package repgen_cmd1

import gd "godot:godot"

Bare :: struct {
	owner: gd.Node,
	hp:    i32, // not replicated
}

@(gd_command = "predict")
bare_hit :: proc(self: ^Bare, amount: i32) -> bool {
	self.hp -= amount
	return true
}
EOF
set +e
CMD1_OUT="$(run_scriptgen "$CMD1" 2>&1)"
CMD1_RC=$?
set -e
if [ "$CMD1_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a command without net_id/replicates was accepted by scriptgen"
	exit 1
fi
echo "$CMD1_OUT" | grep -q 'no networked fields' \
	|| { echo "REPGEN_FAIL: missing the no-replicates command error"; echo "$CMD1_OUT" | tail -3; exit 1; }
echo "$CMD1_OUT" | grep -q 'no `net_id: knet.Net_Id` field' \
	|| { echo "REPGEN_FAIL: missing the no-net_id command error"; echo "$CMD1_OUT" | tail -3; exit 1; }
echo "  ok  command without replicates/net_id rejected with both fixes spelled out"

# ---- (5b): platform-width int arg + non-bool return are scriptgen errors ----
CMD2="$TMP/cmd2"
mkdir -p "$CMD2"
cat > "$CMD2/wide.odin" <<'EOF'
//gd:extends Node
//gd:class Wide
package repgen_cmd2

import gd "godot:godot"
import knet "godot:kit/net"

Wide :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
wide_hit :: proc(self: ^Wide, amount: int) -> bool { // int: platform width
	return true
}

@(gd_command)
wide_poke :: proc(self: ^Wide) { // missing -> bool
}
EOF
set +e
CMD2_OUT="$(run_scriptgen "$CMD2" 2>&1)"
CMD2_RC=$?
set -e
if [ "$CMD2_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: bad command signatures were accepted by scriptgen"
	exit 1
fi
echo "$CMD2_OUT" | grep -q "platform-dependent width" \
	|| { echo "REPGEN_FAIL: missing the int-width command error"; echo "$CMD2_OUT" | tail -3; exit 1; }
echo "$CMD2_OUT" | grep -q "must return \`bool\` first" \
	|| { echo "REPGEN_FAIL: missing the non-bool-return command error"; echo "$CMD2_OUT" | tail -3; exit 1; }
echo "  ok  bad command signatures rejected at scriptgen time"

# ---- (5c): a mispaired `_then` consequence is a scriptgen-time error ----
CMD3="$TMP/cmd3"
mkdir -p "$CMD3"
cat > "$CMD3/odd.odin" <<'EOF'
//gd:extends Node
//gd:class Odd
package repgen_cmd3

import gd "godot:godot"
import knet "godot:kit/net"

Odd :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
odd_hit :: proc(self: ^Odd, amount: i32) -> bool {
	return true
}

odd_hit_then :: proc(self: ^Odd, amount: i32) { // missing the issuer param
}
EOF
set +e
CMD3_OUT="$(run_scriptgen "$CMD3" 2>&1)"
CMD3_RC=$?
set -e
if [ "$CMD3_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a consequence missing its issuer param was accepted by scriptgen"
	exit 1
fi
echo "$CMD3_OUT" | grep -q "must be the issuer" \
	|| { echo "REPGEN_FAIL: missing the consequence-shape error"; echo "$CMD3_OUT" | tail -3; exit 1; }
echo "  ok  mispaired _then consequence rejected at scriptgen time"

# ---- (5d): entity-table contract violations are scriptgen-time errors ----
ENT="$TMP/ent"
mkdir -p "$ENT"
cat > "$ENT/gremlin.odin" <<'EOF'
//gd:extends Node
//gd:class Gremlin
package repgen_ent

import gd "godot:godot"
import knet "godot:kit/net"

Gremlin :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

gremlin_ready :: proc(self: ^Gremlin) {
}
EOF
cat > "$ENT/den.odin" <<'EOF'
//gd:extends Node2D
//gd:class Den
package repgen_ent

import gd "godot:godot"
import knet "godot:kit/net"

Den :: struct {
	owner:   gd.Node2d,
	a_scene: ^gd.Resource `gd:"entity=Gremlin:5"`,
	b_scene: ^gd.Resource `gd:"entity=Gremlin:5"`, // duplicate wire id
	c_scene: ^gd.Resource `gd:"entity=Ghost:9"`,   // no such struct
}

gremlin_spawned :: proc(game: ^Den, self: ^Gremlin, id: knet.Net_Id) { // missing the owner param
}

den_ready :: proc(self: ^Den) {
}
EOF
set +e
ENT_OUT="$(run_scriptgen "$ENT" 2>&1)"
ENT_RC=$?
set -e
if [ "$ENT_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: entity-table contract violations were accepted by scriptgen"
	exit 1
fi
echo "$ENT_OUT" | grep -q "already claimed" \
	|| { echo "REPGEN_FAIL: missing the duplicate-wire-id error"; echo "$ENT_OUT" | tail -4; exit 1; }
echo "$ENT_OUT" | grep -q "no script struct named" \
	|| { echo "REPGEN_FAIL: missing the unknown-entity-struct error"; echo "$ENT_OUT" | tail -4; exit 1; }
echo "$ENT_OUT" | grep -q "entity hook gremlin_spawned: expected" \
	|| { echo "REPGEN_FAIL: missing the census-hook-shape error"; echo "$ENT_OUT" | tail -4; exit 1; }
echo "  ok  entity-table violations rejected: duplicate id, unknown struct, hook shape"

# ---- (5e): a typo'd method NAME in boot_attach/wire_listen is a scriptgen error ----
# (the strings connect Godot signals — a typo compiles and fails as behavior:
# the alt-F4'd-friend-haunts-the-roster bug. "" stays a deliberate skip.)
BM="$TMP/bm"
mkdir -p "$BM"
cat > "$BM/hall.odin" <<'EOF'
//gd:extends Node
//gd:class Hall
package repgen_bm

import gd "godot:godot"
import kboot "godot:kit/boot"
import netgd "godot:kit/netgd"

Hall :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_method)
hall_on_host :: proc(self: ^Hall) {
}

hall_ready :: proc(self: ^Hall) {
	kboot.boot_attach(&self.boot, self.owner, nil, nil, kboot.Options{
		methods = {"on_host", "on_hots", ""},
	})
	netgd.wire_listen(&self.boot.wire, "on_pakcet", "")
}
EOF
set +e
BM_OUT="$(run_scriptgen "$BM" 2>&1)"
BM_RC=$?
set -e
if [ "$BM_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: typo'd signal method names were accepted by scriptgen"
	exit 1
fi
echo "$BM_OUT" | grep -q '"on_hots" names no @(gd_method) of Hall' \
	|| { echo "REPGEN_FAIL: missing the boot_attach method-name error"; echo "$BM_OUT" | tail -4; exit 1; }
echo "$BM_OUT" | grep -q '"on_pakcet" names no @(gd_method) of Hall' \
	|| { echo "REPGEN_FAIL: missing the wire_listen method-name error"; echo "$BM_OUT" | tail -4; exit 1; }
if echo "$BM_OUT" | grep -q '"on_host" names no'; then
	echo "REPGEN_FAIL: the lint flagged a correctly declared method"
	exit 1
fi
[ "$(echo "$BM_OUT" | grep -c 'names no @(gd_method)')" = "2" ] \
	|| { echo "REPGEN_FAIL: empty-string skips must not be flagged"; echo "$BM_OUT" | tail -5; exit 1; }
echo "  ok  typo'd signal method names rejected; \"\" skips stay silent"

# ---- (6): the self-vs-owner lint — bare `self` in a gd.* call is an error ----
# Engine handles are rawptr aliases, so `gd.add_child(self, node)` COMPILES and
# segfaults at runtime (a real consumer hit this three times in one feature).
# Covers: a script's own file, a HELPER file's `^<Struct>` param (the struct set
# is package-wide), and cast(gd.X)self. A clean `self.owner` must still pass.
LNT="$TMP/lnt"
mkdir -p "$LNT"
cat > "$LNT/gemfx.odin" <<'EOF'
//gd:extends Node2D
//gd:class Gemfx
package repgen_lnt

import gd "godot:godot"

Gemfx :: struct {
	owner: gd.Node2d,
}

gemfx_ready :: proc(self: ^Gemfx) {
	gd.connect_to(self.owner, "finished", self, "cleanup") // BAD: target is the struct
	gd.node_queue_free(self.owner) // fine: the engine node
}
EOF
cat > "$LNT/gemfx_helpers.odin" <<'EOF'
package repgen_lnt

import gd "godot:godot"

gemfx_bury :: proc(fx: ^Gemfx, parent: gd.Node) {
	gd.add_child(parent, fx) // BAD: helper param, same struct
	_ = cast(gd.Object)fx    // BAD: the cast crashes identically
}
EOF
set +e
LNT_OUT="$(run_scriptgen "$LNT" 2>&1)"
LNT_RC=$?
set -e
if [ "$LNT_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: bare script-struct pointers in gd.* calls were accepted by scriptgen"
	exit 1
fi
echo "$LNT_OUT" | grep -q 'gd.connect_to: `self` is the ^Gemfx script struct' \
	|| { echo "REPGEN_FAIL: missing the self-arg lint error (script file)"; echo "$LNT_OUT" | tail -4; exit 1; }
echo "$LNT_OUT" | grep -q 'gd.add_child: `fx` is the ^Gemfx script struct' \
	|| { echo "REPGEN_FAIL: missing the helper-param lint error"; echo "$LNT_OUT" | tail -4; exit 1; }
echo "$LNT_OUT" | grep -q 'cast(gd.Object)fx' \
	|| { echo "REPGEN_FAIL: missing the cast lint error"; echo "$LNT_OUT" | tail -4; exit 1; }
if echo "$LNT_OUT" | grep -q 'node_queue_free'; then
	echo "REPGEN_FAIL: the lint flagged a legitimate self.owner call"
	echo "$LNT_OUT" | tail -4
	exit 1
fi
echo "  ok  self-vs-owner lint: struct-as-handle rejected in scripts, helpers, and casts"

echo "REPGEN_OK"
