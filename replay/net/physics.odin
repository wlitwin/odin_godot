package replay_net

import r "godot:replay"

// The existing network model callback can run in a locally managed Timeline.
// This exposes the actual action rejection/savepoint path for local adapters and
// tests, without pretending that a physics wire/recovery codec is available.
// Pass &model as Timeline's immutable user metadata; model.user stays immutable.
model_callback :: proc($S, $C, $A, $E: typeid, $N: int) -> proc(^S, Batch(C, A, N), ^r.Step(Net_Event(E))) {
	return proc(state: ^S, input: Batch(C, A, N), ctx: ^r.Step(Net_Event(E))) {
		network_step(state, input, ctx)
	}
}
