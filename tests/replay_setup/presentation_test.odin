package replay_setup_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"

@(test)
presentation_context_requires_live_admitted_storage :: proc(t: ^testing.T) {
    Session :: rgd.Session(State, Control, u8, u8, 1)
    missing: ^Session
    _, ok := rgd.session_presentation(missing)
    testing.expect(t, !ok)
    session := new(Session)
    defer free(session)
    _, ok = rgd.session_presentation(session)
    testing.expect(t, !ok)
    options := rgd.SESSION_OPTIONS
    options.token = {
        0 = 1,
    }
    testing.expect(t, rgd.session_open(session, r.Frame(State){}, model(State), options) == .None)
    first, admitted := rgd.session_presentation(session)
    testing.expect(t, admitted && first.authority && !first.observer && first.seat == 1 && first.epoch == 1)
    testing.expect_value(t, first.reset, u64(0))
    testing.expect_value(t, first.correction_serial, u64(0))
    testing.expect(t, net.server_step(&session.server) == .None)
    next, ready := rgd.session_presentation(session)
    testing.expect(t, ready && next == first)
    session.fenced = true
    next, ready = rgd.session_presentation(session)
    testing.expect(t, ready && next == first, "presentation scope does not grant execution permission")
    session.retained.count = 1
    session.retained.owners[0].realm = max(u64)
    _, ready = rgd.session_presentation(session)
    testing.expect(t, !ready, "invalid retained ownership refuses before reading runtime data")
    session.retained = {}
    testing.expect(t, rgd.session_close(session) == .None)
    _, ready = rgd.session_presentation(session)
    testing.expect(t, !ready)
    correction := net.State_Correction(State) {
        serial = 99,
    }
    testing.expect(t, !rgd.session_correction(session, first, &correction))
    testing.expect_value(t, correction.serial, u64(99))
}

@(test)
authority_roles_preserve_actual_seat_and_epoch :: proc(t: ^testing.T) {
    for seat in 0 ..= 1 {
        session := new(rgd.Session(State, Control, u8, u8, 1))
        defer free(session)
        session.ready, session.authority = true, true
        session.role = seat == 0 ? .Server : .Host
        cfg := net.DEFAULT_CONFIG
        cfg.epoch = 17
        testing.expect(
            t,
            net.server_init(&session.server, r.Frame(State){}, model(State), {}, cfg, local_seat = u16(seat)) == .None,
        )
        defer rgd.session_close(session)
        info, ok := rgd.session_presentation(session)
        testing.expect(t, ok && info.authority && !info.observer)
        testing.expect_value(t, info.seat, u16(seat))
        testing.expect_value(t, info.epoch, u64(17))
    }
}
