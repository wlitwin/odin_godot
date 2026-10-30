//gd:extends Node
//gd:class SteamProbe
package steam_probe
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import tr "godot:replay/transport"
import transportgd "godot:replay/godot/transport"

SteamProbe :: struct {owner:gd.Node,steam:transportgd.Steam,runtime:transportgd.Steam_Runtime,wire:tr.Transport,role:string,started:u64,sent,received:u32,done:bool}
steam_probe_ready :: proc(self:^SteamProbe) {
	self.role=strings.clone(gd.env_string("STEAM_TEST_ROLE","host"))
	fake:=gd.get_node(self.owner,"FakeSteam")
	if transportgd.steam_runtime_initialize(&self.runtime,cast(gd.Object)fake,480)!=.None {fail(self,"runtime");return}
	method:=gd.new_string_name("new_peer");defer gd.free_string_name(method)
	value:=gd.object_call(cast(gd.Object)fake,method);defer gd.variant_destroy(&value)
	config:=transportgd.STEAM_CONFIG;config.runtime=&self.runtime;config.host_steam_id=76561198000000001;config.virtual_port=u16(gd.env_int("STEAM_TEST_PORT",49499))
	if transportgd.steam_open_peer(&self.steam,cast(gd.Multiplayer_Peer)gd.variant_to_object(&value),config,self.role=="host")!=.None {fail(self,"open peer");return}
	self.wire=transportgd.steam_transport(&self.steam);self.started=gd.time_get_ticks_msec(gd.singleton_time())
}
fail :: proc(self:^SteamProbe,why:cstring) {gd.print_str(fmt.tprintf("REPLAY_STEAM_CONTRACT_FAIL role=%s %s",self.role,why));self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),1)}
steam_probe_process :: proc(self:^SteamProbe,dt:f64) {
	if self.done {return};elapsed:=gd.time_get_ticks_msec(gd.singleton_time())-self.started
	if elapsed>12000 {fail(self,"timeout");return}
	tr.poll(&self.wire)
	peer:tr.Peer_Id=0
	if len(self.steam.packets.remotes)>0 {peer=self.steam.packets.remotes[0]}
	if peer!=0 && self.sent==0 {
		id,ok:=transportgd.steam_remote_id(&self.steam,peer)
		if !ok || id!=(self.role=="host" ? u64(76561198000000002) : u64(76561198000000001)) {fail(self,"Steam ID mapping");return}
		large:=[65536]u8{};for &byte,i in large {byte=u8(i*31+17)}
		if tr.send(&self.wire,peer,.Reliable,large[:])!=.Sent {fail(self,"large send");return}
		small:=[3]u8{7,8,9};if tr.send(&self.wire,peer,.Unreliable,small[:])!=.Sent {fail(self,"small send");return}
		self.sent=1
	}
	for _ in 0..<8 {
		short:[2]u8;packet:=tr.receive(&self.wire,short[:])
		if packet.state==.Empty {break}
		if packet.state!=.Buffer_Too_Small {fail(self,"pending short buffer");return}
		bytes:[65536]u8;full:=tr.receive(&self.wire,bytes[:])
		if full.state!=.Received || full.from!=peer || full.count!=packet.count {fail(self,"retained packet");return}
		if full.generation==0 || full.generation!=packet.generation || full.generation!=tr.peer_generation(&self.wire,peer) {fail(self,"connection generation");return}
		if full.count==65536 {
			if full.channel!=.Reliable {fail(self,"reliable mode");return}
			for byte,i in bytes {if byte!=u8(i*31+17) {fail(self,"large payload");return}}
			self.received |= 1
		} else if full.count==3 {
			if full.channel!=.Unreliable || bytes[0]!=7 || bytes[1]!=8 || bytes[2]!=9 {fail(self,"unreliable payload/mode");return}
			self.received |= 2
		} else {fail(self,"packet length");return}
	}
	if self.received==3 && elapsed>(self.role=="host" ? 3200 : 2000) {
		gd.print_str(fmt.tprintf("REPLAY_STEAM_CONTRACT_OK role=%s large=65536 modes=2 pending_copy=true",self.role))
		self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0)
	}
}
steam_probe_exit_tree :: proc(self:^SteamProbe) {tr.close(&self.wire);transportgd.steam_runtime_release(&self.runtime);delete(self.role)}
