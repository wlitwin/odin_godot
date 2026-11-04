package dockyard_duo

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import ph "godot:replay/physics"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import sc "godot:replay/schema"
import trgd "godot:replay/godot/transport"

Online :: struct{
 enabled,configured,opened,ended,menu_announced:bool,
 party:rgd.Party,
 role:rgd.Session_Role,
 room_owner,relay_owner:ph.Owner_Context,
 native:rawptr,
 tls:gd.Tls_Options,
 content:u64,
 name:string,
 message:[256]u8,message_count:int,
 watch:rgd.Provision_Connection,
 watch_ready,watch_failed:bool,
 watch_code:[p.INVITE_CODE_BYTES]u8,
 watch_code_count:int,
}
online_message :: proc(self:^DockyardDuo,text:string){
 o:=&self.state.online
 if text==string(o.message[:o.message_count]){return}
 o.message_count=copy(o.message[:],transmute([]u8)text)
 log_json("DOCKYARD_CONNECTION",struct{message:string}{string(o.message[:o.message_count])})
}
// Canonical typed identity + authored rules bind the service cohort. No process
// addresses, typeids, user credentials or JS numeric conversion enter this ID.
online_content :: proc(self:^DockyardDuo)->u64{
 codec:=self.state.codec.value
 // App lane v3 binds readiness/ACK to the actual committed peer generation.
 // Bind it to enrollment so older app semantics do not share this service cohort.
 bytes,error:=json.marshal(struct{application:u32,identity:bd.Identity,rules:bd.Digest}{u32(APPLICATION_PROTOCOL),codec.identity,codec.game_rules})
 if error!=nil{return 0};defer delete(bytes)
 hash:=bd.hash_bytes(bytes);value:=get64(hash[:8]);return value==0?1:value
}
online_init :: proc(self:^DockyardDuo)->bool{
 state:=self.state;o:=&state.online;o.enabled=true;o.content=online_content(self)
 allocator:=meter.allocator(self.scope);context.allocator=allocator
 service:=gd.launch_param("DOCKYARD_ROOM_SERVICE","service")
 if service==""{online_message(self,"Online play needs a configured room service. Use the direct launcher for local practice.");return true}
 local:=launch_int("DOCKYARD_ROOM_LOCAL","local",0)==1
 port:=launch_int("BOX3D_SAMPLE_PORT","port",49742)
 endpoint,valid:=auth.endpoint(gd.launch_param("DOCKYARD_ROOM_ADDRESS","address","127.0.0.1"),u16(port))
 if !valid||port<1||port>65535||!p.service_url_valid(service,local){online_message(self,"The room service or gameplay address is invalid.");return true}
 storage,ok:=online_native_init(self,local)
 ice,ice_error:=trgd.rtc_ice_settings("DOCKYARD_ICE_JSON")
 if ice_error!=.None{online_message(self,"The STUN/TURN configuration is invalid.");return true}
 cfg:=rgd.Party_Config{service=service,namespace=fmt.tprintf("dockyard-v1-%016x",o.content),content=o.content,endpoint=endpoint,
  invite_role=.Player,invite_uses=1,local_development=local,tls=o.tls,storage=storage,ice_json=ice,
  relay_credentials=launch_int("DOCKYARD_ROOM_RELAY","relay",0)==1,short_codes=true}
 if !ok||!rgd.party_open(&o.party,cfg,allocator){online_message(self,"Party data could not be opened. Existing data was kept.");return true}
 lease,status:=meter.block_lease(self.scope,state,size_of(Runtime),&state.room,size_of(state.room))
 if status!=bg.OK{error_set(self,"SDK.Room.lease");return false}
 owner,error:=ph.owner_context_create(lease,user_data=&state.room,require_live_instance=false)
 if error!=.None{error_set(self,"SDK.Room.owner");return false};o.room_owner=owner
 relay,rs:=meter.block_lease(self.scope,state,size_of(Runtime),&o.party.relay,size_of(o.party.relay))
 if rs!=bg.OK{error_set(self,"SDK.Relay.lease");return false}
 o.relay_owner,error=ph.owner_context_create(relay,user_data=&o.party.relay,require_live_instance=false)
 if error!=.None{error_set(self,"SDK.Relay.owner");return false}
 o.configured=true;self.role="crew";return true
}
@(gd_method="borrowed_args")
dockyard_duo_party :: proc(self:^DockyardDuo,action,name,invite:string)->bool{
 temp:=runtime.default_temp_allocator_temp_begin();defer runtime.default_temp_allocator_temp_end(temp)
 if self.state==nil{return false};o:=&self.state.online
 if !self.visuals_prepared||!o.configured||o.opened||o.party.active||!o.party.recent_loaded{return false}
 if len(name)<1||len(name)>32{online_message(self,"Choose a crew name of 1–32 UTF-8 bytes.");return false}
 for byte in transmute([]u8)name{if byte<32||byte==127{online_message(self,"Crew names cannot contain control characters.");return false}}
 verb:rgd.Party_Action;ticket:p.Ticket
 switch action{
 case "host":verb=.Create;o.role=.Host
 case "join","watch":
  verb=.Join;o.role=action=="watch"?.Observer:.Client
  index:u32=0;if action=="watch"{index=1}
  valid:bool;ticket,valid=p.short_ticket_parse(invite,o.content,index)
  if !valid{ticket,valid=p.ticket_parse(invite)}
  if !valid{online_message(self,"Enter the 5-character room code.");return false}
 case "recent":verb=.Rejoin;o.role=.Client
 case:return false
 }
 allocator:=meter.allocator(self.scope);context.allocator=allocator
 delete(o.name,allocator);o.name=strings.clone(name,allocator);o.message_count=0
 return rgd.party_begin(&o.party,verb,ticket)
}
// Before Room opens there is no running Timeline. Afterwards only Room drives
// its single Session; this function never creates a second simulation.
online_frame :: proc(self:^DockyardDuo)->bool{
 state:=self.state;o:=&state.online
 if !o.configured||o.ended{return false}
 context.allocator=meter.allocator(self.scope)
 rgd.party_frame(&o.party)
 if o.party.failed{return false}
 online_watch_invite(self)
 if self.visuals_prepared&&o.party.recent_loaded&&!o.menu_announced{
  o.menu_announced=true
  log_json("DOCKYARD_MENU_READY",struct{version:u32,cohort:string}{1,fmt.tprintf("%016x",o.content)})
 }
 if !o.opened&&o.party.ready{
  options:=session_options(self,u16(launch_int("BOX3D_SAMPLE_PORT","port",49742)))
  options.role=o.role;options.network.content=o.content
  room,valid:=rgd.party_room_options(&o.party,options)
  if !valid{online_message(self,"The room grant does not match this build.");o.ended=true;return false}
  room.automatic_successor=false;room.restore_published=false;room.session.replication.accept_checkpoints=false
  ownership:=rgd.Room_Ownership{allocator={state.image_owner.owner,context.allocator.data},container={o.room_owner.owner,&state.room},
   rtc_ice={o.relay_owner.owner,&o.party.relay},allocation_base=state,allocation_bytes=size_of(Runtime)}
  error:=rgd.room_open_complete(&state.room,&state.initial,model(&state.codec),room,allocator=context.allocator,ownership=ownership)
  if error!=.None{
   // Bounded failure evidence contains schema paths/status only, never grants,
   // keys, invite codes, payloads or mutable simulation state.
   request_schema,reply_schema:sc.Schema
   request_report:=sc.init(&request_schema,auth.Request,allocator=context.allocator)
   reply_report:=sc.init(&reply_schema,auth.Reply,allocator=context.allocator)
   log_json("DOCKYARD_ROOM_SCHEMA",struct{request_error,request_path,reply_error,reply_path:string,request_bytes,reply_bytes:int}{fmt.tprintf("%v",request_report.error),request_report.path,fmt.tprintf("%v",reply_report.error),reply_report.path,request_schema.wire_size,reply_schema.wire_size})
   sc.destroy(&request_schema);sc.destroy(&reply_schema)
   online_message(self,fmt.tprintf("Room could not open: %v.",error));o.ended=true;return false
  }
  o.opened=true
 }
 if !o.opened{return false}
 if state.session.ready&&state.session.authority&&state.session.fenced{
  self.go=false;o.ended=true
  online_message(self,"Hosting permission ended. This job stopped. Start a new crew.")
  if !log_stopped_frame(self,"SAMPLE_HOST_LOST"){error_set(self,"host_loss.complete_state unavailable")}
  return false
 }
 if state.session.ready&&!state.session.authority&&state.session.client.has_world{
  reply,complete:=auth.rpc_completed(&state.room.rpc)
  if complete&&reply.result==.None&&reply.view.epoch==state.session.client.cfg.epoch&&reply.view.epoch!=0&&reply.view.remaining_ms==0{
   self.go=false;o.ended=true
   online_message(self,"The host is unavailable. This job stopped. Start a new crew.")
   if !log_stopped_frame(self,"SAMPLE_HOST_LOST"){error_set(self,"host_loss.complete_state unavailable")}
   return false
  }
 }
 if !state.session.ready{
  error:=qualification_frame(self,0,Control{})
  if error!=.None{online_message(self,fmt.tprintf("Room connection failed: %v.",error));o.ended=true;return false}
  if !state.session.ready{return false}
 }
 if !game_session_ready(self){return false}
 if state.room.removed{online_message(self,"This crew membership was removed.");o.ended=true;self.go=false;return false}
 return true
}
@(gd_method)
dockyard_duo_rehost :: proc(self:^DockyardDuo)->bool{
 temp:=runtime.default_temp_allocator_temp_begin();defer runtime.default_temp_allocator_temp_end(temp)
 if self.state==nil||!self.state.online.ended{return false}
 if !log_stopped_frame(self,"SAMPLE_REHOST_FROM"){return false}
 return close_runtime(self)
}
// A distinct explicit creator-invite index grants a fresh membership. Watching
// is the public Session.Observer role; it does not grant authority or a seat.
online_watch_invite :: proc(self:^DockyardDuo){
 o:=&self.state.online
 if !o.party.ready||o.party.profile.value.record.request.verb!=.Create||o.watch_ready||o.watch_failed{return}
 if !o.watch.ready{if rgd.provision_connect(&o.watch,o.party.config.service,o.party.config.tls,o.party.config.local_development)!=.None{o.watch_failed=true;return}}
 if !o.watch.client.pending&&!o.watch.client.complete{
  request,valid:=p.creator_short_invite(o.party.profile.value.record,index=1,local_development=o.party.config.local_development)
  if !valid{request,valid=p.creator_invite(o.party.profile.value.record,.Player,1,index=1,local_development=o.party.config.local_development)}
  if !valid||rgd.provision_request(&o.watch,request)!=.None{o.watch_failed=true;rgd.provision_disconnect(&o.watch);return}
 }
 if error:=rgd.provision_frame(&o.watch);error!=.None{o.watch_failed=true;rgd.provision_disconnect(&o.watch);return}
 if o.watch.client.complete{
  reply:=o.watch.client.reply
  valid:=false
  if reply.result==.None{
   code,ok:=p.short_code(o.party.profile.value.record.request.claim,o.content)
   expected,parsed:=p.short_ticket_parse(string(code[:]),o.content,1)
   if ok&&parsed&&expected==reply.ticket{o.watch_code_count=copy(o.watch_code[:],code[:]);valid=true}
   else{o.watch_code,valid=p.ticket_code(reply.ticket);o.watch_code_count=p.INVITE_CODE_BYTES}
  }
  o.watch_ready=valid;o.watch_failed=!valid;rgd.provision_disconnect(&o.watch)
 }
}
@(gd_method="owned_return")
dockyard_duo_online_status :: proc(self:^DockyardDuo)->gd.String{
 temp:=runtime.default_temp_allocator_temp_begin();defer runtime.default_temp_allocator_temp_end(temp)
 if self.state==nil{return json_string(struct{enabled:bool}{false})}
 o:=&self.state.online;message:=string(o.message[:o.message_count])
 if message==""{message=rgd.party_message(&o.party)}
 if message==""&&o.opened&&!self.go{message="Waiting for your crewmate…"}
 invite:="";if o.party.invited{invite=string(o.party.code[:o.party.code_count])}
 watch_invite:="";if o.watch_ready{watch_invite=string(o.watch_code[:o.watch_code_count])}
 room:=&self.state.room
 return json_string(struct{enabled,configured,busy,can_start,recent,connected,go,ended:bool,name,message,invite,cohort,room_phase,control_error:string,
  registered,rpc_ready,rpc_pending:bool,rpc_verb,rpc_result,lease_epoch,request_schema,reply_schema:string,rpc_stats:auth.Rpc_Stats,watch_invite:string}{
  o.enabled,o.configured,o.party.active,self.visuals_prepared&&o.configured&&o.party.recent_loaded&&!o.party.active&&!o.opened&&!o.ended,o.party.recent_room!=0,
  o.opened,self.go,o.ended,o.name,message,invite,fmt.tprintf("%016x",o.content),fmt.tprintf("%v",room.phase),fmt.tprintf("%v",room.control_error),
  room.registered,room.rpc.ready,room.rpc.pending,fmt.tprintf("%v",room.rpc.request.command.verb),fmt.tprintf("%v",room.rpc.reply.result),fmt.tprintf("%016x",room.lease.view.epoch),fmt.tprintf("%016x",room.rpc.codecs.request.fingerprint),fmt.tprintf("%016x",room.rpc.codecs.reply.fingerprint),room.rpc.stats,watch_invite})
}
online_close :: proc(self:^DockyardDuo)->bool{
 o:=&self.state.online;context.allocator=meter.allocator(self.scope)
 rgd.provision_disconnect(&o.watch);rgd.party_close(&o.party);online_native_close(self)
 if o.tls!=nil{gd.release_ref(o.tls);o.tls=nil}
 delete(o.name);o.name=""
 if ph.owner_context_destroy(&o.relay_owner)!=.None{return false}
 if ph.owner_context_destroy(&o.room_owner)!=.None{return false}
 return true
}
