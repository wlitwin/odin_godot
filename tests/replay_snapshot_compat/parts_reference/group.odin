package replay_net_parts_reference

import r "godot:replay"

// An authored closed simulation group. State reuses the authority's value
// carrier, but project removes nonmembers instead of freezing them at another
// time. Outside dependencies must be explicit timestamped boundary values.
Prediction_Group :: struct($State: typeid) {
	id: u64,
	project: proc(authority: r.Frame(State), seat: u16) -> State,
	valid: proc(group: State, seat: u16) -> bool,
}

Prediction_View :: struct($State: typeid) {frame: r.Frame(State), group: u64, seat: u16}

client_prediction :: proc(c: ^Client($S, $C, $A, $E, $N)) -> (Prediction_View(S), bool) {
	if !c.initialized || c.spectator || !c.has_world {return {}, false}
	f, ok := r.current(&c.timeline)
	return {f, c.model.group.id, c.seat}, ok
}

@(private)
group_config_valid :: proc(g: Prediction_Group($S)) -> bool {
	return g.id == 0 ? g.project == nil && g.valid == nil : g.project != nil && g.valid != nil
}

@(private)
group_frame :: proc(model: Model($S, $C, $A, $E, $N), authority: r.Frame(S), seat: u16, spectator: bool) -> (r.Frame(S), bool) {
	if spectator || model.group.id == 0 {return authority, true}
	if seat == 0 || int(seat) > N {return {}, false}
	state := model.group.project(authority, seat)
	return {tick = authority.tick, state = state}, model.group.valid(state, seat)
}
