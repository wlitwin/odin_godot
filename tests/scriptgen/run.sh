#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Golden test for scriptgen's NESTED replicated/tagged-field discovery
# (nested-replicate-fields). Drives the real scriptgen binary — no Godot — over
# three fixtures and asserts the generated output / diagnostics:
#
#   1. SAME-PACKAGE nesting: a `using`/plain sub-struct in a sibling file — the
#      descriptor must carry each nested replicate field via a COMPOSED offset
#      (offset_of(E, m) + offset_of(type_of(E{}.m), x)), depth-first.
#   2. IMPORTED bundle: `using cs: bundle.State` from a godot:kit/* package
#      resolved via -godot:<root> — its replicate fields (and a deeper plain
#      struct inside the bundle) must appear.
#   3. PLAIN embed surfaces export/onready/signal under namespaced `<field>_<leaf>`
#      names — the typed signal emit helper is generated under that name.
#   4. LOUD guardrail: a non-POD field inside a nested struct is a hard error,
#      naming the offending path, never silently dropped.
#   5. GENERIC structs (`Machine($S)`) resolve — the base is found and params are
#      substituted, so `cur: S` and recursion into a param-typed field both work.
#   6. REAL kit bundles (`using cd: kcombat.Cooldowns(3)`, `kitems.Inventory(8)`) —
#      imported generic bundles resolve and their replicated fields are discovered.
#
# Prints SCRIPTGEN_OK on success. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/scriptgen/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ODIN="${ODIN:-odin}"

# Reuse a pre-built scriptgen (run_all sets SGEN_BIN) or build one.
SGEN="${SGEN_BIN:-}"
if [[ -z "$SGEN" || ! -x "$SGEN" ]]; then
	tmpsg="$(mktemp -d)"
	SGEN="$tmpsg/scriptgen"
	if ! "$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$SGEN" -debug >/dev/null 2>&1; then
		echo "scriptgen: build failed"
		exit 1
	fi
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# ---- fixture 1: same-package `using` + plain, deep --------------------------
sp="$work/samepkg"
mkdir -p "$sp"
cat >"$sp/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class Thing
package sp
import gd "godot:godot"
import knet "godot:kit/net"

Move :: struct { x, y: f32 `gd:"replicate,interp"` }
Deep :: struct { inner: Move, flag: u8 `gd:"replicate"` }

Thing :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	hp:      i32 `gd:"replicate"`,
	using m: Move,   // promoted
	d:       Deep,   // plain, one level deeper
}
@(gd_command="predict")
thing_bump :: proc(self: ^Thing, n: i32) -> bool { self.hp += n; return true }
ODIN

if ! "$SGEN" "$sp" -godot:"$ROOT" >/dev/null 2>&1; then fail "same-package fixture errored"; fi
gen="$sp/odin_godot_scripts.gen.odin"
grep -q "offset_of(Thing, m) + offset_of(type_of(Thing{}.m), x)" "$gen" || fail "missing composed offset for using-nested m.x"
grep -q "offset_of(Thing, d) + offset_of(type_of(Thing{}.d), inner) + offset_of(type_of(Thing{}.d.inner), x)" "$gen" || fail "missing deep composed offset for d.inner.x"
grep -q "size_of(type_of(Thing{}.hp))" "$gen" || fail "top-level hp missing"

# ---- fixture 2: imported bundle (Phase 2) ----------------------------------
coll="$work/coll"                       # a throwaway godot: collection root
mkdir -p "$coll/kit/testbundle"
cat >"$coll/kit/testbundle/bundle.odin" <<'ODIN'
package kit_testbundle
Effect :: struct { kind: u8 `gd:"replicate"`, power: i16 `gd:"replicate"` }
State  :: struct {
	hp:  i32    `gd:"replicate"`,
	fx:  Effect,                 // plain nested WITHIN the bundle
	max: i32    `gd:"export"`,   // reached via the consumer's `using` -> runtime registers
}
ODIN
ip="$work/imp"
mkdir -p "$ip"
cat >"$ip/hero.odin" <<'ODIN'
//gd:extends Node
//gd:class Hero
package imp
import gd "godot:godot"
import knet "godot:kit/net"
import bundle "godot:kit/testbundle"

Hero :: struct {
	owner:    gd.Node,
	net_id:   knet.Net_Id,
	tint:     u8 `gd:"replicate"`,
	using cs: bundle.State,
}
@(gd_command="predict")
hero_hit :: proc(self: ^Hero, n: i32) -> bool { self.hp -= n; return true }
ODIN

if ! "$SGEN" "$ip" -godot:"$coll" >/dev/null 2>&1; then fail "imported-bundle fixture errored (using-reached export must not error)"; fi
igen="$ip/odin_godot_scripts.gen.odin"
grep -q "offset_of(Hero, cs) + offset_of(type_of(Hero{}.cs), hp)" "$igen" || fail "imported bundle replicate field cs.hp not discovered"
grep -q "offset_of(type_of(Hero{}.cs.fx), kind)" "$igen" || fail "deep field inside imported bundle (cs.fx.kind) not discovered"

# ---- fixture 3: plain embed surfaces export/onready/signal (namespaced) -----
comp="$work/comp"
mkdir -p "$comp"
cat >"$comp/fighter.odin" <<'ODIN'
//gd:extends Node
//gd:class Fighter
package comp
import gd "godot:godot"
import knet "godot:kit/net"

Aim :: struct {
	sensitivity: f32          `gd:"export"`,
	reticle:     gd.Node2d    `gd:"onready=UI/Reticle"`,
	fired:       gd.Signal1(i64) `gd:"args=dir"`,
}
Fighter :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	aim:    Aim,   // PLAIN embed -> aim_sensitivity / aim_reticle / aim_fired
}
@(gd_command="predict")
fighter_hit :: proc(self: ^Fighter, n: i32) -> bool { self.hp -= n; return true }
ODIN
if ! "$SGEN" "$comp" -godot:"$ROOT" >/dev/null 2>&1; then fail "plain embed with export/onready/signal must NOT error"; fi
# The signal's typed emit helper is generated under the namespaced name the runtime registers.
grep -q "fighter_emit_aim_fired" "$comp/odin_godot_scripts.gen.odin" || fail "namespaced signal emit helper fighter_emit_aim_fired not generated"

# ---- fixture 4: loud guardrail — a non-POD field inside a nested struct ------
bad="$work/bad"
mkdir -p "$bad"
cat >"$bad/nope.odin" <<'ODIN'
//gd:extends Node
//gd:class Nope
package bad
import gd "godot:godot"
import knet "godot:kit/net"

Inner :: struct { label: string `gd:"replicate"` }   // a string can't ride the wire
Nope :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	hp:      i32 `gd:"replicate"`,
	using i: Inner,
}
@(gd_command="predict")
nope_bump :: proc(self: ^Nope, n: i32) -> bool { self.hp += n; return true }
ODIN

out="$("$SGEN" "$bad" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "non-POD field in a nested struct must fail the build"
echo "$out" | grep -q "Nope.i.label" || fail "error must name the offending nested path Nope.i.label"

# ---- fixture 5: generic structs resolve, with param substitution ------------
gen="$work/gen"
mkdir -p "$gen"
cat >"$gen/g.odin" <<'ODIN'
//gd:extends Node
//gd:class G
package gen
import gd "godot:godot"
import knet "godot:kit/net"

Edge    :: struct($T: typeid) { seen: T }               // nested generic, untagged
Payload :: struct { hp: i32 `gd:"replicate"` }
Machine :: struct($S: typeid) {
	cur:    S `gd:"replicate"`,   // param-typed tagged field -> resolved via type_of
	shadow: Edge(S),              // nested generic -> no-op
}
Holder  :: struct($T: typeid) { tag: u8 `gd:"replicate"`, item: T } // item: T -> recurse into ARG
Gun_State :: enum u8 { Ready, Reload }
G :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	using m: Machine(Gun_State),  // m.cur : Gun_State
	hold:    Holder(Payload),     // hold.tag + hold.item.hp (substitution T=Payload)
}
@(gd_command="predict")
g_bump :: proc(self: ^G, n: i32) -> bool { self.hold.tag += u8(n); return true }
ODIN
if ! "$SGEN" "$gen" -godot:"$ROOT" >/dev/null 2>&1; then fail "generic instantiation must resolve, not error"; fi
ggen="$gen/odin_godot_scripts.gen.odin"
grep -q "offset_of(G, m) + offset_of(type_of(G{}.m), cur)" "$ggen" || fail "generic using field m.cur not resolved"
grep -q "offset_of(type_of(G{}.hold.item), hp)" "$ggen" || fail "substitution into a param-typed field (hold.item.hp) failed"

# ---- fixture 6: REAL kit bundles (imported generic) embed + replicate --------
kit="$work/kitb"
mkdir -p "$kit"
cat >"$kit/hero.odin" <<'ODIN'
//gd:extends Node
//gd:class HeroB
package kitb
import gd "godot:godot"
import knet "godot:kit/net"
import kcombat "godot:kit/combat"
import kitems "godot:kit/items"

HeroB :: struct {
	owner:    gd.Node,
	net_id:   knet.Net_Id,
	hp:       u8 `gd:"replicate"`,     // game-owned, stays flat
	using cd:  kcombat.Cooldowns(3),   // cds:[3]u16 replicate (imported generic bundle)
	using bag: kitems.Inventory(8),    // slots:[8]Slot replicate (imported generic bundle)
}
@(gd_command="predict")
herob_fire :: proc(self: ^HeroB, slot: i32) -> bool { return kcombat.cd_try(&self.cd, int(slot), {cooldown = 10}) }
ODIN
if ! "$SGEN" "$kit" -godot:"$ROOT" >/dev/null 2>&1; then fail "embedding real kit bundles (Cooldowns/Inventory) must resolve"; fi
kgen="$kit/odin_godot_scripts.gen.odin"
grep -q "offset_of(HeroB, cd) + offset_of(type_of(HeroB{}.cd), cds)" "$kgen" || fail "kcombat.Cooldowns(3) cds not discovered"
grep -q "offset_of(HeroB, bag) + offset_of(type_of(HeroB{}.bag), slots)" "$kgen" || fail "kitems.Inventory(8) slots not discovered"

# ---- fixture 7: VERB composition — same-package block, owner threading -------
# A @(gd_command) whose receiver is an EMBEDDED sub-struct is hoisted onto the entity: the
# decode thunk routes into &self.<field>, a pointer 2nd param (the wielder) is filled with
# `self`, and two instances of the same block get path-prefixed, non-colliding names.
vc="$work/composed"
mkdir -p "$vc"
cat >"$vc/runner.odin" <<'ODIN'
//gd:extends Node
//gd:class Runner
package composed
import gd "godot:godot"
import knet "godot:kit/net"

Gun :: struct { ammo: u16 `gd:"replicate"` }
// predicted, OWNER-THREADED (reads its wielder): the ^Runner 2nd param is not a wire arg.
@(gd_command="predict")
gun_fire :: proc(g: ^Gun, owner: ^Runner, dx: i32) -> bool { if owner.hp == 0 {return false}; g.ammo -= 1; return true }
// plain (non-predicted), no owner, no args.
@(gd_command)
gun_reload :: proc(g: ^Gun) -> bool { g.ammo = 8; return true }

Runner :: struct {
	owner:     gd.Node,
	net_id:    knet.Net_Id,
	hp:        u8 `gd:"replicate"`,
	primary:   Gun,   // -> primary_fire / primary_reload
	secondary: Gun,   // -> secondary_fire / secondary_reload
}
ODIN
if ! "$SGEN" "$vc" -godot:"$ROOT" >/dev/null 2>&1; then fail "verb-composition (same-package) must resolve, not error"; fi
vgen="$vc/odin_godot_scripts.gen.odin"
grep -q "RUNNER_CMD_PRIMARY_FIRE :: knet.Cmd_Id" "$vgen" || fail "composed command index const RUNNER_CMD_PRIMARY_FIRE missing"
grep -q "RUNNER_CMD_SECONDARY_FIRE :: knet.Cmd_Id" "$vgen" || fail "second instance must get its own path-prefixed index (SECONDARY_FIRE)"
grep -q "RUNNER_CMD_PRIMARY_RELOAD :: knet.Cmd_Id" "$vgen" || fail "plain composed command RUNNER_CMD_PRIMARY_RELOAD missing"
grep -q "return gun_fire(&self.primary, self, _a0)" "$vgen" || fail "decode thunk must route into &self.primary and pass self (owner)"
grep -q "return gun_reload(&self.secondary)" "$vgen" || fail "plain composed thunk must route into &self.secondary with no owner/args"
grep -q "runner_secondary_fire_cmd :: proc" "$vgen" || fail "issue wrapper must be named per-entity (runner_secondary_fire_cmd)"
grep -q '{name = "primary_fire", id = RUNNER_CMD_PRIMARY_FIRE, predict = true' "$vgen" || fail "composed predict flag (and stable wire id) not carried"
grep -q '{name = "primary_reload", id = RUNNER_CMD_PRIMARY_RELOAD, predict = false' "$vgen" || fail "plain composed command must have predict = false"
grep -q "offset_of(Runner, primary) + offset_of(type_of(Runner{}.primary), ammo)" "$vgen" || fail "the block's replicated state must compose upward beside its verbs"

# ---- fixture 8: VERB composition — IMPORTED block (qualifier + import) --------
# A block imported from a godot: package: the generated file must IMPORT that package and
# qualify the routed proc (play.gun_fire). Owner is the poly `^$E` (a library block that
# can't name the entity) — scriptgen still fills it with `self`.
mkdir -p "$coll/play"
cat >"$coll/play/gun.odin" <<'ODIN'
package play
Gun :: struct { ammo: u16 `gd:"replicate"` }
@(gd_command="predict")
gun_fire :: proc(g: ^Gun, owner: ^$E, dx: i32) -> bool { g.ammo -= 1; return true }
ODIN
ic="$work/impcmd"
mkdir -p "$ic"
cat >"$ic/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class Mob
package impcmd
import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Mob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     u8 `gd:"replicate"`,
	gun:    play.Gun,
}
ODIN
if ! "$SGEN" "$ic" -godot:"$coll" >/dev/null 2>&1; then fail "verb-composition (imported block) must resolve, not error"; fi
icgen="$ic/odin_godot_scripts.gen.odin"
grep -q 'import play "godot:play"' "$icgen" || fail "imported block's package must be imported into the generated file"
grep -q "return play.gun_fire(&self.gun, self, _a0)" "$icgen" || fail "imported composed thunk must qualify (play.) and route + thread owner"
grep -q "MOB_CMD_GUN_FIRE :: knet.Cmd_Id" "$icgen" || fail "imported composed command index MOB_CMD_GUN_FIRE missing"

# ---- fixture 9: the REAL play.Gun library block composes into a consumer ------
# Embeds godot:play's Gun (state + the gun_fire verb) and asserts the whole block drops in: its
# @(gd_command) verb hoists onto the entity (imported + qualified, NO owner param), its Gun_Def
# knob-blob and its plain Gun_Mode mode field both compose into the descriptor.
pg="$work/playgun"
mkdir -p "$pg"
cat >"$pg/turret.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Turret
package playgun
import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Turret :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	hp:     u8 `gd:"replicate"`,
	weapon: play.Gun,   // the real library block: mag/reload/jam state + the gun_fire verb drop in
}
ODIN
if ! "$SGEN" "$pg" -godot:"$ROOT" >/dev/null 2>&1; then fail "the real play.Gun block must compose into a consumer, not error"; fi
tgen="$pg/odin_godot_scripts.gen.odin"
grep -q 'import play "godot:play"' "$tgen" || fail "play.Gun consumer must import godot:play"
grep -q "return play.gun_fire(&self.weapon, _a0, _a1)" "$tgen" || fail "play.gun_fire must route into &self.weapon (imported, qualified, no owner)"
grep -q "TURRET_CMD_WEAPON_FIRE :: knet.Cmd_Id" "$tgen" || fail "play.Gun's verb must hoist as TURRET_CMD_WEAPON_FIRE"
grep -q "size_of(type_of(Turret{}.weapon.def))" "$tgen" || fail "the Gun_Def knob-blob must replicate through the embed"
grep -q "offset_of(type_of(Turret{}.weapon), mode)" "$tgen" || fail "the Gun_Mode mode field must compose through the block"

# ---- fixture 10: METHOD composition — a block's @(gd_method)/@(gd_rpc) hoist ------
# The engine-facing dual of verb composition: a @(gd_method) (owner-threaded, with a return) and a
# @(gd_rpc) whose receiver is an embedded sub-struct register on the ENTITY's method table under a
# path-prefixed name, the trampoline routed into &self.<field>.
mc="$work/methodcomp"
mkdir -p "$mc"
cat >"$mc/robot.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Robot
package methodcomp
import gd "godot:godot"
import knet "godot:kit/net"

Gear :: struct { charge: i32 `gd:"replicate"` }
// owner-threaded @(gd_method) with a return (the ^Robot 2nd param is not a Variant arg).
@(gd_method)
gear_level :: proc(g: ^Gear, owner: ^Robot, bonus: i32) -> i64 { return i64(g.charge + bonus) }
// @(gd_rpc) (implies method), no owner, no args.
@(gd_rpc)
gear_ping :: proc(g: ^Gear) {}

Robot :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	hp:     u8 `gd:"replicate"`,
	gear:   Gear,   // -> gear_level (method) + gear_ping (method + rpc) hoist onto Robot
}
ODIN
if ! "$SGEN" "$mc" -godot:"$ROOT" >/dev/null 2>&1; then fail "method-composition must resolve, not error"; fi
mgen="$mc/odin_godot_scripts.gen.odin"
grep -q '{name = "gear_level", trampoline = _robot_m_gear_level' "$mgen" || fail "composed method must register under the path-prefixed name gear_level"
grep -q "gear_level(&self.gear, self, i32(_a0))" "$mgen" || fail "method trampoline must route into &self.gear, thread the owner (self), and pass the arg"
grep -q '{name = "gear_ping", trampoline = _robot_m_gear_ping' "$mgen" || fail "@(gd_rpc) implies a composed method (gear_ping) too"
grep -q "gear_ping(&self.gear)" "$mgen" || fail "no-owner composed method must route into &self.gear with no self/args"
grep -q '{method = "gear_ping"' "$mgen" || fail "the composed @(gd_rpc) must register its RPC under the namespaced method name"

# ---- fixture 11: play.Ability — two cooldown-cast blocks on one entity ---------
# A second real library block (cooldown-gated cast): two instances prove the composed cast verbs
# get distinct path-prefixed names and the cooldown state composes through each embed.
ab="$work/abilcomp"
mkdir -p "$ab"
cat >"$ab/caster.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Caster
package abilcomp
import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Caster :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	hp:     u8 `gd:"replicate"`,
	lob:    play.Ability,   // -> caster_lob_cast
	cone:   play.Ability,   // -> caster_cone_cast (distinct)
}
ODIN
if ! "$SGEN" "$ab" -godot:"$ROOT" >/dev/null 2>&1; then fail "play.Ability must compose into a consumer, not error"; fi
agen="$ab/odin_godot_scripts.gen.odin"
grep -q "CASTER_CMD_LOB_CAST :: knet.Cmd_Id" "$agen" || fail "first ability's cast must hoist as CASTER_CMD_LOB_CAST"
grep -q "CASTER_CMD_CONE_CAST :: knet.Cmd_Id" "$agen" || fail "second ability instance must get its own path-prefixed cast (CONE_CAST)"
grep -q "return play.ability_cast(&self.lob, _a0, _a1)" "$agen" || fail "cast thunk must route into &self.lob (imported, qualified, no owner)"
# The knob is FLAT since play went canonical-shelf: play.Ability_Def is gone
# (the def table is kcombat's; a string name can never ride a replicated
# blob), and the block replicates a bare cooldown beside its countdown.
grep -q "offset_of(type_of(Caster{}.lob), cooldown)" "$agen" || fail "the flat cooldown knob must replicate through the embed"
grep -q "offset_of(type_of(Caster{}.lob), cd)" "$agen" || fail "the cooldown cd must compose through the block"

# ---- fixture 12: play.Channel — owner-streamed block state + a composed claim ----
# The third authority model through an embed: the block's `gd:"owner"` fields must carry
# the .Owner_Stream flag through composition, and its plain claim command must hoist.
ch="$work/chancomp"
mkdir -p "$ch"
cat >"$ch/hero.odin" <<'ODIN'
//gd:extends Node2D
//gd:class HeroC
package chancomp
import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

HeroC :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	hp:     u8 `gd:"replicate"`,
	rev:    play.Channel,   // -> heroc_rev_claim; target/pct owner-streamed through the embed
}
ODIN
if ! "$SGEN" "$ch" -godot:"$ROOT" >/dev/null 2>&1; then fail "play.Channel must compose into a consumer, not error"; fi
cgen="$ch/odin_godot_scripts.gen.odin"
grep -q 'offset_of(type_of(HeroC{}.rev), target).*flags = {.Owner_Stream}' "$cgen" || fail "the channel's owner flag must carry through the embed (rev.target)"
grep -q 'offset_of(type_of(HeroC{}.rev), pct).*flags = {.Owner_Stream}' "$cgen" || fail "rev.pct must be owner-streamed through the embed"
grep -q "HERO_C_CMD_REV_CLAIM :: knet.Cmd_Id" "$cgen" || fail "the channel's claim must hoist as HERO_C_CMD_REV_CLAIM"
grep -q "return play.channel_claim(&self.rev, _a0)" "$cgen" || fail "claim thunk must route into &self.rev with the wire target"
grep -q '{name = "rev_claim", id = HERO_C_CMD_REV_CLAIM, predict = false' "$cgen" || fail "the claim must be a PLAIN command (no prediction)"

# ---- fixture 13: play.Health — a VERB-FREE block composes state only ----------
# Health ships no @(gd_command) (damage is host-internal, not client intent): its hp/max must
# compose into the descriptor, its Edge scratch must stay off the wire, and NO command artifacts
# may appear for it.
hl="$work/healthcomp"
mkdir -p "$hl"
cat >"$hl/pawn.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Pawn
package healthcomp
import gd "godot:godot"
import knet "godot:kit/net"
import play "godot:play"

Pawn :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	health: play.Health,   // verb-free: state + edge only
}
ODIN
if ! "$SGEN" "$hl" -godot:"$ROOT" >/dev/null 2>&1; then fail "play.Health must compose into a consumer, not error"; fi
hgen="$hl/odin_godot_scripts.gen.odin"
grep -q "offset_of(type_of(Pawn{}.health), hp)" "$hgen" || fail "health.hp must compose into the descriptor"
grep -q "offset_of(type_of(Pawn{}.health), max)" "$hgen" || fail "health.max must compose into the descriptor"
grep -q "offset_of(type_of(Pawn{}.health), seen)" "$hgen" && fail "the Edge scratch must stay OFF the wire"
grep -q "_CMD_" "$hgen" && fail "a verb-free block must hoist NO commands"

# ---- fixture 14: THE METHOD TRAP is a build error -------------------------------
# An attributed proc receiving a DIFFERENT script struct, written in a class's
# HOME file, used to bind to nothing SILENTLY (dead shop-card clicks for a day).
# scriptgen must now refuse the build and say where to move it.
mt="$work/methodtrap"
mkdir -p "$mt"
cat >"$mt/game.odin" <<'ODIN'
//gd:extends Node
//gd:class Game
package methodtrap
import gd "godot:godot"

Game :: struct {
	owner: gd.Node,
}
ODIN
cat >"$mt/panel.odin" <<'ODIN'
//gd:extends Control
//gd:class Panel
package methodtrap
import gd "godot:godot"

Panel :: struct {
	owner: gd.Control,
}

@(gd_method)
game_on_click :: proc(self: ^Game) {} // ^Game method in Panel's home = the trap
ODIN
if "$SGEN" "$mt" -godot:"$ROOT" >"$mt/out.log" 2>&1; then fail "a ^Game @(gd_method) in Panel's home file must FAIL the build"; fi
grep -q "binds to NOTHING" "$mt/out.log" || fail "the method-trap error must name the fix (move to a headerless file)"

# ---- fixture 15: HOST MIGRATION halves -> kboot.boot_migration's table ---------
# The four seams pair on the shell by exact name: thunks + the Succ_Hooks table
# are generated, and the events dispatch grows the boot_migrate_pending tail
# (mechanics AFTER the words halves). Wrong shape, `_then`, and a prefix typo
# are all teaching errors, never silent no-fires.
sc="$work/succession"
mkdir -p "$sc"
cat >"$sc/depot.odin" <<'ODIN'
//gd:extends Node
//gd:class Depot
package succ
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"

Depot :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_half)
depot_backup :: proc(self: ^Depot, w: ^knet.Writer) {}
@(gd_half)
depot_took_over :: proc(self: ^Depot, r: ^knet.Reader) {}
@(gd_half)
depot_wiped :: proc(self: ^Depot) {}
@(gd_half)
depot_migrating :: proc(self: ^Depot, step: kboot.Migrate_Step, target: string, try: int) {}
@(gd_half)
depot_welcomed :: proc(self: ^Depot, me: knet.Player_Id) {}
ODIN
if ! "$SGEN" "$sc" -godot:"$ROOT" >/dev/null 2>&1; then fail "migration halves must resolve, not error"; fi
sgen="$sc/odin_godot_scripts.gen.odin"
grep -q "_depot_succ_backup :: proc(game: rawptr, w: ^knet.Writer)" "$sgen" || fail "backup thunk not generated"
grep -q "depot_succ_hooks := kboot.Succ_Hooks" "$sgen" || fail "the Succ_Hooks table not generated"
grep -q "took_over = _depot_succ_took_over" "$sgen" || fail "took_over not wired into the table"
grep -q "migrating = _depot_succ_migrating" "$sgen" || fail "migrating not wired into the table"
grep -q "kboot.boot_migrate_pending(&self.boot)" "$sgen" || fail "the events tail must drain the kit's noted succession"
grep -q "depot_events :: proc" "$sgen" || fail "declaring migration must emit the events proc (the drain rides it)"

# a migration-only shell (no event halves) still gets the events proc + drain
so="$work/succonly"
mkdir -p "$so"
cat >"$so/vault.odin" <<'ODIN'
//gd:extends Node
//gd:class Vault
package succonly
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"

Vault :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_half)
vault_backup :: proc(self: ^Vault, w: ^knet.Writer) {}
ODIN
if ! "$SGEN" "$so" -godot:"$ROOT" >/dev/null 2>&1; then fail "a migration-only shell must resolve"; fi
ogen="$so/odin_godot_scripts.gen.odin"
grep -q "vault_events :: proc" "$ogen" || fail "migration alone must still emit the events proc"
grep -q "kboot.boot_migrate_pending(&self.boot)" "$ogen" || fail "migration-only events proc must carry the drain"

# wrong shape = a teaching error naming the expected signature
sb="$work/succbad"
mkdir -p "$sb"
cat >"$sb/depot.odin" <<'ODIN'
//gd:extends Node
//gd:class Depot
package succbad
import gd "godot:godot"
import kboot "godot:kit/boot"

Depot :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_half)
depot_backup :: proc(self: ^Depot, blob: []u8) {}
ODIN
if "$SGEN" "$sb" -godot:"$ROOT" >"$sb/out.log" 2>&1; then fail "a wrong-shape migration half must FAIL the build"; fi
grep -q "knet.Writer" "$sb/out.log" || fail "the shape error must spell the expected ^knet.Writer param"

# `_then` on a migration half = a teaching error (fixed roles, no authority narrowing)
st="$work/succthen"
mkdir -p "$st"
cat >"$st/depot.odin" <<'ODIN'
//gd:extends Node
//gd:class Depot
package succthen
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"

Depot :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_half)
depot_took_over_then :: proc(self: ^Depot, r: ^knet.Reader) {}
ODIN
if "$SGEN" "$st" -godot:"$ROOT" >"$st/out.log" 2>&1; then fail "a migration _then must FAIL the build"; fi
grep -q "migration halves have no" "$st/out.log" || fail "the _then error must teach the fixed-role rule"

# A prefix typo. It used to need an EDIT-DISTANCE gate to be noticed at all
# (one edit from the shell's snake, or silence); a declared half is noticed
# because it is declared, however far the spelling drifted.
sn="$work/succnear"
mkdir -p "$sn"
cat >"$sn/depot.odin" <<'ODIN'
//gd:extends Node
//gd:class Depot
package succnear
import gd "godot:godot"
import kboot "godot:kit/boot"
import knet "godot:kit/net"

Depot :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

@(gd_half)
depo_backup :: proc(self: ^Depot, w: ^knet.Writer) {}
ODIN
if "$SGEN" "$sn" -godot:"$ROOT" >"$sn/out.log" 2>&1; then fail "a near-miss migration prefix must FAIL the build"; fi
grep -q "pairs with nothing" "$sn/out.log" || fail "a typo'd migration half must be refused, not silently dropped"
grep -q "depot_backup" "$sn/out.log" || fail "the refusal must name the migration half the author meant"

# ---- fixture: the silent-footgun lints (raw-verb call, tag namespace typo,
# any_seat off the sim lane) — each compiles fine as Odin and used to
# misbehave silently; each is a named build error now. -----------------------
fg="$work/footguns"
mkdir -p "$fg"
cat >"$fg/chest.odin" <<'ODIN'
//gd:extends Node
//gd:class Chest
package fg
import gd "godot:godot"
import knet "godot:kit/net"

Chest :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	gold:   i32 `gd:"replicate"`,
}

@(gd_command = "predict")
chest_take :: proc(self: ^Chest, n: i32) -> bool {
	if self.gold < n {return false}
	self.gold -= n
	return true
}
ODIN
cat >"$fg/game.odin" <<'ODIN'
//gd:extends Node
//gd:class FgGame
package fg
import gd "godot:godot"
import knet "godot:kit/net"

FgGame :: struct {
	owner: gd.Node,
	hp:    i32 `gs:"replicate"`, // the NAMESPACE typo: not a gd tag at all
}

fg_game_ready :: proc(self: ^FgGame) {}
ODIN
cat >"$fg/loot.odin" <<'ODIN'
package fg

// The raw-verb call: bypasses the wrapper — no _then, no validation.
loot_all :: proc(c: ^Chest) {
	chest_take(c, 5)
}
ODIN
out="$("$SGEN" "$fg" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "the footgun fixture must fail the build"
echo "$out" | grep -q "direct call skips the framework" || fail "raw-verb call must error pointing at the _cmd wrapper"
echo "$out" | grep -q 'namespace "gs" is not' || fail "the gs: namespace typo must be named"

# any_seat on a class that doesn't tick: a sim-lane declaration misused.
as="$work/anyseat"
mkdir -p "$as"
cat >"$as/door.odin" <<'ODIN'
//gd:extends Node
//gd:class Door
package as
import gd "godot:godot"
import knet "godot:kit/net"

Door :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	open:   u8 `gd:"replicate"`,
}

@(gd_command = "any_seat")
door_toggle :: proc(self: ^Door) -> bool {
	self.open = 1 - self.open
	return true
}
ODIN
if "$SGEN" "$as" -godot:"$ROOT" >"$as/out.log" 2>&1; then fail "any_seat on a coop class must FAIL the build"; fi
grep -q "sim-lane declaration" "$as/out.log" || fail "the any_seat misuse must say it is a sim-lane declaration"

# ---- fixture: generated acid probes — per entity kind, count/my/field
# @(gd_method)s the test driver reads replicated state through; a
# hand-written proc wearing a probe's name suppresses it (census-style). ----
pr="$work/probes"
mkdir -p "$pr"
cat >"$pr/game.odin" <<'ODIN'
//gd:extends Node
//gd:class PrGame
package pr
import gd "godot:godot"
import knet "godot:kit/net"
import kboot "godot:kit/boot"

PrGame :: struct {
	owner:      gd.Node,
	boot:       kboot.Boot,
	mob_scene:  ^gd.Resource `gd:"entity=Mob:1"`,
}

// The suppression: a hand-written probe wearing the generated name wins.
@(gd_method)
probe_mob_hp :: proc(self: ^PrGame, id: gd.Int) -> gd.Int { return 42 }
ODIN
cat >"$pr/mob.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Mob
package pr
import gd "godot:godot"
import knet "godot:kit/net"

Mob_Pose :: struct { x, y: f32 `gd:"replicate,interp"` }

Mob :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	angry:  bool `gd:"replicate"`,
	pose:   Mob_Pose,
	tag:    [4]u8 `gd:"replicate"`, // compound: no generated probe
}
ODIN
"$SGEN" "$pr" -godot:"$ROOT" >"$pr/out.log" 2>&1 || fail "the probes fixture must generate"
gen="$pr/odin_godot_scripts.gen.odin"
grep -q "_pr_game_probe_mob_count" "$gen" || fail "probe_mob_count must generate"
grep -q "_pr_game_probe_my_mob" "$gen" || fail "probe_my_mob must generate"
grep -q "_pr_game_probe_mob_angry" "$gen" || fail "bool fields get a 1/0 probe"
grep -q "_pr_game_probe_mob_pose_x" "$gen" || fail "nested scalar fields probe under their path"
grep -q "_pr_game_probe_mob_hp :: proc" "$gen" && fail "a hand-written probe name must suppress the generated one"
grep -q "_pr_game_probe_mob_tag" "$gen" && fail "compound fields must not probe"

# ---- fixture: the profile declaration form (gd:"profile=T") -----------------
# The tag on the Session field IS session_profile_install: the install lands
# in the generated ready thunk, the row's field-by-field shape folds into
# NET_FINGERPRINT (same-size layout drift must MOVE the hash — that drift
# used to scramble rows past the version door), and the misuses are loud.
pf="$work/profile"
mkdir -p "$pf"
cat >"$pf/game.odin" <<'ODIN'
//gd:extends Node
//gd:class PfGame
package pf
import gd "godot:godot"
import ksess "godot:kit/session"

Loadout :: struct { look: u8, iron: u8, ready: bool }

PfGame :: struct {
	owner: gd.Node,
	ses:   ksess.Session `gd:"profile=Loadout"`,
}

pf_game_ready :: proc(self: ^PfGame) {}
ODIN
"$SGEN" "$pf" -godot:"$ROOT" >"$pf/out.log" 2>&1 || fail "the profile fixture must generate"
grep -q 'session_profile_install(&(cast(^PfGame)self_raw).ses, Loadout)' "$pf/odin_godot_scripts.gen.odin" \
	|| fail "the ready thunk must install the declared profile row"
grep -q "_register_net_fingerprint" "$pf/odin_godot_guard.gen.odin" \
	|| fail "a profile declaration alone is a kit wire surface (fingerprint default must register)"
fp1=$(grep -oE "NET_FINGERPRINT :: u64\(0x[0-9a-f]+\)" "$pf/odin_godot_guard.gen.odin")
# Swap two same-size fields: the struct's SIZE is unchanged, only the layout —
# exactly the drift the raw install could never catch.
cat >"$pf/game.odin" <<'ODIN'
//gd:extends Node
//gd:class PfGame
package pf
import gd "godot:godot"
import ksess "godot:kit/session"

Loadout :: struct { iron: u8, look: u8, ready: bool }

PfGame :: struct {
	owner: gd.Node,
	ses:   ksess.Session `gd:"profile=Loadout"`,
}

pf_game_ready :: proc(self: ^PfGame) {}
ODIN
"$SGEN" "$pf" -godot:"$ROOT" >"$pf/out2.log" 2>&1 || fail "the reordered profile fixture must generate"
fp2=$(grep -oE "NET_FINGERPRINT :: u64\(0x[0-9a-f]+\)" "$pf/odin_godot_guard.gen.odin")
[[ -n "$fp1" && -n "$fp2" && "$fp1" != "$fp2" ]] \
	|| fail "same-size profile layout drift must move NET_FINGERPRINT (got $fp1 then $fp2)"

# The misuses, all three loud in one run: the tag off the Session field, a row
# type that resolves to nothing, and a class with no ready to wire.
pe="$work/proferr"
mkdir -p "$pe"
cat >"$pe/game.odin" <<'ODIN'
//gd:extends Node
//gd:class PeGame
package pe
import gd "godot:godot"
import ksess "godot:kit/session"

Loadout :: struct { look: u8 }

PeGame :: struct {
	owner: gd.Node,
	bad:   i32 `gd:"profile=Loadout"`,
	ses:   ksess.Session `gd:"profile=Nope"`,
}
ODIN
"$SGEN" "$pe" -godot:"$ROOT" >"$pe/out.log" 2>&1
rc=$?
[[ $rc -ne 0 ]] || fail "the profile-misuse fixture must fail the build"
grep -q "belongs on the ksess.Session field" "$pe/out.log" || fail "a profile tag off the Session field must say where it goes"
grep -q 'no struct "Nope"' "$pe/out.log" || fail "an unresolvable row type must be named"
grep -q "needs a \`pe_game_ready\`" "$pe/out.log" || fail "a profile without a ready must ask for one"

# ---- fixture: the @(gd_message) typed app-message form ----------------------
# One annotated handler becomes the game-owned Typed_Route storage, a
# `<class>_messages` registration proc, and two send doors (peer- and
# seat-addressed) over the runtime typed-route API. The payload's field-by-field
# shape folds into NET_FINGERPRINT — a drifted payload must MOVE the hash, like a
# profile row (same-size layout drift used to scramble a message past the door).
mg="$work/message"
mkdir -p "$mg"
cat >"$mg/game.odin" <<'ODIN'
//gd:extends Node
//gd:class MgGame
package mg
import gd "godot:godot"
import knet "godot:kit/net"

Ping :: struct { seq: u16, hop: u16 }

TAG_PING :: u8(5)

MgGame :: struct {
	owner: gd.Node,
}

@(gd_message="TAG_PING")
mg_game_ping :: proc(self: ^MgGame, from: knet.Player_Id, msg: Ping) {}
ODIN
"$SGEN" "$mg" -godot:"$ROOT" >"$mg/out.log" 2>&1 || { cat "$mg/out.log"; fail "the @(gd_message) fixture must generate"; }
gen="$mg/odin_godot_scripts.gen.odin"
grep -q "_mg_game_ping_route: ksess.Typed_Route(Ping)" "$gen" || fail "the game-owned Typed_Route storage is missing"
grep -q "mg_game_messages :: proc(self: ^MgGame, s: ^ksess.Session)" "$gen" || fail "the <class>_messages registration proc is missing"
grep -q "session_app_listen(s, TAG_PING, &_mg_game_ping_route, self" "$gen" || fail "the route must register under the declared tag"
grep -q "mg_game_ping_send :: proc(s: ^ksess.Session, msg: Ping, to_peer: ksess.Peer_Id" "$gen" || fail "the peer-addressed send door is missing"
grep -q "session_app_send_typed(s, TAG_PING, msg, to_peer, channel)" "$gen" || fail "the send door must frame under the declared tag"
grep -q "mg_game_ping_send_to :: proc(s: ^ksess.Session, player: knet.Player_Id, msg: Ping)" "$gen" || fail "the seat-addressed send door is missing"
grep -q "session_app_send_typed_to(s, player, TAG_PING, msg)" "$gen" || fail "the seat-addressed door must resolve on the authority"
grep -q "_register_net_fingerprint" "$mg/odin_godot_guard.gen.odin" || fail "a @(gd_message) alone is a wire surface (the fingerprint default must register)"
fp1=$(grep -oE "NET_FINGERPRINT :: u64\(0x[0-9a-f]+\)" "$mg/odin_godot_guard.gen.odin")
# Reorder the payload's two same-size fields: SIZE unchanged, only the layout —
# the drift a type NAME can't stand in for. The folded shape must move the hash.
cat >"$mg/game.odin" <<'ODIN'
//gd:extends Node
//gd:class MgGame
package mg
import gd "godot:godot"
import knet "godot:kit/net"

Ping :: struct { hop: u16, seq: u16 }

TAG_PING :: u8(5)

MgGame :: struct {
	owner: gd.Node,
}

@(gd_message="TAG_PING")
mg_game_ping :: proc(self: ^MgGame, from: knet.Player_Id, msg: Ping) {}
ODIN
"$SGEN" "$mg" -godot:"$ROOT" >"$mg/out2.log" 2>&1 || fail "the reordered @(gd_message) fixture must generate"
fp2=$(grep -oE "NET_FINGERPRINT :: u64\(0x[0-9a-f]+\)" "$mg/odin_godot_guard.gen.odin")
[[ -n "$fp1" && -n "$fp2" && "$fp1" != "$fp2" ]] || fail "a drifted @(gd_message) payload must move NET_FINGERPRINT (got $fp1 then $fp2)"

# The misuse: a tagless @(gd_message) is loud (the tag is the game's scarce
# SES_APP byte — scriptgen can't invent it).
mgerr="$work/msgerr"
mkdir -p "$mgerr"
cat >"$mgerr/game.odin" <<'ODIN'
//gd:extends Node
//gd:class MeGame
package me2
import gd "godot:godot"
import knet "godot:kit/net"

Ping :: struct { seq: u16 }

MeGame :: struct { owner: gd.Node }

@(gd_message)
me_game_ping :: proc(self: ^MeGame, from: knet.Player_Id, msg: Ping) {}
ODIN
"$SGEN" "$mgerr" -godot:"$ROOT" >"$mgerr/out.log" 2>&1
[[ $? -ne 0 ]] || fail "a tagless @(gd_message) must fail the build"
grep -q "needs the SES_APP tag" "$mgerr/out.log" || fail "a tagless message must name the tag it needs"

# ---- fixture: the two validation tiers, made one ---------------------------
# `gd:"export,rnage=0:100"` used to sail past scriptgen (the export-spec loop
# had no default arm) and die at BOOT as a record_error on a field that had
# silently lost its hint, while the identical typo behind any OTHER first token
# failed the build. Same tag, two latencies. The spec NAMES now come from
# godot:decl's EXPORT_SPECS; the runtime still owns what each one MEANS.
es="$work/exportspec"
mkdir -p "$es"
cat >"$es/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class EsThing
package es
import gd "godot:godot"

EsThing :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export,rnage=0:100"`,
	mp:    i32 `gd:"export,wibble=3"`,
}
ODIN
out="$("$SGEN" "$es" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a misspelled export spec must fail the BUILD, not wait for boot"
echo "$out" | grep -q 'unknown export spec "rnage" — did you mean `range`' \
	|| fail "a one-edit typo must name the spec it meant"
echo "$out" | grep -q 'unknown export spec "wibble" — the set is:' \
	|| fail "a spec with no near match must list the whole set"
echo "$out" | grep -q "global_dir, resource, array, dict" \
	|| fail "the listed set must be the EXPORT_SPECS projection, not a hand-kept excerpt"
# Every real spec still passes — the gate refuses typos, not the language.
cat >"$es/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class EsThing
package es
import gd "godot:godot"

EsThing :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export,range=0:100,group=Combat,default=10"`,
	note:  gd.String `gd:"export,multiline,subgroup=Text"`,
	path:  gd.String `gd:"export,file=*.png"`,
}
ODIN
"$SGEN" "$es" -godot:"$ROOT" >/dev/null 2>&1 || fail "the real export specs must still build"

# ---- fixture: the unknown-token gate reaches NESTED fields ------------------
# Top-level, `gd:"replciate"` has been a hard error for as long as
# decl.field_expected has existed. One comma of depth used to turn that into
# silence: the nested walk handled replicate/backup, deferred export/onready to
# the runtime, and let everything else fall out the bottom unremarked — so a
# typo inside an embedded block was a field that simply never replicated, with
# no diagnostic in either half of the toolchain. Blocks are where deep tags
# live, which is what made this the cheapest door into the recorded
# gun-that-never-replicated failure.
nt="$work/nesttag"
mkdir -p "$nt"
cat >"$nt/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class NtThing
package nt
import gd "godot:godot"
import knet "godot:kit/net"

Inner :: struct {
	hp: i32 `gd:"replciate"`,
}
Blk :: struct { z: i32 `gd:"replicate"` }
Outer :: struct { using i: Inner, sub: Blk `gd:"manual"` }

NtThing :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	using o: Outer,
}
ODIN
out="$("$SGEN" "$nt" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a typo'd tag on a NESTED field must fail the build, not vanish"
echo "$out" | grep -q 'NtThing.o.i.hp: unknown gd tag `replciate`' \
	|| fail "the nested unknown-tag refusal must name the field by its full access path"
echo "$out" | grep -q 'expected `export`, `onready=PATH`' \
	|| fail "the nested refusal must list the vocabulary from decl.field_expected, not a local excerpt"
# `gd:"manual"` nested is the same silence wearing a KNOWN token: it matched no
# arm, so the nested walk skipped the sub-block entirely — every predict field,
# backup and tick under it gone, no error. Loud now; whether it should instead
# be made to WORK one level down is a shelf-design call, and the message says
# where to put the embed meanwhile.
echo "$out" | grep -q 'NtThing.o.sub: `gd:"manual"` only works on the class'"'"'s OWN embed' \
	|| fail "a nested gd:\"manual\" must be refused, not silently skip the sub-block"
# The control: the same shapes with everything spelled right still build.
cat >"$nt/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class NtThing
package nt
import gd "godot:godot"
import knet "godot:kit/net"

Inner :: struct {
	hp: i32 `gd:"replicate"`,
}
Outer :: struct { using i: Inner, dressing: i32 `gd:"export,range=0:9"` }

NtThing :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	using o: Outer,
}
ODIN
"$SGEN" "$nt" -godot:"$ROOT" >/dev/null 2>&1 || fail "correct nested tags (and deferred exports) must still build"

# ---- fixture: spec ARITY, the other half of the same silent-hint bug --------
# A perfectly spelled spec in the wrong FORM slipped through the gate above:
# `multiline=true` reads like a boolean and the runtime drops the value, and
# bare `range` is a slider with no bounds that used to die at BOOT. Both forms
# now come off decl.EXPORT_SPECS's bare/value columns, which until this item
# were documentation nothing read.
ar="$work/arity"
mkdir -p "$ar"
cat >"$ar/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class ArThing
package ar
import gd "godot:godot"

ArThing :: struct {
	owner: gd.Node,
	note:  gd.String `gd:"export,multiline=true"`,
	hp:    i32 `gd:"export,range"`,
}
ODIN
out="$("$SGEN" "$ar" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a spec in an illegal form must fail the BUILD"
echo "$out" | grep -q '`multiline` takes no value' || fail "a value on a bare-only spec must say so"
echo "$out" | grep -q '`range` needs a value' || fail "a bare value-only spec must say so"
# Both legal forms of a both-ways spec still build — `file` is the reason the
# columns are two bools and not one tri-state enum.
cat >"$ar/thing.odin" <<'ODIN'
//gd:extends Node
//gd:class ArThing
package ar
import gd "godot:godot"

ArThing :: struct {
	owner: gd.Node,
	any:   gd.String `gd:"export,file"`,
	png:   gd.String `gd:"export,file=*.png"`,
}
ODIN
"$SGEN" "$ar" -godot:"$ROOT" >/dev/null 2>&1 || fail "both legal forms of `file` must still build"

# THE EXPORT-SPEC PROJECTION lives in tests/reflect_register now, not here.
# This file used to extract walk_field's and parse_hint_spec's case labels with
# awk and assert them equal to decl.EXPORT_SPECS — a stopgap by the agent who
# could not edit runtime/, and one that could SEE the lists drift but not stop
# them, broke on any reformatting of either switch, and proved only that a label
# had been TYPED. walk_field now DISPATCHES on the table (unknown name refused
# before either switch, then .Meta/.Hint selects which one), so the name set
# cannot drift at all; what remains to prove is that each name MEANS something,
# which is a claim about the runtime's behavior and belongs in a test that runs
# it. tests/reflect_register's `export_spec_vocabulary_is_implemented` walks a
# fixture spelling every spec in every form the columns declare legal and
# requires zero registration errors.

# ---- fixture: //gd:extends is cross-checked against the owner handle --------
# The two spellings of one fact used to be free to disagree. The dangerous
# direction is a handle NARROWER than the base — it registers a plain Node and
# then reaches through the handle with gd.node2d_* calls into an object that
# never was one. The WIDER direction stays legal (most of examples/ declares
# `//gd:extends CharacterBody2D` on an `owner: gd.Node2d`).
xt="$work/extends"
mkdir -p "$xt"
cat >"$xt/bad.odin" <<'ODIN'
//gd:extends Node
//gd:class XtBad
package xt
import gd "godot:godot"

XtBad :: struct {
	owner: gd.Node2d,
}
ODIN
out="$("$SGEN" "$xt" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a handle NARROWER than //gd:extends must fail the build"
echo "$out" | grep -q '`//gd:extends Node` but `owner: gd.Node2d` is a Node2D handle' \
	|| fail "the extends mismatch must name BOTH the comment and the field type"
echo "$out" | grep -q "Write \`//gd:extends Node2D\`" || fail "the refusal must name the fix"
# The widening direction, and the ancestor chains that reach through the
# hand-written roots (Ref_Counted :: ^Object) — all must stay silent.
rm "$xt/bad.odin"
cat >"$xt/ok.odin" <<'ODIN'
//gd:extends CharacterBody2D
//gd:class XtOk
package xt
import gd "godot:godot"

XtOk :: struct {
	owner: gd.Node2d,
}
ODIN
cat >"$xt/ok2.odin" <<'ODIN'
//gd:extends RefCounted
//gd:class XtOk2
package xt
import gd "godot:godot"

XtOk2 :: struct {
	owner: gd.Object,
}
ODIN
# No marker at all: the base is DERIVED from the handle rather than defaulting
# to "Node" — one declaration, not two.
cat >"$xt/derived.odin" <<'ODIN'
//gd:class XtDerived
package xt
import gd "godot:godot"

XtDerived :: struct {
	owner: gd.Area2d,
}
ODIN
"$SGEN" "$xt" -godot:"$ROOT" >/dev/null 2>&1 || fail "a WIDER owner handle (and an ancestor chain through Object) must stay silent"
grep -q 'base = "Area2D"' "$xt/odin_godot_scripts.gen.odin" || fail "a marker-less script must derive its base from the owner handle"

# ---- fixture: the .Boot match is a package, not a suffix -------------------
# `strings.has_suffix(ftype, ".Boot")` was the loosest match in the language:
# ANY package's Boot declared the game shell and got the four transport
# forwards generated onto a class that owns no session.
bt="$work/boot"
mkdir -p "$bt/mine"
cat >"$bt/mine/mine.odin" <<'ODIN'
package mine
Boot :: struct { anything: i32 }
ODIN
cat >"$bt/game.odin" <<'ODIN'
//gd:extends Node
//gd:class BtGame
package bt
import gd "godot:godot"
import mine "./mine"

BtGame :: struct {
	owner: gd.Node,
	boot:  ^mine.Boot,
}
ODIN
"$SGEN" "$bt" -godot:"$ROOT" >/dev/null 2>&1 || fail "a foreign .Boot field must not break the build"
grep -q "_bt_game_std_on_packet" "$bt/odin_godot_scripts.gen.odin" \
	&& fail "a NON-kit/boot .Boot field must not declare the game shell"

# ---- fixture: two declarations, one generated engine method name -----------
# The composed formula (<path>_<verb>) and the direct one
# (strip_struct_prefix(<proc>, <Class>)) are different formulas over different
# inputs, and they could meet: one entry silently never bound.
mn="$work/methodname"
mkdir -p "$mn"
cat >"$mn/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class MnMob
package mn
import gd "godot:godot"

Gun :: struct { ammo: i32 }
@(gd_method)
gun_fire :: proc(self: ^Gun) {}

MnMob :: struct {
	owner: gd.Node,
	gun:   Gun,
}

// Composes to the same engine name as the block's hoisted `gun_fire`.
@(gd_method)
mn_mob_gun_fire :: proc(self: ^MnMob) {}
ODIN
out="$("$SGEN" "$mn" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "two declarations generating one engine method name must fail the build"
echo "$out" | grep -q 'two declarations generate the engine method "gun_fire"' \
	|| fail "the collision must name the generated method"

# ---- fixture: the yields are announced -------------------------------------
# Name shadowing is THE manual-override pattern; a SILENT yield is
# indistinguishable from a typo in the override's own name.
yl="$work/yield"
mkdir -p "$yl"
cat >"$yl/game.odin" <<'ODIN'
//gd:extends Node
//gd:class YlGame
package yl
import gd "godot:godot"
import kboot "godot:kit/boot"

YlGame :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
}

// Takes the generated forward over by name.
@(gd_method)
on_net_down :: proc(self: ^YlGame) {}
ODIN
out="$("$SGEN" "$yl" -godot:"$ROOT" 2>&1)"
echo "$out" | grep -q "scriptgen: yielded: on_net_down" \
	|| fail "a hand-written proc taking a generated name over must be reported"

# ---------------------------------------------------------------------------
# THE ALLOWLIST PROJECTION. Odin refuses an unknown custom attribute outright,
# so every @(gd_*) name the language knows must reach the compiler as
# -custom-attribute:<name> on EVERY build of game scripts. The schema
# (decl/decl.odin's ATTRS) is the source; build/common.sh and
# build_scripts.ps1 are projections of it that nothing could previously check.
# Drift here used to surface as a compile error in someone else's project.
schema_attrs="$(grep -o '{"gd_[a-z_]*"' "$ROOT/decl/decl.odin" | tr -d '{"' | sort -u)"
[[ -n "$schema_attrs" ]] || fail "could not read the attribute schema out of decl/decl.odin"
for src in "build/common.sh" "build/build_scripts.ps1"; do
    [[ -f "$ROOT/$src" ]] || continue
    have="$(grep -o 'custom-attribute:gd_[a-z_]*' "$ROOT/$src" | sed 's/.*://' | sort -u)"
    if [[ "$have" != "$schema_attrs" ]]; then
        fail "$src's attribute allowlist has drifted from decl.ATTRS: schema=[$(echo $schema_attrs)] build=[$(echo $have)]"
    fi
done

# ---------------------------------------------------------------------------
# THE SESSION-EVENT MIRROR. scriptgen's SESSION_EVENTS is transcribed BY HAND
# from kit/session's Event union — it must be, and that is not laziness: this is
# a BUILD-TIME binary that PARSES kit/session as text and cannot import it, and
# an import would make a runtime package a build dependency of the tool that
# generates its callers. Generating either from the other is a build-graph
# fight; the practical ceiling is two guards that between them make a forgotten
# variant impossible to ship, and this is the second of them.
#
#   1. kit/boot/forward.odin holds ONE non-`#partial` switch over every variant,
#      so a new Event does not COMPILE in kit/boot until someone decides what the
#      kit does about it. (That guard is the compiler's; nothing here to check.)
#   2. This: the scriptgen table names every variant, so a new Event is also a
#      pairable half in every game, not a thing only the kit can hear.
#
# Without #2 a variant added with a forward in #1 is invisible to game code and
# fails in the quietest possible way — the game writes `<snake>_thing_happened`,
# nothing generates a call, and the proc simply never runs.
ev_union="$(awk '/^Event :: union \{/{f=1;next} f&&/^\}/{f=0} f&&match($0,/Ev_[A-Za-z0-9_]+/){print substr($0,RSTART,RLENGTH)}' "$ROOT/kit/session/session.odin" | sort -u)"
[[ -n "$ev_union" ]] || fail "could not read the Event union out of kit/session/session.odin"
ev_table="$(awk '/^SESSION_EVENTS := \[\?\]Session_Ev \{/{f=1;next} f&&/^\}/{f=0} f&&match($0,/variant = "Ev_[A-Za-z0-9_]+"/){print substr($0,RSTART+11,RLENGTH-12)}' "$ROOT/scriptgen/main.odin" | sort -u)"
[[ -n "$ev_table" ]] || fail "could not read SESSION_EVENTS out of scriptgen/main.odin"
if [[ "$ev_union" != "$ev_table" ]]; then
    fail "scriptgen's SESSION_EVENTS has drifted from ksess.Event: union-only=[$(comm -23 <(echo "$ev_union") <(echo "$ev_table") | tr '\n' ' ')] table-only=[$(comm -13 <(echo "$ev_union") <(echo "$ev_table") | tr '\n' ' ')] — give the new variant a row (suffix, role, params) in scriptgen/main.odin"
fi

# ---------------------------------------------------------------------------
# THE TWO GRAMMAR BREAKS, and the only thing that makes them survivable: a
# refusal that names the REPLACEMENT TAG. Three games build against a vendored
# copy of this addon and are not in this tree, so for them the error message IS
# the upgrade documentation. Accepting both spellings was never on the table —
# a language with two forms for one declaration teaches neither — which puts
# the entire migration weight on these strings.
gr="$work/grammar"
mkdir -p "$gr"

# (a) THE LANE IS THE FIRST TOKEN. `owner`/`predict` used to be options inside
# `gd:"replicate,…"`, which cost the parser a pairwise constraint matrix and
# hid the one decision that matters (who writes these bytes) among smoothing
# constants. The one-release migration door that rewrote the old form has been
# removed (the three downstream games are retagged); what must still hold is
# the permanent law — a lane in the option list means the field named TWO, and
# the refusal has to say which token was the second one and where a lane goes.
cat >"$gr/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class GrMob
package gr
import gd "godot:godot"
import knet "godot:kit/net"

GrMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"replicate,interp,owner,wire=f16"`,
	hp:     i32 `gd:"replicate,predict"`,
}
ODIN
out="$("$SGEN" "$gr" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a lane in the option list must fail the build, not be quietly accepted"
echo "$out" | grep -q 'is a LANE, not an option' \
	|| fail "a second lane token must be named as a LANE, not reported as an unknown option"
echo "$out" | grep -q 'exactly ONE lane' \
	|| fail "the refusal must state the one-lane law (whoever writes the bytes owns them)"
echo "$out" | grep -q 'the FIRST token' \
	|| fail "the refusal must say where a lane goes — that is the whole fix"

# The lane's option set is CLOSED, which is what replaced the matrix: `slack=`
# is not "an option that requires predict", it is an option the predict lane
# HAS — so on the delta lane it is simply unknown, and the error names what
# that lane does take rather than a cross-token implication to reconstruct.
cat >"$gr/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class GrMob
package gr
import gd "godot:godot"
import knet "godot:kit/net"

GrMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	x:      f32 `gd:"replicate,slack=0.5"`,
	y:      f32 `gd:"owner,cut=32"`,
}
ODIN
out="$("$SGEN" "$gr" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a knob outside its lane's option set must fail the build"
echo "$out" | grep -q 'unknown `replicate` option "slack=0.5" — the replicate lane takes' \
	|| fail "an off-lane knob must be answered by the lane's own closed option set"
echo "$out" | grep -q 'unknown `owner` option "cut=32" — the owner lane takes' \
	|| fail "the owner lane must name its own options, not predict's"

# One lane per field, said as such: a second lane token is not an unknown
# option, it is two writers fighting over the same bytes.
cat >"$gr/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class GrMob
package gr
import gd "godot:godot"
import knet "godot:kit/net"

GrMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	x:      f32 `gd:"owner,predict"`,
}
ODIN
out="$("$SGEN" "$gr" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "two lane tokens on one field must fail the build"
echo "$out" | grep -q 'is a LANE, not an option' \
	|| fail "a second lane token must be diagnosed as a lane, not as a typo'd option"

# All three lanes, spelled the new way, must BUILD — the gate refuses the old
# grammar, not the language.
cat >"$gr/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class GrMob
package gr
import gd "godot:godot"
import knet "godot:kit/net"

GrMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	x, y:   f32 `gd:"owner,interp,wire=f16"`,
	px:     f32 `gd:"predict,interp,slack=0.5,glide=0.1,cut=32"`,
	fuel:   u16 `gd:"predict"`,
}
ODIN
"$SGEN" "$gr" -godot:"$ROOT" >/dev/null 2>&1 || fail "all three lanes in their new spelling must build"

# (b) `entity=Name:id` LEADS ITS TAG. It is a wire declaration — a permanent
# public type id, a fingerprint input, a factory-table row — and it rode as a
# trailing spec of `export` purely by accident of build order. An entity field
# is NECESSARILY an exported PackedScene, so both leading tokens are synthesized.
en="$work/entityfirst"
mkdir -p "$en"
cat >"$en/game.odin" <<'ODIN'
//gd:extends Node
//gd:class EnGame
package en
import gd "godot:godot"
import kboot "godot:kit/boot"

EnGame :: struct {
	owner:     gd.Node,
	boot:      kboot.Boot,
	mob_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=EnMob:1"`,
}
ODIN
cat >"$en/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class EnMob
package en
import gd "godot:godot"
import knet "godot:kit/net"

EnMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}
ODIN
out="$("$SGEN" "$en" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "the old trailing entity= spec must fail the build"
echo "$out" | grep -q 'is a WIRE declaration, not an export spec' \
	|| fail "the old entity= form must be named for WHAT it got wrong, not just refused"
echo "$out" | grep -q 'write `gd:"entity=EnMob:1"`' \
	|| fail "the entity= refusal must spell the replacement tag"
echo "$out" | grep -q 'are synthesized' \
	|| fail "the refusal must say the export and PackedScene hint come for free, or the fix reads like a loss"

# The new form builds, and the synthesis is real: the entity reaches the
# factory table exactly as the four-token spelling did.
perl -pi -e 's/gd:"export,resource=PackedScene,entity=EnMob:1"/gd:"entity=EnMob:1"/' "$en/game.odin"
"$SGEN" "$en" -godot:"$ROOT" >/dev/null 2>&1 || fail "the first-token entity= form must build"
grep -q "EnMob" "$en/odin_godot_scripts.gen.odin" || fail "the synthesized export must still produce the entity's factory row"
grep -q 'NET_FINGERPRINT' "$en/odin_godot_guard.gen.odin" || fail "the entity must still reach the fingerprint"

# A resource hint beside `entity=` is refused rather than silently outranked —
# the declaration already fixed the hint, so a second one is a disagreement.
perl -pi -e 's/gd:"entity=EnMob:1"/gd:"entity=EnMob:1,resource=Texture2D"/' "$en/game.odin"
out="$("$SGEN" "$en" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a resource= beside entity= must fail the build"
echo "$out" | grep -q 'already fixes the resource hint to PackedScene' \
	|| fail "the redundant-hint refusal must say the hint is already decided"

# ---------------------------------------------------------------------------
# @(gd_half): PRESENCE IS DECLARED, THE NAME STILL DECIDES THE PAIRING.
#
# Halves used to be collected by SUFFIX, which could only ever catch half the
# typos. A bad PREFIX (`hf_bump_thn`) still wore `_then`, so the unclaimed sweep
# saw it and guessed; a bad SUFFIX (`hf_bump_after`) wore nothing anyone
# indexed, so scriptgen never looked at it and Odin does not flag an unused
# package-level proc — the half silently never fired, which is the one failure
# this whole language is built to make impossible. The attribute turns "did the
# author mean to pair?" from a heuristic into a fact, so the check is arithmetic
# (claimed, or not) and both typos land in the same error.
hf="$work/half"
mkdir -p "$hf"
cat >"$hf/game.odin" <<'ODIN'
//gd:extends Node
//gd:class HfGame
package hf
import gd "godot:godot"
import knet "godot:kit/net"

HfGame :: struct {
	owner: gd.Node,
	mob:   gd.Object `gd:"entity=HfMob:1"`,
}
ODIN
cat >"$hf/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class HfMob
package hf
import gd "godot:godot"
import knet "godot:kit/net"

HfMob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
hf_bump :: proc(self: ^HfMob, n: i32) -> bool { self.hp += n; return true }

@(gd_half)
hf_bump_then :: proc(game: ^HfGame, self: ^HfMob, by: knet.Player_Id, n: i32) {}
ODIN
"$SGEN" "$hf" -godot:"$ROOT" >/dev/null 2>&1 || fail "a correctly named @(gd_half) must build"

# THE BUG THAT HAD NO NET: a wrong suffix. Nothing wore `_then`, so nothing
# looked, and the consequence never fired.
perl -pi -e 's/^hf_bump_then ::/hf_bump_after ::/' "$hf/mob.odin"
out="$("$SGEN" "$hf" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "an @(gd_half) that pairs with nothing must fail the build"
echo "$out" | grep -q 'pairs with nothing' \
	|| fail "the unpaired-half refusal must say the half pairs with nothing"
echo "$out" | grep -q 'silently never fire' \
	|| fail "the unpaired-half refusal must name the bug it is preventing"
echo "$out" | grep -q 'HfMob pairs: hf_bump_then' \
	|| fail "the unpaired-half refusal must name the real pairing targets, not just the problem"

# A wrong PREFIX under a right suffix — the case the deleted ~600 lines of
# edit-distance guessing existed for — lands in the same one check.
perl -pi -e 's/^hf_bump_after ::/hf_bmp_then ::/' "$hf/mob.odin"
out="$("$SGEN" "$hf" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a prefix-typo'd @(gd_half) must fail the build"
echo "$out" | grep -q 'HfMob pairs: hf_bump_then' \
	|| fail "the prefix-typo refusal must name the real pairing targets"

# The pairing target is read off the ^Struct params, and the leading `game:`
# handle is the CONTEXT, not what the half pairs on — so the class named is the
# one the author was writing against, and the shell's thirty-odd session-event
# names never bury it.
echo "$out" | grep -q 'HfGame pairs:' \
	&& fail "the game handle must not be offered as the pairing class when a second class is named"

# The census hooks are the one mispairing whose fix is not a rename: they key on
# the entity-tagged struct, so an untagged target means a missing `entity=` tag.
perl -pi -e 's/^hf_bmp_then ::/hf_bump_then ::/' "$hf/mob.odin"
cat >>"$hf/mob.odin" <<'ODIN'

@(gd_half)
hf_game_spawned :: proc(game: ^HfGame, self: ^HfGame, id: knet.Net_Id, owner: knet.Player_Id) {}
ODIN
out="$("$SGEN" "$hf" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a census hook on an untagged struct must fail the build"
echo "$out" | grep -q 'no scene field declares `entity=Name:id`' \
	|| fail "an untagged census hook must name the TAG as the fix, not a rename"

# @(gd_fact) and @(gd_half) are the two sides of one line — a fact DECLARES the
# door scriptgen generates, a half PAIRS with a declaration made elsewhere — so
# wearing both is refused rather than resolved into a proc that is somehow each.
perl -pi -e 's/^\@\(gd_half\)\nhf_game_spawned.*\n//' "$hf/mob.odin"
perl -0777 -pi -e 's/\n\@\(gd_half\)\nhf_game_spawned[^\n]*\n//' "$hf/mob.odin"
perl -0777 -pi -e 's/\@\(gd_half\)\nhf_bump_then/\@(gd_fact)\n\@(gd_half)\nhf_bump_then/' "$hf/mob.odin"
out="$("$SGEN" "$hf" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "@(gd_fact) plus @(gd_half) on one proc must fail the build"
echo "$out" | grep -q 'two sides of one line' \
	|| fail "the fact/half overlap refusal must say which attribute declares and which pairs"
echo "$out" | grep -q 'Drop @(gd_half)' \
	|| fail "the fact/half overlap refusal must name the fix"

# ---------------------------------------------------------------------------
# THE FORGOTTEN ATTRIBUTE — the same bug one step earlier than the sweep above.
# `check_unpaired_halves` catches a half that DECLARED itself and paired with
# nothing. This is the case nothing ever caught: exactly the right name, no
# @(gd_half) at all. Scriptgen collects by attribute so it never looked; Odin
# does not flag an unused package-level proc so it never looked either; the
# consequence compiled, read correctly, and never fired. Every resolve_* pass
# already computes the name before looking it up, so on a miss it asks the
# package's proc index whether that exact name exists anyway — and when it
# does, the answer is not "no half was written" but "one was, and never said
# so".
hf2="$work/half_undeclared"
mkdir -p "$hf2"
cat >"$hf2/game.odin" <<'ODIN'
//gd:extends Node
//gd:class H2Game
package h2
import gd "godot:godot"
import knet "godot:kit/net"
import kboot "godot:kit/boot"

H2Game :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
	mob:   gd.Object `gd:"entity=H2Mob:1"`,
}
ODIN
cat >"$hf2/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class H2Mob
package h2
import gd "godot:godot"
import knet "godot:kit/net"

H2Mob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
h2_bump :: proc(self: ^H2Mob, n: i32) -> bool { self.hp += n; return true }

h2_bump_then :: proc(game: ^H2Game, self: ^H2Mob, by: knet.Player_Id, n: i32) {}
ODIN
out="$("$SGEN" "$hf2" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a correctly named half with no @(gd_half) must fail the build"
echo "$out" | grep -q 'h2_bump_then exists but never declared itself' \
	|| fail "the forgotten-attribute refusal must say the proc exists and never declared itself"
echo "$out" | grep -q 'silently never fires' \
	|| fail "the forgotten-attribute refusal must name the bug it is preventing"
echo "$out" | grep -q 'Add @(gd_half)' \
	|| fail "the forgotten-attribute refusal must name the fix, not just the problem"
echo "$out" | grep -q 'collects halves by ATTRIBUTE' \
	|| fail "the forgotten-attribute refusal must say why the name alone was not enough"
# The weaker diagnostic stands down: "returns a payload but no `_then` consumes
# it" only SUSPECTS the consequence is missing, and this one KNOWS it was
# written. Both firing would argue for writing the proc sitting right there.
echo "$out" | grep -q 'no `h2_bump_then` consequence proc consumes it' \
	&& fail "the payload warning must not fire beside the refusal that supersedes it"

# The other lookup sites reach the same answer — an entity hook, a delta edge
# and a sim-lane apply, each named for what it would have been.
cat >>"$hf2/game.odin" <<'ODIN'

h2_mob_spawned :: proc(self: ^H2Game, id: knet.Net_Id, owner: knet.Player_Id) {}
ODIN
cat >>"$hf2/mob.odin" <<'ODIN'

h2_mob_hp_edge :: proc(self: ^H2Mob, old, new: i32) {}
h2_bump_apply :: proc(self: ^H2Mob, n: i32) {}
ODIN
out="$("$SGEN" "$hf2" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "undeclared halves at the hook/edge/apply sites must fail the build"
echo "$out" | grep -q "h2_mob_spawned exists but never declared itself" \
	|| fail "the entity spawn-hook site must demand the attribute too"
echo "$out" | grep -q "h2_mob_hp_edge exists but never declared itself" \
	|| fail "the delta-edge site must demand the attribute too"
echo "$out" | grep -q "h2_bump_apply exists but never declared itself" \
	|| fail "the sim-lane apply site must demand the attribute too"

# THE NEGATIVE CONTROL. Name shadowing is THE way to take a generated thing over
# by hand — census accessors, acid probes and the four transport forwards all
# yield to a proc of their name, and every yield is ANNOUNCED, never refused.
# The new demand keys on names the HALF passes compute, and no generated-yield
# name is one of those, so a deliberate override must still land in `yielded:`
# with a zero exit. A yield turning into an error would break the only override
# mechanism the language has.
rm -rf "$hf2" && mkdir -p "$hf2"
cat >"$hf2/game.odin" <<'ODIN'
//gd:extends Node
//gd:class H2Game
package h2
import gd "godot:godot"
import knet "godot:kit/net"
import kboot "godot:kit/boot"

H2Game :: struct {
	owner: gd.Node,
	boot:  kboot.Boot,
	mob:   gd.Object `gd:"entity=H2Mob:1"`,
}

h2_mob_of :: proc(self: ^H2Game, id: knet.Net_Id) -> ^H2Mob { return nil }
h2_mob_spawn :: proc(self: ^H2Game) -> ^H2Mob { return nil }
probe_h2_mob_count :: proc(self: ^H2Game) -> gd.Int { return 0 }

@(gd_method)
on_packet :: proc(self: ^H2Game, id: gd.Int, packet: gd.Packed_Byte_Array) {}
ODIN
cat >"$hf2/mob.odin" <<'ODIN'
//gd:extends Node
//gd:class H2Mob
package h2
import gd "godot:godot"
import knet "godot:kit/net"

H2Mob :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
}

@(gd_command)
h2_bump :: proc(self: ^H2Mob, n: i32) -> bool { self.hp += n; return true }

@(gd_half)
h2_bump_then :: proc(game: ^H2Game, self: ^H2Mob, by: knet.Player_Id, n: i32) {}
ODIN
out="$("$SGEN" "$hf2" -godot:"$ROOT" 2>&1)"
[[ $? -eq 0 ]] || fail "deliberately shadowed census/probe/forward names must still build: $out"
echo "$out" | grep -q 'never declared itself' \
	&& fail "a yielded proc must never be read as a forgotten half"
for y in h2_mob_of h2_mob_spawn probe_h2_mob_count on_packet; do
	echo "$out" | grep -q "yielded: $y" || fail "$y must still yield to the hand-written proc"
done

# ---- fixture 16: ONE dispatch — a nested tag is checked like a top-level one --
# The two field walks (parse_script's own-fields loop, recurse_into's embedded
# one) used to be separate hand-written token chains, and `export`/`onready=`
# were deferred to the runtime UNVALIDATED in the nested one. So the spelling
# and bare/value arity gates were top-level only: `gd:"export,rnage=0:100"` one
# comma deep sailed past the build and died at boot, while the identical typo on
# the class's own field was a hard error. Both walks now funnel through
# walk_tagged_field with a decl.Field_Site, and these are the three that slipped.
#
# TEETH: every one of these was accepted SILENTLY (exit 0) before the merge.
nested_tag_must_fail() {
	local tag="$1" want="$2"
	local nd="$work/nested_$3"
	mkdir -p "$nd"
	cat >"$nd/f.odin" <<ODIN
//gd:extends Node
//gd:class NestedTag
package nested_$3
import gd "godot:godot"
import knet "godot:kit/net"

Aim :: struct {
	sens: f32 \`gd:"$tag"\`,
}
NestedTag :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 \`gd:"replicate"\`,
	aim:    Aim,
}
@(gd_command="predict")
nestedtag_hit :: proc(self: ^NestedTag, n: i32) -> bool { self.hp -= n; return true }
ODIN
	local out rc
	out="$("$SGEN" "$nd" -godot:"$ROOT" 2>&1)"
	rc=$?
	[[ $rc -ne 0 ]] || fail "nested gd:\"$tag\" must fail the build (it was silently accepted before the walks merged)"
	echo "$out" | grep -q "$want" || fail "nested gd:\"$tag\" errored, but not with $want — got: $out"
	# The diagnostic must name the full ACCESS PATH, not the leaf: the whole
	# point is that you can find the tag inside the block it lives in.
	echo "$out" | grep -q "NestedTag.aim.sens" || fail "nested tag error must name the path NestedTag.aim.sens — got: $out"
}
nested_tag_must_fail 'export,rnage=0:100' 'did you mean `range`' spell
nested_tag_must_fail 'export,multiline=true' 'takes no value' arity
nested_tag_must_fail 'onready=' 'needs a node path' onready

# ---- fixture 17: `entity=` LEADS the tag — for EVERY kind, not just export ---
# The trailing-`entity=` refusal used to live inside the export arm, so the rule
# stopped applying the moment another token led: `gd:"backup,entity=M:1"` went
# to an arm that never looks past specs[0] and was accepted SILENTLY (verified
# against the pre-merge binary) — an entity id that folds into NET_FINGERPRINT
# and mints a factory row, written down and read by nothing. The check now runs
# once for all kinds, before the dispatch.
ent="$work/entlead"
mkdir -p "$ent"
entity_trailing_must_fail() {
	cat >"$ent/f.odin" <<ODIN
//gd:extends Node
//gd:class EntLead
package entlead
import gd "godot:godot"
import knet "godot:kit/net"
import kboot "godot:kit/boot"

Blk :: struct { $2 }
EntLead :: struct {
	owner:  gd.Node,
	boot:   kboot.Boot,
	net_id: knet.Net_Id,
	$1
	blk:    Blk,
}
ODIN
	local out rc
	out="$("$SGEN" "$ent" -godot:"$ROOT" 2>&1)"
	rc=$?
	[[ $rc -ne 0 ]] || fail "$3: a trailing \`entity=\` must fail the build whatever token leads"
	echo "$out" | grep -q "$4" || fail "$3: wrong diagnostic — got: $out"
}
entity_trailing_must_fail 'hp: i32 `gd:"backup,entity=M:1"`,' 'x: i32,' \
	'top-level backup' 'is a WIRE declaration'
entity_trailing_must_fail 'x: i32,' 'h: i32 `gd:"backup,entity=M:1"`,' \
	'nested backup' "declares on the class's OWN scene field"

# ---- fixture 18: the policy TABLE is honored — its Refuse rows still refuse ---
# The per-context policy is decl.FIELD_POLICY now (a decl.Field_Site keyed
# table), consulted once at the top of walk_tagged_field. check_field_policy
# proves every token has a WELL-FORMED row (it fails scriptgen's own build if
# not, which is why there is no fixture for it — a hole cannot produce a working
# binary). This fixture proves the other half: that the gate HONORS the rows —
# the two refusals the table owns that fixtures 16/17 don't already cover, each
# with the exact reason string the table carries, so a row silently losing its
# effect (or its wording) is caught here.
pol="$work/policy"
mkdir -p "$pol"
policy_nested_must_fail() {
	cat >"$pol/f.odin" <<ODIN
//gd:extends Node
//gd:class PolT
package policy
import gd "godot:godot"
import knet "godot:kit/net"
import kboot "godot:kit/boot"
import ksess "godot:kit/session"

Blk :: struct { $1 }
PolT :: struct {
	owner:  gd.Node,
	boot:   kboot.Boot,
	ses:    ksess.Session,
	net_id: knet.Net_Id,
	blk:    Blk,
}
ODIN
	local out rc
	out="$("$SGEN" "$pol" -godot:"$ROOT" 2>&1)"
	rc=$?
	[[ $rc -ne 0 ]] || fail "$2: a nested \`$3\` must be refused by the policy gate"
	echo "$out" | grep -q "$4" || fail "$2: wrong diagnostic (the table's reason string drifted?) — got: $out"
	echo "$out" | grep -q "PolT.blk" || fail "$2: refusal must name the nested path PolT.blk.* — got: $out"
}
policy_nested_must_fail 'p: ksess.Session `gd:"profile=Loadout"`,' \
	'nested profile=' 'profile=' 'silently never installs'
policy_nested_must_fail 'a: knet.Angle `gd:"manual"`,' \
	'nested manual' 'manual' 'silently skips the whole sub-block'

# ---- fixture 19: the map_variant seam is DELIBERATE — nested type-shape is the ---
# runtime's job, not scriptgen's. export/onready are Reflect-home tokens; the
# runtime reflection walk type-checks them at every depth and drops a bad one
# with a loud record_error at boot. So scriptgen runs the TYPE-shape check at top
# level only. This is a DECISION, not an oversight (see parse.odin's Tagged_Field
# seam note): widening it would false-positive on foreign-package bundle types,
# which map_variant (gd.-only) cannot classify but the runtime's typeid check
# resolves. This fixture is that decision's teeth — the same tag+type ERRORS at
# top level and is ACCEPTED nested. Flip either half and someone changed the
# seam without meaning to.
seam="$work/seam"
mkdir -p "$seam"
# nested: a type map_variant cannot classify, exported inside a block — ACCEPTED
# (deferred to the runtime), byte-for-byte the case a naive widening would break.
cat >"$seam/f.odin" <<'ODIN'
//gd:extends Node
//gd:class SeamT
package seam
import gd "godot:godot"
import knet "godot:kit/net"

Gadget :: struct { x: i32 }
Blk :: struct {
	g: Gadget `gd:"export"`,
}
SeamT :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	blk:    Blk,
}
ODIN
"$SGEN" "$seam" -godot:"$ROOT" >/dev/null 2>&1 \
	|| fail "a nested export of a map_variant-unclassifiable type must be ACCEPTED (type-shape is the runtime's job at depth) — widening the seam broke this"
# top level: the identical tag+type — ERRORS "unsupported type" (scriptgen owns
# the top-level type check).
cat >"$seam/f.odin" <<'ODIN'
//gd:extends Node
//gd:class SeamT
package seam
import gd "godot:godot"
import knet "godot:kit/net"

Gadget :: struct { x: i32 }
SeamT :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     i32 `gd:"replicate"`,
	g:      Gadget `gd:"export"`,
}
ODIN
out="$("$SGEN" "$seam" -godot:"$ROOT" 2>&1)"
[[ $? -ne 0 ]] || fail "a TOP-LEVEL export of an unsupported type must still error — the seam is asymmetric by design"
echo "$out" | grep -q "unsupported type" || fail "top-level unsupported export must say so — got: $out"

# ---- fixture 20: a predicted quat GLIDES its correction, on every lane --------
# present.odin's render-error glide grew a .Quat arm (error as a rotation delta,
# eased toward identity, re-applied), so `gd:"predict,interp"` on a quaternion is
# now a first-class predicted rotation — no longer refused. All four lane/interp
# combinations that carry a quaternion must build; the unit glide behaviour is
# pinned in kitsim (predicted_quat_glides_its_correction).
qpin="$work/quatpin"
mkdir -p "$qpin"
quat_lane() {
	cat >"$qpin/f.odin" <<ODIN
//gd:extends Node3D
//gd:class QuatPin
package quatpin
import gd "godot:godot"
import knet "godot:kit/net"

QuatPin :: struct {
	owner:  gd.Node3d,
	net_id: knet.Net_Id,
	rot:    gd.Quaternion \`gd:"$1"\`,
}
ODIN
	"$SGEN" "$qpin" -godot:"$ROOT" >/dev/null 2>&1
}
quat_lane 'predict,interp' || fail "gd:\"predict,interp\" on a quat must be ACCEPTED — the sim lane glides predicted rotations now"
quat_lane 'predict' || fail "gd:\"predict\" (no interp) on a quat must be ACCEPTED — a non-interp predicted field snaps by design"
quat_lane 'owner,interp' || fail "gd:\"owner,interp\" on a quat must be ACCEPTED — owner-streamed quats glide (quat_nlerp)"
quat_lane 'replicate,interp' || fail "gd:\"replicate,interp\" on a quat must be ACCEPTED — delta-lane quats glide (quat_nlerp)"

# ---- fixture 21: a gd-tagged BUNDLE from res://shared/ names its limitation ---
# A shared package (the read-only vocabulary tree every module may import) is NOT a
# bundle source: nested resolution reaches the module's own tree and godot: collections
# only. Embedding a tagged struct from shared/ must be a COMPREHENSIBLE error naming the
# limitation — never a crash and never a silently dropped replicate field. Supporting it
# for real is out of scope; being quiet about it is the bug this pins.
shb="$work/sharedbundle"
mkdir -p "$shb/scripts" "$shb/shared/ids"
cat >"$shb/shared/ids/ids.odin" <<'ODIN'
package shb_ids
Bundle :: struct { hp: i32 `gd:"replicate"` }
ODIN
cat >"$shb/scripts/hero.odin" <<'ODIN'
//gd:extends Node
//gd:class ShHero
package shb_main
import gd "godot:godot"
import knet "godot:kit/net"
import ids "../shared/ids"

ShHero :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	using b: ids.Bundle,
}
ODIN
out="$("$SGEN" "$shb/scripts" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a gd-tagged bundle embedded from res://shared/ must fail the build, not drop the field"
grep -qF -- 'comes from the SHARED package' <<<"$out" || fail "the shared-bundle error must name the shared tree: $out"
grep -qF -- 'ShHero.b' <<<"$out" || fail "the shared-bundle error must name the offending field ShHero.b: $out"
[ -z "$(find "$shb/scripts" -name '*.gen.odin' -print -quit)" ] || fail "the refused shared-bundle tree still left generated code"

# ---- fixture: object exports — typed handles derive the resource hint, ------
# hint-less erased/node handles refuse. The hint is load-bearing (it switches
# on inst_set's refcount hold); a hint-less object export dangles after scene
# load, so the build must either derive the class or stop.
oex="$work/oex"
mkdir -p "$oex"
cat >"$oex/shooter.odin" <<'ODIN'
//gd:extends Node2D
//gd:class Shooter
package oex
import gd "godot:godot"

Shooter :: struct {
	owner:        gd.Node,
	bullet_scene: gd.Packed_Scene `gd:"export"`,                      // typed -> derived hint
	portrait:     gd.Object       `gd:"export,resource=Texture2D"`,   // explicit -> untouched
}
ODIN
if ! "$SGEN" "$oex" -godot:"$ROOT" >/dev/null 2>&1; then fail "typed resource-handle export must NOT error"; fi
grep -q 'resource_class = "PackedScene"' "$oex/odin_godot_scripts.gen.odin" || fail "typed gd.Packed_Scene export must derive resource_class=PackedScene in Field_Meta"
grep -q 'resource_class = "Texture2D"' "$oex/odin_godot_scripts.gen.odin" && fail "an explicit resource= spec must not ALSO synthesize resource_class"

oerase="$work/oerase"
mkdir -p "$oerase"
cat >"$oerase/erased.odin" <<'ODIN'
//gd:extends Node
//gd:class Erased
package oerase
import gd "godot:godot"

Erased :: struct {
	owner: gd.Node,
	thing: gd.Object `gd:"export"`,   // type-erased AND hint-less: refuse
}
ODIN
out="$("$SGEN" "$oerase" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a hint-less gd.Object export must fail the build (it dangles after scene load)"
grep -qF -- 'resource=<Class>' <<<"$out" || fail "the erased-object error must point at resource=<Class>: $out"

onode="$work/onode"
mkdir -p "$onode"
cat >"$onode/noder.odin" <<'ODIN'
//gd:extends Node
//gd:class Noder
package onode
import gd "godot:godot"

Noder :: struct {
	owner: gd.Node,
	buddy: gd.Node2d `gd:"export"`,   // a NODE is not an Inspector resource: refuse
}
ODIN
out="$("$SGEN" "$onode" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "an exported node handle must fail the build"
grep -qF -- 'onready=' <<<"$out" || fail "the node-handle error must point at onready=: $out"

# ---- script-resolving onready (`buddy: ^Buddy `gd:"onready=..."``) ----------
# Happy path: the pointee is a script struct declared in a file that sorts AFTER the
# referencing one — resolve_onready_scripts must validate module-wide, not parse-order.
oscript="$work/oscript"
mkdir -p "$oscript"
cat >"$oscript/a_leader.odin" <<'ODIN'
//gd:extends Node
//gd:class Leader
package oscript
import gd "godot:godot"

Leader :: struct {
	owner: gd.Node,
	buddy: ^Buddy `gd:"onready=Allies/Buddy"`,
	spot:  gd.Node2d `gd:"onready=Spot"`,       // a plain handle rides beside it
	cards: [3]gd.Node2d `gd:"onready=Deck/Card%d"`, // array form: %d template
	squad: [2]^Buddy `gd:"onready=Squad%d"`,        // array of SCRIPT refs
	hud:   gd.Node2d `gd:"onready=%Hud"`,           // scene-unique name
	dock:  ^Buddy `gd:"onready=%dock"`,             // unique name starting with 'd' (NOT a template)
	slots: [2]gd.Node2d `gd:"onready=%dock/Slot%d"`, // unique prefix + mid-name template
}
ODIN
cat >"$oscript/z_buddy.odin" <<'ODIN'
//gd:extends Node
//gd:class Buddy
package oscript
import gd "godot:godot"

Buddy :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export"`,
}
ODIN
"$SGEN" "$oscript" -godot:"$ROOT" >/dev/null 2>&1 || fail "a ^ScriptStruct onready must build (target declared in a later file)"

# Refuse: a pointer to a NON-script struct — silently accepting it used to hand the
# field a raw node pointer reinterpreted as ^T.
obad="$work/obad"
mkdir -p "$obad"
cat >"$obad/bad.odin" <<'ODIN'
//gd:extends Node
//gd:class BadRef
package obad
import gd "godot:godot"

Plain :: struct { x: int }

BadRef :: struct {
	owner: gd.Node,
	oops:  ^Plain `gd:"onready=Nope"`,
}
ODIN
out="$("$SGEN" "$obad" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a ^non-script onready must fail the build"
grep -qF -- 'not a script struct' <<<"$out" || fail "the ^non-script error must name the problem: $out"

# Array-onready template contract: array without %d, %d on a scalar, a stray '%'
# inside a name, and an array whose only "%d" bytes are a unique-name marker — refused.
oarr="$work/oarr"
mkdir -p "$oarr"
cat >"$oarr/arr.odin" <<'ODIN'
//gd:extends Node
//gd:class ArrBad
package oarr
import gd "godot:godot"

ArrBad :: struct {
	owner:  gd.Node,
	cards:  [3]gd.Node2d `gd:"onready=Deck/Card"`,
	scalar: gd.Node2d `gd:"onready=Deck/Card%d"`,
	stray:  gd.Node2d `gd:"onready=Deck/Ca%rd"`,
	umark:  [2]gd.Node2d `gd:"onready=%dock"`,
}
ODIN
out="$("$SGEN" "$oarr" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "array-onready template violations must fail the build"
grep -qF -- 'needs exactly one mid-name `%d`' <<<"$out" || fail "missing-template error absent: $out"
grep -qF -- "for FIXED-ARRAY fields" <<<"$out" || fail "template-on-scalar error absent: $out"
grep -qF -- "ArrBad.stray" <<<"$out" || fail "stray mid-name %% must be refused: $out"
grep -qF -- "ArrBad.umark" <<<"$out" || fail "array with only a unique marker must be refused: $out"

# ---- path-qualified gd_connect (`@(gd_connect="Path/To/Node:signal")`) ------
oconn="$work/oconn"
mkdir -p "$oconn"
cat >"$oconn/listener.odin" <<'ODIN'
//gd:extends Node
//gd:class Listener
//gd:group sentries watchers
package oconn
import gd "godot:godot"

Listener :: struct {
	owner: gd.Node,
}

@(gd_method, gd_connect = "Turret/Barrel:fired")
listener_on_fired :: proc(self: ^Listener) {}

@(gd_method, gd_connect = "area_entered")
listener_on_area :: proc(self: ^Listener) {}

@(gd_method, gd_connect = "Row/Btn%d:pressed")
listener_on_btn :: proc(self: ^Listener, idx: gd.Int) {}

@(gd_method, gd_connect = "%SavePanel:saved")
listener_on_saved :: proc(self: ^Listener) {}

@(gd_method, gd_connect = "%dock:docked")
listener_on_dock :: proc(self: ^Listener) {}
ODIN
"$SGEN" "$oconn" -godot:"$ROOT" >/dev/null 2>&1 || fail "path-qualified gd_connect must build"
cgen="$oconn/odin_godot_scripts.gen.odin"
grep -qF -- '{signal = "fired", method = "on_fired", path = "Turret/Barrel"}' "$cgen" || fail "path-qualified connection row missing/wrong"
grep -qF -- '{signal = "area_entered", method = "on_area"}' "$cgen" || fail "plain connection row must stay path-less"
grep -qF -- '_listener_groups := [?]cstring {"sentries", "watchers"}' "$cgen" || fail "//gd:group table missing/wrong"
grep -qF -- 'groups = raw_data(_listener_groups[:])' "$cgen" || fail "//gd:group Class_Info wiring missing"
grep -qF -- '{signal = "pressed", method = "on_btn", path = "Row/Btn%d", indexed = true}' "$cgen" || fail "indexed connection row missing/wrong"
grep -qF -- '{signal = "saved", method = "on_saved", path = "%SavePanel"}' "$cgen" || fail "scene-unique connection row missing/wrong"
grep -qF -- '{signal = "docked", method = "on_dock", path = "%dock"}' "$cgen" || fail "a %d-prefixed unique name must stay a plain (non-indexed) row"

# Refuse the malformed forms loudly: empty path, empty/garbage signal.
obadc="$work/obadc"
mkdir -p "$obadc"
cat >"$obadc/badc.odin" <<'ODIN'
//gd:extends Node
//gd:class BadConn
package obadc
import gd "godot:godot"

BadConn :: struct {
	owner: gd.Node,
}

@(gd_method, gd_connect = ":fired")
badconn_a :: proc(self: ^BadConn) {}

@(gd_method, gd_connect = "Turret:")
badconn_b :: proc(self: ^BadConn) {}

@(gd_method, gd_connect = "Row%d/Btn%d:pressed")
badconn_c :: proc(self: ^BadConn) {}

@(gd_method, gd_connect = "Tur%ret:fired")
badconn_d :: proc(self: ^BadConn) {}
ODIN
out="$("$SGEN" "$obadc" -godot:"$ROOT" 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "malformed gd_connect forms must fail the build"
grep -qF -- "the path part before ':' is empty" <<<"$out" || fail "empty-path error missing: $out"
grep -qF -- 'is not a signal name' <<<"$out" || fail "empty-signal error missing: $out"
grep -qF -- 'only valid as ONE mid-name `%d` template' <<<"$out" || fail "double-%d error missing: $out"
grep -qF -- '"badconn_d"' <<<"$out" || fail "stray mid-name %% in a connect path must be refused: $out"

# ---- distinct-handle refusal: a ^script_struct is NOT an engine handle -------
# The desert-shooter footgun, pinned: passing a typed onready ref (a SCRIPT STRUCT
# pointer) where a node handle belongs. gd.Object is a DISTINCT rawptr
# (godot/Variant.odin), so this must refuse at compile time — it used to convert
# implicitly (handles were plain rawptr aliases) and SIGSEGV inside the engine.
hguard="$work/handle_guard"
mkdir -p "$hguard"
cat >"$hguard/world.odin" <<'ODIN'
package handle_guard
import gd "godot:godot"

Menu :: struct {
	owner: gd.Node,
}

World :: struct {
	owner: gd.Node,
	menu:  ^Menu,
}

hide_menu :: proc (w: ^World) {
	gd.canvas_item_set_visible(w.menu, false)
}
ODIN
out="$("$ODIN" check "$hguard" -collection:godot="$ROOT" -no-entry-point 2>&1)"
rc=$?
[[ $rc -ne 0 ]] || fail "a ^script_struct passed as a node handle must NOT compile"
grep -q "Cannot assign value 'w.menu' of type '\^Menu'" <<<"$out" || fail "handle-guard refusal shape changed: $out"
# The positive twin: the same call through the node (`.owner`) must build — so this
# pin can never rot into "fails for an unrelated reason".
cat >"$hguard/world.odin" <<'ODIN'
package handle_guard
import gd "godot:godot"

Menu :: struct {
	owner: gd.Node,
}

World :: struct {
	owner: gd.Node,
	menu:  ^Menu,
}

hide_menu :: proc (w: ^World) {
	gd.canvas_item_set_visible(w.menu.owner, false)
}
ODIN
"$ODIN" check "$hguard" -collection:godot="$ROOT" -no-entry-point >/dev/null 2>&1 || fail "the .owner spelling must compile (handle family broke)"

echo "SCRIPTGEN_OK"
