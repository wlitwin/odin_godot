package replay_godot

import "core:strings"
import gd "godot:godot"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rel "godot:replay/relay"
import tr "godot:replay/transport"
import wiregd "godot:replay/godot/internal/wire"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

Relay_Connection :: struct {
	ready: bool,
	socket: transportgd.Websocket,
	client: rel.Client,
	browser_clock: Browser_Lease_Clock,
	url, ice_json: string,
	tls: gd.Tls_Options,
	last_attempt, last_reconnect, revision: u64,
	error: rel.Error,
}
relay_connect :: proc(c: ^Relay_Connection, url: string, grant: p.Grant, tls: gd.Tls_Options = nil, local_development: bool = false) -> bool {
	if c.ready || !p.service_url_valid(url, local_development) || grant.room == 0 || grant.content == 0 || !auth.identity_valid(grant.identity) {return false}
	if !transportgd.websocket_join(&c.socket, url, tls = tls) {return false}
	clock: auth.Clock_Source
	when gd.IS_WEB {clock = browser_lease_clock(&c.browser_clock)} else {clock = auth.native_clock()}
	nonce := storagegd.session_token()
	if !rel.client_open(&c.client, grant.room, grant.content, grant.identity.member, grant.key, nonce, clock, transportgd.websocket_transport(&c.socket)) {transportgd.websocket_close(&c.socket); return false}
	c.url = strings.clone(url); c.tls = tls; if tls != nil {gd.ref_counted_reference(tls)}
	c.ready = true; return true
}
relay_close :: proc(c: ^Relay_Connection) {
	rel.client_close(&c.client); transportgd.websocket_close(&c.socket)
	if c.tls != nil {gd.release_ref(c.tls)}
	delete(c.url); delete(c.ice_json); c^ = {}
}
relay_frame :: proc(c: ^Relay_Connection) {
	if !c.ready {return}
	now, ok := c.client.clock.read(c.client.clock.user)
	if !ok {c.error = .Clock; return}
	if tr.status(&c.client.wire) == .Disconnected && now >= c.last_reconnect && now - c.last_reconnect >= 500 {
		transportgd.websocket_close(&c.socket)
		if !transportgd.websocket_join(&c.socket, c.url, tls = c.tls) {c.error = .Unavailable; return}
		// A challenge belongs to the old physical connection. Start a new one.
		c.client.pending, c.client.complete = false, false; c.last_reconnect = now
	}
	if error := rel.client_pump(&c.client); error != .None {c.error = error}
	if c.client.complete {
		c.client.complete = false; c.error = c.client.reply.error
		if c.error == .None {
			json, valid := relay_ice_json(c.client.reply.grant)
			if !valid {c.error = .Invalid} else {delete(c.ice_json); c.ice_json = json; c.revision += 1}
		}
	}
	if !c.client.pending && tr.status(&c.client.wire) == .Connected &&
	   (c.client.refresh_at == 0 || now >= c.client.refresh_at) && (c.last_attempt == 0 || now - c.last_attempt >= 1000) {
		c.last_attempt = now
		if error := rel.client_begin(&c.client); error != .None {c.error = error}
	}
}
relay_ice_source :: proc(user: rawptr) -> (string, bool) {
	c := cast(^Relay_Connection)user
	if c == nil || !c.ready || c.ice_json == "" {return "", false}
	_, valid := rel.client_grant(&c.client)
	return valid ? c.ice_json : "", valid
}
relay_ice_json :: proc(grant: rel.Grant) -> (string, bool) {
	if !rel.grant_valid(grant) {return "", false}
	g := grant
	urls := gd.new_array_default(); defer gd.free_array(urls)
	for item in g.urls {
		if item == (rel.URL{}) {break}
		u := item; text := gd.new_string_odin(string(u[:rel.fixed_count(u)])); defer gd.free_string(text)
		value := gd.variant_from_string(&text); defer gd.variant_destroy(&value); gd.array_append(&urls, value)
	}
	server := gd.new_dictionary_default(); defer gd.free_dictionary(server)
	values := gd.variant_from_array(&urls); wiregd.set(&server, "urls", values)
	wiregd.set_string(&server, "username", string(g.username[:rel.fixed_count(g.username)]))
	wiregd.set_string(&server, "credential", string(g.credential[:rel.fixed_count(g.credential)]))
	servers := gd.new_array_default(); defer gd.free_array(servers)
	entry := gd.variant_from_dictionary(&server); defer gd.variant_destroy(&entry); gd.array_append(&servers, entry)
	config := gd.new_dictionary_default(); defer gd.free_dictionary(config)
	list := gd.variant_from_array(&servers); wiregd.set(&config, "iceServers", list)
	wiregd.set_string(&config, "iceTransportPolicy", g.relay_only ? "relay" : "all")
	value := gd.variant_from_dictionary(&config); defer gd.variant_destroy(&value)
	text := gd.json_stringify(value, gd.string_empty(), false, false); defer gd.free_string(text)
	json := gd.gd_string_to_odin(text, context.allocator)
	if transportgd.rtc_ice_validate(json) != .None {delete(json); return "", false}
	return json, true
}
