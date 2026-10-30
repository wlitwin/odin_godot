package main

import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"
import game "../../examples/replay_scrapyard/shared/game"

Server :: net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS)
Client :: net.Client(game.World,game.Control,game.Action,game.Event,game.SEATS)
server:Server
client:Client
wire:tr.Memory
endpoints:[2]tr.Memory_Endpoint

run :: proc(seed:u64)->bool {
 assert(tr.memory_init(&wire,seed=seed,cfg={2,512,65536,32768},faults={latency_ticks=7,jitter_ticks=u32(seed%4),retry_ticks=3}))
 defer tr.memory_destroy(&wire)
 for &endpoint,i in endpoints {assert(tr.memory_open(&wire,&endpoint,tr.Peer_Id(i+1)))}
 defer for &endpoint in endpoints {transport:=tr.memory_transport(&endpoint);tr.close(&transport)}
 cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT;cfg.snapshot_every=1;cfg.watch_delay=3
 w:=game.initial(encounter_count=0);w.rules=game.RUN_RULES;w.rules.base_count,w.rules.growth,w.rules.wave_count,w.rules.barrels=0,0,1,0
 w.catalog.mobs[0].bite=0;w.catalog.guns[0].mechanism.mag=255;w.catalog.guns[0].mechanism.jam_per_mille=0
 model:=game.model();model.action_admit=proc(user:rawptr,seat:u16,a:game.Action)->bool{return game.development_allowed(true,1,seat,a)}
 assert(net.server_init(&server,r.Frame(game.World){state=w},model,tr.memory_transport(&endpoints[0]),cfg,local_seat=1)==.None)
 defer net.server_destroy(&server)
 net.server_set_local_token(&server,net.Token{0=1})
 assert(net.client_init(&client,model,tr.memory_transport(&endpoints[1]),net.Token{0=2},cfg=cfg)==.None)
 defer net.client_destroy(&client)
 net.client_remote_observed(&client)
 clock:r.Clock;r.clock_init(&clock,60)
 last_ms:u64
 declared,ready,started:bool
 issued:u64
 enters,starts:int
 observed:map[r.Event_Id]bool;observed=make(map[r.Event_Id]bool);defer delete(observed)
 for frame in u64(0)..<900 {
  assert(tr.memory_advance(&wire,frame));now:=frame*1000/60
  err:=net.server_pump(&server,now);assert(err==.None)
  // Vary client join/render alignment and small local stalls deterministically.
  stall_at:=u64(40)+(seed%16)*5
  stall_ticks:=u64(24)+(seed/16)*8
  pump:=frame>=seed%20 && !(seed>=16 && frame%83==seed%83) && !(seed>=33 && frame>=stall_at && frame<stall_at+stall_ticks)
  if pump {
   before:=client.stats.snapshot_catchups
   err=net.client_pump(&client,now)
   if err!=.None {fmt.printf("STARTUP_FAIL seed=%d frame=%d pump=%v detail=%v\n",seed,frame,err,client.presentation_failure);return false}
   dt:=f64(now-last_ms)/1000;last_ms=now
   if client.stats.snapshot_catchups!=before {r.clock_init(&clock,60);dt=0}
   steps,ok:=r.clock_add(&clock,dt*client.clock_scale);assert(ok)
   for _ in 0..<steps {
    if client.phase==.Running {
     err=net.client_step(&client,game.Control{})
     if err!=.None && err!=.Capacity {fmt.printf("STARTUP_FAIL seed=%d frame=%d step=%v detail=%v\n",seed,frame,err,client.presentation_failure);return false}
    }
    r.clock_consume(&clock)
   }
   changes:[320]view.Change(net.Net_Event(game.Event))
   for {
    count:=view.drain(&client.journal,changes[:]);if count==0 {break}
    for change in changes[:count] {
     if change.confirmed && change.kind==.Begin && change.occurrence.value.kind==.Gameplay {
      e:=change.occurrence
      assert(!observed[e.id]);observed[e.id]=true
      if e.value.value.kind==.Entered {enters+=1}
      if e.value.value.kind==.Started {starts+=1}
     }
    }
   }
  }
  truth,ok:=r.current(&server.timeline);assert(ok)
  if client.phase==.Running && !declared {
   profile:=game.Profile{name=game.name("startup"),look=0,iron=0,abilities={1,2}}
   _,err=net.server_issue(&server,game.Action{kind=.Profile,profile=profile});assert(err==.None)
   _,err=net.client_issue(&client,game.Action{kind=.Profile,profile=profile});assert(err==.None);declared=true
  }
  if declared && truth.state.players[0].meta_claimed && truth.state.players[1].meta_claimed && !ready {
   _,err=net.server_issue(&server,game.Action{kind=.Ready,ready=true});assert(err==.None)
   _,err=net.client_issue(&client,game.Action{kind=.Ready,ready=true});assert(err==.None);ready=true
  }
  if ready && truth.state.players[0].profile.ready && truth.state.players[1].profile.ready && !started {
   _,err=net.server_issue(&server,game.Action{kind=.Start});assert(err==.None);started=true
  }
  if started && truth.state.players[1].in_yard && frame%6==0 && issued<40 {
   for _ in 0..<min(u64(4),40-issued) {
    index:=issued%40
    _,err=net.server_issue(&server,game.Action{kind=.Dev_Spawn,item=0,slot=1,aim={f32(100+index%5*24),f32(i64(index/5)*28-98)}})
    assert(err==.None);issued+=1
   }
  }
  assert(net.server_step(&server)==.None)
 }
 truth,ok:=r.current(&server.timeline);assert(ok)
 assert(client.phase==.Running && client.presentation_failure.serial==0)
 assert(client.authority_frame.tick+u64(cfg.max_prediction)>server.timeline.head)
 assert(issued==40 && truth.state.mobs.count==40 && client.authority_frame.state.mobs.count==40)
 assert(enters==2 && starts==1)
 assert(client.stats.resyncs<=1)
 if seed<=32 {assert(client.stats.resyncs==0)}
 if client.stats.resyncs!=0 {assert(client.resync_notice.reason==.Prediction_Limit);fmt.printf("STARTUP_RESYNC seed=%d count=%d notice=%v\n",seed,client.stats.resyncs,client.resync_notice)}
 fmt.printf("STARTUP_CASE_OK seed=%d head=%d authority=%d confirmations=%d catchups=%d large=%d\n",seed,server.timeline.head,client.authority_frame.tick,len(observed),client.stats.snapshot_catchups,server.stats.large_reliable_snapshots)
 return true
}
main :: proc() {
 for seed in u64(1)..=96 {assert(run(seed))}
 fmt.println("REPLAY_SCRAPYARD_STARTUP_OK cases=96")
}
