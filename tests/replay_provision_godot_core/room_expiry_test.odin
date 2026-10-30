package provision_godot_test

import "core:testing"
import "core:fmt"
import r "godot:replay"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"
import net "godot:replay/net"

Expiry_Clock :: struct {now,expire_at:u64,reads,trip:int,broken:bool}
expiry_clock :: proc(user:rawptr)->(u64,bool) {
 c:=cast(^Expiry_Clock)user;c.reads+=1
 if c.trip!=0 && c.reads>=c.trip {if c.broken {return c.now,false};c.now=c.expire_at}
 return c.now,true
}
expiry_model :: proc()->net.Model(u32,u8,u8,u8,1) {
 return {step=proc(w:^u32,c:[1]u8,joins,leaves:u64,ctx:^r.Step(u8)){w^+=1},
 control_valid=proc(c:u8)->bool{return c==0},hold=proc(c:u8)->u8{return c},state_valid=proc(w:u32)->bool{return true}}
}

@(test)
room_expiry_between_following_preflight_and_redirect_is_a_pause_not_failure :: proc(t:^testing.T) {
 for was_authority in ([2]bool{false,true}) {for broken in ([2]bool{false,true}) {
  clock:=Expiry_Clock{now=1000,broken=broken}
  room:=new(rgd.Room(u32,u8,u8,u8,1));defer free(room)
  room.ready,room.registered,room.control_paused=true,true,true
  room.phase=.Following;room.last_reconnect=1000
  room.options.identity={1,11};room.options.room=44
  room.clock={user=&clock,read=expiry_clock}
  testing.expect_value(t,auth.lease_init(&room.lease,{1,11},44,55,room.clock,false),auth.Error.None)
  seq,err:=auth.lease_request(&room.lease);testing.expect_value(t,err,auth.Error.None)
  endpoint,_:=auth.endpoint("127.0.0.1",49422)
  grant:=auth.View{room=44,content=55,epoch=2,revision=2,coordinator_generation=1,owner={2,22},endpoint=endpoint,policy=auth.DEFAULT_POLICY,remaining_ms=1000}
  testing.expect_value(t,auth.lease_accept(&room.lease,seq,grant),auth.Error.None)
  cfg:=net.DEFAULT_CONFIG;cfg.content,cfg.require_permit=55,true
  room.session.ready,room.session.authority=true,was_authority
  room.session.options=rgd.SESSION_OPTIONS;room.session.options.network=cfg
  if was_authority {
   testing.expect_value(t,net.server_init(&room.session.server,r.Frame(u32){},expiry_model(),{},cfg,permit=auth.lease_permit(&room.lease)),net.Error.None)
  } else {
   testing.expect_value(t,net.client_init(&room.session.client,expiry_model(),{},net.Token{0=1},cfg=cfg,permit=auth.lease_permit(&room.lease)),net.Error.None)
  }
  defer net.server_destroy(&room.session.server);defer net.client_destroy(&room.session.client)
  // Room's read and outer lease check see a live grant. The operation's own
  // lease check reaches the deadline (or gets an invalid clock sample).
  clock.reads,clock.trip,clock.expire_at=0,3,room.lease.deadline
  error:=rgd.room_frame(room,0,0)
  fmt.printf("ROOM_PREFLIGHT_EXPIRY authority=%v broken=%v reads=%d error=%v phase=%v fenced=%v\n",was_authority,broken,clock.reads,error,room.phase,room.session.fenced)
  testing.expect_value(t,clock.reads,3)
  if broken {
   testing.expect_value(t,error,net.Error.Fenced);testing.expect_value(t,room.phase,rgd.Room_Phase.Failed);testing.expect(t,room.lease.poisoned)
  } else {
   testing.expect_value(t,error,net.Error.None);testing.expect_value(t,room.phase,rgd.Room_Phase.Following);testing.expect(t,room.session.fenced && !room.lease.poisoned)
  }
  testing.expect(t,room.session.ready && room.session.authority==was_authority)
  testing.expect_value(t,room.session.server.timeline.head,u64(0));testing.expect_value(t,room.session.client.timeline.head,u64(0))
  testing.expect_value(t,room.migrations,u64(0))
  testing.expect_value(t,was_authority ? room.session.server.cfg.epoch : room.session.client.cfg.epoch,u64(1))
 }}
}

@(test)
published_restore_expiry_preserves_the_prepared_checkpoint_and_clock_faults_fail :: proc(t:^testing.T) {
 for broken in ([2]bool{false,true}) {
  clock:=Expiry_Clock{now=1000,broken=broken}
  room:=new(rgd.Room(u32,u8,u8,u8,1));defer free(room)
  room.ready,room.registered,room.control_paused=true,true,true
  room.phase=.Recovering;room.last_reconnect=1000;room.model=expiry_model()
  room.options.identity={1,11};room.options.room=44
  room.clock={user=&clock,read=expiry_clock}
  source:net.Server(u32,u8,u8,u8,1);defer net.server_destroy(&source)
  cfg:=net.DEFAULT_CONFIG;cfg.content,cfg.require_permit=55,true
  permit:=net.Permit{allow=proc(user:rawptr,epoch:u64)->bool{return epoch==1}}
  testing.expect_value(t,net.server_init(&source,r.Frame(u32){state=42},expiry_model(),{},cfg,local_seat=1,permit=permit),net.Error.None)
  testing.expect_value(t,net.server_set_local_token(&source,net.Token{0=7}),net.Error.None)
  testing.expect_value(t,auth.prepared_capture(&room.restore.prepared,&source,44,11),auth.Error.None)
  defer auth.prepared_destroy(&room.restore.prepared)
  point:=room.restore.prepared.point;bytes:=raw_data(room.restore.prepared.bytes)
  testing.expect_value(t,auth.lease_init(&room.lease,{1,11},44,55,room.clock,true),auth.Error.None)
  seq,err:=auth.lease_request(&room.lease);testing.expect_value(t,err,auth.Error.None)
  endpoint,_:=auth.endpoint("127.0.0.1",49422)
  grant:=auth.View{room=44,content=55,epoch=2,revision=2,coordinator_generation=1,owner={1,11},endpoint=endpoint,policy=auth.DEFAULT_POLICY,remaining_ms=1000,recovered=point,recovery=.Coordinator_Restart}
  testing.expect_value(t,auth.lease_accept(&room.lease,seq,grant),auth.Error.None)
  room.restore.phase=.Granted;room.restore.renewed_epoch=2
  clock.reads,clock.trip,clock.expire_at=0,3,room.lease.deadline
  error:=rgd.room_frame(room,0,0)
  testing.expect_value(t,clock.reads,3)
  if broken {testing.expect_value(t,error,net.Error.Fenced);testing.expect_value(t,room.phase,rgd.Room_Phase.Failed)}
  else {testing.expect_value(t,error,net.Error.None);testing.expect_value(t,room.phase,rgd.Room_Phase.Recovering);testing.expect(t,room.session.fenced)}
  testing.expect(t,!room.session.ready && room.restore.prepared.ready && room.restore.prepared.point==point && raw_data(room.restore.prepared.bytes)==bytes)
  testing.expect_value(t,room.restore.phase,rgd.Room_Restore_Phase.Granted)
  testing.expect_value(t,room.migrations,u64(0))
 }
}
