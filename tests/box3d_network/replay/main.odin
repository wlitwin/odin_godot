package main
import comm "../common"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import v "godot:replay/view"
import f "godot:tests/replay_physics_net/fixture"

Runner :: struct {
	observed:                             Process_Observation,
	args:                                 comm.Args,
	endpoint:                             comm.Endpoint,
	parameters:                           Parameters,
	codec:                                ph.Network_Codec(Game, Control, Action, Event, 2),
	server:                               net.Server(Game, Control, Action, Event, 2),
	client:                               net.Client(Game, Control, Action, Event, 2),
	active, trace_saved, ready_seen:      bool,
	probe:                                r.Complete_Checkpoint(Game, net.Net_Event(Event)),
	charge, logged_epoch, last_confirmed: u64,
	stale_bytes:                          [65536]u8,
	stale_count:                          int,
	stale_channel:                        u32,
	effects:                              [16384]r.Event_Id,
	effect_count, duplicate_effects:      int,
	changes:                              [2048]v.Change(net.Net_Event(Event)),
}
wire_send :: proc(
	user: rawptr,
	to: tr.Peer_Id,
	channel: tr.Channel,
	bytes: []u8,
) -> tr.Send_Result {
	runner := cast(^Runner)user; if to != tr.Peer_Id(runner.args.role == 1 ? 2 : 1) {return .Disconnected}
	if runner.args.role == 1 &&
	   runner.stale_count ==
		   0 {assert(len(bytes) <= len(runner.stale_bytes)); copy(runner.stale_bytes[:], bytes); runner.stale_count = len(bytes); runner.stale_channel = u32(channel)}
	result := comm.send(&runner.endpoint, u32(channel), bytes)
	return result == 1 ? .Sent : result == 0 ? .Backpressure : .Disconnected
}
wire_receive :: proc(user: rawptr, dst: []u8) -> tr.Received {
	runner := cast(^Runner)user
	for _ in 0 ..< 8 {
		result, channel, sequence, count := comm.receive(&runner.endpoint, dst); _ = sequence
		if result == 0 {return {state = .Empty}}
		if result < 0 {return {state = .Disconnected}}
		if result == 2 {return {state = .Buffer_Too_Small, count = int(count)}}
		if channel == 2 {comm.handle_lifecycle(&runner.endpoint, dst[:count]); continue}
		return {
			state = .Received,
			from = tr.Peer_Id(runner.args.role == 1 ? 2 : 1),
			channel = tr.Channel(channel),
			count = int(count),
			generation = runner.endpoint.remote_generation,
		}
	}
	return {state = .Empty}
}
transport :: proc(runner: ^Runner) -> tr.Transport {return{
		user = runner,
		send = wire_send,
		receive = wire_receive,
		poll = proc(user: rawptr) {comm.poll(&(cast(^Runner)user).endpoint)},
		status = proc(user: rawptr) -> tr.Status {return(
				(cast(^Runner)user).endpoint.failed ? .Disconnected : .Connected \
			)},
		connected = proc(user: rawptr, peer: tr.Peer_Id) -> bool {return(
				(cast(^Runner)user).endpoint.connected \
			)},
		generation = proc(user: rawptr, peer: tr.Peer_Id) -> u64 {return(
				(cast(^Runner)user).endpoint.remote_generation \
			)},
	}}
start :: proc(runner: ^Runner, args: comm.Args) {
	runner.args = args; runner.parameters = {
		scale    = args.variant == "rules" ? 2 : 1,
		fault    = args.variant == "fault",
		observer = &runner.observed,
	}
	when SCHEMA_VARIANT {runner.parameters.variant = 1}
	assert(comm.open(&runner.endpoint, args.port, args.role, args.generation))
	cfg := b.recovery_config_default(); cfg.profile = f.PROFILE
	assets: [4]b.Recovery_Asset; for asset, index in f.assets() {assets[index] = {
			id     = asset.id + (args.variant == "assets" ? 100 : 0),
			kind   = b.Recovery_Asset_Kind(asset.kind),
			a      = asset.a,
			b      = asset.b,
			radius = asset.radius,
		}}
	catalog, cs := b.recovery_catalog_create(
		cfg,
		assets[:],
	); assert(cs == .Ok); defer b.recovery_catalog_destroy(&catalog)
	identity, is := b.recovery_catalog_identity(
		&catalog,
	); assert(is == .Ok); build: u64; for byte, index in identity.build_target[:8] {build |= u64(byte) << uint(8 * index)}
	config := ph.config_default(
		f.ASSET_DECLARATION,
		build,
	); config.initial_dynamic_bodies = 32; config.assets[0].id = assets[2].id; config.assets[1].id = assets[3].id
	assert(
		ph.network_codec_init(&runner.codec, &catalog, config, rules(runner.parameters)) == .None,
	)
	runner.charge =
		comm.owned_bytes() +
		u64(
			size_of(Runner),
		); assert(runner.codec.value.reserve(runner.codec.value.catalog, runner.charge) == .None)
	m := model(
		&runner.codec,
		&runner.parameters,
	); netcfg := net.physics_config_default(); netcfg.epoch = args.epoch
	if args.role == 1 {
		world, base, status := f.world(32); assert(status == .Ok)
		cp, error := ph.checkpoint_make(
			r.Frame(Game){state = {base = base}},
			net.Net_Event(Event),
			world,
			config,
		); assert(error == .None)
		assert(b.world_destroy(&world) == .Ok)
		assert(
			net.server_init_complete(
				&runner.server,
				&cp,
				m,
				transport(runner),
				netcfg,
				local_seat = 1,
			) ==
			.None,
		)
		r.complete_checkpoint_destroy(&cp)
		assert(net.server_set_local_token(&runner.server, net.Token{0 = 1}) == .None)
	} else {assert(
			net.client_init(
				&runner.client,
				m,
				transport(runner),
				net.Token{0 = 2},
				cfg = netcfg,
			) ==
			.None,
		)}
	runner.active = true
	comm.reply(
		"{\"event\":\"initialized\",\"role\":%d,\"initial_dynamics\":32,\"caller_catalog_and_world_released\":true}",
		args.role,
	)
}
pump :: proc(runner: ^Runner) -> net.Error {
	now := u64(runner.endpoint.round) * 1000 / 60
	if runner.args.role ==
	   1 {return net.server_pump(&runner.server, now)} else {return net.client_pump(&runner.client, now)}
}
step :: proc(runner: ^Runner) -> (int, net.Error) {
	if !runner.active {return 0, .None}
	if error := pump(runner); error != .None {return 0, error}
	if runner.args.role == 1 {
		tick := runner.server.timeline.head + 1
		assert(net.server_local(&runner.server, script_control(tick, 1)) == .None)
		action := script_action(
			tick,
			1,
		); if action.kind != .None {_, error := net.server_issue(&runner.server, action); assert(error == .None)}
		error := net.server_step(
			&runner.server,
		); if error != .None {return 0, error}; return 1, pump(runner)
	}
	if runner.client.phase != .Running {return 0, .None}
	error := net.client_step(&runner.client, script_control(runner.client.timeline.head + 1, 2))
	if error == .Capacity {return 0, .None}; return error == .None ? 1 : 0, error
}
log_confirmed :: proc(runner: ^Runner) {
	if !runner.active {return}
	epoch := runner.args.role == 1 ? runner.server.cfg.epoch : runner.client.cfg.epoch
	confirmed :=
		runner.args.role == 1 ? runner.server.timeline.head : runner.client.timeline.confirmed
	ready := runner.args.role == 1 || runner.client.has_world
	if !ready {return}
	if runner.logged_epoch != epoch || !runner.ready_seen {
		first := !runner.ready_seen; runner.logged_epoch = epoch; runner.ready_seen = true; runner.last_confirmed = runner.args.role == 1 && first ? 0 : confirmed
		comm.reply(
			"{\"event\":\"recovery_baseline\",\"epoch\":%d,\"tick\":%d}",
			epoch,
			runner.last_confirmed,
		)
	}
	if runner.args.role == 2 && runner.client.physics.accepted.baseline > runner.last_confirmed {
		runner.last_confirmed = runner.client.physics.accepted.baseline
		comm.reply(
			"{\"event\":\"recovery_baseline\",\"epoch\":%d,\"tick\":%d,\"kind\":\"reset\"}",
			epoch,
			runner.last_confirmed,
		)
	}
	for tick in runner.last_confirmed + 1 ..= confirmed {
		accepted: net.Accepted_Input(Control, Action, 2); found: bool
		if runner.args.role ==
		   1 {accepted, found = net.server_accepted_input(&runner.server, tick)} else {accepted, found = net.accepted_read(&runner.client.physics.accepted, tick)}
		assert(found, "confirmed accepted decision missing after baseline")
		for present, seat in accepted.batch.has_action {if present {
				checkpoint: r.Complete_Checkpoint(Game, net.Net_Event(Event)); ce: r.Error
				if runner.args.role ==
				   1 {checkpoint, ce = r.capture_complete(&runner.server.timeline, tick)} else {checkpoint, ce = r.capture_complete(&runner.client.timeline, tick)}; assert(ce == .None)
				state := checkpoint.frame.state
				comm.reply(
					"{\"event\":\"action_decision\",\"epoch\":%d,\"tick\":%d,\"player\":%d,\"kind\":%d,\"applied\":%t,\"body_key\":%d,\"shape_key\":%d,\"generation\":%d}",
					epoch,
					tick,
					seat + 1,
					u8(accepted.batch.actions[seat].kind),
					accepted.decisions.applied[seat],
					u64(state.base.bodies[state.base.initial]),
					u64(state.extra_shape),
					state.base.generation[state.base.initial],
				)
				r.complete_checkpoint_destroy(&checkpoint)
			}}
		data, error := json.marshal(accepted); assert(error == nil)
		comm.reply(
			"{\"event\":\"accepted\",\"epoch\":%d,\"tick\":%d,\"record\":%s}",
			epoch,
			tick,
			string(data),
		); delete(data)
		events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event)); count: int; ee: r.Error
		if runner.args.role ==
		   1 {count, ee = r.copy_events(&runner.server.timeline, tick, events[:])} else {count, ee = r.copy_events(&runner.client.timeline, tick, events[:])}; assert(ee == .None)
		for event in events[:count] {
			// Authority source occurrences are expected IDs, not delivered presentation.
			if runner.args.role ==
			   1 {payload, pe := json.marshal(event.value); assert(pe == nil); comm.reply("{\"event\":\"expected_effect\",\"epoch\":%d,\"tick\":%d,\"source\":%d,\"key\":%d,\"payload\":%s}", event.id.epoch, event.id.tick, event.id.source, event.id.key, string(payload)); delete(payload)}
		}
	}
	runner.last_confirmed = confirmed
	if runner.args.role == 2 {
		for {
			count := v.drain(&runner.client.journal, runner.changes[:]); if count == 0 {break}
			for change in runner.changes[:count] {
				event := change.occurrence
				payload, pe := json.marshal(
					event.value,
				); previous, prev_error := json.marshal(change.previous); assert(pe == nil && prev_error == nil)
				comm.reply(
					"{\"event\":\"journal_change\",\"change\":\"%v\",\"confirmed\":%t,\"scope_epoch\":%d,\"scope_generation\":%d,\"scope_serial\":%d,\"epoch\":%d,\"tick\":%d,\"source\":%d,\"key\":%d,\"payload\":%s,\"previous\":%s}",
					change.kind,
					change.confirmed,
					runner.client.cfg.epoch,
					runner.client.generation,
					runner.client.serial,
					event.id.epoch,
					event.id.tick,
					event.id.source,
					event.id.key,
					string(payload),
					string(previous),
				)
				delete(previous)
				if change.confirmed && (change.kind == .Begin || change.kind == .Confirm) {
					for old in runner.effects[:runner.effect_count] {if old == event.id {runner.duplicate_effects += 1; assert(false, "duplicate delivered confirmed effect")}}
					assert(
						runner.effect_count < len(runner.effects),
					); runner.effects[runner.effect_count] = event.id; runner.effect_count += 1
					comm.reply(
						"{\"event\":\"effect\",\"epoch\":%d,\"tick\":%d,\"source\":%d,\"key\":%d,\"kind\":\"%v\",\"payload\":%s}",
						event.id.epoch,
						event.id.tick,
						event.id.source,
						event.id.key,
						event.value.kind,
						string(payload),
					)
				}
				delete(payload)
			}
		}
	}
}
status_reply :: proc(
	runner: ^Runner,
	command: string,
	steps: int,
	error: net.Error = .None,
	odin_live: i64 = 0,
	odin_peak: i64 = 0,
) {
	head, confirmed, epoch, repairs, resyncs: u64; ready, resync: bool; phase := net.Phase.Joining; game: Game
	if !runner.active {epoch = 0; ready = false} else if runner.args.role == 1 {
		head =
			runner.server.timeline.head; confirmed = head; epoch = runner.server.cfg.epoch; ready = runner.active; frame, found := r.current_values(&runner.server.timeline); if found {game = frame.state}
	} else {
		head =
			runner.client.timeline.head; confirmed = runner.client.timeline.confirmed; epoch = runner.client.cfg.epoch; phase = runner.client.phase; ready = phase == .Running; resync = phase == .Resyncing; resyncs = runner.client.stats.resyncs
		if runner.client.physics != nil {repairs = runner.client.physics.repairs}
		frame, found := r.current_values(&runner.client.timeline); if found {game = frame.state}
	}
	engine, es := b.engine_allocation_stats(
		
	); wrapper, ws := b.snapshot_allocation_stats(); assert(es == .Ok && ws == .Ok); io := comm.stats(&runner.endpoint)
	actual :=
		engine.live_bytes +
		wrapper.live_bytes +
		u64(odin_live) +
		comm.socket_owned_bytes(
			
		); assert(actual <= b.ALPHA_RESOURCE_BYTES, "all owned per-process requests")
	planned, executed: u64; if runner.client.physics != nil {planned = runner.client.physics.last_planned_depth; executed = runner.client.physics.last_executed_steps}; assert(executed <= 8)

	comm.reply(
		"{\"event\":\"ack\",\"command\":\"%s\",\"role\":%d,\"round\":%d,\"active\":%t,\"ready\":%t,\"needs_resync\":%t,\"status\":\"%v\",\"phase\":\"%v\",\"epoch\":%d,\"head\":%d,\"confirmed\":%d,\"steps\":%d,\"repairs\":%d,\"resyncs\":%d,\"out_sequence\":%d,\"tx_pending\":%d,\"rx_pending\":%d,\"engine_live\":%d,\"wrapper_live\":%d,\"provider_live\":%d,\"io_owned\":%d,\"io_queued_peak\":%d,\"body_peak\":%d,\"shape_peak\":%d,\"contact_peak\":%d,\"joint_peak\":%d,\"actual_requested\":%d,\"odin_live\":%d,\"odin_peak\":%d,\"planned_depth\":%d,\"executed_steps\":%d,\"effects\":%d,\"duplicate_effects\":%d,\"births\":%d,\"deaths\":%d,\"exact_extra_ends\":%d}",
		command,
		runner.args.role,
		runner.endpoint.round,
		runner.active,
		ready,
		resync,
		error,
		phase,
		epoch,
		head,
		confirmed,
		steps,
		repairs,
		resyncs,
		runner.endpoint.sequence,
		io[3],
		io[4],
		engine.live_bytes,
		wrapper.live_bytes,
		ph.allocation_stats().live_bytes,
		comm.owned_bytes(),
		io[2],
		runner.observed.peak.body_count,
		runner.observed.peak.shape_count,
		runner.observed.peak.contact_count,
		runner.observed.peak.joint_count,
		actual,
		odin_live,
		odin_peak,
		planned,
		executed,
		runner.effect_count,
		runner.duplicate_effects,
		game.base.births,
		game.base.deaths,
		game.exact_extra_ends,
	)
}
diagnostic :: proc(runner: ^Runner, tick: u64, files: bool) {
	if runner.args.role == 2 &&
	   tick >
		   runner.client.timeline.confirmed {comm.reply("{\"event\":\"diagnostic_rejected\",\"tick\":%d}", tick); return}
	cp: r.Complete_Checkpoint(Game, net.Net_Event(Event)); error: r.Error
	if runner.args.role ==
	   1 {cp, error = r.capture_complete(&runner.server.timeline, tick)} else {cp, error = r.capture_complete(&runner.client.timeline, tick)}
	if error !=
	   .None {comm.reply("{\"event\":\"diagnostic_rejected\",\"tick\":%d,\"error\":\"%v\"}", tick, error); return}
	defer r.complete_checkpoint_destroy(&cp)
	view, ve := net.complete_view(
		runner.codec.value,
		&cp,
		&runner.codec.state,
		&runner.codec.occurrence,
	); assert(ve == .None); defer net.complete_view_destroy(&view)
	signature, se := bd.sign(
		view.frame,
	); assert(se == .None); hex := comm.signature_hex(signature); defer delete(hex)
	comm.reply(
		"{\"event\":\"signature\",\"epoch\":%d,\"tick\":%d,\"hex\":\"%s\"}",
		view.frame.epoch,
		tick,
		hex,
	)
	if files {
		prefix := fmt.tprintf(
			"%s/frame-%d-%d",
			runner.args.out,
			view.frame.epoch,
			tick,
		); bytes: [bd.SIGNATURE_BYTES]u8; _, be := bd.signature_encode(signature, bytes[:]); assert(be == .None); comm.write_bytes(fmt.tprintf("%s.sig", prefix), bytes[:])
		for part in bd.Part {comm.write_bytes(fmt.tprintf("%s.part%d", prefix, int(part)), view.frame.parts[part])}
	}
	data, je := json.marshal(
		cp.frame.state,
	); assert(je == nil); defer delete(data); comm.reply("{\"event\":\"game\",\"epoch\":%d,\"tick\":%d,\"state\":%s}", view.frame.epoch, tick, string(data))
}
local_state :: proc(runner: ^Runner) {
	if !runner.active {return}
	if runner.args.role == 2 &&
	   !runner.client.has_world {comm.reply("{\"event\":\"local_state\",\"has_world\":false,\"head\":0}"); return}
	cp: r.Complete_Checkpoint(Game, net.Net_Event(Event)); error: r.Error
	if runner.args.role ==
	   1 {cp, error = r.capture_complete(&runner.server.timeline, runner.server.timeline.head)} else {cp, error = r.capture_complete(&runner.client.timeline, runner.client.timeline.head)}; assert(error == .None); defer r.complete_checkpoint_destroy(&cp)
	n, ne := ph.dump(
		&cp,
		nil,
	); assert(ne == .None); bytes := make([]u8, int(n)); defer delete(bytes); _, de := ph.dump(&cp, bytes); assert(de == .None); digest := bd.hash_bytes(bytes); hex := comm.hex_bytes(digest[:]); defer delete(hex)
	data, je := json.marshal(cp.frame.state); assert(je == nil); defer delete(data)
	comm.reply(
		"{\"event\":\"local_state\",\"has_world\":true,\"head\":%d,\"solver_sha256\":\"%s\",\"game\":%s}",
		cp.frame.tick,
		hex,
		string(data),
	)
}
save_trace :: proc(runner: ^Runner) {
	if runner.args.role != 2 ||
	   runner.trace_saved ||
	   runner.client.physics == nil ||
	   !runner.client.physics.trace.ready {return}
	count, error := net.client_physics_trace(
		&runner.client,
		nil,
	); assert(error == .None); data := make([]u8, count); defer delete(data); _, error = net.client_physics_trace(&runner.client, data); assert(error == .None); comm.write_bytes(fmt.tprintf("%s/first.trace", runner.args.out), data); runner.trace_saved = true
	comm.reply("{\"event\":\"first_trace\",\"bytes\":%d}", count)
}
probe_check :: proc(runner: ^Runner) {
	current, error := r.capture_complete(
		&runner.client.timeline,
		runner.client.timeline.head,
	); assert(error == .None); defer r.complete_checkpoint_destroy(&current)
	before, be := net.complete_view(
		runner.codec.value,
		&runner.probe,
		&runner.codec.state,
		&runner.codec.occurrence,
	); assert(be == .None); defer net.complete_view_destroy(&before)
	after, ae := net.complete_view(
		runner.codec.value,
		&current,
		&runner.codec.state,
		&runner.codec.occurrence,
	); assert(ae == .None); defer net.complete_view_destroy(&after)
	equal :=
		before.frame.identity == after.frame.identity &&
		before.frame.epoch == after.frame.epoch &&
		before.frame.tick == after.frame.tick
	for part in bd.Part {equal = equal && len(before.frame.parts[part]) == len(after.frame.parts[part]) && mem.compare(before.frame.parts[part], after.frame.parts[part]) == 0}
	comm.reply("{\"event\":\"probe_equal\",\"equal\":%t}", equal)
}
release_runtime :: proc(runner: ^Runner) {
	if !runner.active {return}
	if runner.args.role ==
	   1 {net.server_destroy(&runner.server)} else {net.client_destroy(&runner.client)}
	runner.codec.value.release(runner.codec.value.catalog, runner.charge); runner.charge = 0
	assert(ph.network_codec_destroy(&runner.codec) == .None); runner.active = false
}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking); backing := context.allocator; context.allocator = mem.tracking_allocator(&tracking)
	runner := new(
		Runner,
	); args := comm.args(); start(runner, args); comm.reply("{\"event\":\"started\",\"role\":%d,\"framework\":\"replay\"}", args.role)
	running := true
	for running {
		command := comm.read_command(); if len(command.fields) == 0 {break}
		{
			defer comm.command_destroy(&command); parts := command.fields; name := parts[0]
			if len(parts) > 1 &&
			   (name == "PUMP" ||
					   name == "STEP") {runner.endpoint.round = u32(comm.number(parts[1]))}
			error := net.Error.None; steps := 0
			switch name {
			case "PUMP":
				if runner.active {error = pump(runner)} else {comm.poll(&runner.endpoint); for _ in 0 ..< 256 {result, channel, _, count := comm.receive(&runner.endpoint, runner.endpoint.packet[:]); if result == 0 {break}; assert(result == 1); if channel == 2 {comm.handle_lifecycle(&runner.endpoint, runner.endpoint.packet[:count])}}}
			case "STEP":
				steps, error = step(runner)
			case "MALFORMED":
				assert(args.role == 1 && runner.stale_count > 0); bytes := runner.stale_bytes
				bytes[0] ~= 0x80
				assert(
					comm.send(
						&runner.endpoint,
						runner.stale_channel,
						bytes[:runner.stale_count],
					) ==
					1,
				)
			case "STALE":
				assert(args.role == 1 && runner.stale_count > 0)
				assert(
					comm.send(
						&runner.endpoint,
						runner.stale_channel,
						runner.stale_bytes[:runner.stale_count],
					) ==
					1,
				)
			case "EPOCH":
				epoch := comm.number(parts[1])
				if args.role == 1 {
					archive: net.Checkpoint(
						Game,
						Control,
						Action,
						2,
					); assert(net.checkpoint_capture(&runner.server, &archive) == .None)
					m := model(
						&runner.codec,
						&runner.parameters,
					); net.server_destroy(&runner.server)
					assert(
						net.server_restore(
							&runner.server,
							&archive,
							m,
							transport(runner),
							{
								epoch = epoch,
								local_seat = 1,
								retain_membership = true,
								preserve_pending = true,
							},
						) ==
						.None,
					)
					net.checkpoint_destroy(
						&archive,
					); runner.logged_epoch = epoch; runner.last_confirmed = runner.server.timeline.head
				} else {
					_, _ = net.client_recovery(&runner.client)
					assert(net.client_authority(&runner.client, epoch, transport(runner)) == .None)
				}
			case "SIG":
				diagnostic(runner, comm.number(parts[1]), false)
			case "DIAG":
				diagnostic(runner, comm.number(parts[1]), true)
			case "PROBE_SAVE":
				r.complete_checkpoint_destroy(&runner.probe); error: r.Error
				runner.probe, error = r.capture_complete(&runner.client.timeline, runner.client.timeline.head)
				assert(error == .None)
			case "PROBE_CHECK":
				probe_check(runner)
			case "STATE":
				local_state(runner)
			case "STATUS":
			case "RELEASE":
				release_runtime(runner)
			case "QUIT":
				running = false
			case:
				assert(false, "unknown command")
			}
			if runner.active {
				if args.role == 2 && runner.client.has_world {
					first := max(
						runner.client.timeline.confirmed + 1,
						runner.client.timeline.head > 7 ? runner.client.timeline.head - 7 : 0,
					)
					for tick in first ..= runner.client.timeline.head {input, found := r.read_input(&runner.client.timeline, tick); if found {data, je := json.marshal(input); assert(je == nil); comm.reply("{\"event\":\"used_input\",\"epoch\":%d,\"tick\":%d,\"batch\":%s}", runner.client.cfg.epoch, tick, string(data)); delete(data)}}
				}
				log_confirmed(runner); save_trace(runner)
			}
			comm.poll(
				&runner.endpoint,
			); status_reply(runner, name, steps, error, tracking.current_memory_allocated, tracking.peak_memory_allocated)
			assert(
				error == .None ||
				error == .Capacity ||
				(args.variant == "fault" && runner.trace_saved),
				"runner operation error",
			)
		}
		free_all(context.temp_allocator)
	}
	r.complete_checkpoint_destroy(&runner.probe)
	release_runtime(runner); comm.close(&runner.endpoint); free(runner)
	engine, es := b.engine_allocation_stats(
		
	); wrapper, ws := b.snapshot_allocation_stats(); assert(es == .Ok && ws == .Ok)
	assert(
		engine.live_bytes == 0 && wrapper.live_bytes == 0 && ph.allocation_stats().live_bytes == 0,
	)
	conservative :=
		engine.high_water_bytes +
		wrapper.high_water_bytes +
		u64(tracking.peak_memory_allocated) +
		comm.socket_owned_bytes(
			
		); assert(conservative <= b.ALPHA_RESOURCE_BYTES, "conservative independent requested-byte maxima")
	context.allocator =
		backing; comm.reply("{\"event\":\"closed\",\"framework\":\"replay\",\"engine_live\":%d,\"wrapper_live\":%d,\"provider_live\":%d,\"odin_live\":%d,\"odin_peak\":%d,\"conservative_requested_peak\":%d,\"max_rss\":%d,\"socket_live\":%d}", engine.live_bytes, wrapper.live_bytes, ph.allocation_stats().live_bytes, tracking.current_memory_allocated, tracking.peak_memory_allocated, conservative, comm.peak_rss(), comm.socket_live_bytes())
	assert(tracking.current_memory_allocated == 0 && comm.socket_live_bytes() == 0)
}
