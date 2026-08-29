package wireabi_native

import fixture "../scripts"
import "core:fmt"
import knet "godot:kit/net"

main :: proc() {
	actual := fixture.Wire_Fixture_Actual_Bytes()
	assert(
		actual == fixture.WIRE_FIXTURE_BYTES,
		"native raw bytes differ from the canonical fixture",
	)
	schema := &fixture.NET_SCHEMA
	assert(knet.net_schema_valid(schema))
	broken := schema^
	broken.abi_fingerprint ~= 1
	assert(!knet.net_schema_valid(&broken))
	assert(schema.abi_version == 1 && schema.endian == .Little)
	assert(schema.abi_fingerprint == fixture.NET_ABI_FINGERPRINT)
	assert(schema.fingerprint == fixture.NET_FINGERPRINT)
	assert(schema.canonical == fixture.NET_SCHEMA_CANONICAL)
	assert(len(schema.entities) == 1 && schema.entities[0].name == "WireAbiFixture")
	field, field_ok := knet.net_schema_field(schema, "WireAbiFixture", "state")
	assert(field_ok && field.struct_width == 12 && field.wire_width == 12)
	assert(knet.net_schema_span_valid(field.types, len(schema.types)))
	action, action_ok := knet.net_schema_action(schema, "WireAbiFixture", "set")
	assert(action_ok && action.model == .Immediate)
	assert(action.policy.access == .Any_Seat && action.policy.prediction == .Optimistic)
	args := knet.net_schema_action_args(schema, action)
	assert(len(args) == 1 && args[0].name == "sample" && args[0].kind == "i16")
	outcomes := knet.net_schema_action_outcomes(schema, action)
	assert(len(outcomes) == 1 && outcomes[0].name == "accepted" && outcomes[0].type_name == "i16")
	assert(action.consequence.name == "wire_abi_fixture_set_then")
	assert(action.consequence.authority_only && !action.consequence.takes_game)
	assert(len(schema.messages) == 1 && schema.messages[0].tag == 4)
	fmt.printf(
		"WIREABI_NATIVE fp=0x%x fields=%d actions=%d bytes=",
		fixture.NET_ABI_FINGERPRINT,
		len(schema.fields),
		len(schema.actions),
	)
	for b in actual {fmt.printf("%02x", b)}
	fmt.println()
}
