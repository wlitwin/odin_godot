package replay_godot

import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"

Steam_Error :: enum {None,Unavailable,Invalid_Config,Not_Initialized,Interface,Initialization,Create,Transport}
Steam_Runtime :: struct {singleton:gd.Object,ready:bool,steam_id:u64,status:i64,error:Steam_Error}
// A factory returns an owned Variant containing a fresh MultiplayerPeer. The
// adapter retains the peer and destroys that Variant on every path. Its user and
// runtime are borrowed and must outlive every Session/Room connection.
Steam_Config :: struct {runtime:^Steam_Runtime,peer:gd.Multiplayer_Peer,host_steam_id:u64,virtual_port:u16,max_peers:u16,
 factory_user:rawptr,peer_factory:proc(user:rawptr)->gd.Variant}
STEAM_CONFIG :: Steam_Config{max_peers=16}
Steam :: struct {packets:Multiplayer_Transport,runtime:^Steam_Runtime,error:Steam_Error}

// Capability detection does not initialize Steam, create a lobby, or change
// presence. The game explicitly initializes one runtime before opening sessions.
steam_available :: proc()->bool {
	when gd.IS_WEB {return false} else {
		name:=gd.new_string_name("Steam");defer gd.free_string_name(name)
		if !gd.engine_has_singleton(gd.singleton_engine(),name) {return false}
		kind:=gd.new_string_name("SteamMultiplayerPeer");defer gd.free_string_name(kind)
		return gd.class_db_can_instantiate(gd.singleton_class_db(),kind)
	}
}
steam_runtime_init :: proc(runtime:^Steam_Runtime,app_id:u32)->Steam_Error {
	if runtime.ready || app_id==0 {return .Invalid_Config}
	if !steam_available() {runtime.error=.Unavailable;return .Unavailable}
	name:=gd.new_string_name("Steam");defer gd.free_string_name(name)
	return steam_runtime_initialize(runtime,gd.engine_get_singleton(gd.singleton_engine(),name),app_id)
}
// Explicit binding supports a supplied GodotSteam singleton and API-contract
// fixtures. The caller owns the singleton; the runtime borrows it until closed.
steam_runtime_initialize :: proc(runtime:^Steam_Runtime,singleton:gd.Object,app_id:u32)->Steam_Error {
	if runtime.ready || singleton==nil || app_id==0 {return .Invalid_Config}
	if !steam_method(singleton,"steamInitEx") || !steam_method(singleton,"getSteamID") || !steam_method(singleton,"run_callbacks") {runtime.error=.Interface;return .Interface}
	id:=gd.Int(app_id);embed:=false
	args:=[2]gd.Variant{gd.variant_from_int(&id),gd.variant_from_bool(&embed)};defer for &arg in args {gd.variant_destroy(&arg)}
	method:=gd.new_string_name("steamInitEx");defer gd.free_string_name(method)
	result:=gd.object_call(singleton,method,..args[:]);defer gd.variant_destroy(&result)
	if gdext.variant_get_type(&result)!=.Dictionary {runtime.error=.Interface;return .Interface}
	dictionary:=gd.variant_to_dictionary(&result);defer gd.free_dictionary(dictionary)
	key:=gd.new_string_odin("status");defer gd.free_string(key);key_value:=gd.variant_from_string(&key);defer gd.variant_destroy(&key_value)
	value:=gd.dictionary_get(&dictionary,key_value,gd.Variant{});defer gd.variant_destroy(&value)
	if gdext.variant_get_type(&value)!=.Int {runtime.error=.Interface;return .Interface}
	runtime.status=gd.variant_to_int(&value)
	if runtime.status!=0 {runtime.error=.Initialization;return .Initialization}
	steam_id,ok:=steam_integer(singleton,"getSteamID")
	if !ok || steam_id==0 {runtime.error=.Initialization;return .Initialization}
	runtime.singleton,runtime.steam_id,runtime.ready,runtime.error=singleton,u64(steam_id),true,.None
	return .None
}
steam_runtime_poll :: proc(runtime:^Steam_Runtime) {
	if runtime==nil || !runtime.ready {return}
	method:=gd.new_string_name("run_callbacks");defer gd.free_string_name(method)
	value:=gd.object_call(runtime.singleton,method);gd.variant_destroy(&value)
}
// Does not call Steam shutdown: other peers/lobby services may share the API.
steam_runtime_release :: proc(runtime:^Steam_Runtime) {runtime^={}}

steam_open :: proc(s:^Steam,config:Steam_Config,host:bool)->Steam_Error {
	if s.packets.peer!=nil || config.max_peers<1 || config.max_peers>4095 || (!host && config.host_steam_id==0) {s.error=.Invalid_Config;return s.error}
	if config.runtime==nil || !config.runtime.ready {s.error=.Not_Initialized;return s.error}
 if config.peer!=nil && config.peer_factory!=nil {s.error=.Invalid_Config;return s.error}
	if config.peer!=nil {return steam_open_peer(s,config.peer,config,host)}
 if config.peer_factory!=nil {
  value:=config.peer_factory(config.factory_user);defer gd.variant_destroy(&value)
  if gdext.variant_get_type(&value)!=.Object {s.error=.Interface;return s.error}
  peer:=cast(gd.Multiplayer_Peer)gd.variant_to_object(&value)
  if peer==nil {s.error=.Interface;return s.error}
  return steam_open_peer(s,peer,config,host)
 }
	if !steam_available() {s.error=.Unavailable;return s.error}
	kind:=gd.new_string_name("SteamMultiplayerPeer");defer gd.free_string_name(kind)
	value:=gd.class_db_instantiate(gd.singleton_class_db(),kind);defer gd.variant_destroy(&value)
	peer:=cast(gd.Multiplayer_Peer)gd.variant_to_object(&value)
	if peer==nil {s.error=.Interface;return s.error}
	return steam_open_peer(s,peer,config,host)
}
// Retains a caller-created peer, then calls its direct create_host/create_client
// entry point. Useful for GodotSteam builds or bindings that provide the object.
steam_open_peer :: proc(s:^Steam,peer:gd.Multiplayer_Peer,config:Steam_Config,host:bool)->Steam_Error {
	if s.packets.peer!=nil || peer==nil || config.max_peers<1 || config.max_peers>4095 || (!host && config.host_steam_id==0) {s.error=.Invalid_Config;return s.error}
	if config.runtime==nil || !config.runtime.ready {s.error=.Not_Initialized;return s.error}
	object:=cast(gd.Object)peer
	for method in ([3]string{"create_host","create_client","get_steam_id_for_peer_id"}) {if !steam_method(object,method) {s.error=.Interface;return s.error}}
	if !multiplayer_attach(&s.packets,peer,int(config.max_peers)) {s.error=.Transport;return s.error}
	s.runtime=config.runtime
	method:=gd.new_string_name(host ? "create_host" : "create_client");defer gd.free_string_name(method)
	port:=gd.Int(config.virtual_port);target:=transmute(i64)config.host_steam_id
	args:=[2]gd.Variant{gd.variant_from_int(&target),gd.variant_from_int(&port)};defer for &arg in args {gd.variant_destroy(&arg)}
	value:=gd.object_call(object,method,..(host ? args[1:] : args[:]));defer gd.variant_destroy(&value)
	if gdext.variant_get_type(&value)!=.Int || gd.variant_to_int(&value)!=0 {multiplayer_close(&s.packets);s.runtime=nil;s.error=.Create;return s.error}
	s.error=.None;return .None
}
steam_transport :: proc(s:^Steam)->tr.Transport {return {user=s,send=steam_send,receive=steam_receive,poll=steam_poll,status=steam_status,connected=steam_connected,generation=steam_generation,close=steam_close}}
steam_id :: proc(s:^Steam)->tr.Peer_Id {return multiplayer_id(&s.packets)}
steam_remote_id :: proc(s:^Steam,peer:tr.Peer_Id)->(u64,bool) {
	if s.packets.peer==nil || !steam_connected(s,peer) {return 0,false}
	id:=gd.Int(peer);arg:=gd.variant_from_int(&id);defer gd.variant_destroy(&arg)
	value,ok:=steam_integer(cast(gd.Object)s.packets.peer,"get_steam_id_for_peer_id",arg)
	return u64(value),ok && value!=0
}
steam_close :: proc(raw:rawptr) {s:=cast(^Steam)raw;multiplayer_close(&s.packets);s.runtime=nil}
@(private)
steam_send :: proc(raw:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {s:=cast(^Steam)raw;return multiplayer_send(&s.packets,to,channel,bytes)}
@(private)
steam_receive :: proc(raw:rawptr,dst:[]u8)->tr.Received {s:=cast(^Steam)raw;return multiplayer_receive(&s.packets,dst)}
@(private)
steam_poll :: proc(raw:rawptr) {s:=cast(^Steam)raw;steam_runtime_poll(s.runtime);multiplayer_poll(&s.packets)}
@(private)
steam_status :: proc(raw:rawptr)->tr.Status {s:=cast(^Steam)raw;return multiplayer_status(&s.packets)}
@(private)
steam_connected :: proc(raw:rawptr,peer:tr.Peer_Id)->bool {s:=cast(^Steam)raw;return multiplayer_connected(&s.packets,peer)}
@(private)
steam_generation :: proc(raw:rawptr,peer:tr.Peer_Id)->u64 {s:=cast(^Steam)raw;return multiplayer_generation(&s.packets,peer)}
@(private)
steam_method :: proc(object:gd.Object,method:string)->bool {name:=gd.new_string_name(method);defer gd.free_string_name(name);return gd.object_has_method(object,name)}
@(private)
steam_integer :: proc(object:gd.Object,method:string,args:..gd.Variant)->(i64,bool) {
	name:=gd.new_string_name(method);defer gd.free_string_name(name)
	value:=gd.object_call(object,name,..args);defer gd.variant_destroy(&value)
	if gdext.variant_get_type(&value)!=.Int {return 0,false};return gd.variant_to_int(&value),true
}

// Decimal Steam IDs are opaque 64-bit addresses. Reject empty, zero, signs,
// separators and overflow rather than wrapping a mistyped endpoint.
steam_parse_id :: proc(text:string)->(u64,bool) {
	if len(text)==0 || len(text)>20 {return 0,false}
	value:=u64(0)
	for c in text {
		if c<'0' || c>'9' {return 0,false}
		digit:=u64(c-'0');if value>(max(u64)-digit)/10 {return 0,false}
		value=value*10+digit
	}
	return value,value!=0
}
