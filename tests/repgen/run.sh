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
#       and mispaired `<verb>_then` consequences (the shape is validated at
#       build time — a consequence can never silently not fire).
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
	'lerp = .F32' \
	'lerp = .Quat' \
	'lerp = .Custom, blend = pawn_blend_aim' \
	'wire = .F16' \
	'wire = .Custom, codec = pawn_charge_codec' \
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

# @(gd_command) artifacts: thunks decode-check-call, table carries predict flags,
# wrappers are typed and role-branch on ctx.is_authority. The `<verb>_then`
# consequence pairs by name: payload returns are captured and threaded, the
# call is gated on the authoritative run (env.authority in the thunk; the
# wrapper's authority branch fires it for the host's own issues).
for needle in \
	'_pawn_cmd_hit :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool' \
	'_a0 := knet.read_i32(r)' \
	'if r.err {return false}' \
	'{name = "hit", predict = true, invoke = _pawn_cmd_hit}' \
	'{name = "mark", predict = false, invoke = _pawn_cmd_mark}' \
	'pawn_command_set := knet.Command_Set{entity_desc = &pawn_net_desc' \
	'pawn_hit_cmd :: proc(ctx: ^knet.Command_Ctx, self: ^Pawn, amount: i32) -> bool' \
	'pawn_mark_cmd :: proc(ctx: ^knet.Command_Ctx, self: ^Pawn, label: string, who: knet.Player_Id) -> bool' \
	'if ctx.is_authority {' \
	'knet.command_begin(ctx, self.net_id, 0)' \
	'knet.write_player_id(&ctx.msg, who)' \
	'_ok, _p0 := pawn_loot(self, _a0)' \
	'if _ok && env.authority {' \
	'pawn_loot_then(self, env.by, _a0, _p0)' \
	'pawn_loot_then(self, ctx.me, slot, _p0)' \
; do
	if ! grep -qF "$needle" "$GEN"; then
		echo "REPGEN_FAIL: generated file is missing command artifact: $needle"
		exit 1
	fi
done
# Commands are NOT Godot methods: they must not leak into the method tables.
if grep -qF '_pawn_m_hit' "$GEN"; then
	echo "REPGEN_FAIL: a @(gd_command) proc leaked into the method trampolines"
	exit 1
fi
echo "  ok  command thunks, table, set, and typed issue wrappers generated"

# @(gd_tick) artifacts: the ksim import, the input POD assert, the rawptr
# thunk (nil input coasts; the author call stays typed), and the Sim_Set the
# game hands to lane_track_set. Never a Godot method.
for needle in \
	'import ksim "godot:kit/sim"' \
	'intrinsics.type_is_nearly_simple_compare(Pawn_Input)' \
	'_pawn_tick_step :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane)' \
	'if input == nil {return}' \
	'pawn_tick(cast(^Pawn)entity, (cast(^Pawn_Input)input)^, lane)' \
	'pawn_sim_set := ksim.Sim_Set{entity_desc = &pawn_net_desc, tick = _pawn_tick_step, input_size = size_of(Pawn_Input)}' \
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
echo "  ok  tick thunk + sim set generated (POD-asserted input, coast-on-nil)"

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
	'return rt.script_of(node, Pawn)' \
; do
	if ! grep -qF "$needle" "$BGEN"; then
		echo "REPGEN_FAIL: generated file is missing entity artifact: $needle"
		exit 1
	fi
done
echo "  ok  entity table generated (TYPE const, kinds row, typed census hooks)"

"$ODIN" check "$GOOD" -collection:godot="$ROOT" -no-entry-point \
	${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"}
echo "  ok  generated package compiles (odin check)"

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

# ---- (3b): a non-POD type scriptgen can't judge fails the CONSUMER compile ----
BAD="$TMP/bad"
mkdir -p "$BAD"
cat > "$BAD/chatty.odin" <<'EOF'
//gd:extends Node
//gd:class Chatty
package repgen_bad

import gd "godot:godot"

Chatty :: struct {
	owner: gd.Node,
	data:  []u8 `gd:"replicate"`, // slice: not a Variant type, so only the #assert can catch it
}

chatty_ready :: proc(self: ^Chatty) {}
EOF
run_scriptgen "$BAD" # scriptgen succeeds — the type check is the consumer compiler's
set +e
CHECK_OUT="$("$ODIN" check "$BAD" -collection:godot="$ROOT" -no-entry-point 2>&1)"
CHECK_RC=$?
set -e
if [ "$CHECK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a replicated slice field COMPILED — the POD assert is not enforcing"
	exit 1
fi
if ! echo "$CHECK_OUT" | grep -q "Chatty.data"; then
	echo "REPGEN_FAIL: the POD failure does not name the offending field (Chatty.data):"
	echo "$CHECK_OUT" | tail -5
	exit 1
fi
echo "  ok  non-POD replicate field fails the build, naming Chatty.data"

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
if ! echo "$SGEN_OUT" | grep -q "unknown replicate option"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the unknown option:"
	echo "$SGEN_OUT" | tail -3
	exit 1
fi
echo "  ok  unknown replicate option rejected at scriptgen time"

# ---- (4a): `owner` and `predict` on one field — two authority lanes, an error ----
LANES="$TMP/lanes"
mkdir -p "$LANES"
cat > "$LANES/torn.odin" <<'EOF'
//gd:extends Node
//gd:class Torn
package repgen_lanes

import gd "godot:godot"

Torn :: struct {
	owner: gd.Node,
	x:     f32 `gd:"replicate,owner,predict"`, // two writers, one field: refused
}

torn_ready :: proc(self: ^Torn) {}
EOF
set +e
LANES_OUT="$(run_scriptgen "$LANES" 2>&1)"
LANES_RC=$?
set -e
if [ "$LANES_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: owner+predict on one field was accepted by scriptgen"
	exit 1
fi
if ! echo "$LANES_OUT" | grep -q "mutually exclusive"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the lane conflict:"
	echo "$LANES_OUT" | tail -3
	exit 1
fi
echo "  ok  owner+predict lane conflict rejected at scriptgen time"

# ---- (4a2): @(gd_tick) contract violations — returns a value / no predict fields ----
TIK="$TMP/tik"
mkdir -p "$TIK"
cat > "$TIK/spinny.odin" <<'EOF'
//gd:extends Node
//gd:class Spinny
package repgen_tik

import gd "godot:godot"

Spinny :: struct {
	owner: gd.Node,
	angle: f32 `gd:"replicate,predict"`,
}

@(gd_tick)
spinny_tick :: proc(self: ^Spinny) -> bool { // tick procs return NOTHING
	self.angle += 1
	return true
}
EOF
set +e
TIK_OUT="$(run_scriptgen "$TIK" 2>&1)"
TIK_RC=$?
set -e
if [ "$TIK_RC" -eq 0 ]; then
	echo "REPGEN_FAIL: a value-returning @(gd_tick) was accepted by scriptgen"
	exit 1
fi
if ! echo "$TIK_OUT" | grep -q "return nothing"; then
	echo "REPGEN_FAIL: scriptgen error doesn't explain the tick-return rule:"
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
if ! echo "$NOP_OUT" | grep -q 'replicate,predict'; then
	echo "REPGEN_FAIL: scriptgen error doesn't point at the missing predict tag:"
	echo "$NOP_OUT" | tail -3
	exit 1
fi
echo "  ok  tick contract violations rejected: return value, no predict fields"

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
if ! echo "$LRP_OUT" | grep -q "needs a blend proc name"; then
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
echo "$CMD1_OUT" | grep -q 'no gd:"replicate" fields' \
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
	a_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Gremlin:5"`,
	b_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Gremlin:5"`, // duplicate wire id
	c_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Ghost:9"`,   // no such struct
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
