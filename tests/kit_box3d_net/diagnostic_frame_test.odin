package kit_box3d_net_test

import "base:runtime"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import net "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

Diagnostic_Allocation_Gate :: struct {
	base:      mem.Allocator,
	remaining: int,
}
diagnostic_allocator :: proc(gate: ^Diagnostic_Allocation_Gate) -> mem.Allocator {
	return {
		data = gate,
		procedure = proc(
			data: rawptr,
			mode: mem.Allocator_Mode,
			size, alignment: int,
			old: rawptr,
			old_size: int,
			location: runtime.Source_Code_Location,
		) -> (
			[]u8,
			mem.Allocator_Error,
		) {
			gate := cast(^Diagnostic_Allocation_Gate)data
			if mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed {
				if gate.remaining == 0 {return nil, .Out_Of_Memory}
				if gate.remaining > 0 {gate.remaining -= 1}
			}
			return gate.base.procedure(
				gate.base.data,
				mode,
				size,
				alignment,
				old,
				old_size,
				location,
			)
		},
	}
}
diagnostic_expect_parts :: proc(t: ^testing.T, left, right: ^k.World_Diagnostic_Frame) {
	testing.expect_value(t, bd.compare(left.signature, right.signature), bd.Difference.Match)
	for part in bd.Part {testing.expect_value(t, mem.compare(left.view.parts[part], right.view.parts[part]), 0)}
}
@(test)
diagnostic_confirmed_bounds_and_exact_public_parity :: proc(t: ^testing.T) {
	baseline := k.world_diagnostic_frame_owned_bytes()
	host, client: Box; start_pair(&host, &client); cat := catalog(); defer b.recovery_catalog_destroy(&cat)
	setup(&host, 3, &cat); setup(&client, 3, &cat); defer destroy(&host); defer destroy(&client)
	frame: k.World_Diagnostic_Frame; defer k.world_diagnostic_frame_destroy(&frame)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Rejected,
	)
	bootstrap(t, &host, &client)
	before, be := k.lane_world_checkpoint(
		&client.lane,
		0,
	); testing.expect_value(t, be, k.World_Error.Ok); defer k.world_checkpoint_destroy(&before)
	side, _ := p.read(&client.physics); fields, fx := client.proxies, client.effects
	engine, es := b.engine_allocation_stats(); testing.expect_value(t, es, b.Status.Ok)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Ok,
	)
	engine_after, _ := b.engine_allocation_stats(
		
	); testing.expect_value(t, engine_after.total_calls, engine.total_calls)
	expected, se := k.lane_world_confirmed_signature(
		&client.lane,
		0,
	); testing.expect_value(t, se, k.World_Error.Ok)
	testing.expect_value(t, bd.compare(expected, frame.signature), bd.Difference.Match)
	signed, sign_error := bd.sign(
		frame.view,
	); testing.expect_value(t, sign_error, bd.Error.None); testing.expect_value(t, bd.compare(signed, frame.signature), bd.Difference.Match)
	wire, we := k.lane_world_export(
		&host.lane,
		0,
	); testing.expect_value(t, we, k.World_Error.Ok); defer delete(wire)
	sig, sige := bd.signature_decode(
		wire[:bd.SIGNATURE_BYTES],
	); testing.expect_value(t, sige, bd.Error.None)
	reader := net.reader_make(
		wire[bd.SIGNATURE_BYTES:],
	); recovery_size := int(net.read_u32(&reader)); _ = net.reader_view(&reader, recovery_size)
	for part in bd.Part {bytes := net.reader_view(&reader, int(sig.lengths[part])); testing.expect_value(t, mem.compare(bytes, frame.view.parts[part]), 0)}
	testing.expect(t, !reader.err && len(net.reader_remaining(&reader)) == 0)
	// Only the explicit authority exporter has a recovery attachment. The new
	// owner contains precisely the signed five diagnostic parts and no world.
	_, rejected := k.lane_world_export(
		&client.lane,
		0,
	); testing.expect_value(t, rejected, k.World_Error.Rejected)
	after, ae := k.lane_world_checkpoint(
		&client.lane,
		0,
	); testing.expect_value(t, ae, k.World_Error.Ok); defer k.world_checkpoint_destroy(&after)
	equal, ee := k.world_checkpoint_equal(
		&before,
		&after,
	); testing.expect_value(t, ee, k.World_Error.Ok); testing.expect(t, equal)
	current, _ := p.read(
		&client.physics,
	); testing.expect_value(t, current, side); testing.expect_value(t, client.proxies, fields); testing.expect_value(t, client.effects, fx)
	owner_ptr := raw_data(frame.view.parts[.Solver]); signature := frame.signature
	testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 1, &frame),
		k.World_Error.Rejected,
	)
	testing.expect_value(
		t,
		raw_data(frame.view.parts[.Solver]),
		owner_ptr,
	); testing.expect_value(t, frame.signature, signature)
	testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
	testing.expect(t, !k.lane_world_network_status(&client.lane).ready)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Ok,
	)
	k.world_diagnostic_frame_destroy(&frame); k.world_diagnostic_frame_destroy(&frame)
	testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), baseline)
}

@(test)
diagnostic_detached_clone_source_destroy_and_origin_release :: proc(t: ^testing.T) {
	baseline := k.world_diagnostic_frame_owned_bytes()
	host, client := new(Box), new(Box); start_pair(host, client); cat := catalog()
	setup(host, 3, &cat); setup(client, 3, &cat); bootstrap(t, host, client)
	frame, clone, later: k.World_Diagnostic_Frame
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Ok,
	)
	first_charge :=
		k.world_diagnostic_frame_owned_bytes() - baseline; testing.expect(t, first_charge > 0)
	testing.expect_value(t, k.world_diagnostic_frame_clone(&frame, &clone), k.World_Error.Ok)
	diagnostic_expect_parts(t, &frame, &clone)
	for part in bd.Part {if len(frame.view.parts[part]) > 0 {testing.expect(t, raw_data(frame.view.parts[part]) != raw_data(clone.view.parts[part]))}}
	testing.expect_value(t, k.world_diagnostic_frame_owned_bytes() - baseline, first_charge * 2)
	destroy(client); destroy(host); free(client); free(host); b.recovery_catalog_destroy(&cat)
	engine, _ := b.engine_allocation_stats(
		
	); wrapper, _ := b.snapshot_allocation_stats(); testing.expect_value(t, engine.live_bytes, u64(0)); testing.expect_value(t, wrapper.live_bytes, u64(0))
	testing.expect_value(
		t,
		k.world_diagnostic_frame_clone(&frame, &later),
		k.World_Error.Ok,
	); diagnostic_expect_parts(t, &frame, &later)
	// Self replacement clones first, then releases the former owner.
	testing.expect_value(
		t,
		k.world_diagnostic_frame_clone(&later, &later),
		k.World_Error.Ok,
	); diagnostic_expect_parts(t, &frame, &later)
	k.world_diagnostic_frame_destroy(&frame); k.world_diagnostic_frame_destroy(&clone)
	signed, error := bd.sign(
		later.view,
	); testing.expect_value(t, error, bd.Error.None); testing.expect_value(t, bd.compare(signed, later.signature), bd.Difference.Match)
	k.world_diagnostic_frame_destroy(&later); k.world_diagnostic_frame_destroy(&later)
	testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), baseline)
}

@(test)
diagnostic_failure_capacity_and_history_preserve_previous_owner :: proc(t: ^testing.T) {
	baseline := k.world_diagnostic_frame_owned_bytes()
	host, client: Box; start_pair(&host, &client); cat := catalog(); defer b.recovery_catalog_destroy(&cat)
	setup(
		&host,
		3,
		&cat,
	); setup(&client, 3, &cat); defer destroy(&host); defer destroy(&client); bootstrap(t, &host, &client)
	gate := Diagnostic_Allocation_Gate{context.allocator, -1}
	frame: k.World_Diagnostic_Frame; defer k.world_diagnostic_frame_destroy(&frame)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame, diagnostic_allocator(&gate)),
		k.World_Error.Ok,
	)
	charge := k.world_diagnostic_frame_owned_bytes(
		
	); pointer := raw_data(frame.view.parts[.Solver]); signature := frame.signature
	fields, fx := client.proxies, client.effects
	side, side_ok := p.read(&client.physics); testing.expect(t, side_ok)
	for fail in 0 ..< 2 {
		gate.remaining = fail
		testing.expect_value(
			t,
			k.lane_world_diagnostic_frame(&client.lane, 0, &frame, diagnostic_allocator(&gate)),
			k.World_Error.Allocation_Failed,
		)
		testing.expect_value(
			t,
			k.world_diagnostic_frame_owned_bytes(),
			charge,
		); testing.expect_value(t, raw_data(frame.view.parts[.Solver]), pointer); testing.expect_value(t, frame.signature, signature)
		gate.remaining = fail
		testing.expect_value(
			t,
			k.world_diagnostic_frame_clone(&frame, &frame),
			k.World_Error.Allocation_Failed,
		)
		testing.expect_value(
			t,
			k.world_diagnostic_frame_owned_bytes(),
			charge,
		); testing.expect_value(t, raw_data(frame.view.parts[.Solver]), pointer)
	}
	gate.remaining = -1
	old_encode := client.lane.world.network.config.codec.encode
	client.lane.world.network.config.codec.encode = proc(
		user, image: rawptr,
		part: bd.Part,
		out: []u8,
	) -> (
		int,
		k.World_Error,
	) {return k.WORLD_NETWORK_BYTES + 1, .Ok}
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Capacity,
	)
	client.lane.world.network.config.codec.encode = old_encode
	old_extra :=
		client.lane.world.config.additional_owned_bytes; client.lane.world.config.additional_owned_bytes = k.WORLD_MEMORY_BYTES
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Budget,
	)
	client.lane.world.config.additional_owned_bytes = old_extra
	testing.expect_value(
		t,
		frame.signature,
		signature,
	); testing.expect_value(t, raw_data(frame.view.parts[.Solver]), pointer); testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), charge)
	testing.expect_value(
		t,
		client.proxies,
		fields,
	); now, ok := p.read(&client.physics); testing.expect(t, ok); testing.expect_value(t, now, side); testing.expect_value(t, client.effects, fx)
	for _ in 0 ..< 129 {testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1); discard(&host)}
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&host.lane, 0, &frame),
		k.World_Error.History_Missing,
	)
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&host.lane, k.lane_now(&host.lane) + 1, &frame),
		k.World_Error.History_Missing,
	)
	testing.expect_value(
		t,
		frame.signature,
		signature,
	); testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), charge)
	k.world_diagnostic_frame_destroy(
		&frame,
	); testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), baseline)
}

@(test)
diagnostic_registry_two_lane_boundary_detach_and_failed_attach :: proc(t: ^testing.T) {
	baseline := k.world_diagnostic_frame_owned_bytes()
	host, client := new(Box), new(Box); start_pair(host, client); cat := catalog()
	setup(host, 3, &cat); setup(client, 3, &cat); bootstrap(t, host, client)
	frame, copy: k.World_Diagnostic_Frame
	testing.expect_value(
		t,
		k.lane_world_diagnostic_frame(&client.lane, 0, &frame),
		k.World_Error.Ok,
	)
	charge := k.world_diagnostic_frame_owned_bytes() - baseline
	checkpoint, ce := k.lane_world_checkpoint(
		&host.lane,
		0,
	); testing.expect_value(t, ce, k.World_Error.Ok)
	testing.expect_value(
		t,
		k.lane_world_owned_bytes(&host.lane),
		k.lane_world_owned_bytes(&client.lane),
	)
	engine, _ := b.engine_allocation_stats(); wrapper, _ := b.snapshot_allocation_stats()
	total :=
		engine.live_bytes +
		wrapper.live_bytes +
		p.owned_bytes() +
		k.lane_world_owned_bytes(&host.lane)
	testing.expect(t, total + charge < k.WORLD_MEMORY_BYTES)
	// Model nonduplicated external ownership in the SECOND Lane. A detached
	// clone must include it even though its original bytes came from the first.
	client.lane.world.config.additional_owned_bytes += k.WORLD_MEMORY_BYTES - total - charge + 1
	original_pointer := raw_data(frame.view.parts[.Solver]); original_signature := frame.signature
	fields := host.proxies; side, _ := p.read(&host.physics); effects := host.effects
	testing.expect_value(t, k.world_diagnostic_frame_clone(&frame, &frame), k.World_Error.Budget)
	failed_copy, error := k.world_checkpoint_clone(
		&checkpoint,
	); testing.expect_value(t, error, k.World_Error.Budget); testing.expect(t, failed_copy.image == nil)
	testing.expect_value(
		t,
		raw_data(frame.view.parts[.Solver]),
		original_pointer,
	); testing.expect_value(t, frame.signature, original_signature)
	now, _ := p.read(
		&host.physics,
	); testing.expect_value(t, now, side); testing.expect_value(t, host.proxies, fields); testing.expect_value(t, host.effects, effects)
	client.lane.world.config.additional_owned_bytes -= 1
	testing.expect_value(t, k.world_diagnostic_frame_clone(&frame, &copy), k.World_Error.Ok)
	diagnostic_expect_parts(t, &frame, &copy); k.world_diagnostic_frame_destroy(&copy)
	destroy(client); free(client)
	testing.expect_value(
		t,
		k.world_diagnostic_frame_clone(&frame, &copy),
		k.World_Error.Ok,
	); k.world_diagnostic_frame_destroy(&copy)
	// Partial Core attach failure after its candidate becomes visible to its
	// own accounting must not register or leave a stale Lane in the list.
	probe: Box; probe.peer = s.HOST_PEER; probe.ses.send = send; probe.ses.send_user = &probe; s.session_host_start(&probe.ses, "failed-attach")
	k.lane_init(&probe.lane, &probe.ses, size_of(Control), cfg = {slots = 128})
	provider := host.lane.world.provider; provider.initial_execution = host.lane.world.published
	provider.capture = proc(user, execution: rawptr) -> (rawptr, k.World_Error) {return nil,
			.Allocation_Failed}
	stable := k.lane_world_owned_bytes(&host.lane)
	for _ in 0 ..< 3 {
		testing.expect_value(
			t,
			k.lane_world_attach(&probe.lane, provider, nil),
			k.World_Error.Allocation_Failed,
		)
		testing.expect(
			t,
			probe.lane.world == nil,
		); testing.expect_value(t, k.lane_world_owned_bytes(&host.lane), stable)
	}
	k.lane_destroy(&probe.lane); s.session_destroy(&probe.ses)
	k.world_checkpoint_destroy(&checkpoint); destroy(host); free(host)
	// No registry node or owner callback now retains either source Lane.
	testing.expect_value(
		t,
		k.world_diagnostic_frame_clone(&frame, &copy),
		k.World_Error.Ok,
	); k.world_diagnostic_frame_destroy(&copy)
	for _ in 0 ..< 3 {
		again: Box; auxiliary(&again, &cat)
		testing.expect_value(
			t,
			k.world_diagnostic_frame_clone(&frame, &copy),
			k.World_Error.Ok,
		); k.world_diagnostic_frame_destroy(&copy)
		destroy(&again)
	}
	b.recovery_catalog_destroy(&cat); k.world_diagnostic_frame_destroy(&frame)
	testing.expect_value(t, k.world_diagnostic_frame_owned_bytes(), baseline)
}
