//gd:extends Node
//gd:class GodotLifetimesProbe
package godot_lifetimes_probe

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import ng "godot:kit/netgd"
import ks "godot:kit/session"
import save "godot:kit/save"
import fx "godot:kit/fx"

GodotLifetimesProbe :: struct {owner:gd.Node,sprite:gd.Node2d,stage:int,before:f64,until:u64}
release :: proc(object:gd.Ref_Counted) {if object!=nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
godot_lifetimes_probe_ready :: proc(self:^GodotLifetimesProbe) {
	performance:=gd.singleton_performance()
	before:=gd.performance_get_monitor(performance,.Object_Count)
	for _ in 0..<128 {
		gd.action_add_key("lifetime_key",i64(gd.Key.Space));gd.action_add_mouse_button("lifetime_mouse",i64(gd.Mouse_Button.Left))
		gd.erase_action("lifetime_key");gd.erase_action("lifetime_mouse")
	}
	input_growth:=gd.performance_get_monitor(performance,.Object_Count)-before
	mp:=gd.node_get_multiplayer(self.owner);defer release(mp)
	peer:=gd.multiplayer_api_get_multiplayer_peer(mp);defer release(peer)
	mp_before:=gd.ref_counted_get_reference_count(mp);peer_before:=gd.ref_counted_get_reference_count(peer)
	for _ in 0..<128 {
		ng.peer_address(self.owner,2)
		gd.my_peer_id(self.owner);gd.is_server(self.owner);gd.connected_peers(self.owner);gd.rpc_sender_id(self.owner)
	}
	mp_growth:=gd.ref_counted_get_reference_count(mp)-mp_before;peer_growth:=gd.ref_counted_get_reference_count(peer)-peer_before
	gd.print_str(fmt.tprintf("GODOT_LIFETIMES input_growth=%.0f multiplayer_growth=%d peer_growth=%d",input_growth,mp_growth,peer_growth))
	if input_growth!=0 || mp_growth!=0 || peer_growth!=0 {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	// Each offline installation replaces the previous peer. Only the API's
	// reference and this query's reference may remain after the helper returns.
	session:ks.Session;defer ks.session_destroy(&session)
	wire:ng.Session_Wire;ng.wire_attach(&wire,self.owner,&session,1);defer ng.wire_detach(&wire)
	for _ in 0..<8 {
		if !ng.transport_host(&wire,&ng.OFFLINE,{},"lifetime",55) {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
		current:=gd.multiplayer_api_get_multiplayer_peer(mp)
		refs:=gd.ref_counted_get_reference_count(current);release(current)
		if refs!=2 {gd.print_str(fmt.tprintf("GODOT_LIFETIMES offline_refs=%d",refs));gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	}
	gd.multiplayer_clear_peer(self.owner)
	if gd.my_peer_id(self.owner)!=0 || gd.is_server(self.owner) || len(gd.connected_peers(self.owner))!=0 {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	packet:=[1]u8{1}
	if ng.send_reliable(self.owner,1,packet[:])!=.Err_Unavailable {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	file_before:=gd.performance_get_monitor(performance,.Object_Count)
	for _ in 0..<64 {
		data:=[4]u8{1,2,3,4}
		if !save.write_file("user://lifetime.bin",data[:]) {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
		bytes,ok:=save.read_file("user://lifetime.bin");defer delete(bytes)
		if !ok || len(bytes)!=4 || bytes[3]!=4 {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	}
	growth:=gd.performance_get_monitor(performance,.Object_Count)-file_before
	gd.print_str(fmt.tprintf("GODOT_LIFETIMES file_growth=%.0f",growth))
	if growth!=0 {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
	self.sprite=gd.new_node2d();gd.add_child(self.owner,self.sprite);self.stage=1
}
godot_lifetimes_probe_process :: proc(self:^GodotLifetimesProbe,dt:f64) {
	if self.stage==1 {
		self.before=gd.performance_get_monitor(gd.singleton_performance(),.Object_Count)
		for _ in 0..<64 {fx.flash(self.sprite,{1,0,0,1})}
		self.until=gd.time_get_ticks_msec(gd.singleton_time())+600;self.stage=2
	} else if self.stage==2 && gd.time_get_ticks_msec(gd.singleton_time())>=self.until {
		growth:=gd.performance_get_monitor(gd.singleton_performance(),.Object_Count)-self.before
		gd.print_str(fmt.tprintf("GODOT_LIFETIMES tween_growth=%.0f",growth));self.stage=3
		if growth!=0 {gd.scene_tree_quit(gd.get_tree(self.owner),1);return}
		gd.print_str("GODOT_LIFETIMES_OK");gd.scene_tree_quit(gd.get_tree(self.owner),0)
	}
}
