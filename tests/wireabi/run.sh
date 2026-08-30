#!/usr/bin/env bash
# Canonical wire-ABI target fixture. Scriptgen emits one schema/fingerprint;
# native, web, Linux, and Windows checks must all accept the generated layout
# and endian assertions plus the same raw-byte-producing fixture.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ODIN="${ODIN:-odin}"
SCRIPTS="$ROOT/tests/wireabi/scripts"

source "$ROOT/build/common.sh"
build_scriptgen
run_scriptgen "$SCRIPTS"

ATTRS=(
	-custom-attribute:gd_method -custom-attribute:gd_connect
	-custom-attribute:gd_rpc -custom-attribute:gd_command
	-custom-attribute:gd_tick -custom-attribute:gd_input
	-custom-attribute:gd_sample -custom-attribute:gd_step
	-custom-attribute:gd_event -custom-attribute:gd_cue -custom-attribute:gd_fact
	-custom-attribute:gd_half -custom-attribute:gd_message
)

check_target() {
	local label="$1"; shift
	"$ODIN" check "$SCRIPTS" -collection:godot="$ROOT" -no-entry-point "${ATTRS[@]}" "$@"
	echo "  ok  $label accepts the canonical fingerprint and byte vector"
}

"$ODIN" run "$ROOT/tests/wireabi/native" -collection:godot="$ROOT" "${ATTRS[@]}"
echo "  ok  native produced the canonical raw byte vector"
check_target web -target:freestanding_wasm32 -define:ODIN_GODOT_WEB=true
check_target linux-amd64 -target:linux_amd64
check_target windows-amd64 -target:windows_amd64

GUARD="$SCRIPTS/odin_godot_guard.gen.odin"
grep -q '^NET_ABI_FINGERPRINT :: u64(0x' "$GUARD"
grep -q '^NET_SCHEMA_CANONICAL :: `wire-abi v=1 endian=little' "$GUARD"
grep -q '^NET_SCHEMA := _guard_knet.Net_Schema {' "$GUARD"
grep -q 'field entity.WireAbiFixture.state lane=delta encoding=raw struct-width=12 wire-width=12' "$GUARD"
grep -q 'type entity.WireAbiFixture.state.inner.mode kind=enum width=1 align=1 base=u8 values=Idle=#0,Walk=#1,Run=#2' "$GUARD"
grep -q 'action entity.WireAbiFixture.set id=.* access=any-seat prediction=optimistic schedule=immediate args-bound=32' "$GUARD"
grep -q 'arg entity.WireAbiFixture.set.sample index=0 kind=i16 width=2 bound=1' "$GUARD"
grep -q 'message message.WireAbiFixture.note tag=4 tag-name=TAG_WIRE_ABI encoding=raw width=4 bound=262144' "$GUARD"
grep -q '{path = "entity.WireAbiFixture.state", entity = "WireAbiFixture", name = "state", lane = .Delta' "$GUARD"
grep -q '{path = "entity.WireAbiFixture.set", entity = "WireAbiFixture", name = "set".*model = .Immediate' "$GUARD"
grep -q '{owner = "entity.WireAbiFixture.set", name = "accepted", type_name = "i16"}' "$GUARD"
grep -q 'consequence = {name = "wire_abi_fixture_set_then", authority_only = true, takes_game = false}' "$GUARD"
grep -q '{path = "message.WireAbiFixture.note", entity = "WireAbiFixture", name = "note".*tag = 4' "$GUARD"

# A profile-only package proves NET_SCHEMA is emitted even when the canonical
# ABI surface has no replicated entity or action descriptor.
PROFILE="$ROOT/tests/wireabi/profile"
run_scriptgen "$PROFILE"
"$ODIN" check "$PROFILE" -collection:godot="$ROOT" -no-entry-point "${ATTRS[@]}"
PROFILE_GUARD="$PROFILE/odin_godot_guard.gen.odin"
grep -q 'profile profile.Profile_Row encoding=raw width=4 bound=256' "$PROFILE_GUARD"
grep -q '{path = "profile.Profile_Row", type_name = "Profile_Row", encoding = "raw", width = 4, bound = 256' "$PROFILE_GUARD"
grep -q '^NET_SCHEMA := _guard_knet.Net_Schema {' "$PROFILE_GUARD"
echo "  ok  profile-only packages expose their canonical row through NET_SCHEMA"

# Build an incompatible sibling schema (u32 stamp -> u64) and pin the exact
# fingerprints used by the real in-memory JOIN test in tests/kitsession.
ALT_ROOT="$(mktemp -d)"
odin_gd_cleanup_on_exit "$ALT_ROOT"
ALT="$ALT_ROOT/scripts"
mkdir -p "$ALT"
cp "$SCRIPTS/fixture.odin" "$ALT/fixture.odin"
sed -i.bak 's/stamp:   u32/stamp:   u64/' "$ALT/fixture.odin"
rm -f "$ALT/fixture.odin.bak"
grep -q 'stamp:   u64' "$ALT/fixture.odin" || {
	echo "WIREABI_FAIL: incompatible-schema mutation was a no-op" >&2
	exit 1
}
run_scriptgen "$ALT"
BASE_FP="$(sed -n 's/^NET_FINGERPRINT :: u64(\(0x[0-9a-f]*\)).*/\1/p' "$GUARD")"
ALT_FP="$(sed -n 's/^NET_FINGERPRINT :: u64(\(0x[0-9a-f]*\)).*/\1/p' "$ALT/odin_godot_guard.gen.odin")"
[[ "$BASE_FP" == "0xfc3f66e9fcd2414b" ]]
[[ "$ALT_FP" == "0x72a0945e37810e4e" ]]
[[ "$BASE_FP" != "$ALT_FP" ]]
grep -q 'WIRE_FIXTURE_FINGERPRINT :: u64(0xfc3f66e9fcd2414b)' "$ROOT/tests/kitsession/kitsession_test.odin"
grep -q 'WIRE_FIXTURE_U64_FINGERPRINT :: u64(0x72a0945e37810e4e)' "$ROOT/tests/kitsession/kitsession_test.odin"
echo "  ok  incompatible recursive schema moves the handshake fingerprint"

# The route's numeric byte, not merely its source identifier, is schema data.
TAG_ALT="$ALT_ROOT/tag/scripts"
mkdir -p "$TAG_ALT"
cp "$SCRIPTS/fixture.odin" "$TAG_ALT/fixture.odin"
sed -i.bak 's/TAG_WIRE_ABI :: u8(4)/TAG_WIRE_ABI :: u8(5)/' "$TAG_ALT/fixture.odin"
rm -f "$TAG_ALT/fixture.odin.bak"
run_scriptgen "$TAG_ALT"
TAG_FP="$(sed -n 's/^NET_FINGERPRINT :: u64(\(0x[0-9a-f]*\)).*/\1/p' "$TAG_ALT/odin_godot_guard.gen.odin")"
[[ "$BASE_FP" != "$TAG_FP" ]]
grep -q 'message message.WireAbiFixture.note tag=5 tag-name=TAG_WIRE_ABI' "$TAG_ALT/odin_godot_guard.gen.odin"
echo "  ok  changing a typed-message tag byte moves the fingerprint"

expect_reject() {
	local name="$1" needle="$2" dir="$ROOT/tests/wireabi/reject/$1" log="$ALT_ROOT/$1.log"
	if "$SGEN" "$dir" -godot:"$ROOT" >"$log" 2>&1; then
		echo "WIREABI_FAIL: $name was accepted" >&2
		exit 1
	fi
	grep -q "$needle" "$log" || {
		echo "WIREABI_FAIL: $name failed without expected diagnostic /$needle/" >&2
		cat "$log" >&2
		exit 1
	}
}

expect_reject platform_sensitive 'platform/build-dependent wire width'
expect_reject platform_uint 'platform/build-dependent wire width'
expect_reject implicit_enum 'implicit platform-width storage'
expect_reject computed_enum 'network enum assignments must be integer literals'
expect_reject pointer 'unsupported wire type'
expect_reject padding 'implicit padding byte'
expect_reject container 'unsupported wire type'
expect_reject input 'input.Bad_Input.count: "int" has a platform/build-dependent wire width'
expect_reject profile 'profile.Bad_Profile.target: unsupported wire type'
expect_reject message 'message.BadMessageWire.receive.text: unsupported wire type'
echo "  ok  recursive validation rejects bad replicated fields, inputs, profiles, and typed messages"

echo "WIREABI_OK"
