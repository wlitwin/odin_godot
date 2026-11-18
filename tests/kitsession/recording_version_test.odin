package kit_session_test

import "core:testing"
import ksess "godot:kit/session"

expect_recording_refusal :: proc(t: ^testing.T, bytes: []u8, unchecked: bool) {
    target: Peer_Box
    box_make(&target, 300)
    defer box_destroy(&target)
    if unchecked {ksess.session_configure(&target.s, {fingerprint = ksess.FINGERPRINT_NONE})}
    ksess.session_client_start(&target.s, TOKEN_ALICE, "alice")
    testing.expect_value(t, ksess.session_replay(&target.s, bytes), 0)
    testing.expect(t, !target.s.joined && len(target.s.reg.entries) == 0)
}

@(test)
recordings_gate_protocol_and_schema_before_welcome :: proc(t: ^testing.T) {
    modes := [2]bool{false, true}
    for unchecked in modes {
        host, client, valid: Peer_Box
        box_make(&host, 1); box_make(&client, 100); box_make(&valid, 200)
        defer {box_destroy(&host); box_destroy(&client); box_destroy(&valid)}
        if unchecked {
            ksess.session_configure(&host.s, {fingerprint = ksess.FINGERPRINT_NONE})
            ksess.session_configure(&client.s, {fingerprint = ksess.FINGERPRINT_NONE})
            ksess.session_configure(&valid.s, {fingerprint = ksess.FINGERPRINT_NONE})
        }
        ksess.session_host_start(&host.s, "host")
        ksess.session_client_start(&client.s, TOKEN_ALICE, "alice")
        ksess.session_record_start(&client.s)
        ksess.session_client_join(&client.s)
        pump([]^Peer_Box{&host, &client})
        original := ksess.session_recording(&client.s)
        ksess.session_client_start(&valid.s, TOKEN_ALICE, "alice")
        testing.expect(t, ksess.session_replay(&valid.s, original) > 0 && valid.s.joined)
        corrupted := make([]u8, len(original))
        defer delete(corrupted)
        copy(corrupted, original)
        offsets := [4]int{0, 4, 6, 14} // magic, format, protocol, schema
        for offset in offsets {
            corrupted[offset] ~= 1
            expect_recording_refusal(t, corrupted, unchecked)
            corrupted[offset] ~= 1
        }
        expect_recording_refusal(t, original[ksess.RECORDING_HEADER_BYTES:], unchecked)
        for n in 0 ..< ksess.RECORDING_HEADER_BYTES {
            expect_recording_refusal(t, original[:n], unchecked)
        }
    }
}
