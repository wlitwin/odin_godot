package main
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import old "../replay_snapshot_compat/reference"
import tr "godot:replay/transport"
import view "godot:replay/view"

World :: struct {sequence:u64,value:u8}
Control :: struct {sequence:u64,value:u8,spare:[64]u8}
model :: proc($M:typeid)->M {
 return {control_timing=.Latest_Observation,
  step=proc(w:^World,c:[2]Control,_,_:u64,_:^r.Step(u8)){if c[1].sequence>w.sequence {w^={c[1].sequence,c[1].value}}},
  control_valid=proc(c:Control)->bool{return c.value<200},state_valid=proc(w:World)->bool{return w.value<200},hold=proc(c:Control)->Control{return c}}
}
run :: proc(old_server,old_client:bool) {
 memory:tr.Memory;assert(tr.memory_init(&memory,77,{2,512,8192,16384},{latency_ticks=4,retry_ticks=3}));defer tr.memory_destroy(&memory)
 ends:[2]tr.Memory_Endpoint;for &e,i in ends {assert(tr.memory_open(&memory,&e,tr.Peer_Id(i+1)))}
 defer for &e in ends {wire:=tr.memory_transport(&e);tr.close(&wire)}
 ns:net.Server(World,Control,u8,u8,2);os:old.Server(World,Control,u8,u8,2)
 nc:net.Client(World,Control,u8,u8,2);oc:old.Client(World,Control,u8,u8,2)
 defer net.server_destroy(&ns);defer old.server_destroy(&os);defer net.client_destroy(&nc);defer old.client_destroy(&oc)
 if old_server {assert(old.server_init(&os,r.Frame(World){},model(old.Model(World,Control,u8,u8,2)),tr.memory_transport(&ends[0]),local_seat=1)==.None)}
 else {assert(net.server_init(&ns,r.Frame(World){},model(net.Model(World,Control,u8,u8,2)),tr.memory_transport(&ends[0]),local_seat=1)==.None)}
 if old_client {assert(old.client_init(&oc,model(old.Model(World,Control,u8,u8,2)),tr.memory_transport(&ends[1]),old.Token{0=2})==.None)}
 else {assert(net.client_init(&nc,model(net.Model(World,Control,u8,u8,2)),tr.memory_transport(&ends[1]),net.Token{0=2})==.None)}
 assert((old_server ? os.contract : ns.contract)==(old_client ? oc.contract : nc.contract))
 for tick in u64(0)..<350 {
  tr.memory_advance(&memory,tick);now:=tick*16
  if old_server {assert(old.server_pump(&os,now)==.None);assert(old.server_step(&os)==.None)}
  else {assert(net.server_pump(&ns,now)==.None);assert(net.server_step(&ns)==.None)}
  c:=Control{sequence=tick,value=u8(tick%199)}
  if old_client {
   assert(old.client_pump(&oc,now)==.None)
   if oc.phase==.Running {err:=old.client_step(&oc,c);assert(err==.None || err==.Capacity)}
   changes:[512]view.Change(old.Net_Event(u8));for view.drain(&oc.journal,changes[:])>0 {}
  } else {
   assert(net.client_pump(&nc,now)==.None)
   if nc.phase==.Running {err:=net.client_step(&nc,c);assert(err==.None || err==.Capacity)}
   changes:[512]view.Change(net.Net_Event(u8));for view.drain(&nc.journal,changes[:])>0 {}
  }
 }
 state:=World{}
 if old_server {frame,_:=r.current(&os.timeline);state=frame.state;assert(os.stats.rejected_inputs==0)}
 else {frame,_:=r.current(&ns.timeline);state=frame.state;assert(ns.stats.rejected_inputs==0);assert((ns.stats.compact_recent_facts>0)==!old_client)}
 assert(state.sequence>330)
 if old_client {assert(oc.phase==.Running && oc.stats.resyncs==0)}
 else {assert(nc.phase==.Running && nc.stats.resyncs==0);assert(nc.compact_observations_negotiated==!old_server);assert((nc.stats.compact_observations>0)==!old_server)}
 fmt.printf("RECENT_FACTS_COMPAT_OK old_server=%v old_client=%v bundles=%d saved=%d\n",old_server,old_client,old_server ? 0 : ns.stats.compact_recent_facts,old_server ? 0 : ns.stats.recent_fact_bytes_saved)
 fmt.printf("OBSERVATION_COMPAT_OK old_server=%v old_client=%v received=%d compact=%d\n",old_server,old_client,state.sequence,old_client ? 0 : nc.stats.compact_observations)
}
main :: proc() {run(true,false);run(false,true);run(false,false);fmt.println("REPLAY_OBSERVATION_COMPAT_OK")}
