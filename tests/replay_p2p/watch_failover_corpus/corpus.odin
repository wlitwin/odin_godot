package watch_failover_corpus
import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import c "../rejoin_corpus"

verify_case :: proc(seed:u64)->u64 {
	f:c.Fixture
	assert(tr.memory_init(&f.network,seed,{3,512,1024,8192},{latency_ticks=3,jitter_ticks=2,loss_permyriad=1000,duplicate_permyriad=1000,retry_ticks=3}))
	defer tr.memory_destroy(&f.network)
	defer {for &peer in f.peers {rb.destroy(&peer)};for &endpoint in f.endpoints {wire:=tr.memory_transport(&endpoint);tr.close(&wire)}}
	cfg:=rb.DEFAULT_CONFIG;cfg.history=128;roster:=c.ROSTER
	for &peer,i in f.peers {assert(tr.memory_open(&f.network,&f.endpoints[i],roster[i]));assert(rb.init(&peer,r.Frame(c.World){},c.model(),c.ROSTER,u16(i),tr.memory_transport(&f.endpoints[i]),cfg)==.None)}
	// Check the callable and its owner before running input through the callback.
	for &peer in f.peers {assert(peer.model.step==c.step && peer.timeline.user==&peer.model)}
	for _ in 0..<180 {c.cycle(&f,90)}
	network:tr.Memory;assert(tr.memory_init(&network,seed+80,{2,512,8192,8192},{latency_ticks=2,jitter_ticks=1,loss_permyriad=1000,duplicate_permyriad=1000,retry_ticks=3}));defer tr.memory_destroy(&network)
	ends:[2]tr.Memory_Endpoint
	for &endpoint,i in ends {assert(tr.memory_open(&network,&endpoint,tr.Peer_Id(i+1)))}
	defer {for &endpoint in ends {wire:=tr.memory_transport(&endpoint);tr.close(&wire)}}
	watch:rb.Watch(c.World,c.Input,c.Event,3);source:rb.Watch_Source(c.World,c.Input,c.Event,3)
	defer rb.watch_destroy(&watch);defer rb.watch_source_destroy(&source)
	transfer:=rec.DEFAULT_CONFIG;transfer.retry_ms,transfer.timeout_ms=30,500
	assert(rb.watch_init(&watch,r.Frame(c.World){},c.model(),c.ROSTER,1,tr.memory_transport(&ends[1]),77,cfg,transfer)==.None)
	assert(rb.watch_source_init(&source,&f.peers[0],2,tr.memory_transport(&ends[0]),77,transfer)==.None)
	for segment in 0..<3 {
		target:=u64(180+segment*90)
		for _ in 0..<400 {
			c.cycle(&f,target);assert(tr.memory_advance(&network,f.clock))
			assert(rb.watch_source_pump(&source,f.clock*1000/60)==.None)
			assert(rb.watch_pump(&watch,f.clock*1000/60)==.None)
		}
		frame,known:=rb.watch_current(&watch);truth,_:=r.current(&f.peers[0].timeline)
		assert(known && frame.tick==target && reflect.equal(frame,truth) && watch.states[watch.active].chain==f.peers[0].chain)
		for &peer in f.peers {assert(peer.phase==.Running && peer.timeline.confirmed==target && peer.chain==f.peers[0].chain)}
		if segment<2 {
			reset:=watch.reset
			point,error:=rb.watch_rebind(&watch,1,tr.memory_transport(&ends[1]),u64(78+segment),f.clock*1000/60);assert(error==.None)
			kept,_:=rb.watch_current(&watch);assert(reflect.equal(kept,frame) && watch.reset==reset)
			rb.watch_source_destroy(&source)
			assert(rb.watch_source_init(&source,&f.peers[segment+1],2,tr.memory_transport(&ends[0]),u64(78+segment),transfer,resume=&point)==.None)
		}
	}
	assert(watch.stats.rebinds==2 && watch.stats.resets==1 && !watch.rebind_pending)
	return watch.states[watch.active].chain
}
