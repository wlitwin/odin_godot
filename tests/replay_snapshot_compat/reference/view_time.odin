package replay_net_legacy

import r "godot:replay"

View_Status :: enum u8 {Unavailable, Live, Historical, Expired, Invalid}
View_Time :: struct {from, to: u64, fraction: u16, status: View_Status}
View_Stamp :: struct {from_id, to_id, from_tick, to_tick: u64, fraction: u16, valid: bool}

@(private)
Sent_View :: struct {id, tick, sent_ms: u64, valid: bool}

// Sample the observed presentation and bind exactly that bracket to subsequent
// input samples. Compute aim from these same returned frames/alpha. Reading a
// newer network snapshot later in the frame does not rewrite an earlier aim.
client_present :: proc(c: ^Client($S, $C, $A, $E, $N)) -> (a, b: r.Frame(S), alpha: f32, ok: bool) {
	first, second, fraction, available := client_observed(c)
	a = first
	b = second
	alpha, ok = fraction, available
	if !ok {c.presented = {}; return}
	q := u16(clamp(alpha, 0, 1) * 65535)
	c.presented = {from_id = c.observed_ids[a.tick % u64(c.cfg.history)], to_id = c.observed_ids[b.tick % u64(c.cfg.history)],
	               from_tick = a.tick, to_tick = b.tick, fraction = q, valid = true}
	// Drawing and querying use the identical quantized interpolation fraction.
	return a, b, f32(q) / 65535, true
}

view_position :: proc(v: View_Time) -> f64 {return f64(v.from) + (v.to >= v.from ? f64(v.to - v.from) : 0) * f64(v.fraction) / 65535}

@(private)
view_shape_valid :: proc(v: View_Stamp) -> bool {
	return !v.valid ? v == (View_Stamp{}) : v.to_tick >= v.from_tick
}

@(private)
view_time_valid :: proc(v: View_Time, tick: u64, span: u32) -> bool {
	if v.status > .Invalid {return false}
	if v.status == .Historical {return v.from <= v.to && v.to <= tick && v.to - v.from <= u64(span)}
	if v.status == .Live {return v.from == v.to && v.to <= tick && v.fraction == 0}
	return true // Rejected hints are retained for diagnostics, never queried.
}

@(private)
server_view :: proc(s: ^Server($S, $C, $A, $E, $N), index: int, v: View_Stamp) -> View_Time {
	if !v.valid {return {status = .Unavailable}}
	result := View_Time{v.from_tick, v.to_tick, v.fraction, .Invalid}
	if !view_shape_valid(v) || v.to_tick > s.timeline.head || v.to_tick - v.from_tick > u64(s.cfg.max_view_span) {s.stats.rejected_views += 1; return result}
	peer := &s.peers[index]
	from, a := sent_view(s, index, v.from_id, v.from_tick)
	to, b := sent_view(s, index, v.to_id, v.to_tick)
	if !a || !b {s.stats.rejected_views += 1; return result}
	_ = from; _ = to
	age := f64(s.timeline.head) - view_position(result)
	bound := u64(s.cfg.max_rewind)
	if peer.rtt_floor_ms != 0 {
		observed := (peer.rtt_floor_ms * u64(s.cfg.hz) + 999) / 1000 + u64(s.cfg.watch_delay) + u64(s.cfg.view_slack)
		bound = min(bound, observed)
	}
	if age > f64(bound) {s.stats.expired_views += 1; result.status = .Expired; return result}
	result.status = .Historical
	return result
}

@(private)
sent_view :: proc(s: ^Server($S, $C, $A, $E, $N), index: int, id, tick: u64) -> (Sent_View, bool) {
	peer := &s.peers[index]
	if id == 0 {return peer.welcome_view, peer.welcome_view.valid && peer.welcome_view.tick == tick}
	for proof in s.snapshot_tx[index].views {if proof.valid && proof.id == id && proof.tick == tick {return proof, true}}
	return {}, false
}
