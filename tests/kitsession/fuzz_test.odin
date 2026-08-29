package kit_session_test

// Always-on deterministic decoder corpus. The session tests already exercise
// every happy-path packet through the in-memory transport; these properties
// systematically walk truncation and semantic-size boundaries around them.

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"

@(test)
welcome_decoder_commits_only_complete_packets :: proc(t: ^testing.T) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	SES_WELCOME_TEST :: u8(1)
	knet.write_u8(&w, SES_WELCOME_TEST)
	knet.write_player_id(&w, knet.Player_Id(2))
	knet.write_u16(&w, 2)
	for name, i in ([]string{"host", "alice"}) {
		knet.write_player_id(&w, knet.Player_Id(i + 1))
		knet.write_string(&w, name)
		knet.write_bool(&w, true)
		knet.write_bool(&w, false)
		knet.write_bool(&w, false)
	}
	knet.write_bool(&w, true)
	packet := knet.writer_bytes(&w)

	// The last AOI byte is intentionally optional for old peers. Every prefix
	// before that compatibility boundary must commit no roster and no seat.
	for cut in 0 ..< len(packet) - 1 {
		client: Peer_Box
		box_make(&client, 100)
		ksess.session_client_start(&client.s, TOKEN_ALICE, "alice")
		r := knet.reader_make(packet[:cut])
		ksess.session_handle_packet(&client.s, ksess.HOST_PEER, &r)
		testing.expect(t, !client.s.joined)
		testing.expect_value(t, len(client.s.players), 0)
		box_destroy(&client)
	}

	client: Peer_Box
	box_make(&client, 100)
	defer box_destroy(&client)
	ksess.session_client_start(&client.s, TOKEN_ALICE, "alice")
	r := knet.reader_make(packet)
	ksess.session_handle_packet(&client.s, ksess.HOST_PEER, &r)
	testing.expect(t, client.s.joined)
	testing.expect_value(t, len(client.s.players), 2)
}

App_Fuzz_Probe :: struct {
	calls: int,
}

@(private = "file")
app_fuzz_handler :: proc(
	user: rawptr,
	from: knet.Player_Id,
	from_peer: ksess.Peer_Id,
	r: ^knet.Reader,
) {
	(cast(^App_Fuzz_Probe)user).calls += 1
}

@(test)
packet_and_app_ceilings_precede_dispatch :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}
	probe: App_Fuzz_Probe
	TAG :: u8(7)
	ksess.session_app_route(&host.s, TAG, &probe, app_fuzz_handler)
	ksess.session_host_start(&host.s, "host")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	message := make([]u8, ksess.APP_MESSAGE_MAX_BYTES + 3)
	defer delete(message)
	message[0] = ksess.SES_APP
	message[1] = TAG
	r := knet.reader_make(message)
	bad := ksess.session_malformed(&host.s)
	ksess.session_handle_packet(&host.s, alice.peer, &r)
	testing.expect(t, r.err)
	testing.expect_value(t, probe.calls, 0)
	testing.expect_value(t, ksess.session_malformed(&host.s), bad + 1)

	packet := make([]u8, knet.MAX_PACKET_BYTES + 1)
	defer delete(packet)
	packet[0] = ksess.SES_APP
	packet[1] = TAG
	r = knet.reader_make(packet)
	bad = ksess.session_malformed(&host.s)
	ksess.session_handle_packet(&host.s, alice.peer, &r)
	testing.expect(t, r.err)
	testing.expect_value(t, probe.calls, 0)
	testing.expect_value(t, ksess.session_malformed(&host.s), bad + 1)
}

@(test)
resume_decoder_preflights_every_strict_prefix :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "host")
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksess.session_snapshot(&host.s, &w)
	snapshot := knet.writer_bytes(&w)

	for cut in 0 ..< len(snapshot) {
		candidate: Peer_Box
		box_make(&candidate, 2)
		ok := ksess.session_host_resume(&candidate.s, knet.Player_Id(1), "heir", snapshot[:cut])
		testing.expect(t, !ok)
		testing.expect(t, !candidate.s.joined && !candidate.s.is_host)
		testing.expect_value(t, len(candidate.s.players), 0)
		box_destroy(&candidate)
	}
}
