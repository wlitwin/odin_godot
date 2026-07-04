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
#       no replicated fields, platform-width int args, non-bool returns.
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
# wrappers are typed and role-branch on ctx.is_authority.
for needle in \
	'_pawn_cmd_hit :: proc(entity: rawptr, r: ^knet.Reader) -> bool' \
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
echo "$CMD2_OUT" | grep -q "must return exactly \`bool\`" \
	|| { echo "REPGEN_FAIL: missing the non-bool-return command error"; echo "$CMD2_OUT" | tail -3; exit 1; }
echo "  ok  bad command signatures rejected at scriptgen time"

echo "REPGEN_OK"
