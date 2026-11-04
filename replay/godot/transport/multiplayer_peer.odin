package replay_godot_transport

import "core:mem"
import r "godot:replay"
import bg "godot:box3d/godot"
import rt "godot:runtime"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

// Retains one independent MultiplayerPeer. No SceneMultiplayer is installed.
// Attach before connecting/polling so every connection signal is observed.
Multiplayer_Ownership :: struct {allocator,container:r.Owned_Context}
Multiplayer_Transport :: struct {
 ownership:Multiplayer_Ownership,
 retained:r.Owner_Retains,
 managed:[2]rt.Managed_Callable,
 cleanup:bool,
	allocator:mem.Allocator,
	peer:gd.Multiplayer_Peer,
	pending:tr.Received,
	buffer:[]u8,
	remotes:[dynamic]tr.Peer_Id,
	connections:[]Multiplayer_Connection,
	connection_serial:u64,
	capacity:int,
	connected_cb,disconnected_cb:Multiplayer_Callback,
	connected_call,disconnected_call:gd.Callable,
	watching_connected,watching_disconnected:bool,
	rejected_connections:u64,
	retired_packets:u64,
}
@(private)
Multiplayer_Connection :: struct {id:tr.Peer_Id,generation:u64,prior_packets:int}
@(private)
Multiplayer_Callback :: struct {owner:^Multiplayer_Transport,joined:bool}

multiplayer_attach :: proc(m:^Multiplayer_Transport,peer:gd.Multiplayer_Peer,capacity:int=16,allocator:=context.allocator)->bool {
	if m.peer!=nil || peer==nil || capacity<1 || capacity>4095 {return false}
	kind:=gd.new_string_name("MultiplayerPeer");valid:=gd.object_is_class(cast(gd.Object)peer,kind);gd.free_string_name(kind)
	if !valid {return false}
 managed:=!r.owner_is_nil(m.ownership.container.owner)
 if r.owner_contexts_check({owner=m.ownership.allocator.owner,owner_allocator_data=m.ownership.allocator.data},allocator)!=.None ||
    r.owned_context_access(m.ownership.container,m,managed,.Execute)!=.None{return false}
 if managed && r.owner_is_nil(m.ownership.allocator.owner){return false}
 owners:=[?]r.Owner{m.ownership.allocator.owner,m.ownership.container.owner}
 if r.owner_retains_acquire(&m.retained,owners[:])!=.None{return false}
	m.allocator,m.peer,m.capacity=allocator,peer,capacity;gd.ref_counted_reference(peer)
	m.buffer=make([]u8,tr.MAX_PACKET_BYTES,allocator);m.remotes=make([dynamic]tr.Peer_Id,0,capacity,allocator)
	m.connections=make([]Multiplayer_Connection,capacity,allocator)
	m.connected_cb,m.disconnected_cb=Multiplayer_Callback{m,true},Multiplayer_Callback{m,false}
 if managed {
  for index in 0..<2 {
   handle,status:=multiplayer_callable(m,index==0)
   if status!=bg.OK{multiplayer_try_close(m);return false}
   m.managed[index]=handle
  }
  m.connected_call=m.managed[0].value;m.disconnected_call=m.managed[1].value
 } else {
  info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=multiplayer_connection_changed,callable_userdata=&m.connected_cb}
  gdext.callable_custom_create2(&m.connected_call,&info);info.callable_userdata=&m.disconnected_cb;gdext.callable_custom_create2(&m.disconnected_call,&info)
 }
	connected:=gd.new_string_name("peer_connected");disconnected:=gd.new_string_name("peer_disconnected");defer gd.free_string_name(connected);defer gd.free_string_name(disconnected)
	m.watching_connected=gd.object_connect(cast(gd.Object)peer,connected,m.connected_call,0)==.Ok
	m.watching_disconnected=gd.object_connect(cast(gd.Object)peer,disconnected,m.disconnected_call,0)==.Ok
	if !m.watching_connected || !m.watching_disconnected {multiplayer_close(m);return false}
	return true
}
multiplayer_transport :: proc(m:^Multiplayer_Transport)->tr.Transport {
	return {user=m,send=multiplayer_send,receive=multiplayer_receive,poll=multiplayer_poll,status=multiplayer_status,close=multiplayer_close,connected=multiplayer_connected,generation=multiplayer_generation}
}
multiplayer_id :: proc(m:^Multiplayer_Transport)->tr.Peer_Id {return multiplayer_status(m)==.Connected ? tr.Peer_Id(gd.multiplayer_peer_get_unique_id(m.peer)) : 0}
@(private)
multiplayer_send :: proc(raw:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
	m:=cast(^Multiplayer_Transport)raw
	if to==0 || u64(to)>u64(max(i32)) || len(bytes)==0 || channel>.Unreliable {return .Invalid}
	if len(bytes)>tr.MAX_PACKET_BYTES {return .Too_Large}
	if multiplayer_status(m)!=.Connected || !multiplayer_connected(m,to) {return .Disconnected}
	packet:=gd.new_packed_byte_array();defer gd.free_packed_byte_array(packet)
	if gd.packed_byte_array_resize(&packet,gd.Int(len(bytes)))!=0 {return .Backpressure}
	copy(gd.packed_byte_array_view(&packet),bytes)
	gd.multiplayer_peer_set_target_peer(m.peer,gd.Int(to));gd.multiplayer_peer_set_transfer_channel(m.peer,0)
	gd.multiplayer_peer_set_transfer_mode(m.peer,channel==.Reliable ? .Transfer_Mode_Reliable : .Transfer_Mode_Unreliable)
	return gd.packet_peer_put_packet(m.peer,packet)==.Ok ? .Sent : .Backpressure
}
@(private)
multiplayer_receive :: proc(raw:rawptr,dst:[]u8)->tr.Received {
	m:=cast(^Multiplayer_Transport)raw
	if m.peer==nil || multiplayer_status(m)==.Disconnected {return {state=.Disconnected}}
	if m.pending.state==.Received && m.pending.generation!=multiplayer_generation(m,m.pending.from) {m.pending={};m.retired_packets+=1}
	for _ in 0..<64 {if m.pending.state==.Received {break}
		if gd.packet_peer_get_available_packet_count(m.peer)==0 {return {state=.Empty}}
		from:=gd.multiplayer_peer_get_packet_peer(m.peer);mode:=gd.multiplayer_peer_get_packet_mode(m.peer)
		generation:u64
		for connection in m.connections {if connection.id==tr.Peer_Id(from) && connection.prior_packets==0 {generation=connection.generation;break}}
		packet:=gd.packet_peer_get_packet(m.peer);defer gd.free_packed_byte_array(packet);bytes:=gd.packed_byte_array_view(&packet)
		for &connection in m.connections {if connection.prior_packets>0 {connection.prior_packets-=1}}
		if from<=0 || generation==0 || generation!=multiplayer_generation(m,tr.Peer_Id(from)) {m.retired_packets+=1;continue}
		if len(bytes)>len(m.buffer) {return {state=.Too_Large,count=len(bytes)}}
		copy(m.buffer,bytes);m.pending={state=.Received,from=tr.Peer_Id(from),count=len(bytes),generation=generation,channel=mode==.Transfer_Mode_Reliable ? .Reliable : .Unreliable}
	}
	if m.pending.state!=.Received {return {state=.Empty}}
	result:=m.pending
	if len(dst)<result.count {result.state=.Buffer_Too_Small;return result}
	copy(dst,m.buffer[:result.count]);m.pending={};return result
}
@(private)
multiplayer_status :: proc(raw:rawptr)->tr.Status {
	m:=cast(^Multiplayer_Transport)raw;if m.peer==nil {return .Disconnected}
	switch gd.multiplayer_peer_get_connection_status(m.peer) {case .Connection_Disconnected:return .Disconnected;case .Connection_Connecting:return .Connecting;case .Connection_Connected:return .Connected}
	return .Disconnected
}
@(private)
multiplayer_poll :: proc(raw:rawptr) {
	m:=cast(^Multiplayer_Transport)raw;if m.peer==nil {return}
	if multiplayer_status(m)!=.Disconnected {gd.multiplayer_peer_poll(m.peer)}
	if multiplayer_status(m)==.Disconnected {
		for &connection in m.connections {connection={}}
		clear(&m.remotes)
		if m.pending.state==.Received {m.pending={};m.retired_packets+=1}
	}
}
@(private)
multiplayer_connected :: proc(raw:rawptr,peer:tr.Peer_Id)->bool {m:=cast(^Multiplayer_Transport)raw;if multiplayer_status(m)!=.Connected {return false};for id in m.remotes {if id==peer {return true}};return false}
@(private)
multiplayer_generation :: proc(raw:rawptr,id:tr.Peer_Id)->u64 {
	m:=cast(^Multiplayer_Transport)raw
	if multiplayer_status(m)!=.Connected {return 0}
	for connection in m.connections {if connection.id==id {return connection.generation}}
	return 0
}
// Legacy Transport.close remains borrowed/void. Managed Session composition
// calls try_close directly and propagates Busy before releasing parent children.
multiplayer_close :: proc(raw:rawptr){multiplayer_try_close(cast(^Multiplayer_Transport)raw)}
multiplayer_try_close :: proc(m:^Multiplayer_Transport)->bg.Status {
 if m==nil{return bg.INVALID_ARGUMENT}
 if r.owner_retains_access(&m.retained)!=.None{return bg.INCOMPATIBLE}
 if m.cleanup {
  retained:=m.retained;m^={}
  if r.owner_retains_drop(&retained)!=.None{m.retained=retained;m.cleanup=true;return bg.INCOMPATIBLE}
  return bg.OK
 }
 managed:=!r.owner_is_nil(m.ownership.container.owner)
 if managed {
  stats,status:=rt.managed_callable_stats();if status!=bg.OK{return status}
  if stats.inflight_calls!=0{return rt.MANAGED_CALLABLE_BUSY}
 }
 if m.peer!=nil {
  connected:=gd.new_string_name("peer_connected");disconnected:=gd.new_string_name("peer_disconnected");defer gd.free_string_name(connected);defer gd.free_string_name(disconnected)
  if m.watching_connected{gd.object_disconnect(cast(gd.Object)m.peer,connected,m.connected_call);m.watching_connected=false}
  if m.watching_disconnected{gd.object_disconnect(cast(gd.Object)m.peer,disconnected,m.disconnected_call);m.watching_disconnected=false}
  if managed {
   for &handle in m.managed{status:=rt.managed_callable_close(&handle);if status!=bg.OK{return status}}
  } else {gd.free_callable(m.connected_call);gd.free_callable(m.disconnected_call)}
  gd.multiplayer_peer_close(m.peer);gd.release_ref(m.peer);m.peer=nil
 }
 delete(m.buffer,m.allocator);delete(m.connections,m.allocator);delete(m.remotes)
 retained:=m.retained;m^={}
 if r.owner_retains_drop(&retained)!=.None{m.retained=retained;m.cleanup=true;return bg.INCOMPATIBLE}
 return bg.OK
}
// Declare retained exact aliases before an existing ENet constructor attaches.
multiplayer_prepare :: proc(m:^Multiplayer_Transport,ownership:Multiplayer_Ownership)->bg.Status {
 if m==nil || m.peer!=nil || m.retained.count!=0 || m.cleanup{return bg.INVALID_ARGUMENT}
 if r.owned_context_access(ownership.container,m,true)!=.None{return bg.INCOMPATIBLE}
 m.ownership=ownership;return bg.OK
}

@(private)
multiplayer_connection_changed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
	context=gdext.godot_context();gdext.variant_new_nil(ret);error^={};if argc!=1 || gdext.variant_get_type(args[0])!=.Int {return}
 callback:=cast(^Multiplayer_Callback)raw
 multiplayer_changed(callback.owner,callback.joined,args[0])
}
@(private)
multiplayer_changed :: proc(m:^Multiplayer_Transport,joined:bool,value:gdext.VariantPtr){
 id:i64;convert:=gdext.get_variant_to_type_constructor(.Int);convert(&id,value);if id<=0 || id>i64(max(i32)) {m.rejected_connections+=1;return}
	for existing,i in m.remotes {if existing==tr.Peer_Id(id) {
		if !joined {
			ordered_remove(&m.remotes,i)
			for &connection in m.connections {if connection.id==tr.Peer_Id(id) {
				connection={};break
			}}
			if m.pending.state==.Received && m.pending.from==tr.Peer_Id(id) {m.pending={};m.retired_packets+=1}
		}
		return
	}}
	if joined {
		slot:=-1
		for connection,i in m.connections {if connection.id==tr.Peer_Id(id) {slot=i;break}}
		if slot<0 {for connection,i in m.connections {if connection.id==0 {slot=i;break}}}
		if slot<0 || m.connection_serial==max(u64) {m.rejected_connections+=1;gd.multiplayer_peer_disconnect_peer(m.peer,id,true);return}
		m.connection_serial+=1
		// All packets already in the backend FIFO precede this connection.
		// Keep the boundary even when this numeric ID has never been recorded.
		m.connections[slot]={tr.Peer_Id(id),m.connection_serial,int(gd.packet_peer_get_available_packet_count(m.peer))}
		append(&m.remotes,tr.Peer_Id(id))
	}
}

@(private)
Multiplayer_Payload :: struct {owner:r.Owner,retained:r.Owner_Retains,allocator:mem.Allocator,transport:^Multiplayer_Transport,joined:bool}
@(private)
MULTIPLAYER_SIGNAL :: u32(0x4d500001)
@(private)
multiplayer_callable :: proc(m:^Multiplayer_Transport,joined:bool)->(rt.Managed_Callable,bg.Status){
 service:=bg.service_get();if service.capsule_create==nil{return {},bg.UNSUPPORTED}
 payload,error:=mem.new_clone(Multiplayer_Payload{owner=m.ownership.container.owner,allocator=m.allocator,transport=m,joined=joined},m.allocator)
 if error!=.None{return {},bg.OUT_OF_MEMORY}
 owners:=[?]r.Owner{m.ownership.allocator.owner,m.ownership.container.owner}
 if r.owner_retains_acquire(&payload.retained,owners[:])!=.None{retained:=payload.retained;mem.free(payload,m.allocator);r.owner_retains_drop(&retained);return {},bg.INCOMPATIBLE}
 capsule:bg.Capsule
 status:=service.capsule_create(service.user,&payload.owner,payload,multiplayer_dispatch,&capsule)
 if status!=bg.OK{retained:=payload.retained;mem.free(payload,m.allocator);r.owner_retains_drop(&retained);return {},status}
 handle,created:=rt.managed_callable_create(&capsule,MULTIPLAYER_SIGNAL)
 if created!=bg.OK{capsule.destroy(capsule.user);return {},created}
 return handle,bg.OK
}
@(private)
multiplayer_dispatch :: proc "c"(data:rawptr,operation:u32,args:rawptr)->bg.Status {
 context=gdext.godot_context()
 payload:=cast(^Multiplayer_Payload)data
 if payload==nil || r.owner_access(payload.owner)!=.None{return bg.INCOMPATIBLE}
 if operation==bg.CAPSULE_DESTROY {
  retained,allocator:=payload.retained,payload.allocator
  mem.free(payload,allocator)
  return r.owner_retains_drop(&retained)==.None?bg.OK:bg.INCOMPATIBLE
 }
 if operation!=MULTIPLAYER_SIGNAL || args==nil{return bg.INVALID_ARGUMENT}
 if r.owner_access(payload.owner,.Execute)!=.None{return bg.INCOMPATIBLE}
 call:=cast(^rt.Managed_Callable_Args)args
 if call.reserved!=0 || call.count!=1 || call.variants==nil{return bg.INVALID_ARGUMENT}
 value:=cast(gdext.VariantPtr)call.variants[0]
 if gdext.variant_get_type(value)!=.Int{return bg.INVALID_ARGUMENT}
 multiplayer_changed(payload.transport,payload.joined,value)
 return bg.OK
}
