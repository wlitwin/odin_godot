package replay_godot

import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

@(private)
rtc_signal_poll :: proc(r:^Rtc) {
 if r.error!=.None {return}
 gd.web_socket_peer_poll(r.ws)
 state:=gd.web_socket_peer_get_ready_state(r.ws);now:=rtc_clock(nil)
 if r.initial_deadline!=0 && !r.registered && !r.reconnecting && now>=r.initial_deadline {r.error=.Signaling;return}
 if state==.State_Closed {
  if r.initial_retry {
   if now>=r.retry_at {r.initial_retry=false;rtc_signal_connect(r)}
   return
  }
  if !r.signaling_lost {r.retry_at=now+500}
  r.signaling_lost=true
  if !r.config.resume_signaling || r.config.authorize==nil || len(r.resume_token)==0 {return}
  if now<r.retry_at {return}
  r.reconnecting=true;r.preserve_channels=true
  for &peer in r.slots {if peer.conn!=nil && !rtc_peer_connected(&peer) {r.preserve_channels=false;break}}
  if !r.preserve_channels {for &peer in r.slots {rtc_peer_close(&peer)}}
  r.retry_at=now+500
  rtc_signal_connect(r)
  return
 }
 if state!=.State_Open {
  if now-r.started>15000 {
   if r.reconnecting {gd.web_socket_peer_close(r.ws,1000,gd.string_empty());r.retry_at=now+500} else {r.error=.Signaling}
  };return
 }
 if !r.announced {
  d:=gd.new_dictionary_default();defer gd.free_dictionary(d)
  rtc_set_string(&d,"type",r.config.host ? "create" : "join")
  if len(r.config.room)>0 {rtc_set_string(&d,"room",r.config.room)}
  rtc_resume_fields(r,&d)
  if !rtc_signal_send(r,&d) {r.error=.Signaling;return}
  r.announced=true
 }
 for _ in 0..<64 {
  if gd.packet_peer_get_available_packet_count(r.ws)==0 {break}
  packet:=gd.packet_peer_get_packet(r.ws);defer gd.free_packed_byte_array(packet)
  bytes:=gd.packed_byte_array_view(&packet)
  if len(bytes)>32768 || !rtc_json_depth(bytes) {r.error=.Protocol;break}
  s:=gd.new_string_odin(string(bytes));defer gd.free_string(s)
  v:=gd.json_parse_string(s);defer gd.variant_destroy(&v)
  if gdext.variant_get_type(&v)!=.Dictionary {r.error=.Protocol;break}
  d:=gd.variant_to_dictionary(&v);defer gd.free_dictionary(d)
  rtc_signal_message(r,&d)
  if r.error!=.None {break}
 }
 if !r.registered && rtc_clock(nil)-r.started>15000 {r.error=.Signaling}
}
@(private)
rtc_signal_message :: proc(r:^Rtc,d:^gd.Dictionary) {
 typ:=rtc_get_string(d,"type",32);defer delete(typ)
 switch typ {
 case "auth_challenge":
  if !r.announced || r.registered || r.challenged || r.config.authorize==nil {r.error=.Authentication;return}
  challenge:=rtc_get_string(d,"challenge",256);defer delete(challenge)
  if len(challenge)==0 {r.error=.Authentication;return}
  r.challenged=true
  proof:=r.config.authorize(r.config.authorization_user,challenge,r.config.room,r.config.host)
  if len(proof)==0 || len(proof)>1024 {r.error=.Authentication;return}
  request:=gd.new_dictionary_default();defer gd.free_dictionary(request)
  rtc_set_string(&request,"type",r.config.host ? "create" : "join")
  rtc_set_string(&request,"room",r.config.room);rtc_set_string(&request,"auth",proof)
  rtc_resume_fields(r,&request)
  if !rtc_signal_send(r,&request) {r.error=.Signaling}
 case "created","joined":
  id:=rtc_get_int(d,"id");room:=rtc_get_string(d,"room",64);defer delete(room)
  if r.registered || (typ=="created")!=r.config.host || id<1 || id>i64(max(i32)) ||
     (r.config.host && id!=1) || (!r.config.host && id==1) || len(room)==0 {r.error=.Protocol;return}
  if r.config.authorize!=nil && (!r.challenged || room!=r.config.room) {r.error=.Authentication;return}
  resume:=rtc_get_string(d,"resume",32);defer delete(resume)
  if r.reconnecting && (tr.Peer_Id(id)!=r.id || resume!=r.resume_token) {r.error=.Authentication;return}
  if r.config.resume_signaling && len(resume)!=32 {r.error=.Authentication;return}
  if r.reconnecting {r.signaling_resumes+=1}
  r.reconnecting,r.signaling_lost=false,false
  delete(r.room,r.allocator);delete(r.resume_token,r.allocator)
  r.resume_token=strings.clone(resume,r.allocator)
  r.id=tr.Peer_Id(id);r.room=strings.clone(room,r.allocator);r.registered=true
 case "peer":
  id:=rtc_get_int(d,"id")
  if !r.registered || id<1 || id>i64(max(i32)) || tr.Peer_Id(id)==r.id {r.error=.Protocol;return}
  replace:=rtc_get_string(d,"replace",8);defer delete(replace)
  if replace=="yes" {existing:=rtc_find(r,tr.Peer_Id(id));if existing!=nil {rtc_peer_close(existing)}}
  member_text:=rtc_get_string(d,"member",16);defer delete(member_text)
  incarnation_text:=rtc_get_string(d,"incarnation",16);defer delete(incarnation_text)
  member,member_ok:=rtc_identity_value(member_text);incarnation,incarnation_ok:=rtc_identity_value(incarnation_text)
  if r.config.require_identity && (!member_ok || !incarnation_ok) {r.error=.Authentication;return}
  if !rtc_peer_open(r,tr.Peer_Id(id)) {r.error=.Handshake;return}
  peer:=rtc_find(r,tr.Peer_Id(id))
  if member_ok && incarnation_ok {
   if peer.identity.member!=0 && (peer.identity.member!=member || peer.identity.incarnation!=incarnation) {r.error=.Authentication;return}
   peer.identity={member,incarnation}
  }
 case "peer_left":
  peer:=rtc_find(r,tr.Peer_Id(rtc_get_int(d,"id")))
  // A signaling disconnect must not tear down healthy direct channels.
  if peer!=nil && !rtc_peer_connected(peer) {rtc_peer_close(peer)}
 case "signal":
  peer:=rtc_find(r,tr.Peer_Id(rtc_get_int(d,"from")));if peer==nil {return}
  v:=rtc_get(d,"data");defer gd.variant_destroy(&v)
  if gdext.variant_get_type(&v)!=.Dictionary {peer.failed=true;return}
  data:=gd.variant_to_dictionary(&v);defer gd.free_dictionary(data)
  rtc_apply_signal(peer,&data)
 case "error":
  reason:=rtc_get_string(d,"reason",32);defer delete(reason)
  if r.reconnecting && (reason=="duplicate" || reason=="no_room") {
   gd.web_socket_peer_close(r.ws,1000,gd.string_empty());r.retry_at=rtc_clock(nil)+500
  } else if r.config.wait_for_host && !r.config.host && !r.registered && !r.reconnecting && reason=="no_room" && rtc_clock(nil)<r.initial_deadline {
   r.initial_retry=true;gd.web_socket_peer_close(r.ws,1000,gd.string_empty());r.retry_at=rtc_clock(nil)+500
  } else {r.error=r.config.authorize!=nil ? .Authentication : .Signaling}
 case:r.error=.Protocol
 }
}
@(private)
rtc_peer_open :: proc(r:^Rtc,id:tr.Peer_Id)->bool {
 if rtc_find(r,id)!=nil {return true}
 if r.connection_serial==max(u64) {r.error=.Capacity;return false}
 peer:^Rtc_Peer
 for &slot in r.slots {if slot.conn==nil {peer=&slot;break}}
 if peer==nil {r.error=.Capacity;return false}
 conn:=gd.new_web_rtc_peer_connection();if conn==nil {return false};gd.ref_counted_init_ref(conn)
 r.connection_serial+=1
 peer^={id=id,serial=r.connection_serial,owner=r,conn=conn,started=rtc_clock(nil),ice=make([dynamic]Rtc_Ice,0,8,r.allocator)}
 ok:=false;defer {if !ok {rtc_peer_close(peer)}}
 ice_json:=r.config.ice_json
 if r.config.ice_source!=nil {valid:bool;ice_json,valid=r.config.ice_source(r.config.ice_user);if !valid {return false}}
 if rtc_ice_validate(ice_json)!=.None {return false}
 js:=gd.new_string_odin(ice_json);defer gd.free_string(js)
 v:=gd.json_parse_string(js);defer gd.variant_destroy(&v)
 if gdext.variant_get_type(&v)!=.Dictionary {return false}
 cfg:=gd.variant_to_dictionary(&v);defer gd.free_dictionary(cfg)
 if gd.web_rtc_peer_connection_initialize(conn,cfg)!=.Ok {return false}
 names:=[2]cstring{"session_description_created","ice_candidate_created"}
 procs:=[2]gdext.ExtensionCallableCustomCall{rtc_description_created,rtc_ice_created}
 for i in 0..<2 {
  cb:=new(Rtc_Callback,r.allocator);cb^={true,peer,r.allocator};peer.callbacks[i]=cb
  info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,callable_userdata=cb,call_func=procs[i],free_func=rtc_callback_free}
  gdext.callable_custom_create2(&peer.calls[i],&info)
  if gd.object_connect(cast(gd.Object)conn,gd.new_string_name_cstring(names[i],true),peer.calls[i],0)!=.Ok {return false}
  peer.watching[i]=true
 }
 for i in 0..<len(peer.channels) {
  if i==2 && r.config.legacy_control {continue}
  options:=gd.new_dictionary_default();defer gd.free_dictionary(options)
  rtc_set_bool(&options,"negotiated",true);rtc_set_int(&options,"id",i64(i));rtc_set_bool(&options,"ordered",i==0)
  if i==1 {rtc_set_int(&options,"maxRetransmits",0)}
  label:=gd.new_string_odin(i==0 ? "replay-reliable-v1" : i==1 ? "replay-unreliable-v1" : "replay-control-v1");defer gd.free_string(label)
  peer.channels[i]=gd.web_rtc_peer_connection_create_data_channel(conn,label,options)
  if peer.channels[i]==nil {return false}
  gd.web_rtc_data_channel_set_write_mode(peer.channels[i],.Write_Mode_Binary)
 }
 if r.id<id && gd.web_rtc_peer_connection_create_offer(conn)!=.Ok {return false}
 ok=true;return true
}
@(private)
rtc_apply_signal :: proc(peer:^Rtc_Peer,data:^gd.Dictionary) {
 kind:=rtc_get_string(data,"kind",16);defer delete(kind)
 switch kind {
 case "sdp":
  typ:=rtc_get_string(data,"sdp_type",16);defer delete(typ)
  sdp:=rtc_get_string(data,"sdp",24576);defer delete(sdp)
  expected:=peer.owner.id<peer.id ? "answer" : "offer"
  if peer.remote_set || typ!=expected || len(sdp)==0 {peer.failed=true;return}
  peer.control_separate=!peer.owner.config.legacy_control && rtc_get_int(data,"control_stream")==1
  t:=gd.new_string_odin(typ);defer gd.free_string(t)
  s:=gd.new_string_odin(sdp);defer gd.free_string(s)
  if gd.web_rtc_peer_connection_set_remote_description(peer.conn,t,s)!=.Ok {peer.failed=true;return}
  peer.remote_set=true
 case "ice":
  media:=rtc_get_string(data,"media",256);defer delete(media)
  name:=rtc_get_string(data,"name",4096);defer delete(name)
  index:=rtc_get_int(data,"index")
  if len(name)==0 || index<0 || index>65535 || len(peer.ice)>=64 {peer.failed=true;return}
  append(&peer.ice,Rtc_Ice{strings.clone(media,peer.owner.allocator),strings.clone(name,peer.owner.allocator),index})
  if peer.remote_ready {rtc_flush_ice(peer)}
 case:peer.failed=true
 }
}
@(private)
rtc_flush_ice :: proc(peer:^Rtc_Peer) {
 for ice in peer.ice {
  media:=gd.new_string_odin(ice.media);name:=gd.new_string_odin(ice.name)
  if gd.web_rtc_peer_connection_add_ice_candidate(peer.conn,media,gd.Int(ice.index),name)!=.Ok {peer.failed=true}
  gd.free_string(media);gd.free_string(name)
  delete(ice.media,peer.owner.allocator);delete(ice.name,peer.owner.allocator)
 }
 clear(&peer.ice)
}
@(private)
rtc_callback_free :: proc "c"(user:rawptr) {
 context=gdext.godot_context();cb:=cast(^Rtc_Callback)user;free(cb,cb.allocator)
}
@(private)
rtc_description_created :: proc "c"(user:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
 cb:=cast(^Rtc_Callback)user;if !cb.active || argc!=2 {return};peer:=cb.peer
 typ,sdp:gd.String
 convert:=gdext.get_variant_to_type_constructor(.String);convert(&typ,args[0]);convert(&sdp,args[1])
 defer gd.free_string(typ);defer gd.free_string(sdp)
 if gd.web_rtc_peer_connection_set_local_description(peer.conn,typ,sdp)!=.Ok {peer.failed=true;return}
 if peer.owner.id>peer.id {peer.remote_ready=true} else {peer.local_offer=true}
 d:=gd.new_dictionary_default();defer gd.free_dictionary(d)
 rtc_set_string(&d,"kind","sdp");rtc_set(&d,"sdp_type",gd.variant_from_string(&typ));rtc_set(&d,"sdp",gd.variant_from_string(&sdp))
 if !peer.owner.config.legacy_control {rtc_set_int(&d,"control_stream",1)}
 if !rtc_relay(peer,&d) {peer.failed=true}
}
@(private)
rtc_ice_created :: proc "c"(user:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
 cb:=cast(^Rtc_Callback)user;if !cb.active || argc!=3 {return};peer:=cb.peer
 media,name:gd.String;index:i64
 convert:=gdext.get_variant_to_type_constructor(.String);convert(&media,args[0]);convert(&name,args[2])
 convert_int:=gdext.get_variant_to_type_constructor(.Int);convert_int(&index,args[1])
 defer gd.free_string(media);defer gd.free_string(name)
 d:=gd.new_dictionary_default();defer gd.free_dictionary(d)
 rtc_set_string(&d,"kind","ice");rtc_set(&d,"media",gd.variant_from_string(&media));rtc_set(&d,"name",gd.variant_from_string(&name));rtc_set_int(&d,"index",index)
 if !rtc_relay(peer,&d) {peer.failed=true}
}
@(private)
rtc_relay :: proc(peer:^Rtc_Peer,data:^gd.Dictionary)->bool {
 d:=gd.new_dictionary_default();defer gd.free_dictionary(d)
 rtc_set_string(&d,"type","signal");rtc_set_int(&d,"to",i64(peer.id));rtc_set(&d,"data",gd.variant_from_dictionary(data))
 return rtc_signal_send(peer.owner,&d)
}
@(private)
rtc_signal_send :: proc(r:^Rtc,d:^gd.Dictionary)->bool {
 if gd.web_socket_peer_get_ready_state(r.ws)!=.State_Open || gd.web_socket_peer_get_current_outbound_buffered_amount(r.ws)>96*1024 {return false}
 v:=gd.variant_from_dictionary(d);defer gd.variant_destroy(&v)
 s:=gd.json_stringify(v,gd.string_empty(),false,false);defer gd.free_string(s)
 return gd.web_socket_peer_send_text(r.ws,s)==.Ok
}
@(private)
rtc_get :: proc(d:^gd.Dictionary,key:cstring)->gd.Variant {
 s:=gd.new_string_cstring(key);defer gd.free_string(s);k:=gd.variant_from_string(&s);defer gd.variant_destroy(&k)
 nil_value:gd.Variant;return gd.dictionary_get(d,k,nil_value)
}
@(private)
rtc_get_string :: proc(d:^gd.Dictionary,key:cstring,limit:int)->string {
 v:=rtc_get(d,key);defer gd.variant_destroy(&v);if gdext.variant_get_type(&v)!=.String {return ""}
 s:=gd.variant_to_string(&v);defer gd.free_string(s)
 size:=gdext.string_to_utf8_chars(&s,nil,0);if size<0 || size>i64(limit) {return ""}
 bytes:=make([]u8,int(size));if size>0 {gdext.string_to_utf8_chars(&s,cstring(raw_data(bytes)),size)}
 return string(bytes)
}
@(private)
rtc_get_int :: proc(d:^gd.Dictionary,key:cstring)->i64 {
 v:=rtc_get(d,key);defer gd.variant_destroy(&v)
 typ:=gdext.variant_get_type(&v);if typ!=.Int && typ!=.Float {return -1}
 if typ==.Float {f:=gd.variant_to_float(&v);if f<0 || f>f64(max(i32)) || f!=f64(i64(f)) {return -1};return i64(f)}
 return gd.variant_to_int(&v)
}
@(private)
rtc_set :: proc(d:^gd.Dictionary,key:cstring,value:gd.Variant) {
 value:=value;defer gd.variant_destroy(&value)
 s:=gd.new_string_cstring(key);defer gd.free_string(s);k:=gd.variant_from_string(&s);defer gd.variant_destroy(&k)
 gd.dictionary_set(d,k,value)
}
@(private)
rtc_set_string :: proc(d:^gd.Dictionary,key:cstring,value:string) {s:=gd.new_string_odin(value);defer gd.free_string(s);rtc_set(d,key,gd.variant_from_string(&s))}
@(private)
rtc_set_int :: proc(d:^gd.Dictionary,key:cstring,value:i64) {v:=value;rtc_set(d,key,gd.variant_from_int(&v))}
@(private)
rtc_set_bool :: proc(d:^gd.Dictionary,key:cstring,value:bool) {v:=value;rtc_set(d,key,gd.variant_from_bool(&v))}
// Limit parser recursion before handing untrusted signaling JSON to the engine.
@(private)
rtc_json_depth :: proc(bytes:[]u8)->bool {
 depth:=0;quoted,escape:bool
 for b in bytes {
  if quoted {if escape {escape=false} else if b=='\\' {escape=true} else if b=='"' {quoted=false};continue}
  if b=='"' {quoted=true} else if b=='{' || b=='[' {depth+=1;if depth>16 {return false}} else if b=='}' || b==']' {depth-=1;if depth<0 {return false}}
 }
 return depth==0 && !quoted
}


@(private)
rtc_resume_fields :: proc(r:^Rtc,d:^gd.Dictionary) {
 if r.reconnecting {
  rtc_set_string(d,"resume",r.resume_token)
  rtc_set_string(d,"preserve",r.preserve_channels ? "yes" : "no")
 }
}

@(private)
rtc_identity_hex :: proc(value:u64)->string {
 bytes:[8]u8;for &byte,i in bytes {byte=u8(value>>uint(i*8))};return rtc_hex(bytes[:])
}
@(private)
rtc_identity_value :: proc(text:string)->(u64,bool) {
 bytes:[8]u8;if !rtc_unhex(bytes[:],text) {return 0,false}
 value:u64;for byte,i in bytes {value|=u64(byte)<<uint(i*8)};return value,value!=0
}
