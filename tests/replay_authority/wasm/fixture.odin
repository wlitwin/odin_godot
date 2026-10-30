package replay_authority_wasm

import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import net "godot:replay/net"
import sample "godot:tests/replay_recovery/shared/archive"
import tr "godot:replay/transport"

@(require)
instantiate :: proc() {
	record := auth.record_make(1, sample.CONTENT, {1, 1})
	c: auth.Coordinator
	auth.coordinator_init(&c, record, proc(user: rawptr, expected: u64, next: auth.Record) -> bool {return false}, nil, 0)
	clock := auth.native_clock()
	clock.read(clock.user) // unsupported browser clock must fail closed
	l: auth.Lease
	auth.lease_init(&l, {1, 1}, 1, sample.CONTENT, {read = proc(user: rawptr) -> (u64, bool) {return 0, true}}, true)
	request, _ := auth.lease_request(&l)
	view, _ := auth.coordinator_view(&c, 0)
	auth.lease_accept(&l, request, view)
	auth.lease_permit(&l)
	prepared: auth.Prepared
	rx: rec.Receiver(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS)
	auth.prepared_copy(&prepared, &rx, rec.Archive{})
	s: sample.Server
	auth.prepared_restore(&prepared, &s, sample.model(), {}, &l, 1)
	auth.prepared_capture(&prepared, &s, 1, 1)
	service: auth.Service
	keys := [1]auth.Credential{{identity = {1, 1}, key = {0 = 1}}}
	auth.service_init(&service, record, proc(user: rawptr, expected: u64, next: auth.Record) -> bool {return false}, nil,
	                  l.clock, tr.Transport{}, keys[:])
	auth.service_pump(&service)
	client: auth.Rpc_Client
	auth.rpc_client_init(&client, &l, auth.Key{0 = 1}, auth.Nonce{0 = 2}, tr.Transport{})
	auth.rpc_begin(&client, {verb = .Query})
	auth.rpc_client_pump(&client)
	auth.rpc_completed(&client)
	auth.rpc_client_destroy(&client)
	auth.service_destroy(&service)
	auth.prepared_destroy(&prepared)
	net.server_destroy(&s)
}
