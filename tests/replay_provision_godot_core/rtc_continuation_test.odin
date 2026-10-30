package provision_godot_test

import "core:testing"
import transportgd "godot:replay/godot/transport"

@(test)
rtc_continuation_requires_exact_room_role_and_authenticated_resumption :: proc(t: ^testing.T) {
	room := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	cfg := transportgd.Rtc_Config{room = room, resume_signaling = true, authorize = proc(user: rawptr, challenge, room: string, create: bool) -> string {return ""}}
	value := transportgd.Rtc_Continuation{peer = 2, token = {0 = 1}}; copy(value.room[:], transmute([]u8)room)
	testing.expect(t, transportgd.rtc_continuation_valid(value, cfg))
	runtime := transportgd.Rtc{ready = true, registered = true, id = 2, room = room, config = cfg, resume_token = "01000000000000000000000000000000"}
	saved, available := transportgd.rtc_continuation(&runtime); testing.expect(t, available && saved == value)
	runtime.registered = false; _, available = transportgd.rtc_continuation(&runtime); testing.expect(t, !available)
	runtime.registered, runtime.reconnecting = true, true; _, available = transportgd.rtc_continuation(&runtime); testing.expect(t, !available)
	runtime.reconnecting, runtime.error = false, .Authentication; _, available = transportgd.rtc_continuation(&runtime); testing.expect(t, !available)
	changed := value; changed.room[0] = 'f'; testing.expect(t, !transportgd.rtc_continuation_valid(changed, cfg))
	changed = value; changed.token = {}; testing.expect(t, !transportgd.rtc_continuation_valid(changed, cfg))
	changed = value; changed.peer = 1; testing.expect(t, !transportgd.rtc_continuation_valid(changed, cfg))
	changed = value; changed.host = true; testing.expect(t, !transportgd.rtc_continuation_valid(changed, cfg))
	cfg.authorize = nil; testing.expect(t, !transportgd.rtc_continuation_valid(value, cfg))
	cfg.authorize = proc(user: rawptr, challenge, room: string, create: bool) -> string {return ""}
	cfg.resume_signaling = false; testing.expect(t, !transportgd.rtc_continuation_valid(value, cfg))
	testing.expect(t, transportgd.rtc_continuation_valid({}, cfg))
}
