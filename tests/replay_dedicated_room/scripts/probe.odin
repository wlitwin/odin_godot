//gd:extends Node
//gd:class DedicatedRoomProbe
package dedicated_room_probe
import "core:fmt"
import "core:os"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"
import game "godot:examples/replay_scrapyard/shared/game"

DedicatedRoomProbe :: struct {
 owner:gd.Node,
 member:int,folder,mode:string,started:u64,ready_sent,triggered,done,finishing:bool,
 room:rgd.Room(game.World,game.Control,game.Action,game.Event,game.SEATS),
 store:db.Store,service:auth.Service,control:rgd.Enet,
 expected:r.Frame(game.World),point:auth.Point,expected_ready:bool,checked_epoch,diagnostic_at,durable_after:u64,
}
mark :: proc(self:^DedicatedRoomProbe,name:string) {if seen(self,name) {return};assert(os.write_entire_file(fmt.tprintf("%s/%s",self.folder,name),string("ready"))==nil)}
seen :: proc(self:^DedicatedRoomProbe,name:string)->bool {return os.is_file(fmt.tprintf("%s/%s",self.folder,name))}
fail :: proc(self:^DedicatedRoomProbe,why:string) {if self.done {return};self.done=true;gd.print_str(fmt.tprintf("DEDICATED_ROOM_FAIL member=%d %s",self.member,why));gd.scene_tree_quit(gd.get_tree(self.owner),1)}
dedicated_room_probe_ready :: proc(self:^DedicatedRoomProbe) {
 self.member=int(gd.env_int("DED_MEMBER",0));self.folder=gd.env_string("DED_DIR","");self.mode=gd.env_string("DED_MODE","planned")
 self.started=gd.time_get_ticks_msec(gd.singleton_time());port:=u16(gd.env_int("DED_PORT",40100))
 if self.member==0 {
  if db.open(&self.store,fmt.tprintf("%s/room.sqlite3",self.folder),true)!=.None {fail(self,"database");return}
  policy:=auth.DEFAULT_POLICY;policy.mode=.Dedicated
  record:=auth.record_make(92,game.CONTENT,{1,101},policy);keys:[4]auth.Credential
  for i in 0..<4 {
   id:=auth.Identity{u64(i+1),u64(i+101)};endpoint,_:=auth.endpoint("127.0.0.1",port+u16(i+1))
   record.members[i]={identity=id,endpoint=endpoint,enabled=true,can_host=i<2,trusted_authority=i<2,infrastructure=i<2,game_token_hash=net.token_hash(rgd.session_token(fmt.tprintf("dedicated-room-%d",i+1)))}
   keys[i]={identity=id,key={0=u8(51+i)}}
  }
  if !rgd.enet_host(&self.control,port,8,bind_ip="127.0.0.1") || auth.service_init(&self.service,record,db.commit,&self.store,auth.native_clock(),rgd.enet_transport(&self.control),keys[:])!=.None {fail(self,"coordinator");return}
  gd.print_str("DEDICATED_ROOM_COORDINATOR_READY");return
 }
 opts:=rgd.SESSION_OPTIONS;opts.role=self.member<=2 ? .Server : .Client
 opts.network.content,opts.network.hz=game.CONTENT,game.HZ;opts.token=rgd.session_token(fmt.tprintf("dedicated-room-%d",self.member));opts.latency_ms=120
 opts.replication.accept_checkpoints=self.member<=2
 options:=rgd.Room_Options{identity={u64(self.member),u64(self.member+100)},key={0=u8(self.member+50)},room=92,coordinator="127.0.0.1",control_port=port,bootstrap=self.member==1,automatic_successor=true,session=opts}
 if rgd.room_open(&self.room,r.Frame(game.World){state=game.initial(dedicated=true,encounter_count=0)},game.model(),options)!=.None {fail(self,"room open");return}
}
dedicated_room_probe_process :: proc(self:^DedicatedRoomProbe,dt:f64) {
 if self.done {return}
 if self.member!=0 && seen(self,"exit-all") {self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0);return}
 if gd.time_get_ticks_msec(gd.singleton_time())-self.started>40000 {fail(self,"timeout");return}
 if self.member==0 {if auth.service_pump(&self.service)!=.None {fail(self,"coordinator pump")};if seen(self,"finished-1") && seen(self,"finished-2") && seen(self,"finished-3") && seen(self,"finished-4") {mark(self,"exit-all")};return}
 if e:=rgd.room_frame(&self.room,dt,game.Control{});e!=.None && e!=.Presentation {fail(self,fmt.tprintf("room frame %v",e));return}
 changes:[512]v.Change(net.Net_Event(game.Event));for rgd.session_changes(&self.room.session,changes[:])>0 {}
 outcomes:[net.ACTION_CAPACITY]net.Action_Outcome
 if !self.room.session.authority {for net.client_outcomes(&self.room.session.client,outcomes[:])>0 {}}
 s:=&self.room.session;if !s.ready {return};seat:=rgd.session_seat(s);epoch:=s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
 if self.member<=2 && seat!=0 {fail(self,fmt.tprintf("infrastructure consumed player seat %d role=%v",seat,s.role));return}
 frame,ok:=rgd.session_authority_state(s);if !ok {return}
 if epoch==1 && (s.authority || s.client.phase==.Running) {mark(self,fmt.tprintf("admitted-%d",self.member))}
 if self.member>=3 {
  if seat!=u16(self.member-2) {fail(self,"player seat changed");return}
  if !self.ready_sent && frame.state.players[seat-1].connected {_,e:=rgd.room_issue(&self.room,game.Action{kind=.Ready,ready=true});if e==.None {self.ready_sent=true}}
 }
 avatars:=0;for p in frame.state.players {if p.in_yard {avatars+=1}}
 if avatars>2 {fail(self,"extra avatar");return}
 if s.authority && frame.tick>=self.diagnostic_at {
  status:=rgd.room_backup_status(&self.room);self.diagnostic_at=frame.tick+60
  gd.print_str(fmt.tprintf("DEDICATED_ROOM_PROGRESS member=%d epoch=%d avatars=%d phase=%v backup=%v nominee=%d age=%d point=%d head=%d sent=%d ack=%d link=%v",self.member,epoch,avatars,self.room.phase,status.phase,status.nominee.member,status.age_ticks,status.point.archive.tick,frame.tick,s.link.sequence,s.link.outgoing.acknowledged.archive.sequence,s.link.error))
 }
 if self.room.prepared.ready && self.point!=self.room.prepared.point {
  cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
  if net.checkpoint_decode(&cp,self.room.prepared.bytes,game.model(),game.CONTENT)!=.None {fail(self,"prepared decode");return}
  self.expected,self.point,self.expected_ready=cp.frame,self.room.prepared.point,true
 }
 if s.authority && epoch>1 && self.checked_epoch!=epoch {
  restored,found:=r.read(&s.server.timeline,self.room.recovery.checkpoint_tick)
  if !self.expected_ready || self.point.archive.tick!=self.room.recovery.checkpoint_tick || !found || !reflect.equal(restored,self.expected) {fail(self,"restore frame changed");return}
  self.checked_epoch=epoch
  gd.print_str(fmt.tprintf("DEDICATED_ROOM_RESTORED member=%d epoch=%d seat=0 tick=%d",self.member,epoch,restored.tick))
 }
 if avatars==2 && (!s.authority && s.client.phase==.Running || s.authority) {
  mark(self,fmt.tprintf("ready-%d-%d",epoch,self.member))
  if s.authority && epoch==1 && !self.triggered && seen(self,"ready-1-3") && seen(self,"ready-1-4") {
   if self.durable_after==0 {self.durable_after=frame.tick}
   status:=rgd.room_backup_status(&self.room)
   if status.phase==.Ready && self.room.backup_observation.point.archive.tick>=self.durable_after {
    self.triggered=true;gd.print_str(fmt.tprintf("DEDICATED_ROOM_TRIGGER member=%d epoch=%d avatars=%d seat=%d nominee=%d",self.member,epoch,avatars,seat,status.nominee.member))
    if self.mode=="planned" || self.mode=="repeat" {if rgd.room_handoff(&self.room)!=.None {fail(self,"handoff refused")}} else {mark(self,"kill-owner")}
   }
  }
  if s.authority && epoch==2 && seen(self,"ready-2-1") && seen(self,"ready-2-3") && seen(self,"ready-2-4") && rgd.room_backup_status(&self.room).phase==.Ready {
   if self.mode=="repeat" {
    if !self.triggered {self.triggered=true;if rgd.room_handoff(&self.room)!=.None {fail(self,"second handoff refused")}}
   } else {mark(self,"complete")}
  }
  if self.mode=="repeat" && s.authority && epoch==3 && seen(self,"ready-3-2") && seen(self,"ready-3-3") && seen(self,"ready-3-4") && rgd.room_backup_status(&self.room).phase==.Ready {mark(self,"complete")}
 }
 if !self.finishing && epoch==(self.mode=="repeat" ? u64(3) : u64(2)) && seen(self,"complete") {
  gd.print_str(fmt.tprintf("DEDICATED_ROOM_OK member=%d epoch=%d seat=%d authority=%v role=%v avatars=%d",self.member,epoch,seat,s.authority,s.role,avatars))
  self.finishing=true;mark(self,fmt.tprintf("finished-%d",self.member))
 }
}
dedicated_room_probe_exit_tree :: proc(self:^DedicatedRoomProbe) {rgd.room_close(&self.room);auth.service_destroy(&self.service);wire:=rgd.enet_transport(&self.control);tr.close(&wire);db.close(&self.store)}
