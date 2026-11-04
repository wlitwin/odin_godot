package kit_box3d_net_test

import "core:testing"
import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

expect_same :: proc(t: ^testing.T, host, client: ^Box, tick: u64) {
	a, ae := k.lane_world_checkpoint(
		&host.lane,
		tick,
	); testing.expect_value(t, ae, k.World_Error.Ok); defer k.world_checkpoint_destroy(&a)
	c, ce := k.lane_world_checkpoint(
		&client.lane,
		tick,
	); testing.expect_value(t, ce, k.World_Error.Ok); defer k.world_checkpoint_destroy(&c)
	equal, ee := k.world_checkpoint_equal(
		&a,
		&c,
	); testing.expect_value(t, ee, k.World_Error.Ok); testing.expect(t, equal)
	sa, se := k.lane_world_confirmed_signature(
		&host.lane,
		tick,
	); sc, sce := k.lane_world_confirmed_signature(&client.lane, tick)
	testing.expect_value(
		t,
		se,
		k.World_Error.Ok,
	); testing.expect_value(t, sce, k.World_Error.Ok); testing.expect_value(t, bd.compare(sa, sc), bd.Difference.Match)
}
bootstrap :: proc(t: ^testing.T, host, client: ^Box) {
	testing.expect_value(
		t,
		k.lane_world_send_checkpoint(&host.lane, client.peer, .Welcome),
		k.World_Error.Ok,
	)
	pump({host, client}); testing.expect_value(t, k.lane_frame(&client.lane, 0), 0)
	testing.expect(
		t,
		k.lane_world_network_status(&client.lane).ready,
	); expect_same(t, host, client, 0)
}
@(test)
accepted_controls_actions_replace_guesses_through_session :: proc(t: ^testing.T) {
 host, client: Box; start_pair(&host, &client); cat := catalog(); defer b.recovery_catalog_destroy(&cat)
 setup(&host, 3, &cat); setup(&client, 3, &cat); defer destroy(&host); defer destroy(&client)
 bootstrap(t, &host, &client)
 client.axis = 1; client.action_at = 1; client.action_kind = 1
 if !advance_pair_to(t, &host, &client, 3) {return}
 expect_same(t, &host, &client, 3); expect_full5(t, &host, &client, 3)
 accepted, origin, sequence, e := k.lane_world_accepted_input(&client.lane, 1, 2, 1)
 testing.expect_value(t, e, k.World_Error.Ok)
 testing.expect_value(t, origin, k.World_Input_Origin.Submitted); testing.expect_value(t, sequence, u64(1))
 if e == .Ok {testing.expect_value(t, (cast(^Action)raw_data(accepted)).kind, u32(1))}
 game, _ := p.read(&client.physics); testing.expect_value(t, game.births, u32(1))
 // An impulse on the hinged first body does not guarantee different state.
 // A real Host Spawn6 after the Client Remove5 leaves an extra body and a
 // different Side at6, before the Client receives this authority-only action.
 // ACCEPTED is a fact receipt; only the actual cadence SIGNATURE6 verifies it.
 host.axis = 2; host.action_at = 6; host.action_kind = 1
 client.action_at = 5; client.action_kind = 2
 for _ in 0 ..< 3 {if !advance_one(t, &client) {return}}
 pump({&host, &client})
 for _ in 0 ..< 3 {if !advance_one(t, &host) {return}}
 expect_ordinary(t, &host)
 authority, ae := k.lane_world_checkpoint(&host.lane, 6)
 predicted, pe := k.lane_world_checkpoint(&client.lane, 6)
 testing.expect_value(t, ae, k.World_Error.Ok); testing.expect_value(t, pe, k.World_Error.Ok)
 defer k.world_checkpoint_destroy(&authority); defer k.world_checkpoint_destroy(&predicted)
 authority_side, ase := p.checkpoint_side(&authority, Side)
 predicted_side, pse := p.checkpoint_side(&predicted, Side)
 testing.expect_value(t, ase, k.World_Error.Ok); testing.expect_value(t, pse, k.World_Error.Ok)
 testing.expect_value(t, authority_side.births, u32(2)); testing.expect_value(t, predicted_side.births, u32(1))
 testing.expect_value(t, authority_side.deaths, u32(1)); testing.expect_value(t, predicted_side.deaths, u32(1))
 testing.expect(t, authority_side.alive[authority_side.initial] && !predicted_side.alive[predicted_side.initial])
 authority_observed, aoe := p.observe(&host.physics)
 predicted_observed, poe := p.observe(&client.physics)
 testing.expect_value(t, aoe, k.World_Error.Ok); testing.expect_value(t, poe, k.World_Error.Ok)
 testing.expect_value(t, authority_observed.counts.body_count, predicted_observed.counts.body_count + 1)
 equal, ee := k.world_checkpoint_equal(&authority, &predicted)
 testing.expect_value(t, ee, k.World_Error.Ok); testing.expect(t, !equal, "the real prediction must differ before verified repair")
 testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(3))
 resims, effects := client.lane.stat_resims, client.effects
 pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
 testing.expect_value(t, k.lane_world_protocol_status(&client.lane).matched_signature_tick, u64(6))
 testing.expect_value(t, client.lane.stat_resims - resims, 3)
 expect_same(t, &host, &client, 6); expect_full5(t, &host, &client, 6)
 testing.expect_value(t, client.effects, effects + 1) // exactly the previously unknown Host Spawn6, no duplicate old FX
 authority_action, action_origin, action_sequence, action_error := k.lane_world_accepted_input(&client.lane, 6, 1, 1)
 testing.expect_value(t, action_error, k.World_Error.Ok)
 testing.expect_value(t, action_origin, k.World_Input_Origin.Authority); testing.expect_value(t, action_sequence, u64(6))
 if action_error == .Ok {
  testing.expect_value(t, (cast(^Action)raw_data(authority_action)).kind, u32(1))
  testing.expect_value(t, (cast(^Action)raw_data(authority_action)).serial, u32(6))
 }
 game, _ = p.read(&client.physics)
 testing.expect_value(t, game.births, u32(2)); testing.expect_value(t, game.deaths, u32(1)); testing.expect(t, game.ends >= 1)
 testing.expect_value(t, client.effects, host.effects)
 old_protocol := k.lane_world_protocol_status(&client.lane)
 old_epoch := k.lane_world_epoch(&client.lane)
 testing.expect_value(t, k.lane_world_begin_epoch(&host.lane, 3), k.World_Error.Ok)
 testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Reset), k.World_Error.Ok)
 pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
 // Sequence is epoch-local: begin_epoch resets it, so first Reset is1.
 // Require the actual new (epoch, scope) and complete validated publication.
 current_protocol := k.lane_world_protocol_status(&client.lane)
 testing.expect_value(t, k.lane_world_epoch(&client.lane), u64(3))
 testing.expect(t, k.lane_world_epoch(&client.lane) > old_epoch)
 testing.expect_value(t, current_protocol.bootstrap_sequence, u64(1))
 testing.expect_value(t, current_protocol.full_states_received, old_protocol.full_states_received + 1)
 testing.expect_value(t, current_protocol.matched_signature_tick, u64(6))
 if !advance_pair_to(t, &host, &client, 9) {return}
 expect_same(t, &host, &client, 9); expect_full5(t, &host, &client, 9)
 testing.expect_value(t, k.lane_world_network_status(&client.lane).epoch, u64(3))
 testing.expect_value(t, client.effects, host.effects)
}

@(test)
complete_wire_late_join_survives_source_and_catalog_destruction :: proc(t: ^testing.T) {
	host := new(Box); client := new(Box); defer free(client); start_pair(host, client)
	cat := catalog(); setup(host, 3, &cat)
	for _ in 0 ..< 10 {testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)}
	expected, ce := k.lane_world_checkpoint(
		&host.lane,
		10,
	); testing.expect_value(t, ce, k.World_Error.Ok); defer k.world_checkpoint_destroy(&expected)
	testing.expect_value(
		t,
		k.lane_world_send_checkpoint(&host.lane, client.peer, .Welcome),
		k.World_Error.Ok,
	)
	saved := host.out; host.out = nil; destroy(host); free(host); b.recovery_catalog_destroy(&cat)
	// A newly constructed destination uses its own catalog and native world.
	cat = catalog(
		
	); setup(client, 3, &cat); b.recovery_catalog_destroy(&cat); defer destroy(client)
	for parcel in saved {if parcel.to == client.peer {
			r := n.reader_make(parcel.bytes); s.session_handle_packet(&client.ses, s.HOST_PEER, &r)
		}; delete(parcel.bytes)}; delete(saved)
	_ = k.lane_frame(
		&client.lane,
		0,
	); testing.expect(t, k.lane_world_network_status(&client.lane).ready)
	actual, ae := k.lane_world_checkpoint(
		&client.lane,
		10,
	); testing.expect_value(t, ae, k.World_Error.Ok); defer k.world_checkpoint_destroy(&actual)
	same, e := k.world_checkpoint_equal(
		&expected,
		&actual,
	); testing.expect_value(t, e, k.World_Error.Ok); testing.expect(t, same)
	testing.expect_value(t, client.effects, 0) // bootstrap seeds history, no old cosmetics
	k.world_checkpoint_destroy(&expected) // no remaining source geometry owner before execution
	testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
}

@(test)
failed_revision_preserves_pair_and_explicit_resync_repairs_hold :: proc(t: ^testing.T) {
 host, client: Box; start_pair(&host, &client); cat := catalog(); defer b.recovery_catalog_destroy(&cat)
 setup(&host, 3, &cat); setup(&client, 3, &cat); defer destroy(&host); defer destroy(&client)
 bootstrap(t, &host, &client)
 for _ in 0 ..< 3 {if !advance_one(t, &client) {return}}
 before, be := k.lane_world_checkpoint(&client.lane, 3)
 testing.expect_value(t, be, k.World_Error.Ok); defer k.world_checkpoint_destroy(&before)
 protected: k.World_Diagnostic_Frame
 testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 0, &protected), k.World_Error.Ok)
 defer k.world_diagnostic_frame_destroy(&protected)
 fields, fx := client.proxies, client.effects; side, _ := p.read(&client.physics)
 net := client.lane.world.network; used := net.used
 used_data := make([]u8, len(net.used_data)); copy(used_data, net.used_data); defer delete(used_data)
 client.fail = true; host.axis = 2
 pump({&host, &client})
 for _ in 0 ..< 3 {if !advance_one(t, &host) {return}}
 expect_ordinary(t, &host)
 pump({&host, &client}); _ = k.lane_frame(&client.lane, 0) // actual SIGNATURE3 repair fails in staged callback
 after, ae := k.lane_world_checkpoint(&client.lane, 3)
 testing.expect_value(t, ae, k.World_Error.Ok); defer k.world_checkpoint_destroy(&after)
 same, e := k.world_checkpoint_equal(&before, &after)
 testing.expect_value(t, e, k.World_Error.Ok); testing.expect(t, same)
 current: k.World_Diagnostic_Frame
 testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 0, &current), k.World_Error.Ok)
 defer k.world_diagnostic_frame_destroy(&current)
 for part in bd.Part {testing.expect_value(t, mem.compare(protected.view.parts[part], current.view.parts[part]), 0)}
 now, _ := p.read(&client.physics)
 testing.expect_value(t, now, side); testing.expect_value(t, fields, client.proxies); testing.expect_value(t, client.effects, fx)
 testing.expect_value(t, k.lane_now(&client.lane), u64(3)); testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(0))
 testing.expect_value(t, net.used, used); testing.expect_value(t, mem.compare(net.used_data, used_data), 0)
 testing.expect(t, k.lane_world_needs_resync(&client.lane))
 // Immutable received authority facts survive a failed Native/Side revision;
 // that does not authorize any used-state, confirmation or effect publication.
 accepted, origin, sequence, ledger_error := k.lane_world_accepted_input(&client.lane, 1, 1, 0)
 testing.expect_value(t, ledger_error, k.World_Error.Ok)
 testing.expect_value(t, origin, k.World_Input_Origin.Authority); testing.expect_value(t, sequence, u64(1))
 if ledger_error == .Ok {testing.expect_value(t, (cast(^Control)raw_data(accepted)).axis, i32(2))}
 client.fail = false
 testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
 pump({&host, &client}); _ = k.lane_frame(&host.lane, 0); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
 expect_same(t, &host, &client, 3); expect_full5(t, &host, &client, 3)
 for _ in 0 ..< 8 {if !advance_one(t, &client) {return}}
 limited := false
 for _ in 0 ..< 4 {
  testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 120), 0)
  limited = limited || k.lane_world_status(&client.lane) == .Prediction_Limit
  testing.expect_value(t, k.lane_now(&client.lane), u64(11))
 }
 testing.expect(t, limited, "the ninth prediction tick must actually hit the existing8-tick hold")
 predicted_fx := client.effects
 prior_scope := k.lane_world_protocol_status(&client.lane).bootstrap_sequence
 testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
 pump({&host, &client}); _ = k.lane_frame(&host.lane, 0); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
 testing.expect_value(t, client.effects, predicted_fx) // Reset does not replay old cosmetics
 testing.expect(t, k.lane_world_protocol_status(&client.lane).bootstrap_sequence > prior_scope)
 expect_same(t, &host, &client, 3); expect_full5(t, &host, &client, 3)
 authority_fx := host.effects
 if !advance_pair_to(t, &host, &client, 6) {return}
 expect_same(t, &host, &client, 6); expect_full5(t, &host, &client, 6)
 testing.expect_value(t, client.effects - predicted_fx, 1)
 testing.expect_value(t, host.effects - authority_fx, 1)
}
