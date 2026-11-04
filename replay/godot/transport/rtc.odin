package replay_godot_transport

import wiregd "godot:replay/godot/internal/wire"

import "core:mem"
import "core:strings"
import auth "godot:replay/authority"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"
import r "godot:replay"
import bg "godot:box3d/godot"
import rt "godot:runtime"

// Raw WebRTC data channels. Owns all Godot objects; never installs MultiplayerAPI.
// Keep Rtc at a stable address from rtc_open until rtc_close. The signaling relay
// introduces peers; lower numeric ID makes the offer (star or mesh relay).
Rtc_Error :: enum {None, Unsupported, Configuration, Signaling, Protocol, Capacity, Handshake, Authentication}
// In-memory continuation for this registered RTC instance only. It is not a
// membership credential or durable checkpoint and never bypasses fresh proof.
Rtc_Continuation :: struct {peer: tr.Peer_Id, room: [64]u8, token: [16]u8, host: bool}
Rtc_Config :: struct {
 url, room: string,
 host: bool,
 // Explicit deployment configuration, including STUN/TURN when required.
 ice_json: string,
 ice_user: rawptr,
 ice_source: proc(user: rawptr) -> (json: string, valid: bool),
 native_extension: bool,
 // Retain ordered-channel credit delivery when interoperating with a relay
 // that strips optional SDP metadata. Normal peers negotiate a separate stream.
 legacy_control: bool,
 resume_signaling: bool,
 require_identity: bool,
 // A newly provisioned guest can finish enrollment before the creator opens
 // signaling. Retry only an explicit no_room response, bounded to 15 seconds.
 wait_for_host: bool,
 authorization_user: rawptr,
 authorize: proc(user:rawptr,challenge,room:string,create:bool)->string,
 continuation: Rtc_Continuation,
}
Rtc :: struct {
 ownership:Rtc_Ownership,
 retained:r.Owner_Retains,
 cleanup:bool,
 callback_depth:u32,
 ready, registered, announced, ever_connected, challenged: bool,
 failed_peers,connection_serial: u64,
 allocator: mem.Allocator,
 ws: gd.Web_Socket_Peer,
 config: Rtc_Config,
 id: tr.Peer_Id,
 room: string,
 error: Rtc_Error,
 signaling_lost, reconnecting, preserve_channels: bool,
 resume_token: string,
 retry_at, signaling_resumes: u64,
 initial_retry: bool,
 initial_deadline: u64,
 started: u64,
 slots: [16]Rtc_Peer,
 fragments: tr.Fragments,
 cursor: int,
 pending: tr.Received,
 buffer: [1184]u8,
}
@(private)
Rtc_Peer :: struct {
 id: tr.Peer_Id,
 identity: auth.Identity,
 serial:u64,
 owner: ^Rtc,
 conn: gd.Web_Rtc_Peer_Connection,
 channels: [3]gd.Web_Rtc_Data_Channel,
 calls: [2]gd.Callable,
 managed:[2]rt.Managed_Callable,
 callbacks: [2]^Rtc_Callback,
 watching: [2]bool,
 local_offer, remote_set, remote_ready, failed: bool,
 control_separate: bool,
 started: u64,
 tx,acked,received,ack_sent: [2]u64,
 last_ack,last_probe: [2]u64,
 ice: [dynamic]Rtc_Ice,
}
@(private)
Rtc_Ice :: struct {media, name: string, index: i64}
@(private)
Rtc_Callback :: struct {active:bool,peer:^Rtc_Peer,allocator:mem.Allocator}

rtc_open :: proc(r:^Rtc,cfg:Rtc_Config,allocator:=context.allocator)->bool {
 if r.ready||r.cleanup {return false}
 if (cfg.resume_signaling || cfg.require_identity) && cfg.authorize==nil {r.error=.Configuration;return false}
 if !rtc_continuation_valid(cfg.continuation,cfg) {r.error=.Configuration;return false}
 when ODIN_ARCH!=.wasm32 && ODIN_ARCH!=.wasm64p32 {
  if !cfg.native_extension {r.error=.Unsupported;return false}
 }
 if len(cfg.url)==0 || len(cfg.url)>2048 || (!strings.has_prefix(cfg.url,"ws://") && !strings.has_prefix(cfg.url,"wss://")) ||
    len(cfg.room)>64 || (!cfg.host && len(cfg.room)==0) || rtc_ice_validate(cfg.ice_json)!=.None {r.error=.Configuration;return false}
 when ODIN_ARCH==.wasm32 || ODIN_ARCH==.wasm64p32 {
  setting:=gd.new_string_odin("network/limits/webrtc/max_channel_in_buffer_kb");defer gd.free_string(setting)
  fallback:=i64(64);value:=gd.variant_from_int(&fallback);defer gd.variant_destroy(&value)
  capacity:=gd.project_settings_get_setting(gd.singleton_project_settings(),setting,value);defer gd.variant_destroy(&capacity)
  if gd.variant_to_int(&capacity)<64 {r.error=.Configuration;return false}
 }
 if !rtc_ownership_open(r,cfg,allocator){r.error=.Configuration;return false}
 r.allocator=allocator;r.config=cfg
 r.config.url=strings.clone(cfg.url,allocator);r.config.room=strings.clone(cfg.room,allocator)
 r.config.ice_json=strings.clone(len(cfg.ice_json)==0 ? `{"iceServers":[]}` : cfg.ice_json,allocator)
 r.ready=true;r.error=.None;r.started=rtc_clock(nil)
 if cfg.wait_for_host {r.initial_deadline=r.started+15000}
 if cfg.continuation.peer!=0 {
  continuation:=cfg.continuation
  r.id=continuation.peer;r.resume_token=strings.clone(wiregd.hex_encode(continuation.token[:]),allocator)
  r.reconnecting=true;r.preserve_channels=false
 }
 if !rtc_signal_connect(r) {rtc_close(r);r.error=.Signaling;return false}
 fragment_cfg:=tr.DEFAULT_FRAGMENT_CONFIG;fragment_cfg.mtu=1184
 if !tr.fragments_init(&r.fragments,rtc_raw_transport(r),rtc_clock,cfg=fragment_cfg,allocator=allocator) {rtc_close(r);r.error=.Signaling;return false}
 assert(tr.fragments_limit_unreliable(&r.fragments,8))
 return true
}
rtc_transport :: proc(r:^Rtc)->tr.Transport {
 wire:=tr.fragments_transport(&r.fragments)
 // Closing the public interface releases the channels and signaling socket too.
 wire.user=r;wire.send=rtc_send;wire.receive=rtc_receive;wire.poll=rtc_poll;wire.status=rtc_status;wire.connected=rtc_connected;wire.generation=rtc_generation;wire.close=rtc_transport_close
 return wire
}
rtc_close :: proc(r:^Rtc) {_=rtc_try_close(r)}

@(private)
rtc_clock :: proc(user:rawptr)->u64 {return u64(gd.time_get_ticks_msec(gd.singleton_time()))}
@(private)
rtc_unref :: proc(object:gd.Ref_Counted) {if object!=nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
@(private)
rtc_raw_transport :: proc(r:^Rtc)->tr.Transport {return {user=r,send=rtc_raw_send,receive=rtc_raw_receive,poll=rtc_raw_poll,status=rtc_status,connected=rtc_connected,generation=rtc_generation}}
@(private)
rtc_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {r:=cast(^Rtc)user;t:=tr.fragments_transport(&r.fragments);return tr.send(&t,to,channel,bytes)}
@(private)
rtc_receive :: proc(user:rawptr,dst:[]u8)->tr.Received {r:=cast(^Rtc)user;t:=tr.fragments_transport(&r.fragments);return tr.receive(&t,dst)}
@(private)
rtc_poll :: proc(user:rawptr) {r:=cast(^Rtc)user;t:=tr.fragments_transport(&r.fragments);tr.poll(&t)}
@(private)
rtc_transport_close :: proc(user:rawptr) {rtc_close(cast(^Rtc)user)}
@(private)
rtc_status :: proc(user:rawptr)->tr.Status {
 r:=cast(^Rtc)user;if !r.ready || r.error!=.None {return .Disconnected}
 if r.registered && r.config.host {return .Connected}
 for &peer in r.slots {if rtc_peer_connected(&peer) {return .Connected}}
 if r.signaling_lost || r.ever_connected || r.failed_peers>0 {return .Disconnected}
 return .Connecting
}
@(private)
rtc_connected :: proc(user:rawptr,id:tr.Peer_Id)->bool {
 r:=cast(^Rtc)user;if !r.ready || r.error!=.None {return false}
 peer:=rtc_find(r,id);return peer!=nil && rtc_peer_connected(peer)
}
@(private)
rtc_find :: proc(r:^Rtc,id:tr.Peer_Id)->^Rtc_Peer {if id==0 {return nil};for &peer in r.slots {if peer.id==id {return &peer}};return nil}
@(private)
rtc_peer_connected :: proc(peer:^Rtc_Peer)->bool {
 if peer.conn==nil || peer.failed || gd.web_rtc_peer_connection_get_connection_state(peer.conn)!=.State_Connected {return false}
 for channel,i in peer.channels {if i==2 && !peer.control_separate {continue};if channel==nil || gd.web_rtc_data_channel_get_ready_state(channel)!=.State_Open {return false}}
 return true
}
@(private)
rtc_raw_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
 r:=cast(^Rtc)user;if !rtc_connected(r,to) {return .Disconnected}
 if channel>.Unreliable || len(bytes)==0 {return .Invalid};if len(bytes)>1184 {return .Too_Large}
 peer:=rtc_find(r,to)
 if peer.tx[channel]==max(u64) || peer.tx[channel]-peer.acked[channel]>=16 {return .Backpressure}
 next:=peer.tx[channel]+1
 if !rtc_packet_send(peer,channel,0,next,bytes) {return .Backpressure}
 if peer.tx[channel]==peer.acked[channel] {peer.last_ack[channel]=rtc_clock(nil)}
 peer.tx[channel]=next;return .Sent
}
@(private)
rtc_raw_receive :: proc(user:rawptr,dst:[]u8)->tr.Received {
 r:=cast(^Rtc)user;if !r.ready {return {state=.Disconnected}}
 if r.pending.state==.Received && (!rtc_connected(r,r.pending.from) || r.pending.generation!=rtc_generation(r,r.pending.from)) {r.pending={}}
 if r.pending.state!=.Received {
  for _ in 0..<128 {
   found:=false
   for n in 0..<len(r.slots)*3 {
    at:=(r.cursor+n)%(len(r.slots)*3);peer:=&r.slots[at/3];physical:=at%3
    if !rtc_peer_connected(peer) {continue}
    if physical==2 && !peer.control_separate {continue}
    dc:=peer.channels[physical];if gd.packet_peer_get_available_packet_count(dc)==0 {continue}
    packet:=gd.packet_peer_get_packet(dc);defer gd.free_packed_byte_array(packet)
    bytes:=gd.packed_byte_array_view(&packet);r.cursor=(at+1)%(len(r.slots)*3);found=true
    if len(bytes)<16 || len(bytes)>1200 || bytes[0]!='R' || bytes[1]!='P' || bytes[2]!='C' || bytes[3]!=1 || bytes[4]>1 || bytes[5]>2 || bytes[6]!=0 || bytes[7]!=0 {peer.failed=true;break}
    channel:=tr.Channel(bytes[4]);kind:=bytes[5];sequence:=u64(0)
    for b,i in bytes[8:16] {sequence|=u64(b)<<uint(i*8)}
    if sequence==0 {peer.failed=true;break}
    control_path:=physical==0 || (physical==2 && peer.control_separate)
    if kind==1 { // Cumulative acknowledgments may arrive out of order.
     if !control_path || len(bytes)!=16 || sequence>peer.tx[channel] {peer.failed=true;break}
     if sequence>peer.acked[channel] {peer.acked[channel]=sequence;peer.last_ack[channel]=rtc_clock(nil)}
    } else if kind==2 { // Reliable fence releases credit for lost unreliable data.
     if !control_path || channel!=.Unreliable || len(bytes)!=16 {peer.failed=true;break}
     peer.received[channel]=max(peer.received[channel],sequence)
    } else {
     if physical!=int(channel) || len(bytes)==16 || (channel==.Reliable && sequence!=peer.received[channel]+1) {peer.failed=true;break}
     peer.received[channel]=max(peer.received[channel],sequence)
     copy(r.buffer[:],bytes[16:]);r.pending={state=.Received,from=peer.id,generation=peer.serial,channel=channel,count=len(bytes)-16}
    }
    break
   }
   if !found || r.pending.state==.Received {break}
  }
 }
 if r.pending.state!=.Received {return {state=rtc_status(r)==.Disconnected ? .Disconnected : .Empty}}
 result:=r.pending;if len(dst)<result.count {result.state=.Buffer_Too_Small;return result}
 copy(dst,r.buffer[:result.count]);r.pending={};return result
}
@(private)
rtc_raw_poll :: proc(user:rawptr) {
 r:=cast(^Rtc)user;if !r.ready {return}
 rtc_signal_poll(r)
 for &peer in r.slots {
  if peer.conn==nil {continue}
  gd.web_rtc_peer_connection_poll(peer.conn)
  for channel in peer.channels {if channel!=nil {gd.web_rtc_data_channel_poll(channel)}}
  now:=rtc_clock(nil)
  if rtc_peer_connected(&peer) {
   r.ever_connected=true
   for channel in tr.Channel {
    if peer.received[channel]>peer.ack_sent[channel] && rtc_packet_send(&peer,channel,1,peer.received[channel],nil) {peer.ack_sent[channel]=peer.received[channel]}
    if peer.tx[channel]>peer.acked[channel] && now-peer.last_ack[channel]>15000 {peer.failed=true}
   }
   if peer.tx[tr.Channel.Unreliable]-peer.acked[tr.Channel.Unreliable]>=16 && now-peer.last_probe[tr.Channel.Unreliable]>=1000 {
    if rtc_packet_send(&peer,.Unreliable,2,peer.tx[tr.Channel.Unreliable],nil) {peer.last_probe[tr.Channel.Unreliable]=now}
   }
  }
  // Applying a remote answer is async. Stable after our local offer proves it
  // is installed; the answer callback proves a remote offer is installed.
  if peer.local_offer && peer.remote_set && gd.web_rtc_peer_connection_get_signaling_state(peer.conn)==.Signaling_State_Stable {peer.remote_ready=true}
  if peer.remote_ready {rtc_flush_ice(&peer)}
  state:=gd.web_rtc_peer_connection_get_connection_state(peer.conn)
  if peer.failed || state==.State_Failed || state==.State_Closed ||
     (state!=.State_Connected && rtc_clock(nil)-peer.started>45000) {
   if peer.failed || state==.State_Failed || state!=.State_Closed {r.failed_peers+=1}
   rtc_peer_close(&peer)
  }
 }
}
@(private)
rtc_peer_close :: proc(peer:^Rtc_Peer) {_=rtc_peer_try_close(peer)}
@(private)
rtc_peer_try_close :: proc(peer:^Rtc_Peer)->bg.Status {
 if peer.conn==nil{return bg.OK}
 managed:=rtc_managed(peer.owner)
 if managed{stats,status:=rt.managed_callable_stats();if status!=bg.OK{return status};if stats.inflight_calls!=0{return rt.MANAGED_CALLABLE_BUSY}}
 for cb in peer.callbacks {if cb!=nil {cb.active=false}}
 names:=[2]cstring{"session_description_created","ice_candidate_created"}
 for call,i in peer.calls {
  if peer.watching[i]{gd.object_disconnect(cast(gd.Object)peer.conn,gd.new_string_name_cstring(names[i],true),call);peer.watching[i]=false}
  if managed{status:=rt.managed_callable_close(&peer.managed[i]);if status!=bg.OK{return status}}
  else if peer.callbacks[i]!=nil{gd.free_callable(call);peer.callbacks[i]=nil}
 }
 for channel in peer.channels {if channel!=nil {gd.web_rtc_data_channel_close(channel);rtc_unref(channel)}}
 gd.web_rtc_peer_connection_close(peer.conn);rtc_unref(peer.conn)
 for ice in peer.ice {delete(ice.media,peer.owner.allocator);delete(ice.name,peer.owner.allocator)};delete(peer.ice)
 peer^={};return bg.OK
}

// At most 16 unacknowledged data packets per physical channel. Godot's JS
// receiver has its own finite ring; SCTP reliability alone does not protect it.
@(private)
rtc_packet_send :: proc(peer:^Rtc_Peer,channel:tr.Channel,kind:u8,sequence:u64,bytes:[]u8)->bool {
 physical:=kind==0 ? int(channel) : peer.control_separate ? 2 : 0
 dc:=peer.channels[physical]
 if int(gd.web_rtc_data_channel_get_buffered_amount(dc))+len(bytes)+16>32*1024 {return false}
 packet:=gd.new_packed_byte_array();defer gd.free_packed_byte_array(packet)
 if gd.packed_byte_array_resize(&packet,gd.Int(len(bytes)+16))!=0 {return false}
 dst:=gd.packed_byte_array_view(&packet)
 dst[0],dst[1],dst[2],dst[3]='R','P','C',1;dst[4],dst[5],dst[6],dst[7]=u8(channel),kind,0,0
 for &b,i in dst[8:16] {b=u8(sequence>>uint(i*8))};copy(dst[16:],bytes)
 return gd.packet_peer_put_packet(dc,packet)==.Ok
}

// Copy the currently connected physical IDs. Transport identities are not seats;
// the application still supplies its admitted roster or explicit Remap bindings.
rtc_peers :: proc(r:^Rtc,dst:[]tr.Peer_Id)->int {
 if !r.ready || r.error!=.None {return 0}
 count:=0
 for &peer in r.slots {
  if !rtc_peer_connected(&peer) {continue}
  if count==len(dst) {break};dst[count]=peer.id;count+=1
 }
 return count
}


// Close just the signaling socket. Authenticated adapters reconnect from poll;
// gameplay channels retain their packet/fragment state when healthy.
rtc_drop_signaling :: proc(r:^Rtc) {
 if !r.ready || r.ws==nil {return}
 gd.web_socket_peer_close(r.ws,1000,gd.string_empty())
}
@(private)
rtc_signal_connect :: proc(r:^Rtc)->bool {
 if r.ws!=nil {gd.web_socket_peer_close(r.ws,1000,gd.string_empty());rtc_unref(r.ws)}
 r.ws=gd.new_web_socket_peer();if r.ws==nil {return false};gd.ref_counted_init_ref(r.ws)
 gd.web_socket_peer_set_inbound_buffer_size(r.ws,128*1024);gd.web_socket_peer_set_outbound_buffer_size(r.ws,128*1024);gd.web_socket_peer_set_max_queued_packets(r.ws,128)
 url:=gd.new_string_odin(r.config.url);defer gd.free_string(url)
 r.started=rtc_clock(nil);r.announced,r.challenged,r.registered=false,false,false
 return gd.web_socket_peer_connect_to_url(r.ws,url,nil)==.Ok
}


// Local diagnostic generation, incremented only when a peer connection is built.
rtc_connection_serial :: proc(r:^Rtc,id:tr.Peer_Id)->u64 {
 peer:=rtc_find(r,id);return peer!=nil ? peer.serial : 0
}

rtc_continuation :: proc(r: ^Rtc) -> (Rtc_Continuation, bool) {
 if !r.ready || !r.registered || r.reconnecting || r.error!=.None || !r.config.resume_signaling || r.config.authorize==nil || len(r.room)!=64 {return {},false}
 result:=Rtc_Continuation{peer=r.id,host=r.config.host};copy(result.room[:],transmute([]u8)r.room)
 if !wiregd.hex_decode(result.token[:],r.resume_token) || !rtc_continuation_valid(result,r.config) {return {},false}
 return result,true
}
rtc_continuation_valid :: proc(value: Rtc_Continuation, cfg: Rtc_Config) -> bool {
 if value==(Rtc_Continuation{}) {return true}
 v:=value
 if !cfg.resume_signaling || cfg.authorize==nil || v.peer==0 || v.peer>tr.Peer_Id(max(i32)) || v.host!=cfg.host ||
    (v.host ? v.peer!=1 : v.peer==1) || len(cfg.room)!=64 || string(v.room[:])!=cfg.room || v.token==([16]u8{}) {return false}
 return true
}

// A verified provider introduction, available only for a connected peer on a
// challenged signaling connection. Physical IDs alone convey no member identity.
rtc_peer_identity :: proc(r:^Rtc,id:tr.Peer_Id)->(auth.Identity,bool) {
 if !r.ready || r.error!=.None || r.config.authorize==nil {return {},false}
 peer:=rtc_find(r,id)
 if peer==nil || !rtc_peer_connected(peer) || !auth.identity_valid(peer.identity) {return {},false}
 return peer.identity,true
}

@(private)
rtc_generation :: proc(user:rawptr,id:tr.Peer_Id)->u64 {
 r:=cast(^Rtc)user;if !r.ready {return 0}
 peer:=rtc_find(r,id);return peer!=nil ? peer.serial : 0
}
