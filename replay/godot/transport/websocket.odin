package replay_godot_transport

import "core:mem"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

// Raw WebSocket messages. The Transport view is reliable-only; service hosts may
// use websocket_receive/send_text to multiplex JSON signaling and binary RPCs.
// Owns its Godot references and never installs MultiplayerAPI.
Websocket_Config :: struct {peers,queued_packets,buffer_bytes:int,handshake_ms:u64}
DEFAULT_WEBSOCKET_CONFIG :: Websocket_Config{16,64,256*1024,10000}
Websocket :: struct {
 ready,server:bool,
 allocator:mem.Allocator,
 listener:gd.Tcp_Server,
 tls:gd.Tls_Options,
 peers:[]Websocket_Peer,
 config:Websocket_Config,
 next_id:tr.Peer_Id,
 cursor:int,
 pending:Websocket_Message,
 buffer:[]u8,
 rejected:u64,
}
Websocket_Message :: struct {using packet:tr.Received,text:bool}
@(private)
Websocket_Peer :: struct {id:tr.Peer_Id,peer:gd.Web_Socket_Peer,started:u64,tls:gd.Stream_Peer_Tls}

websocket_host :: proc(w:^Websocket,port:u16,bind_ip:string="127.0.0.1",cfg:=DEFAULT_WEBSOCKET_CONFIG,allocator:=context.allocator,tls:gd.Tls_Options=nil)->bool {
 when gd.IS_WEB {return false} else {
  if tls!=nil && !gd.tls_options_is_server(tls) {return false}
  if port==0 || !websocket_init(w,cfg,allocator) {return false}
  if tls!=nil {gd.ref_counted_reference(tls);w.tls=tls}
  w.server=true;w.next_id=1
  w.listener=gd.new_tcp_server();gd.ref_counted_init_ref(w.listener)
  ip:=gd.new_string_odin(bind_ip);defer gd.free_string(ip)
  if gd.tcp_server_listen(w.listener,gd.Int(port),ip)!=.Ok {websocket_close(w);return false}
  return true
 }
}
websocket_join :: proc(w:^Websocket,url:string,cfg:=DEFAULT_WEBSOCKET_CONFIG,allocator:=context.allocator,tls:gd.Tls_Options=nil)->bool {
 if tls!=nil && (gd.tls_options_is_server(tls) || gd.tls_options_is_unsafe_client(tls) || !strings.has_prefix(url,"wss://")) {return false}
 if len(url)==0 || len(url)>2048 || (!strings.has_prefix(url,"ws://") && !strings.has_prefix(url,"wss://")) || !websocket_init(w,cfg,allocator) {return false}
 peer:=websocket_new_peer(w)
 address:=gd.new_string_odin(url);defer gd.free_string(address)
 if gd.web_socket_peer_connect_to_url(peer,address,tls)!=.Ok {websocket_unref(peer);websocket_close(w);return false}
 w.peers[0]={id=1,peer=peer,started=websocket_now()};return true
}
websocket_transport :: proc(w:^Websocket)->tr.Transport {
 return {user=w,send=websocket_send,receive=websocket_binary_receive,poll=websocket_poll,status=websocket_status,connected=websocket_connected,close=websocket_transport_close}
}
websocket_close :: proc(w:^Websocket) {
 if !w.ready {return}
 for &slot in w.peers {websocket_drop(&slot)}
 if w.listener!=nil {gd.socket_server_stop(w.listener);websocket_unref(w.listener)}
 if w.tls!=nil {websocket_unref(w.tls)}
 delete(w.peers,w.allocator);delete(w.buffer,w.allocator);w^={}
}
websocket_send_text :: proc(w:^Websocket,to:tr.Peer_Id,text:string)->tr.Send_Result {
 if len(text)==0 || len(text)>tr.MAX_PACKET_BYTES {return .Invalid}
 peer:=websocket_find(w,to);if peer==nil {return .Disconnected}
 if int(gd.web_socket_peer_get_current_outbound_buffered_amount(peer))+len(text)>w.config.buffer_bytes {return .Backpressure}
 value:=gd.new_string_odin(text);defer gd.free_string(value)
 return gd.web_socket_peer_send_text(peer,value)==.Ok ? .Sent : .Backpressure
}
websocket_receive :: proc(w:^Websocket,dst:[]u8)->Websocket_Message {
 if !w.ready {return {packet={state=.Disconnected}}}
 if w.pending.state==.Received && !websocket_connected(w,w.pending.from) {w.pending={}}
 if w.pending.state!=.Received {
  for n in 0..<len(w.peers) {
   at:=(w.cursor+n)%len(w.peers);slot:=&w.peers[at]
   if slot.peer==nil || gd.web_socket_peer_get_ready_state(slot.peer)!=.State_Open || gd.packet_peer_get_available_packet_count(slot.peer)==0 {continue}
   packet:=gd.packet_peer_get_packet(slot.peer);defer gd.free_packed_byte_array(packet)
   bytes:=gd.packed_byte_array_view(&packet);w.cursor=(at+1)%len(w.peers)
   if len(bytes)>len(w.buffer) {w.rejected+=1;return {packet={state=.Too_Large,from=slot.id,count=len(bytes)}}}
   copy(w.buffer,bytes);w.pending={packet={state=.Received,from=slot.id,channel=.Reliable,count=len(bytes)},text=gd.web_socket_peer_was_string_packet(slot.peer)};break
  }
 }
 if w.pending.state!=.Received {return {packet={state=websocket_status(w)==.Disconnected ? .Disconnected : .Empty}}}
 result:=w.pending
 if len(dst)<result.count {result.state=.Buffer_Too_Small;return result}
 copy(dst,w.buffer[:result.count]);w.pending={};return result
}
websocket_peers :: proc(w:^Websocket,dst:[]tr.Peer_Id)->int {
 count:=0
 for slot in w.peers {if slot.peer!=nil && gd.web_socket_peer_get_ready_state(slot.peer)==.State_Open {if count==len(dst) {break};dst[count]=slot.id;count+=1}}
 return count
}
websocket_disconnect :: proc(w:^Websocket,id:tr.Peer_Id) {for &slot in w.peers {if slot.id==id {websocket_drop(&slot);return}}}

@(private)
websocket_init :: proc(w:^Websocket,cfg:Websocket_Config,allocator:mem.Allocator)->bool {
 if w.ready || cfg.peers<1 || cfg.peers>128 || cfg.queued_packets<1 || cfg.queued_packets>1024 || cfg.buffer_bytes<128*1024 || cfg.buffer_bytes>4*1024*1024 || cfg.handshake_ms<250 || cfg.handshake_ms>60000 {return false}
 w.allocator,w.config=allocator,cfg;w.peers=make([]Websocket_Peer,cfg.peers,allocator);w.buffer=make([]u8,tr.MAX_PACKET_BYTES,allocator);w.ready=true;return true
}
@(private)
websocket_new_peer :: proc(w:^Websocket)->gd.Web_Socket_Peer {
 peer:=gd.new_web_socket_peer();gd.ref_counted_init_ref(peer)
 gd.web_socket_peer_set_inbound_buffer_size(peer,gd.Int(w.config.buffer_bytes));gd.web_socket_peer_set_outbound_buffer_size(peer,gd.Int(w.config.buffer_bytes))
 gd.web_socket_peer_set_max_queued_packets(peer,gd.Int(w.config.queued_packets));return peer
}
@(private)
websocket_poll :: proc(user:rawptr) {
 w:=cast(^Websocket)user;if !w.ready {return};now:=websocket_now()
 for &slot in w.peers {
  if slot.tls!=nil && slot.peer==nil {
   gd.stream_peer_tls_poll(slot.tls)
   status:=gd.stream_peer_tls_get_status(slot.tls)
   if status==.Status_Connected {
    slot.peer=websocket_new_peer(w)
    if gd.web_socket_peer_accept_stream(slot.peer,slot.tls)!=.Ok {websocket_drop(&slot);continue}
   } else if status!=.Status_Handshaking || now-slot.started>w.config.handshake_ms {websocket_drop(&slot);continue}
  }
  if slot.peer==nil {continue}
  gd.web_socket_peer_poll(slot.peer)
  state:=gd.web_socket_peer_get_ready_state(slot.peer)
  if state==.State_Closed || (state!=.State_Open && now-slot.started>w.config.handshake_ms) {websocket_drop(&slot)}
 }
 when !gd.IS_WEB {
  if w.listener!=nil {
   for _ in 0..<8 {
    if !gd.socket_server_is_connection_available(w.listener) {break}
    stream:=gd.tcp_server_take_connection(w.listener);if stream==nil {break}
    defer websocket_unref(stream)
    free:=-1;for slot,i in w.peers {if slot.peer==nil && slot.tls==nil {free=i;break}}
    if free<0 || w.next_id==max(tr.Peer_Id) {gd.stream_peer_socket_disconnect_from_host(stream);w.rejected+=1;continue}
    if w.tls!=nil {
     secure:=gd.new_stream_peer_tls();gd.ref_counted_init_ref(secure)
     if gd.stream_peer_tls_accept_stream(secure,stream,w.tls)!=.Ok {websocket_unref(secure);continue}
     w.next_id+=1;w.peers[free]={id=w.next_id,started=now,tls=secure};continue
    }
    peer:=websocket_new_peer(w)
    if gd.web_socket_peer_accept_stream(peer,stream)!=.Ok {websocket_unref(peer);continue}
    w.next_id+=1;w.peers[free]={id=w.next_id,peer=peer,started=now}
   }
  }
 }
}
@(private)
websocket_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
 w:=cast(^Websocket)user;if channel!=.Reliable {return .Invalid}
 peer:=websocket_find(w,to);if peer==nil {return .Disconnected}
 if int(gd.web_socket_peer_get_current_outbound_buffered_amount(peer))+len(bytes)>w.config.buffer_bytes {return .Backpressure}
 packet:=gd.new_packed_byte_array();defer gd.free_packed_byte_array(packet)
 if gd.packed_byte_array_resize(&packet,gd.Int(len(bytes)))!=0 {return .Backpressure}
 copy(gd.packed_byte_array_view(&packet),bytes)
 return gd.packet_peer_put_packet(peer,packet)==.Ok ? .Sent : .Backpressure
}
@(private)
websocket_binary_receive :: proc(user:rawptr,dst:[]u8)->tr.Received {
 w:=cast(^Websocket)user
 for _ in 0..<64 {
  message:=websocket_receive(w,dst)
  if !message.text {return message.packet}
  if message.state==.Buffer_Too_Small {w.pending={}}
  w.rejected+=1
 }
 return {state=.Empty}
}
@(private)
websocket_status :: proc(user:rawptr)->tr.Status {
 w:=cast(^Websocket)user;if !w.ready {return .Disconnected}
 if w.server {return .Connected}
 peer:=w.peers[0].peer;if peer==nil {return .Disconnected}
 switch gd.web_socket_peer_get_ready_state(peer) {case .State_Open:return .Connected;case .State_Connecting:return .Connecting;case .State_Closing,.State_Closed:return .Disconnected}
 return .Disconnected
}
@(private)
websocket_find :: proc(w:^Websocket,id:tr.Peer_Id)->gd.Web_Socket_Peer {
 if !w.ready {return nil};for slot in w.peers {if slot.id==id && slot.peer!=nil && gd.web_socket_peer_get_ready_state(slot.peer)==.State_Open {return slot.peer}};return nil
}
@(private)
websocket_connected :: proc(user:rawptr,id:tr.Peer_Id)->bool {return websocket_find(cast(^Websocket)user,id)!=nil}
@(private)
websocket_transport_close :: proc(user:rawptr) {websocket_close(cast(^Websocket)user)}
@(private)
websocket_now :: proc()->u64 {return gd.time_get_ticks_msec(gd.singleton_time())}
@(private)
websocket_unref :: proc(object:gd.Ref_Counted) {if object!=nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
@(private)
websocket_drop :: proc(slot:^Websocket_Peer) {
 if slot.peer!=nil {gd.web_socket_peer_close(slot.peer,1000,gd.string_empty());websocket_unref(slot.peer)}
 if slot.tls!=nil {gd.stream_peer_tls_disconnect_from_stream(slot.tls);websocket_unref(slot.tls)}
 slot^={}
}
