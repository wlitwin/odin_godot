package replay_godot

import "core:mem"
import gd "godot:godot"
import "godot:gdext"
import p "godot:replay/p2p/provision"
import tr "godot:replay/transport"
import wiregd "godot:replay/godot/internal/wire"
import transportgd "godot:replay/godot/transport"

P2P_Rendezvous_Hub :: struct {
	ready: bool,
	allocator: mem.Allocator,
	hub: ^p.Hub,
	socket: ^transportgd.Websocket,
	rooms: []Rendezvous,
	bindings: [128]Rendezvous_Binding,
}
p2p_rendezvous_hub_init :: proc(r: ^P2P_Rendezvous_Hub, hub: ^p.Hub, socket: ^transportgd.Websocket, allocator := context.allocator) -> bool {
	if r.ready || hub == nil || !hub.ready || socket == nil || !socket.ready || !socket.server {return false}
	r.allocator, r.hub, r.socket = allocator, hub, socket
	r.rooms = make([]Rendezvous, len(hub.rooms), allocator); r.ready = true
	return true
}
p2p_rendezvous_hub_destroy :: proc(r: ^P2P_Rendezvous_Hub) {
	for &room in r.rooms {rendezvous_destroy(&room)}
	delete(r.rooms, r.allocator); r^ = {}
}
p2p_rendezvous_hub_pump :: proc(r: ^P2P_Rendezvous_Hub) {
	if !r.ready {return}
	for &signal, i in r.rooms {
		room := r.hub.rooms[i]
		if room == nil || r.hub.poisoned || room.enrollment.service.coordinator.poisoned {if signal.ready {rendezvous_destroy(&signal)}; continue}
		if !signal.ready {
            cfg := DEFAULT_RENDEZVOUS_CONFIG; cfg.mesh = true
            if !rendezvous_provider_init(&signal, rendezvous_p2p_room_provider(room), r.socket, cfg) {continue}
        }
		rendezvous_pump(&signal)
	}
	for &binding in r.bindings {if binding.peer != 0 && !rendezvous_connection_live(r.socket, binding.peer) {binding = {}}}
}

// The first bounded JSON message selects an opaque current rendezvous code.
// That choice confers no membership: the existing per-room challenge/MAC and
// process-registration proof still authenticates this physical connection.
p2p_rendezvous_hub_receive :: proc(r: ^P2P_Rendezvous_Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
	if !r.ready || from == 0 {return false}
	p2p_rendezvous_hub_pump(r)
	for binding in r.bindings {if binding.peer == from {return rendezvous_receive(&r.rooms[binding.room], from, bytes)}}
	if len(bytes) > 32768 || !wiregd.json_depth(bytes) {transportgd.websocket_disconnect(r.socket, from); return false}
	text := gd.new_string_odin(string(bytes)); defer gd.free_string(text)
	value := gd.json_parse_string(text); defer gd.variant_destroy(&value)
	if gdext.variant_get_type(&value) != .Dictionary {transportgd.websocket_disconnect(r.socket, from); return false}
	data := gd.variant_to_dictionary(&value); defer gd.free_dictionary(data)
	code := wiregd.get_string(&data, "room", 64); defer delete(code)
	if len(code) != 64 {transportgd.websocket_disconnect(r.socket, from); return false}
	slot := -1
	for &room, i in r.rooms {if room.ready && string(room.code[:]) == code {slot = i; break}}
	if slot < 0 {transportgd.websocket_disconnect(r.socket, from); return false}
	for &binding in r.bindings {
		if binding.peer == 0 {binding = {from, slot}; return rendezvous_receive(&r.rooms[slot], from, bytes)}
	}
	transportgd.websocket_disconnect(r.socket, from); return false
}
