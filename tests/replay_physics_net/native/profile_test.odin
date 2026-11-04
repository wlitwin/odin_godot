package replay_physics_native_net_test

import "core:testing"
import "core:mem"
import "core:fmt"
import "core:time"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import bd "godot:box3d/diagnostics"
import v "godot:replay/view"
import f "../fixture"

Saved_Packet :: struct {data:net.Complete_Data,tick:u64,kind:u16}
Capture_Wire :: struct {
	base:tr.Transport,
	codec:^ph.Network_Codec(f.Game,f.Control,f.Action,f.Event,2),
	packets:[512]Saved_Packet,
	count:int,
	bytes:u64,
}
capture_send :: proc(pointer:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
	capture:=cast(^Capture_Wire)pointer
	if capture.count==len(capture.packets){return .Backpressure}
	if capture.codec.value.reserve(capture.codec.value.catalog,u64(len(bytes)))!=.None{return .Backpressure}
	storage,error:=mem.alloc_bytes(len(bytes))
	if error!=.None {capture.codec.value.release(capture.codec.value.catalog,u64(len(bytes)));return .Backpressure}
	copy(storage,bytes);meta,_,_:=sc.inspect(bytes)
 owned,owner_error:=net.complete_data_adopt(storage,context.allocator,capture.codec.value)
 if owner_error!=.None{delete(storage,context.allocator);capture.codec.value.release(capture.codec.value.catalog,u64(len(bytes)));return .Backpressure}
 capture.packets[capture.count]={data=owned,tick=meta.tick,kind=meta.kind}
	capture.count+=1;capture.bytes+=u64(len(bytes));return .Sent
}
capture_transport :: proc(capture:^Capture_Wire)->tr.Transport {
	wire:=capture.base;wire.user=capture;wire.send=capture_send
	wire.receive=proc(pointer:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Capture_Wire)pointer).base,dst)}
	wire.status=proc(pointer:rawptr)->tr.Status{return tr.status(&(cast(^Capture_Wire)pointer).base)}
	wire.connected=proc(pointer:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Capture_Wire)pointer).base,peer)}
	wire.poll=nil;wire.close=nil;return wire
}
profile_max_counts:b.World_Counters
profile_step :: proc(game:^f.Game,controls:[2]f.Control,joins,leaves:u64,ctx:^r.Step(f.Event)){
	model_step(game,controls,joins,leaves,ctx)
	observation,error:=ph.observe(ctx.execution)
	if error==.None {
		profile_max_counts.body_count=max(profile_max_counts.body_count,observation.counts.body_count)
		profile_max_counts.shape_count=max(profile_max_counts.shape_count,observation.counts.shape_count)
		profile_max_counts.contact_count=max(profile_max_counts.contact_count,observation.counts.contact_count)
		profile_max_counts.joint_count=max(profile_max_counts.joint_count,observation.counts.joint_count)
	}
}
put64 :: proc(dst:[]u8,value:u64){for i in 0..<8 {dst[i]=u8(value>>uint(i*8))}}

@(test)
full32_single_runtime_history_and_eight_tick_canonical_repair_profile :: proc(t:^testing.T){
	// Saved canonical packets stay explicitly charged while the authority and
	// its catalog die, before the client allocates its own complete H128 ring.
	capture:=new(Capture_Wire);defer free(capture)
	defer for &packet in capture.packets[:capture.count] {net.complete_data_destroy(&packet.data)}
	profile_max_counts={}
	catalog:=catalog_make(t);config:=config_make(&catalog,32)
	world,game,status:=f.world(32);testing.expect_value(t,status,b.Status.Ok)
	initial,error:=ph.checkpoint_make(r.Frame(f.Game){state=game},net.Net_Event(f.Event),world,config)
	testing.expect_value(t,error,r.Error.None);b.world_destroy(&world)
	source_codec:ph.Network_Codec(f.Game,f.Control,f.Action,f.Event,2)
	testing.expect_value(t,ph.network_codec_init(&source_codec,&catalog,config,network_rules()),net.Error.None)
	capture.codec=&source_codec
	testing.expect_value(t,source_codec.value.reserve(source_codec.value.catalog,u64(size_of(Capture_Wire))),net.Error.None)
	memory:tr.Memory;testing.expect(t,tr.memory_init(&memory,cfg={2,32,tr.MAX_PACKET_BYTES,2048}))
	endpoints:[2]tr.Memory_Endpoint;for &endpoint,index in endpoints {tr.memory_open(&memory,&endpoint,tr.Peer_Id(index+1))}
	capture.base=tr.memory_transport(&endpoints[0])
	model:=network_model(&source_codec);model.step=profile_step
	cfg:=net.physics_config_default()
	source:net.Server(f.Game,f.Control,f.Action,f.Event,2)
	testing.expect_value(t,net.server_init_complete(&source,&initial,model,capture_transport(capture),cfg,local_seat=1),net.Error.None)
	testing.expect_value(t,net.server_set_local_token(&source,net.Token{0=1}),net.Error.None)
	// Existing client produces the actual version/content/model Hello. It owns
	// no solver until Welcome, and is destroyed before the authority trajectory.
	bootstrap:net.Client(f.Game,f.Control,f.Action,f.Event,2)
	testing.expect_value(t,net.client_init(&bootstrap,model,tr.memory_transport(&endpoints[1]),net.Token{0=2},cfg=cfg),net.Error.None)
	net.client_pump(&bootstrap,0);net.client_destroy(&bootstrap);tr.memory_advance(&memory,0);net.server_pump(&source,0)
	max_normal:u64
	for tick in 1..=160 {
		if tick==40 || tick==41 || tick==95 || tick==115 {_,issue_error:=net.server_issue(&source,f.Action{kind=tick==95?.Remove:tick==115?.Motor:.Spawn});testing.expect_value(t,issue_error,net.Error.None)}
		testing.expect_value(t,net.server_local(&source,f.Control{x=tick%2==0?10:-10}),net.Error.None)
		started:=time.tick_now();testing.expect_value(t,net.server_step(&source),net.Error.None);wall:=u64(time.tick_since(started))
		core:=source.timeline.external_profile.last_total_ns;max_normal=max(max_normal,core)
		fmt.printf("PHYSICS_PROFILE_SAMPLE phase=authority tick=%d normal_core_ns=%d step_and_wire_ns=%d\n",tick,core,wall)
	}
	// Correlated retained-image request uses the existing runner's actual route,
	// yielding a full Snapshot with the accepted last-eight window at tick160.
	request:=make([]u8,sc.HEADER_BYTES+source.codecs.request.wire_size);defer delete(request)
	peer:=source.peers[1];body:=request[sc.HEADER_BYTES:]
	put64(body[:8],peer.generation);put64(body[8:16],peer.serial);put64(body[16:24],1);put64(body[24:32],0)
	testing.expect_value(t,sc.pack_bytes(source.codecs.request.fingerprint,{kind=31,epoch=cfg.epoch,tick=160,content=cfg.content},body,request).error,sc.Error.None)
	remote:=tr.memory_transport(&endpoints[1]);testing.expect_value(t,tr.send(&remote,1,.Reliable,request),tr.Send_Result.Sent)
	tr.memory_advance(&memory,0);testing.expect_value(t,net.server_pump(&source,0),net.Error.None)
	engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();testing.expect(t,es==.Ok&&ws==.Ok)
	fmt.printf("PHYSICS_PROFILE_SOURCE engine_live=%d wrapper_live=%d provider_live=%d saved_payload_bytes=%d total_live=%d\n",engine.live_bytes,wrapper.live_bytes,ph.allocation_stats().live_bytes,capture.bytes,engine.live_bytes+wrapper.live_bytes+ph.allocation_stats().live_bytes)
	net.server_destroy(&source);r.complete_checkpoint_destroy(&initial);tr.memory_destroy(&memory)
	release_saved:=source_codec.value.release;saved_catalog:=source_codec.value.catalog
	testing.expect_value(t,ph.network_codec_destroy(&source_codec),net.Error.None);b.recovery_catalog_destroy(&catalog)
	defer release_saved(saved_catalog,u64(size_of(Capture_Wire)))
	catalog=catalog_make(t);defer b.recovery_catalog_destroy(&catalog)
	client_codec:ph.Network_Codec(f.Game,f.Control,f.Action,f.Event,2)
	testing.expect_value(t,ph.network_codec_init(&client_codec,&catalog,config,network_rules()),net.Error.None);defer ph.network_codec_destroy(&client_codec)
	client_codec.profile_clock.read=proc(rawptr)->(u64,bool){return u64(time.tick_now()._nsec)/1000,true}
	model=network_model(&client_codec);model.step=profile_step
	testing.expect(t,tr.memory_init(&memory,cfg={2,32,tr.MAX_PACKET_BYTES,2048}));defer tr.memory_destroy(&memory)
	endpoints={}
	for &endpoint,index in endpoints {testing.expect(t,tr.memory_open(&memory,&endpoint,tr.Peer_Id(index+1)))}
	authority:=tr.memory_transport(&endpoints[0])
	client:net.Client(f.Game,f.Control,f.Action,f.Event,2)
	testing.expect_value(t,net.client_init(&client,model,tr.memory_transport(&endpoints[1]),net.Token{0=2},cfg=cfg),net.Error.None);defer net.client_destroy(&client)
	client.profile_clock=client_codec.profile_clock
	drain:=make([]u8,tr.MAX_PACKET_BYTES);defer delete(drain)
	journal_changes:=make([]v.Change(net.Net_Event(f.Event)),2048);defer delete(journal_changes)
	for tick in 1..=152 {
		for packet in capture.packets[:capture.count] {
			if packet.tick!=u64(tick){continue}
			testing.expect_value(t,tr.send(&authority,2,.Reliable,packet.data.bytes),tr.Send_Result.Sent)
		}
		tr.memory_advance(&memory,u64(tick));testing.expect_value(t,net.client_pump(&client,u64(tick)*16),net.Error.None)
		if tick>1 {testing.expect_value(t,net.client_step(&client,f.Control{}),net.Error.None)}
		v.drain(&client.journal,journal_changes[:]);tr.memory_advance(&memory,u64(tick));for tr.receive(&authority,drain).state==.Received{}
	}
	testing.expect_value(t,client.timeline.confirmed,u64(152))
	if client.phase!=.Running{return}
	for _ in 0..<8 {if client.timeline.head>=160{break};testing.expect_value(t,net.client_step(&client,f.Control{}),net.Error.None)}
	testing.expect_value(t,client.timeline.head,u64(160))
	before_verified:=client.physics.verified_compares
	before_replay:=client.stats.replayed_ticks;before_repairs:=client.physics.repairs
	client.profile_metrics[.Physics_Inspect]={};client.profile_metrics[.Physics_Decode]={};client.profile_metrics[.Physics_Repair]={};client.profile_metrics[.Physics_Compare]={};client_codec.native_decode={}
	for packet in capture.packets[:capture.count] {
		if packet.tick==160 && packet.kind==28 {testing.expect_value(t,tr.send(&authority,2,.Reliable,packet.data.bytes),tr.Send_Result.Sent)}
	}
	tr.memory_advance(&memory,160);started:=time.tick_now()
	testing.expect_value(t,net.client_pump(&client,160*16),net.Error.None);repair_wall:=u64(time.tick_since(started))
	testing.expect_value(t,client.timeline.confirmed,u64(160));testing.expect_value(t,client.timeline.head,u64(160))
	testing.expect_value(t,client.physics.verified_compares-before_verified,u64(1))
	testing.expect_value(t,client.stats.replayed_ticks-before_replay,u64(8));testing.expect_value(t,client.physics.repairs-before_repairs,u64(1));testing.expect(t,!client.physics.trace.ready)
	_,retained:=r.read_values(&client.timeline,33);_,expired:=r.read_values(&client.timeline,32);testing.expect(t,retained&&!expired)
	current,ce:=r.capture_complete(&client.timeline,160);testing.expect_value(t,ce,r.Error.None);defer r.complete_checkpoint_destroy(&current)
	view,ve:=net.complete_view(client_codec.value,&current,&client_codec.state,&client_codec.occurrence);testing.expect_value(t,ve,net.Error.None);defer net.complete_view_destroy(&view)
	actual,_:=bd.sign(view.frame);testing.expect_value(t,bd.compare(client.physics.signatures[160%128],actual),bd.Difference.Match)
	fmt.printf("PHYSICS_PROFILE_PHASES inspect=%v envelope_decode=%v native_decode=%v revision=%v compare=%v\n",client.profile_metrics[.Physics_Inspect],client.profile_metrics[.Physics_Decode],client_codec.native_decode,client.profile_metrics[.Physics_Repair],client.profile_metrics[.Physics_Compare])
	engine,_=b.engine_allocation_stats();wrapper,_=b.snapshot_allocation_stats();owned:=ph.allocation_stats()
	fmt.printf("PHYSICS_PROFILE_RESULT initial=32 total_bodies=%d shapes=%d contacts=%d joints=%d history=128 repair=8 normal_core_max_ns=%d correction_core_ns=%d correction_decode_wall_ns=%d engine_live=%d wrapper_live=%d provider_live=%d tracked_live=%d tracked_observed_peak=%d command_reserve=%d write_reserve=%d saved_payload_bytes=%d images_complete=true\n",profile_max_counts.body_count,profile_max_counts.shape_count,profile_max_counts.contact_count,profile_max_counts.joint_count,max_normal,client.timeline.external_profile.last_total_ns,repair_wall,engine.live_bytes,wrapper.live_bytes,owned.live_bytes,engine.live_bytes+wrapper.live_bytes+owned.live_bytes,owned.observed_live_peak,ph.RESERVATION_BYTES,b.RECOVERY_WRITE_RESERVE_BYTES,capture.bytes)
}
