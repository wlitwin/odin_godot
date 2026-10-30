package replay_godot

import gd "godot:godot"
import tr "godot:replay/transport"

// ENet supplies construction/addressing; the shared adapter owns the raw peer,
// packet buffers, bounded connection registry and callback lifetime.
Enet :: struct {using packets:Multiplayer_Transport}
enet_host :: proc(e:^Enet,port:u16,max_clients:u16=32,bind_ip:cstring="*",allocator:=context.allocator)->bool {
	when gd.IS_WEB {return false} else {
		if e.peer!=nil || max_clients==0 || max_clients>4095 {return false}
		peer:=gd.new_e_net_multiplayer_peer();if peer==nil {return false}
		gd.ref_counted_init_ref(peer);defer gd.release_ref(peer)
		if !multiplayer_attach(&e.packets,cast(gd.Multiplayer_Peer)peer,int(max_clients),allocator) {return false}
		ip:=gd.new_string_cstring(bind_ip);gd.e_net_multiplayer_peer_set_bind_ip(peer,ip);gd.free_string(ip)
		if gd.e_net_multiplayer_peer_create_server(peer,gd.Int(port),gd.Int(max_clients),0,0,0)!=.Ok {multiplayer_close(&e.packets);return false}
		return true
	}
}
enet_join :: proc(e:^Enet,address:cstring,port:u16,allocator:=context.allocator)->bool {
	when gd.IS_WEB {return false} else {
		if e.peer!=nil {return false}
		peer:=gd.new_e_net_multiplayer_peer();if peer==nil {return false}
		gd.ref_counted_init_ref(peer);defer gd.release_ref(peer)
		if !multiplayer_attach(&e.packets,cast(gd.Multiplayer_Peer)peer,16,allocator) {return false}
		addr:=gd.new_string_cstring(address);err:=gd.e_net_multiplayer_peer_create_client(peer,addr,gd.Int(port),0,0,0,0);gd.free_string(addr)
		if err!=.Ok {multiplayer_close(&e.packets);return false}
		return true
	}
}
enet_transport :: proc(e:^Enet)->tr.Transport {return multiplayer_transport(&e.packets)}
enet_id :: proc(e:^Enet)->tr.Peer_Id {return multiplayer_id(&e.packets)}
