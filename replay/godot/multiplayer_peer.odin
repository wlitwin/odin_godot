package replay_godot

import "core:mem"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

// Retains one independent MultiplayerPeer. No SceneMultiplayer is installed.
// Attach before connecting/polling so every connection signal is observed.
Multiplayer_Transport :: struct {
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
	m.allocator,m.peer,m.capacity=allocator,peer,capacity;gd.ref_counted_reference(peer)
	m.buffer=make([]u8,tr.MAX_PACKET_BYTES,allocator);m.remotes=make([dynamic]tr.Peer_Id,0,capacity,allocator)
	m.connections=make([]Multiplayer_Connection,capacity,allocator)
	m.connected_cb,m.disconnected_cb=Multiplayer_Callback{m,true},Multiplayer_Callback{m,false}
	info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=multiplayer_connection_changed,callable_userdata=&m.connected_cb}
	gdext.callable_custom_create2(&m.connected_call,&info);info.callable_userdata=&m.disconnected_cb;gdext.callable_custom_create2(&m.disconnected_call,&info)
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
multiplayer_close :: proc(raw:rawptr) {
	m:=cast(^Multiplayer_Transport)raw
	if m.peer!=nil {
		connected:=gd.new_string_name("peer_connected");disconnected:=gd.new_string_name("peer_disconnected");defer gd.free_string_name(connected);defer gd.free_string_name(disconnected)
		if m.watching_connected {gd.object_disconnect(cast(gd.Object)m.peer,connected,m.connected_call)}
		if m.watching_disconnected {gd.object_disconnect(cast(gd.Object)m.peer,disconnected,m.disconnected_call)}
		gd.free_callable(m.connected_call);gd.free_callable(m.disconnected_call)
		gd.multiplayer_peer_close(m.peer);gd.release_ref(m.peer)
	}
	delete(m.buffer,m.allocator);delete(m.connections,m.allocator);delete(m.remotes);m^={}
}
@(private)
multiplayer_connection_changed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
	context=gdext.godot_context();gdext.variant_new_nil(ret);error^={};if argc!=1 || gdext.variant_get_type(args[0])!=.Int {return}
	callback:=cast(^Multiplayer_Callback)raw;m:=callback.owner
	id:i64;convert:=gdext.get_variant_to_type_constructor(.Int);convert(&id,args[0]);if id<=0 || id>i64(max(i32)) {m.rejected_connections+=1;return}
	for existing,i in m.remotes {if existing==tr.Peer_Id(id) {
		if !callback.joined {
			ordered_remove(&m.remotes,i)
			for &connection in m.connections {if connection.id==tr.Peer_Id(id) {
				connection={};break
			}}
			if m.pending.state==.Received && m.pending.from==tr.Peer_Id(id) {m.pending={};m.retired_packets+=1}
		}
		return
	}}
	if callback.joined {
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
