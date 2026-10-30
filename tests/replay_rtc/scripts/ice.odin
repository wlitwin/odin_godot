//gd:extends Node
//gd:class IceValidation
package replay_rtc_probe

import "core:fmt"
import gd "godot:godot"
import auth "godot:replay/authority"
import rgd "godot:replay/godot"
import transportgd "godot:replay/godot/transport"

IceValidation :: struct {owner: gd.Node}
ice_validation_ready :: proc(self: ^IceValidation) {
	Case :: struct {json: string, expected: transportgd.Rtc_Ice_Error}
	cases := [?]Case{
		{"", .None}, {`{}`, .None}, {`{"iceServers":[]}`, .None},
		{`{"iceTransportPolicy":"relay","iceServers":[]}`, .Policy},
		{`{"iceTransportPolicy":"relay"}`, .Policy},
		{`{"iceTransportPolicy":"unknown"}`, .Policy},
		{`{"iceTransportPolicy":false}`, .Policy},
		{`{"iceServers":"turn:host"}`, .Servers}, {`{"iceServers":[3]}`, .Servers},
		{`{"iceServers":[{"urls":[]}]}`, .Url},
		{`{"iceServers":[{"urls":"https://host"}]}`, .Url},
		{`{"iceServers":[{"urls":"stun:host:65536"}]}`, .Url},
		{`{"iceServers":[{"urls":"stun:host/path"}]}`, .Url},
		{`{"iceServers":[{"urls":"turn://host","username":"u","credential":"p"}]}`, .Url},
		{`{"iceServers":[{"urls":"turn:?transport=udp","username":"u","credential":"p"}]}`, .Url},
		{`{"iceServers":[{"urls":"turn:host"}]}`, .Credentials},
		{`{"iceServers":[{"urls":"turn:host","username":true,"credential":"p"}]}`, .Credentials},
		{`{"iceServers":[{"urls":"stun:host:3478"}]}`, .None},
		{`{"iceTransportPolicy":"relay","iceServers":[{"urls":["turn:127.0.0.1:3478?transport=tcp","turns:[::1]:5349"],"username":"u","credential":"p"}]}`, .None},
		{`[]`, .Json}, {`{"iceServers":`, .Json},
	}
	for item, index in cases {
		got := transportgd.rtc_ice_validate(item.json)
		if got != item.expected {gd.print_str(fmt.tprintf("RTC_ICE_FAIL case=%d expected=%v got=%v", index, item.expected, got)); gd.scene_tree_quit(gd.get_tree(self.owner), 1); return}
	}
	large: [8193]u8; for &b in large {b = ' '}
	if transportgd.rtc_ice_validate(string(large[:])) != .Size {gd.scene_tree_quit(gd.get_tree(self.owner), 1); return}
	party: rgd.Party; defer rgd.party_close(&party)
	endpoint, _ := auth.endpoint("127.0.0.1", 45001)
	text := `{"iceTransportPolicy":"relay","iceServers":[{"urls":"turn:127.0.0.1:3478","username":"u","credential":"p"}]}`
	mutable := make([]u8, len(text)); defer delete(mutable); copy(mutable, transmute([]u8)text)
	storage := rgd.Party_Storage{
		open = proc(user: rawptr, slot: string) -> (rgd.Enrollment_Backing, bool) {return {}, false},
		recent = proc(user: rawptr, key: string) -> (u64, u64, rgd.Party_Error) {return 0, 0, .None},
		select = proc(user: rawptr, key: string, room, revision: u64) -> rgd.Party_Error {return .Storage},
	}
	if !rgd.party_open(&party, {service = "wss://example.test", namespace = "ice-fixture", content = 55, endpoint = endpoint, invite_uses = 1, ice_json = string(mutable), storage = storage}) {gd.scene_tree_quit(gd.get_tree(self.owner), 1); return}
	mutable[0] = '!'
	if party.config.ice_json != text {gd.scene_tree_quit(gd.get_tree(self.owner), 1); return}
	party.ready = true; party.grant = {room = 44, content = 55, identity = {1, 1}, key = {0 = 1}, token = {0 = 2}}
	session := rgd.SESSION_OPTIONS; session.network.content = 55
	options, ok := rgd.party_room_options(&party, session)
	if !ok || options.session.rtc.ice_json != text {gd.scene_tree_quit(gd.get_tree(self.owner), 1); return}
	gd.print_str(fmt.tprintf("RTC_ICE_CONFIG_OK cases=%d owned=true room_propagation=true", len(cases) + 1))
	gd.scene_tree_quit(gd.get_tree(self.owner), 0)
}
