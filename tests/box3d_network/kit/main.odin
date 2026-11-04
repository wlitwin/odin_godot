package main
import comm "../common"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import pf "godot:tests/replay_physics_net/fixture"

adapter_send :: proc(user: rawptr, to: s.Peer_Id, bytes: []u8, channel: s.Channel) {
	box := cast(^Box)user
	expected :=
		box.peer == s.HOST_PEER ? s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1) : s.HOST_PEER
	if to != expected && to != s.BROADCAST_PEER {return}
	if box.args.role == 1 &&
	   channel == .Stream &&
	   box.stale_count ==
		   0 {assert(len(bytes) <= len(box.stale_bytes)); copy(box.stale_bytes[:], bytes); box.stale_count = len(bytes); box.stale_channel = u32(channel)}
	result := comm.send(&box.endpoint, u32(channel), bytes)
	assert(
		result == 1,
		"bounded Kit transport backpressure/disconnect; Reliable never silently dropped",
	)
}
start :: proc(box: ^Box, args: comm.Args) {
	box.args =
		args; box.peer = args.role == 1 ? s.HOST_PEER : s.Peer_Id(100 + int(args.generation) - 1); box.rule_scale = args.variant == "rules" ? 2 : 1; box.input_variant = args.variant == "schema"
	assert(comm.open(&box.endpoint, args.port, args.role, args.generation))
	box.ses.send = adapter_send; box.ses.send_user = box
	if args.role ==
	   1 {s.session_host_start(&box.ses, "authority", token = 0x1001); initialize_world(box)} else {s.session_client_start(&box.ses, 0x2002, "client"); s.session_client_join(&box.ses)}
}
initialize_world :: proc(box: ^Box) {
	cat := catalog()
	if box.args.variant == "assets" {
		b.recovery_catalog_destroy(&cat)
		cfg := b.recovery_config_default(); cfg.profile = pf.PROFILE
		source := pf.assets(); table: [4]b.Recovery_Asset
		for asset, i in source {table[i] = {
				id     = asset.id + 100,
				kind   = b.Recovery_Asset_Kind(asset.kind),
				a      = asset.a,
				b      = asset.b,
				radius = asset.radius,
			}}
		status: b.Status; cat, status = b.recovery_catalog_create(cfg, table[:]); check(status)
	}
	setup(box, 32, &cat); check(b.recovery_catalog_destroy(&cat)); box.active = true
	comm.reply(
		"{\"event\":\"initialized\",\"role\":%d,\"initial_dynamics\":32,\"caller_catalog_released\":true,\"peer\":%d}",
		box.args.role,
		box.peer,
	)
}
// Trusted adapter lifecycle notifications, never game/solver truth.
poll_packets :: proc(box: ^Box) {
	comm.poll(&box.endpoint)
	for _ in 0 ..< 256 {
		result, channel, sequence, count := comm.receive(
			&box.endpoint,
			box.endpoint.packet[:],
		); _ = sequence
		if result == 0 {break}; assert(result == 1, "TCP framing/disconnect")
		bytes := box.endpoint.packet[:count]
		if channel == 2 {
			old_peer :=
				box.peer == s.HOST_PEER ? s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1) : s.HOST_PEER
			disconnected := comm.handle_lifecycle(&box.endpoint, bytes)
			if disconnected {s.session_peer_disconnected(&box.ses, old_peer, .Transport_Lost)}
			continue
		}
		from :=
			box.peer == s.HOST_PEER ? s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1) : s.HOST_PEER
		if box.source_released {continue}
		reader := n.reader_make(
			bytes,
		); s.session_handle_packet(&box.ses, from, &reader, s.Channel(channel))
		if !box.active && box.ses.me != 0 {initialize_world(box)}
	}
}
log_accepted :: proc(box: ^Box) {
	if !box.active {return}
	status := k.lane_world_network_status(&box.lane)
	if box.args.role == 2 && !box.ready_seen && status.ready {
		box.ready_seen =
			true; box.logged_epoch = status.epoch; box.last_confirmed = status.confirmed
		comm.reply(
			"{\"event\":\"recovery_baseline\",\"epoch\":%d,\"tick\":%d,\"kind\":\"welcome\"}",
			status.epoch,
			status.confirmed,
		)
	}
	if status.epoch !=
	   box.logged_epoch {first := box.logged_epoch == 0; box.logged_epoch = status.epoch; box.last_confirmed = box.args.role == 1 && first ? 0 : status.confirmed; comm.reply("{\"event\":\"epoch_baseline\",\"epoch\":%d,\"tick\":%d,\"ready\":%t}", status.epoch, status.confirmed, status.ready)}
	if status.needs_resync {box.reset_observed = true}
	if box.args.role == 2 &&
	   box.reset_observed &&
	   status.ready &&
	   !status.needs_resync &&
	   status.confirmed > box.last_confirmed {
		comm.reply(
			"{\"event\":\"recovery_baseline\",\"epoch\":%d,\"tick\":%d,\"kind\":\"reset\"}",
			status.epoch,
			status.confirmed,
		)
		box.last_confirmed = status.confirmed; box.reset_observed = false
	}
	if status.confirmed < box.last_confirmed {return}
	for tick in box.last_confirmed + 1 ..= status.confirmed {
		for player in 1 ..= 2 {for class in 0 ..= 1 {
				bytes, origin, sequence, error := k.lane_world_accepted_input(
					&box.lane,
					tick,
					n.Player_Id(player),
					u16(class),
				); assert(error == .Ok)
				if class == 0 {
					axis: i32
					if box.input_variant {axis = (cast(^Control_V2)raw_data(bytes)).axis} else {axis = (cast(^Control)raw_data(bytes)).axis}
					comm.reply(
						"{\"event\":\"accepted\",\"epoch\":%d,\"tick\":%d,\"player\":%d,\"class\":0,\"axis\":%d,\"origin\":\"%v\",\"sequence\":%d}",
						status.epoch,
						tick,
						player,
						axis,
						origin,
						sequence,
					)
				} else {action := (cast(^Action)raw_data(bytes))^
					if action.kind != 0 {
						cp, ce := k.lane_world_checkpoint(
							&box.lane,
							tick,
						); assert(ce == .Ok); side, se := p.checkpoint_side(&cp, Side); assert(se == .Ok)
						comm.reply(
							"{\"event\":\"action_decision\",\"epoch\":%d,\"tick\":%d,\"player\":%d,\"kind\":%d,\"applied\":%t,\"body_key\":%d,\"shape_key\":%d,\"generation\":%d}",
							status.epoch,
							tick,
							player,
							action.kind,
							side.last_decision[player - 1] == 1,
							u64(side.keys[side.initial]),
							u64(side.extra_shape),
							side.generation[side.initial],
						)
						k.world_checkpoint_destroy(&cp)
					}
					comm.reply(
						"{\"event\":\"accepted\",\"epoch\":%d,\"tick\":%d,\"player\":%d,\"class\":1,\"kind\":%d,\"serial\":%d,\"origin\":\"%v\",\"sequence\":%d}",
						status.epoch,
						tick,
						player,
						action.kind,
						action.serial,
						origin,
						sequence,
					)}
			}}
	}
	box.last_confirmed = status.confirmed
}
status_reply :: proc(
	box: ^Box,
	command: string,
	steps: int = 0,
	odin_live: i64 = 0,
	odin_peak: i64 = 0,
) {
	status := k.World_Network_Status {
		error = .Unsupported,
	}; game: Side
	if box.active {status = k.lane_world_network_status(&box.lane); game, _ = p.read(&box.physics)}
	engine, es := b.engine_allocation_stats(
		
	); wrapper, ws := b.snapshot_allocation_stats(); check(es); check(ws)
	io := comm.stats(&box.endpoint)
	actual :=
		engine.live_bytes +
		wrapper.live_bytes +
		u64(odin_live) +
		comm.socket_owned_bytes(
			
		); assert(actual <= b.ALPHA_RESOURCE_BYTES, "all owned per-process requests")

	comm.reply(
		"{\"event\":\"ack\",\"command\":\"%s\",\"role\":%d,\"round\":%d,\"active\":%t,\"ready\":%t,\"needs_resync\":%t,\"status\":\"%v\",\"epoch\":%d,\"head\":%d,\"confirmed\":%d,\"steps\":%d,\"resims\":%d,\"out_sequence\":%d,\"tx_pending\":%d,\"rx_pending\":%d,\"engine_live\":%d,\"wrapper_live\":%d,\"provider_live\":%d,\"io_owned\":%d,\"io_queued_peak\":%d,\"body_peak\":%d,\"shape_peak\":%d,\"contact_peak\":%d,\"joint_peak\":%d,\"actual_requested\":%d,\"odin_live\":%d,\"odin_peak\":%d,\"effects\":%d,\"duplicate_effects\":%d,\"births\":%d,\"deaths\":%d,\"exact_extra_ends\":%d}",
		command,
		box.args.role,
		box.endpoint.round,
		box.active,
		status.ready,
		status.needs_resync,
		status.error,
		status.epoch,
		status.head,
		status.confirmed,
		steps,
		box.lane.stat_resims,
		box.endpoint.sequence,
		io[3],
		io[4],
		engine.live_bytes,
		wrapper.live_bytes,
		p.owned_bytes(),
		comm.owned_bytes(),
		io[2],
		box.peak.body_count,
		box.peak.shape_count,
		box.peak.contact_count,
		box.peak.joint_count,
		actual,
		odin_live,
		odin_peak,
		box.effects,
		box.duplicate_effects,
		game.births,
		game.deaths,
		game.exact_extra_ends,
	)
}
diagnostic :: proc(box: ^Box, tick: u64, write_files: bool) {
	frame: k.World_Diagnostic_Frame; error := k.lane_world_diagnostic_frame(&box.lane, tick, &frame)
	if error !=
	   .Ok {comm.reply("{\"event\":\"diagnostic_rejected\",\"tick\":%d,\"error\":\"%v\"}", tick, error); return}
	defer k.world_diagnostic_frame_destroy(&frame)
	hex := comm.signature_hex(frame.signature); defer delete(hex)
	comm.reply(
		"{\"event\":\"signature\",\"epoch\":%d,\"tick\":%d,\"hex\":\"%s\"}",
		frame.view.epoch,
		tick,
		hex,
	)
	if write_files {
		name := fmt.tprintf("%s/frame-%d-%d", box.args.out, frame.view.epoch, tick)
		signature: [bd.SIGNATURE_BYTES]u8; _, se := bd.signature_encode(frame.signature, signature[:]); assert(se == .None); comm.write_bytes(fmt.tprintf("%s.sig", name), signature[:])
		for part in bd.Part {comm.write_bytes(fmt.tprintf("%s.part%d", name, int(part)), frame.view.parts[part])}
	}
	cp, ce := k.lane_world_checkpoint(
		&box.lane,
		tick,
	); assert(ce == .Ok); defer k.world_checkpoint_destroy(&cp)
	game, ge := p.checkpoint_side(
		&cp,
		Side,
	); assert(ge == .Ok); data, je := json.marshal(game); assert(je == nil); defer delete(data)
	comm.reply(
		"{\"event\":\"game\",\"epoch\":%d,\"tick\":%d,\"state\":%s}",
		frame.view.epoch,
		tick,
		string(data),
	)
}
local_state :: proc(box: ^Box) {
	if !box.active {return}
	cp, error := k.lane_world_checkpoint(
		&box.lane,
		box.lane.world.head,
	); assert(error == .Ok); defer k.world_checkpoint_destroy(&cp)
	n, ne := p.checkpoint_dump(
		&cp,
		nil,
		Side,
	); assert(ne == .Ok); bytes := make([]u8, int(n)); defer delete(bytes); _, de := p.checkpoint_dump(&cp, bytes, Side); assert(de == .Ok)
	digest := bd.hash_bytes(
		bytes,
	); hex := comm.hex_bytes(digest[:]); defer delete(hex); side, se := p.checkpoint_side(&cp, Side); assert(se == .Ok); data, je := json.marshal(side); assert(je == nil); defer delete(data)
	comm.reply(
		"{\"event\":\"local_state\",\"head\":%d,\"solver_sha256\":\"%s\",\"game\":%s}",
		cp.tick,
		hex,
		string(data),
	)
}
save_trace :: proc(box: ^Box) {
	if !box.active || box.trace_saved {return}
	trace := k.lane_world_network_trace(&box.lane)
	if trace == nil || !trace.ready {return}
	count, e := bd.trace_encode(
		trace,
		nil,
	); assert(e == .None); bytes := make([]u8, count); defer delete(bytes); _, e = bd.trace_encode(trace, bytes); assert(e == .None)
	comm.write_bytes(fmt.tprintf("%s/first.trace", box.args.out), bytes); box.trace_saved = true
	comm.reply("{\"event\":\"first_trace\",\"bytes\":%d}", count)
}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	backing := context.allocator; context.allocator = mem.tracking_allocator(&tracking)
	box := new(Box); args := comm.args(); start(box, args)
	comm.reply("{\"event\":\"started\",\"role\":%d,\"framework\":\"kit\"}", args.role)
	running := true
	for running {
		command := comm.read_command(); if len(command.fields) == 0 {break}
		{
			defer comm.command_destroy(&command)
			parts := command.fields; name := parts[0]; box.command_serial += 1
			if len(parts) > 1 &&
			   (name == "PUMP" || name == "STEP") {box.endpoint.round = u32(comm.number(parts[1]))}
			steps := 0
			switch name {
			case "PUMP":
				poll_packets(box); if box.active {_ = k.lane_frame(&box.lane, 0)}
			case "STEP":
				poll_packets(box); if box.active {steps = k.lane_frame(&box.lane, 1.0 / 60)}
			case "WELCOME":
				assert(args.role == 1 && box.active)
				assert(
					k.lane_world_send_checkpoint(
						&box.lane,
						s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1),
						.Welcome,
					) ==
					.Ok,
				)
			case "CHECKPOINT":
				assert(args.role == 1)
				assert(
					k.lane_world_send_checkpoint(
						&box.lane,
						s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1),
						.Correction,
					) ==
					.Ok,
				)
			case "RESET":
				box.reset_observed = true
				if args.role ==
				   1 {assert(k.lane_world_send_checkpoint(&box.lane, s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1), .Reset) == .Ok)} else {assert(k.lane_world_request_reset(&box.lane) == .Ok)}
			case "MALFORMED":
				assert(args.role == 1 && box.stale_count > 3); bytes := box.stale_bytes
				bytes[3] ~= 0x80
				assert(comm.send(&box.endpoint, box.stale_channel, bytes[:box.stale_count]) == 1)
			case "STALE":
				assert(args.role == 1 && box.stale_count > 0)
				assert(
					comm.send(
						&box.endpoint,
						box.stale_channel,
						box.stale_bytes[:box.stale_count],
					) ==
					1,
				)
			case "EPOCH":
				assert(args.role == 1)
				assert(k.lane_world_begin_epoch(&box.lane, comm.number(parts[1])) == .Ok)
				assert(
					k.lane_world_send_checkpoint(
						&box.lane,
						s.Peer_Id(100 + int(box.endpoint.remote_generation) - 1),
						.Reset,
					) ==
					.Ok,
				)
				box.last_confirmed = k.lane_world_confirmed(&box.lane)
				box.logged_epoch = k.lane_world_epoch(&box.lane)
			case "SIG":
				diagnostic(box, comm.number(parts[1]), false)
			case "DIAG":
				diagnostic(box, comm.number(parts[1]), true)
			case "RELEASE":
				assert(box.active); destroy(box); box.active = false; box.source_released = true
			case "PROBE_SAVE":
				k.world_checkpoint_destroy(&box.probe); error: k.World_Error
				box.probe, error = k.lane_world_checkpoint(&box.lane, box.lane.world.head)
				assert(error == .Ok)
			case "PROBE_CHECK":
				current, error := k.lane_world_checkpoint(&box.lane, box.lane.world.head)
				assert(error == .Ok)
				equal, ee := k.world_checkpoint_equal(&box.probe, &current)
				k.world_checkpoint_destroy(&current)
				assert(ee == .Ok)
				comm.reply("{\"event\":\"probe_equal\",\"equal\":%t}", equal)
			case "STATE":
				local_state(box)
			case "STATUS":
			case "QUIT":
				running = false
			case:
				assert(false, "unknown command")
			}
			if box.active {log_accepted(box); save_trace(box)}
			comm.poll(
				&box.endpoint,
			); status_reply(box, name, steps, tracking.current_memory_allocated, tracking.peak_memory_allocated)
		}
		free_all(context.temp_allocator)
	}
	k.world_checkpoint_destroy(&box.probe)
	if box.active {destroy(box); box.active = false}
	comm.close(&box.endpoint); free(box)
	engine, es := b.engine_allocation_stats(
		
	); wrapper, ws := b.snapshot_allocation_stats(); check(es); check(ws)
	assert(engine.live_bytes == 0 && wrapper.live_bytes == 0 && p.owned_bytes() == 0)
	conservative :=
		engine.high_water_bytes +
		wrapper.high_water_bytes +
		u64(tracking.peak_memory_allocated) +
		comm.socket_owned_bytes(
			
		); assert(conservative <= b.ALPHA_RESOURCE_BYTES, "conservative independent requested-byte maxima")
	context.allocator = backing
	comm.reply(
		"{\"event\":\"closed\",\"framework\":\"kit\",\"engine_live\":%d,\"wrapper_live\":%d,\"provider_live\":%d,\"odin_live\":%d,\"odin_peak\":%d,\"conservative_requested_peak\":%d,\"max_rss\":%d,\"socket_live\":%d}",
		engine.live_bytes,
		wrapper.live_bytes,
		p.owned_bytes(),
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		conservative,
		comm.peak_rss(),
		comm.socket_live_bytes(),
	)
	assert(tracking.current_memory_allocated == 0 && comm.socket_live_bytes() == 0)
}
