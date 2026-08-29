//gd:extends Node
//gd:class WireAbiFixture
package wireabi_fixture

import gd "godot:godot"
import knet "godot:kit/net"

TAG_WIRE_ABI :: u8(4)

Wire_Mode :: enum u8 {
	Idle,
	Walk,
	Run,
}

Wire_Inner :: struct {
	x:     u16,
	mode:  Wire_Mode,
	flags: u8,
}

// Twelve raw bytes, recursively described by NET_SCHEMA_CANONICAL. Every field
// boundary is naturally aligned and the final size has no compiler-owned tail.
Wire_Payload :: struct {
	stamp:   u32,
	inner:   Wire_Inner,
	samples: [2]i16,
}

WireAbiFixture :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	state:  Wire_Payload `gd:"replicate"`,
}

// The canonical ABI includes behavioral wire contract too: who may issue an
// action, whether it predicts, its argument ceiling, and when it is scheduled.
@(gd_command = knet.Action_Policy {
	access = .Any_Seat,
	prediction = .Optimistic,
	max_args_bytes = 32,
})
wire_abi_fixture_set :: proc(self: ^WireAbiFixture, sample: i16) -> (applied: bool, accepted: i16) {
	self.state.samples[0] = sample
	return true, sample
}

@(gd_half)
wire_abi_fixture_set_then :: proc(
	self: ^WireAbiFixture,
	by: knet.Player_Id,
	sample: i16,
	accepted: i16,
) {
	_ = self
	_ = by
	_ = sample
	_ = accepted
}

@(gd_message = "TAG_WIRE_ABI")
wire_abi_fixture_note :: proc(self: ^WireAbiFixture, from: knet.Player_Id, msg: Wire_Inner) {
	_ = self
	_ = from
	_ = msg
}
