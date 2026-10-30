//gd:extends Node
//gd:class ReplayRoomService
package replay_room_service

import "core:fmt"
import "core:crypto"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import rel "godot:replay/relay"
import ck "godot:replay/provision/checkpoint"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import pitch "godot:examples/replay_speedball/shared/pitch"
import slopball "godot:examples/replay_slopball/shared/pitch"
import slopball3d "godot:examples/replay_slopball3d/shared/pitch"
import claimball "godot:examples/replay_claimball/shared/pitch"
import duel "godot:examples/replay_quickdraw/shared/duel"
import scrapyard "godot:examples/replay_scrapyard/shared/game"

ReplayRoomService :: struct {
	owner: gd.Node,
	ready: bool,
	store: db.Store,
	hub: p.Hub,
	signal: rgd.Rendezvous_Hub,
	socket: rgd.Websocket,
	wire: tr.Transport,
	tls: gd.Tls_Options,
	relay: rel.Server,
	checkpoints: ck.Hub,
	cave_backend: db.Checkpoint_Backend(cave.World,cave.Control,cave.Action,cave.Event,cave.SEATS),
	cave_owned_backend: db.Checkpoint_Backend(cave_owned.World,cave_owned.Control,cave_owned.Action,cave_owned.Event,cave_owned.SEATS),
	duel_backend: db.Checkpoint_Backend(duel.World,duel.Controls,duel.Action,duel.Event,duel.SEATS),
	slopball3d_backend: db.Checkpoint_Backend(slopball3d.World,slopball3d.Control,slopball3d.Action,slopball3d.Event,slopball3d.SEATS),
	slopball_backend: db.Checkpoint_Backend(slopball.World,slopball.Control,slopball.Action,slopball.Event,slopball.SEATS),
	claimball_backend: db.Checkpoint_Backend(claimball.World,claimball.Controls,claimball.Action,claimball.Event,claimball.SEATS),
	pitch_backend: db.Checkpoint_Backend(pitch.World,pitch.Controls,pitch.Action,pitch.Event,pitch.SEATS),
	scrapyard_backend: db.Checkpoint_Backend(scrapyard.World,scrapyard.Control,scrapyard.Action,scrapyard.Event,scrapyard.SEATS),
}
parse_content :: proc(text: string) -> (u64, bool) {
	text := text; base := u64(10)
	if len(text) > 2 && text[:2] == "0x" {base = 16; text = text[2:]}
	if len(text) == 0 || len(text) > 20 {return 0, false}
	value := u64(0)
	for b in text {
		digit := u64(99)
		if b >= '0' && b <= '9' {digit = u64(b - '0')} else if b >= 'a' && b <= 'f' {digit = u64(b - 'a' + 10)} else if b >= 'A' && b <= 'F' {digit = u64(b - 'A' + 10)}
		if digit >= base || value > (max(u64) - digit) / base {return 0, false}
		value = value * base + digit
	}
	return value, value != 0
}
unref :: proc(object: gd.Ref_Counted) {if object != nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
replay_room_service_ready :: proc(self: ^ReplayRoomService) {
	content, valid := parse_content(gd.env_string("REPLAY_ROOM_CONTENT", ""))
	port, rooms := gd.env_int("REPLAY_ROOM_PORT", 49740), gd.env_int("REPLAY_ROOM_CAPACITY", 16)
	mode := gd.env_string("REPLAY_ROOM_MODE", "cooperative")
	bind := gd.env_string("REPLAY_ROOM_BIND", "127.0.0.1")
	if !valid || port < 1 || port > 65535 || rooms < 1 || rooms > p.MAX_ROOMS || (mode != "cooperative" && mode != "dedicated") {fail(self, "invalid content/port/capacity/mode"); return}
	if _,ok:=checkpoint_model(content,gd.env_string("REPLAY_ROOM_CHECKPOINT_MODEL",""));!ok {fail(self,"checkpoint model does not match deployment content");return}
	cert_path, key_path := gd.env_string("REPLAY_ROOM_CERT", ""), gd.env_string("REPLAY_ROOM_KEY", "")
	local := gd.env_int("REPLAY_ROOM_LOCAL_DEVELOPMENT", 0) == 1
	if cert_path == "" && key_path == "" && local && (bind == "127.0.0.1" || bind == "::1") {
		// Explicit loopback-only development transport.
	} else {
		if cert_path == "" || key_path == "" {fail(self, "TLS certificate and key required"); return}
		cert := gd.new_x509_certificate(); gd.ref_counted_init_ref(cert); defer unref(cert)
		key := gd.new_crypto_key(); gd.ref_counted_init_ref(key); defer unref(key)
		cp, kp := gd.new_string_odin(cert_path), gd.new_string_odin(key_path); defer gd.free_string(cp); defer gd.free_string(kp)
		if gd.x509_certificate_load(cert, cp) != .Ok || gd.crypto_key_load(key, kp, false) != .Ok {fail(self, "TLS material could not be loaded"); return}
		self.tls = gd.tls_options_server(key, cert)
	}
	if db.open(&self.store, gd.env_string("REPLAY_ROOM_DB", ""), gd.env_int("REPLAY_ROOM_CREATE_DB", 0) == 1) != .None {fail(self, "private database could not be opened"); return}
	existing: [p.MAX_ROOMS]p.Bundle
	count, err := db.load_all(&self.store, content, existing[:int(rooms)])
	if err != .None {fail(self, "room inventory invalid or exceeds capacity"); return}
	if !rgd.websocket_host(&self.socket, u16(port), bind, cfg = {128, 64, 256 * 1024, 10000}, tls = self.tls) {fail(self, "listen failed"); return}
	self.wire = rgd.websocket_transport(&self.socket)
	cfg := p.HUB_CONFIG; cfg.content, cfg.rooms = content, int(rooms)
	if mode == "dedicated" {cfg.policy.mode = .Dedicated}
	if p.hub_open(&self.hub, cfg, existing[:count], db.commit, &self.store, auth.native_clock(), self.wire) != .None ||
	   !rgd.rendezvous_hub_init(&self.signal, &self.hub, &self.socket) {fail(self, "coordinator startup failed"); return}
	checkpoint_name,checkpoint_ok:=checkpoint_open(self,content)
	if !checkpoint_ok {fail(self,"checkpoint model or endpoint startup failed");return}
	secret_path, turn_urls := gd.env_string("REPLAY_ROOM_TURN_SECRET_FILE", ""), gd.env_string("REPLAY_ROOM_TURN_URLS", "")
	if secret_path != "" || turn_urls != "" {
		ttl := gd.env_int("REPLAY_ROOM_TURN_TTL", 600)
		if secret_path == "" || turn_urls == "" || ttl < 5 || ttl > 3600 {fail(self, "TURN provider configuration invalid"); return}
		bytes, error := rgd.storage_read(secret_path, 256)
		defer {if len(bytes) > 0 {crypto.zero_explicit(raw_data(bytes), len(bytes))}; delete(bytes)}
		if error != .None {fail(self, "TURN provider secret could not be read"); return}
		urls := strings.split(turn_urls, ",", context.temp_allocator)
		if len(urls) < 1 || len(urls) > rel.MAX_URLS {fail(self, "TURN URL count invalid"); return}
		config := rel.Config{content = content, secret = strings.trim_space(string(bytes)), ttl = u32(ttl), relay_only = gd.env_int("REPLAY_ROOM_TURN_RELAY_ONLY", 0) == 1}
		for text, i in urls {valid: bool; config.urls[i], valid = rel.url(strings.trim_space(text)); if !valid {fail(self, "TURN URL invalid"); return}}
		if !rel.server_open(&self.relay, config, rel.hub_authorize, &self.hub, {read = relay_clock}, self.wire) {fail(self, "TURN provider startup failed"); return}
	}
	self.ready = true
	gd.print_str(fmt.tprintf("REPLAY_ROOM_SERVICE_READY rooms=%d content=%x tls=%t port=%d checkpoints=%s", count, content, self.tls != nil, port,checkpoint_name))
}
replay_room_service_process :: proc(self: ^ReplayRoomService, dt: f64) {
	if !self.ready {return}
	tr.poll(&self.wire)
	rgd.rendezvous_hub_pump(&self.signal)
	buffer: [tr.MAX_PACKET_BYTES]u8
	for _ in 0 ..< 32 {
		message := rgd.websocket_receive(&self.socket, buffer[:])
		if message.state == .Empty || message.state == .Disconnected {break}
		if message.state != .Received {continue}
		if message.text {rgd.rendezvous_hub_receive(&self.signal, message.from, buffer[:message.count])}
		else if !ck.hub_receive(&self.checkpoints,message.from,buffer[:message.count]) && !rel.server_receive(&self.relay, message.from, buffer[:message.count]) && !p.hub_receive(&self.hub, message.from, buffer[:message.count]) {p.hub_control_receive(&self.hub, message.from, buffer[:message.count])}
	}
	if self.checkpoints.ready && ck.hub_update(&self.checkpoints)!=.None {fail(self,"checkpoint room inventory changed or storage fenced");return}
}
fail :: proc(self: ^ReplayRoomService, reason: string) {gd.print_str(fmt.tprintf("REPLAY_ROOM_SERVICE_FAIL %s", reason)); gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
replay_room_service_exit_tree :: proc(self: ^ReplayRoomService) {
	ck.hub_close(&self.checkpoints)
	rgd.rendezvous_hub_destroy(&self.signal); p.hub_close(&self.hub); rgd.websocket_close(&self.socket)
	rel.server_close(&self.relay)
	db.close(&self.store); unref(self.tls)
}
relay_clock :: proc(user: rawptr) -> (u64, u64, bool) {
	wall := gd.time_get_unix_time_from_system(gd.singleton_time())
	clock := auth.native_clock(); mono, valid := clock.read(clock.user)
	if !valid || !(wall >= 1 && wall < 9007199254740991) {return 0, 0, false}
	return u64(wall), mono, true
}
