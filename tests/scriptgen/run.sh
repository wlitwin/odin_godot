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

echo "SCRIPTGEN_OK"
