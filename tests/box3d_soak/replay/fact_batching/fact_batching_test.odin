// One prospective work-count criterion; no clock or production change.
package replay_fact_batching_test

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
import fr "godot:tests/box3d_soak/replay/facts_recovery"
import f "godot:tests/replay_physics_net/fixture"

DEPTH :: u64(8)
Packet_Metadata :: struct {
 gate,index:int,
 kind:u16,
 tick:u64,
 channel:tr.Channel,
 held,released,snapshot:bool,
 hash:bd.Digest,
}
Observation :: struct {
	scope, stage, counter_kind: string,
	setup_complete, semantic_ok, prospective_work_count_ok: bool,
	base, target, initial_head, predicted_head, authority_head: u64,
	head_before, head_after, confirmed_before, confirmed_after: u64,
	generation, serial, final_generation, final_serial: u64,
	facts_before, facts_after, replayed_before, replayed_after: u64,
	repairs_before, repairs_after, corrections_before, corrections_after: u64,
	last_executed_steps, resyncs_before, resyncs_after: u64,
	prediction_calls, observed_client_pump_calls, fact_packets_received, held_snapshots: int,
	journal_capacity, journal_count_before, journal_count_after: int,
	pump_status: i32,
	step_contract, accepted_prefix_equal, full5_available, full5_equal: bool,
	snapshot_header: net.Physics_Chunk_Header,
	snapshot_header_available, checkpoint_drops_ok: bool,
	raw_packets: int,
	raw_archive_ok, raw_bytes_intact, all_drops_ok, cleanup_ok: bool,
	native_live, wrapper_live, provider_live, odin_live: u64,
}

exercise :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) -> bool {
	o.stage = "existing_public_generic4_Welcome"
	if !a.open(t,c) {return false}
	p := &c.pair
	o.base=p.client.timeline.confirmed; o.target=o.base+DEPTH; o.initial_head=p.client.timeline.head
	o.generation=p.client.generation; o.serial=p.client.serial
	if !a.check(t,!p.client.spectator && p.client.cfg.history==128 && p.client.cfg.max_prediction==8 && p.server.timeline.head==o.base,"actual driver Welcome/H128/pred8 and same authority base") {return false}
	c.gates[1].hold_snapshots=true
	o.stage="public_prediction_backlog8_without_receive"
	for p.client.timeline.head<o.target {
		if !a.none(t,net.client_step(&p.client,f.Control{}),"actual public neutral prediction") {return false}
		o.prediction_calls+=1
	}
	o.predicted_head=p.client.timeline.head
	if !a.check(t,p.client.timeline.head==o.target && p.client.timeline.confirmed==o.base,"all eight actual outstanding predicted ticks") {return false}
	o.stage="eight_genuine_authority_facts_with_distinct_controls"
	for p.server.timeline.head<o.target {
		tick:=p.server.timeline.head+1
		if !a.server_pump(t,c,tick*17) {return false}
		// Valid local controls differ at every tick. The model and physics are
		// unchanged; these are ordinary public authority inputs, not row writes.
		if !a.none(t,net.server_local(&p.server,f.Control{x=i16(tick-o.base)}),"real local authority control") || !a.none(t,net.server_step(&p.server),"real ordinary authority step") {return false}
	}
	o.authority_head=p.server.timeline.head
	if !a.check(t,p.client.timeline.head==o.target && p.client.timeline.confirmed==o.base,"no client receive before burst") {return false}
	// Existing Link receive/capture is transport work only. The work-count
	// window below contains exactly one direct public client_pump invocation.
	first_packet:=c.gates[1].count // Capture the actual Link receive, before the direct client pump.
	if !a.check(t,tr.memory_advance(&p.memory,o.target*17),"public Memory time") || !a.check(t,rec.link_pump(&c.links[1],o.target*17),"public client Link") {return false}
	o.stage="ONE_actual_client_pump"
	o.head_before=p.client.timeline.head; o.confirmed_before=p.client.timeline.confirmed
	o.facts_before=p.client.facts_contiguous; o.replayed_before=p.client.stats.replayed_ticks
	o.repairs_before=p.client.physics.repairs; o.corrections_before=p.client.stats.corrections
	o.resyncs_before=p.client.stats.resyncs; o.step_contract=p.client.timeline.external.require_step
	o.journal_capacity=len(p.client.journal.queue); o.journal_count_before=p.client.journal.queue_count
	o.observed_client_pump_calls+=1
	error:=net.client_pump(&p.client,o.target*17); o.pump_status=i32(error)
	o.head_after=p.client.timeline.head; o.confirmed_after=p.client.timeline.confirmed
	o.facts_after=p.client.facts_contiguous; o.replayed_after=p.client.stats.replayed_ticks
	o.repairs_after=p.client.physics.repairs; o.corrections_after=p.client.stats.corrections
	o.last_executed_steps=p.client.physics.last_executed_steps; o.resyncs_after=p.client.stats.resyncs
	o.final_generation=p.client.generation; o.final_serial=p.client.serial
	o.journal_count_after=p.client.journal.queue_count
	if !a.none(t,error,"single actual client pump semantic status") || !a.check(t,c.gates[1].error=="","actual packet capture status") {return false}
	for saved in c.gates[1].saved[first_packet:c.gates[1].count] {
		_,fingerprint,inspected:=sc.inspect(saved.data.bytes)
		if inspected.error==.None && fingerprint==p.client.physics.schemas.fact.fingerprint {o.fact_packets_received+=1}
		if saved.snapshot && saved.held && !saved.released {o.held_snapshots+=1}
	}
	o.snapshot_header,o.snapshot_header_available=fr.header(c,o.base+1)
	if !a.check(t,o.fact_packets_received==int(DEPTH) && o.held_snapshots>0 && o.snapshot_header_available && o.facts_after>=o.target,"real signed fact burst through target; ordinary Snapshot stays held") {return false}
	o.setup_complete=true; o.accepted_prefix_equal=true
	for tick:=o.base+1;tick<=o.target;tick+=1 {
		authority,af:=net.server_accepted_input(&p.server,tick)
		replica,rf:=net.accepted_read(&p.client.physics.accepted,tick)
		o.accepted_prefix_equal=af && rf && authority.batch.controls==replica.batch.controls && o.accepted_prefix_equal
	}
	if !a.check(t,o.accepted_prefix_equal && o.confirmed_after==o.target && o.head_after==o.target && p.client.phase==.Running && o.final_generation==o.generation && o.final_serial==o.serial && o.resyncs_after==o.resyncs_before && o.step_contract,"independent semantic confirmation/scope/accepted-prefix/real-step contract") {return false}
	authority,ae:=r.capture_complete(&p.server.timeline,o.target)
	if !a.check(t,ae==.None,"actual confirmed authority checkpoint") {return false}
	replica,re:=r.capture_complete(&p.client.timeline,o.target)
	if re==.None {o.full5_available=true; o.full5_equal=a.complete_same(c,&authority,&replica); o.checkpoint_drops_ok=r.complete_checkpoint_destroy(&replica)==.None && o.checkpoint_drops_ok}
	o.checkpoint_drops_ok=r.complete_checkpoint_destroy(&authority)==.None && o.checkpoint_drops_ok
	if !a.check(t,re==.None && o.full5_available && o.full5_equal && o.checkpoint_drops_ok,"independent complete5 equality and checked checkpoint drops") {return false}
	o.semantic_ok=true
	o.prospective_work_count_ok=o.observed_client_pump_calls==1 && o.replayed_after-o.replayed_before==DEPTH && o.repairs_after-o.repairs_before==1
	return true
}

cleanup :: proc(t: ^testing.T, c: ^a.Case, o: ^Observation) {
	drops:=o.checkpoint_drops_ok; intact:=true; archived:=true
	for &gate,gi in c.gates {for &saved,i in gate.saved[:gate.count] {
		o.raw_packets+=1; intact=bd.hash_bytes(saved.data.bytes)==saved.hash && intact
		name:=fmt.aprintf("raw-%d-%03d.bin",gi,i); archived=os.write_entire_file(name,saved.data.bytes)==nil && archived; delete(name)
		metadata:=Packet_Metadata{gi,i,saved.kind,saved.tick,saved.packet.channel,saved.held,saved.released,saved.snapshot,saved.hash}
		name=fmt.aprintf("raw-%d-%03d.json",gi,i); a.write_json(name,metadata); delete(name)
	}}
	drops=net.client_destroy(&c.pair.client)==.None && drops
	drops=net.server_destroy(&c.pair.server)==.None && drops
	for &link in c.links {if link.ready {drops=rec.link_destroy(&link)==.None && drops}}
	for &gate in c.gates {for &saved in gate.saved[:gate.count] {drops=net.complete_data_destroy(&saved.data)==.None && drops}}
	if c.pair.codec.ready {drops=ph.network_codec_destroy(&c.pair.codec)==.None && drops}
	if c.pair.catalog._handle!=nil {drops=b.recovery_catalog_destroy(&c.pair.catalog)==.Ok && drops}
	if len(c.pair.memory.packets)>0 {tr.memory_destroy(&c.pair.memory)}
	engine,es:=b.engine_allocation_stats(); wrapper,ws:=b.snapshot_allocation_stats()
	o.native_live=engine.live_bytes; o.wrapper_live=wrapper.live_bytes; o.provider_live=ph.allocation_stats().live_bytes
	o.raw_archive_ok=archived; o.raw_bytes_intact=intact; o.all_drops_ok=drops && es==.Ok && ws==.Ok
	o.cleanup_ok=archived && intact && o.all_drops_ok && o.native_live==0 && o.wrapper_live==0 && o.provider_live==0
	a.check(t,o.cleanup_ok,"raw packets/source leases intact and Native/provider cleanup0")
}

@(test)
eight_outstanding_signed_facts_use_one_eight_step_repair :: proc(t: ^testing.T) {
	backing:=context.allocator; tracking:mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking,backing,backing); context.allocator=mem.tracking_allocator(&tracking)
	c:=new(a.Case)
	o:=Observation{scope="synthetic_generic4_staticOFFddff_nilOwner_real_complete_physics_Memory_Link_NOT_live_cause_or_CPU",counter_kind="public_committed_replayed_ticks_from_result.steps_not_Native_call_count",checkpoint_drops_ok=true,pump_status=-1}
	reached:=exercise(t,c,&o)
	cleanup(t,c,&o); free(c); o.odin_live=u64(tracking.current_memory_allocated)
	testing.expect_value(t,o.odin_live,u64(0))
	context.allocator=backing; mem.tracking_allocator_destroy(&tracking)
	if reached && o.setup_complete && o.semantic_ok && o.cleanup_ok && o.odin_live==0 {
		o.stage="ONLY_COMBINED_PROSPECTIVE_WORK_COUNT_CRITERION"
		testing.expect(t,o.prospective_work_count_ok,"PROSPECTIVE work count: one actual client_pump must confirm all8 with exactly8 committed real replay steps and1 repair")
	}
	bytes,error:=json.marshal(o); testing.expect(t,error==nil)
	if error==nil {defer delete(bytes); testing.expect(t,os.write_entire_file("fact-batching-observation.json",bytes)==nil)}
}
