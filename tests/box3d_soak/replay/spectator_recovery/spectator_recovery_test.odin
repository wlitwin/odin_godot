// One public spectator regression. Generic4/static Native/nilOwner/Memory;
// NOT actual Core/SDK32/ENet/CPU or a reconstruction of a live failure.
package replay_spectator_recovery_test

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import a "godot:tests/box3d_soak/replay/action_scope_case_a"
import ar "godot:tests/box3d_soak/replay/action_retire"
import fr "godot:tests/box3d_soak/replay/facts_recovery"
import f "godot:tests/replay_physics_net/fixture"

TARGET :: u64(20)
NOW :: u64(340)
MAX_FINAL_PUMPS :: 4

State :: struct {
	label: string,
	spectator: bool,
	phase: net.Phase,
	head, confirmed, facts_contiguous, authority_seen, generation, serial: u64,
	journal_count, journal_capacity, journal_headroom: int,
	pending_bytes: int,
	pending_checkpoint: bool,
	waiting_tick, resyncs, snapshot_catchups: u64,
}
Observation :: struct {
	scope, stage: string,
	setup_complete, welcome_ACK_matches, facts_ready, target_packet_observed: bool,
	initial_checkpoint_drop_ok: bool,
	welcome, old_snapshot, target_snapshot: net.Physics_Chunk_Header,
	welcome_ACK, old_ACK: net.Physics_Ack,
	old_ACK_matches: bool,
	states: [8]State,
	state_count: int,
	final_pumps: int,
	full5_attempted, full5_available, full5_equal, checkpoint_drops_ok: bool,
	authority_capture_status, spectator_capture_status: i32,
	prospective_criterion: bool,
	raw_capture_count: int,
	raw_archive_ok, all_saved_bytes_intact, all_drops_ok, cleanup_observed: bool,
	native_live, wrapper_live, provider_live, odin_live: u64,
}

observe :: proc(c: ^a.Case, o: ^Observation, label: string) {
	p := &c.pair.client
	o.states[o.state_count] = {label, p.spectator, p.phase,
		p.timeline.head, p.timeline.confirmed, p.facts_contiguous, p.authority_tick_seen, p.generation, p.serial,
		p.journal.queue_count, len(p.journal.queue), len(p.journal.queue)-p.journal.queue_count,
		len(p.physics.pending.bytes), p.physics.pending_checkpoint != nil,
		p.physics.waiting_tick, p.stats.resyncs, p.stats.snapshot_catchups}
	o.state_count += 1
}

// This is the CaseA public setup, with spectator=true supplied at construction.
// CaseA's actual gates/pumps/callbacks are reused; no client state is assigned.
open_spectator :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) -> bool {
	p := &c.pair; cfg := b.recovery_config_default(); cfg.profile = f.PROFILE
	assets: [4]b.Recovery_Asset
	for value, i in f.assets() {assets[i] = {id=value.id, kind=b.Recovery_Asset_Kind(value.kind), a=value.a, b=value.b, radius=value.radius}}
	status: b.Status; p.catalog, status = b.recovery_catalog_create(cfg, assets[:])
	if !a.check(t, status == .Ok, "catalog") {return false}
	identity, identity_status := b.recovery_catalog_identity(&p.catalog)
	if !a.check(t, identity_status == .Ok, "catalog identity") {return false}
	build: u64; for byte, i in identity.build_target[:8] {build |= u64(byte)<<uint(i*8)}
	config := ph.config_default(f.ASSET_DECLARATION, build)
	config.initial_dynamic_bodies = 4; config.assets[0].id = 3; config.assets[1].id = 4
	world, game, world_status := f.world(4)
	if !a.check(t, world_status == .Ok, "generic four-body world") {return false}
	initial, error := ph.checkpoint_make(r.Frame(f.Game){state=game}, net.Net_Event(f.Event), world, config)
	b.world_destroy(&world)
	if !a.check(t, error == .None, "initial complete checkpoint") {return false}
	defer {
		o.initial_checkpoint_drop_ok = r.complete_checkpoint_destroy(&initial) == .None
		a.check(t, o.initial_checkpoint_drop_ok, "initial checkpoint checked drop")
	}
	if !a.none(t, ph.network_codec_init(&p.codec, &p.catalog, config, ar.rules()), "existing fixture codec") {return false}
	if !a.check(t, tr.memory_init(&p.memory, cfg={2,64,tr.MAX_PACKET_BYTES,4096}), "Memory") {return false}
	for &endpoint, i in p.endpoints {if !a.check(t, tr.memory_open(&p.memory, &endpoint, tr.Peer_Id(i+1)), "Memory endpoint") {return false}}
	for &gate, i in c.gates {
		gate.base = tr.memory_transport(&p.endpoints[i]); gate.codec = &p.codec
		if !a.check(t, rec.link_init(&c.links[i], a.gate_wire(&gate)), "public Link") {return false}
	}
	model := net.Model(f.Game,f.Control,f.Action,f.Event,2){complete_state=true, complete_codec=p.codec.value,
		step=ar.step, action=ar.action, control_valid=f.control_valid, action_valid=f.action_valid, hold=f.hold,
		action_timing=.Receipt, state_valid=proc(g: f.Game)->bool{return g.initial==4}}
	network := net.physics_config_default(); network.snapshot_every = 1
	if !a.none(t, net.server_init_complete(&p.server, &initial, model, rec.link_game_transport(&c.links[0]), network, local_seat=1), "real Server") {return false}
	if !a.none(t, net.server_set_local_token(&p.server, net.Token{0=1}), "Server token") {return false}
	if !a.none(t, net.client_init(&p.client, model, rec.link_game_transport(&c.links[1]), net.Token{0=2}, spectator=true, cfg=network), "public spectator constructor") {return false}
	c.gates[1].chunk = &p.client.physics.schemas.chunk
	if !a.client_pump(t,c,0) || !a.server_pump(t,c,0) || !a.none(t,net.server_step(&p.server),"membership") || !a.client_pump(t,c,0) || !a.server_pump(t,c,0) {return false}
	return a.check(t, p.client.spectator && p.client.phase == .Running && p.client.timeline.confirmed == 1, "actual spectator Welcome1")
}

welcome_header :: proc(c: ^a.Case) -> (net.Physics_Chunk_Header, bool) {
	for saved in c.gates[1].saved[:c.gates[1].count] {
		meta, fingerprint, inspected := sc.inspect(saved.data.bytes)
		if inspected.error != .None || fingerprint != c.pair.client.physics.schemas.chunk.fingerprint {continue}
		_, body, unpacked := sc.unpack_bytes(fingerprint, saved.data.bytes, meta)
		if unpacked.error != .None || len(body) < c.pair.client.physics.schemas.chunk.wire_size {continue}
		header: net.Physics_Chunk_Header
		if sc.decode(&c.pair.client.physics.schemas.chunk, &header, body[:c.pair.client.physics.schemas.chunk.wire_size]).error == .None && header.purpose == u32(net.Complete_Purpose.Welcome) {return header,true}
	}
	return {},false
}

exercise :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) -> bool {
	o.stage = "real_spectator_Welcome_ACK"
	if !open_spectator(t,c,o) {return false}
	p := &c.pair; observe(c,o,"after_actual_Welcome")
	welcome_found: bool; o.welcome,welcome_found = welcome_header(c)
	o.welcome_ACK,o.welcome_ACK_matches = fr.old_ack_matches(c,o.welcome)
	if !a.check(t,welcome_found && o.welcome_ACK_matches,"genuine Welcome and actual scope/id/digest ACK") {return false}
	if !a.check(t,p.client.cfg.history==128 && p.client.cfg.max_prediction==8 && TARGET>p.client.timeline.head && TARGET-p.client.timeline.head>8 && TARGET-p.client.timeline.head<128,"target gap>8 and<history128") {return false}
	c.gates[1].hold_snapshots = true; o.stage = "real_authority20_with_ordinary_snapshots_held"
	for p.server.timeline.head < TARGET {
		if !a.server_pump(t,c,(p.server.timeline.head+1)*17) || !a.none(t,net.server_step(&p.server),"ordinary authority step") {return false}
	}
	if !a.client_pump(t,c,NOW) {return false}
	observe(c,o,"after_signed_facts_with_snapshot_held")
	o.facts_ready = p.client.facts_contiguous >= TARGET
	if !a.check(t,o.facts_ready,"actual validated contiguous signed facts through20") {return false}
	old_found: bool; o.old_snapshot,old_found = fr.header(c,2)
	if !a.check(t,old_found,"actual held ordinary Snapshot2") {return false}
	c.gates[1].hold_snapshots = false; c.gates[1].release_snapshots = true
	if !a.client_pump(t,c,NOW) {return false}
	c.gates[1].hold_snapshots = true; c.gates[1].release_snapshots = false
	if !a.server_pump(t,c,NOW) {return false}
	o.old_ACK,o.old_ACK_matches = fr.old_ack_matches(c,o.old_snapshot)
	if !a.check(t,o.old_ACK_matches,"real Snapshot2 ACK unlocks current authority Snapshot") {return false}
	observe(c,o,"before_actual_Snapshot20")
	if !a.check(t,TARGET>p.client.timeline.confirmed && TARGET-p.client.timeline.confirmed>8 && TARGET-p.client.timeline.confirmed<128,"actual pre-delivery ordinary Snapshot20 gap>8 and<H128") {return false}
	o.stage = "deliver_real_Snapshot20_and_public_pumps"
	c.gates[1].hold_snapshots = false; c.gates[1].release_snapshots = true
	for _ in 0..<MAX_FINAL_PUMPS {
		if !a.client_pump(t,c,NOW) {return false}
		o.final_pumps += 1; observe(c,o,"after_public_spectator_pump")
		if p.client.phase != .Running || p.client.timeline.confirmed >= TARGET {break}
	}
	o.target_snapshot,o.target_packet_observed = fr.header(c,TARGET)
	if !a.check(t,o.target_packet_observed && o.target_snapshot.generation==o.welcome.generation && o.target_snapshot.serial==o.welcome.serial,"actual delivered same-scope ordinary Snapshot20") {return false}
	o.setup_complete = true
	if p.client.timeline.head >= TARGET && p.client.timeline.confirmed >= TARGET {
		o.full5_attempted = true
		authority,ae := r.capture_complete(&p.server.timeline,TARGET); o.authority_capture_status = i32(ae)
		if ae == .None {
			spectator,ce := r.capture_complete(&p.client.timeline,TARGET); o.spectator_capture_status = i32(ce)
			if ce == .None {
				o.full5_available = true; o.full5_equal = a.complete_same(c,&authority,&spectator)
				o.checkpoint_drops_ok = r.complete_checkpoint_destroy(&spectator)==.None && o.checkpoint_drops_ok
			}
			o.checkpoint_drops_ok = r.complete_checkpoint_destroy(&authority)==.None && o.checkpoint_drops_ok
		}
	}
	o.prospective_criterion = p.client.spectator && p.client.phase==.Running && p.client.timeline.confirmed>=TARGET && o.full5_available && o.full5_equal
	return true
}

cleanup :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) {
	drops := o.checkpoint_drops_ok; intact := true; archived := true
	for &gate,gi in c.gates {
		for &saved,i in gate.saved[:gate.count] {
			o.raw_capture_count += 1; intact = bd.hash_bytes(saved.data.bytes)==saved.hash && intact
			name := fmt.aprintf("raw-%d-%03d.bin",gi,i)
			archived = os.write_entire_file(name,saved.data.bytes)==nil && archived; delete(name)
		}
	}
	drops = net.client_destroy(&c.pair.client)==.None && drops
	drops = net.server_destroy(&c.pair.server)==.None && drops
	for &link in c.links {if link.ready {drops = rec.link_destroy(&link)==.None && drops}}
	for &gate in c.gates {for &saved in gate.saved[:gate.count] {drops = net.complete_data_destroy(&saved.data)==.None && drops}}
	if c.pair.codec.ready {drops = ph.network_codec_destroy(&c.pair.codec)==.None && drops}
	if c.pair.catalog._handle!=nil {drops = b.recovery_catalog_destroy(&c.pair.catalog)==.Ok && drops}
	if len(c.pair.memory.packets)>0 {tr.memory_destroy(&c.pair.memory)}
	engine,es := b.engine_allocation_stats(); wrapper,ws := b.snapshot_allocation_stats()
	o.native_live=engine.live_bytes; o.wrapper_live=wrapper.live_bytes; o.provider_live=ph.allocation_stats().live_bytes
	o.raw_archive_ok=archived; o.all_saved_bytes_intact=intact; o.all_drops_ok=drops && es==.Ok && ws==.Ok
	o.cleanup_observed=archived && intact && o.all_drops_ok && o.initial_checkpoint_drop_ok && o.native_live==0 && o.wrapper_live==0 && o.provider_live==0
	a.check(t,o.cleanup_observed,"raw bytes preserved and checked complete Native/provider cleanup")
}

@(test)
spectator_signed_facts_and_ahead_snapshot_reach_complete20 :: proc(t: ^testing.T) {
	backing:=context.allocator; tracking:mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking,backing,backing); context.allocator=mem.tracking_allocator(&tracking)
	c:=new(a.Case)
	o:=Observation{scope="generic4_actualCompleteCodec_publicSpectator_Memory_nilOwner_static_NOTSDK32_ENet_CPU",checkpoint_drops_ok=true,authority_capture_status=-1,spectator_capture_status=-1}
	reached:=exercise(t,c,&o)
	cleanup(t,c,&o); free(c); o.odin_live=u64(tracking.current_memory_allocated)
	testing.expect_value(t,o.odin_live,u64(0))
	context.allocator=backing; mem.tracking_allocator_destroy(&tracking)
	if reached && o.setup_complete && o.cleanup_observed && o.odin_live==0 {
		o.stage="ONLY_PROSPECTIVE_SPECTATOR_RECOVERY_CRITERION"
		testing.expect(t,o.prospective_criterion,"EXPECTED baseline RED: genuine spectator must confirm20 with equal complete5 after real signed facts and ahead ordinary Snapshot20")
	}
	bytes,error:=json.marshal(o); testing.expect(t,error==nil)
	if error==nil {defer delete(bytes); testing.expect(t,os.write_entire_file("spectator-recovery-observation.json",bytes)==nil)}
}
