package replay_godot

import "core:strings"
import gd "godot:godot"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import net "godot:replay/net"
import tr "godot:replay/transport"

Provision_Connection :: struct {
	ready: bool,
	socket: Websocket,
	client: p.Client,
	browser_clock: Browser_Lease_Clock,
	url: string,
	tls: gd.Tls_Options,
	last_reconnect: u64,
}

// TLS verifies the server. Optional native client TLSOptions may supply a
// private CA, but unsafe/server options are refused by websocket_join. Browser
// verification belongs to its trust store. Plain WS requires an explicit local
// development opt-in and a literal loopback authority without userinfo.
provision_connect :: proc(c: ^Provision_Connection, url: string, tls: gd.Tls_Options = nil, local_development: bool = false) -> p.Error {
	if c.ready || !provision_url_valid(url, local_development) {return .Invalid}
	if !websocket_join(&c.socket, url, tls = tls) {return .Not_Ready}
	clock: auth.Clock_Source
	when gd.IS_WEB {clock = browser_lease_clock(&c.browser_clock)} else {clock = auth.native_clock()}
	if !p.client_open(&c.client, websocket_transport(&c.socket), clock) {websocket_close(&c.socket); return .Invalid}
	c.url = strings.clone(url)
	if tls != nil {gd.ref_counted_reference(tls); c.tls = tls}
	c.ready = true
	return .None
}
provision_disconnect :: proc(c: ^Provision_Connection) {
	p.client_close(&c.client); websocket_close(&c.socket)
	if c.tls != nil {websocket_unref(c.tls)}
	delete(c.url); c^ = {}
}
provision_request :: proc(c: ^Provision_Connection, request: p.Request) -> p.Error {
	if !c.ready {return .Not_Ready}
	return p.client_begin(&c.client, request)
}
provision_frame :: proc(c: ^Provision_Connection) -> p.Error {
	if !c.ready {return .Not_Ready}
	now, ok := c.client.clock.read(c.client.clock.user)
	if !ok {return .Clock}
	if tr.status(&c.client.wire) == .Disconnected && now >= c.last_reconnect && now - c.last_reconnect >= 500 {
		websocket_close(&c.socket)
		if !websocket_join(&c.socket, c.url, tls = c.tls) {return .Not_Ready}
		c.last_reconnect = now
	}
	return p.client_pump(&c.client)
}

// Borrowed options remain borrowed until room_open. Registration is mandatory
// for a new process; receiving a membership grant is not an authority lease.
room_with_grant :: proc(options: Room_Options, grant: p.Grant) -> (Room_Options, bool) {
	if grant.room == 0 || grant.content == 0 || !auth.identity_valid(grant.identity) || grant.identity.member > auth.MAX_MEMBERS ||
	   ((grant.can_host || grant.infrastructure) && !grant.trusted_authority) || grant.key == (auth.Key{}) || grant.token == (net.Token{}) ||
	   options.session.network.content != grant.content {return {}, false}
	result := options
	result.room, result.identity, result.key = grant.room, grant.identity, grant.key
	result.bootstrap, result.provisioned_incarnation = grant.identity.member == 1, false
	result.session.token, result.session.incarnation = grant.token, 0
	return result, true
}

provision_url_valid :: proc(url: string, local_development: bool = false) -> bool {return p.service_url_valid(url, local_development)}
