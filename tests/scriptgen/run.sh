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
gen="$sp/thing.gen.odin"
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
igen="$ip/hero.gen.odin"
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
grep -q "fighter_emit_aim_fired" "$comp/fighter.gen.odin" || fail "namespaced signal emit helper fighter_emit_aim_fired not generated"

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
ggen="$gen/g.gen.odin"
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
kgen="$kit/hero.gen.odin"
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
vgen="$vc/runner.gen.odin"
grep -q "RUNNER_CMD_PRIMARY_FIRE :: u16" "$vgen" || fail "composed command index const RUNNER_CMD_PRIMARY_FIRE missing"
grep -q "RUNNER_CMD_SECONDARY_FIRE :: u16" "$vgen" || fail "second instance must get its own path-prefixed index (SECONDARY_FIRE)"
grep -q "RUNNER_CMD_PRIMARY_RELOAD :: u16" "$vgen" || fail "plain composed command RUNNER_CMD_PRIMARY_RELOAD missing"
grep -q "return gun_fire(&self.primary, self, _a0)" "$vgen" || fail "decode thunk must route into &self.primary and pass self (owner)"
grep -q "return gun_reload(&self.secondary)" "$vgen" || fail "plain composed thunk must route into &self.secondary with no owner/args"
grep -q "runner_secondary_fire_cmd :: proc" "$vgen" || fail "issue wrapper must be named per-entity (runner_secondary_fire_cmd)"
grep -q '{name = "primary_fire", predict = true' "$vgen" || fail "composed predict flag not carried"
grep -q '{name = "primary_reload", predict = false' "$vgen" || fail "plain composed command must have predict = false"
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
icgen="$ic/mob.gen.odin"
grep -q 'import play "godot:play"' "$icgen" || fail "imported block's package must be imported into the generated file"
grep -q "return play.gun_fire(&self.gun, self, _a0)" "$icgen" || fail "imported composed thunk must qualify (play.) and route + thread owner"
grep -q "MOB_CMD_GUN_FIRE :: u16" "$icgen" || fail "imported composed command index MOB_CMD_GUN_FIRE missing"

# ---- fixture 9: the REAL play.Gun library block composes into a consumer ------
# Embeds godot:play's Gun (state + the gun_fire verb) and asserts the whole block drops in: its
# @(gd_command) verb hoists onto the entity (imported + qualified, NO owner param), its Gun_Def
# knob-blob and its Machine(Gun_Mode) mode both compose into the descriptor.
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
tgen="$pg/turret.gen.odin"
grep -q 'import play "godot:play"' "$tgen" || fail "play.Gun consumer must import godot:play"
grep -q "return play.gun_fire(&self.weapon, _a0, _a1)" "$tgen" || fail "play.gun_fire must route into &self.weapon (imported, qualified, no owner)"
grep -q "TURRET_CMD_WEAPON_FIRE :: u16" "$tgen" || fail "play.Gun's verb must hoist as TURRET_CMD_WEAPON_FIRE"
grep -q "size_of(type_of(Turret{}.weapon.def))" "$tgen" || fail "the Gun_Def knob-blob must replicate through the embed"
grep -q "offset_of(type_of(Turret{}.weapon.mode), cur)" "$tgen" || fail "Machine(Gun_Mode) mode.cur must compose through the block"

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
mgen="$mc/robot.gen.odin"
grep -q '{name = "gear_level", trampoline = _robot_m_gear_level' "$mgen" || fail "composed method must register under the path-prefixed name gear_level"
grep -q "gear_level(&self.gear, self, i32(_a0))" "$mgen" || fail "method trampoline must route into &self.gear, thread the owner (self), and pass the arg"
grep -q '{name = "gear_ping", trampoline = _robot_m_gear_ping' "$mgen" || fail "@(gd_rpc) implies a composed method (gear_ping) too"
grep -q "gear_ping(&self.gear)" "$mgen" || fail "no-owner composed method must route into &self.gear with no self/args"
grep -q '{method = "gear_ping"' "$mgen" || fail "the composed @(gd_rpc) must register its RPC under the namespaced method name"

echo "SCRIPTGEN_OK"
