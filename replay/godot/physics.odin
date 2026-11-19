package replay_godot

import r "godot:replay"
import net "godot:replay/net"
import storagegd "godot:replay/godot/storage"

// Explicit complete-mode entry to the existing Session. The image is borrowed
// during initialization; the underlying Timeline owns its independent clone.
// Client/Observer roles use ordinary session_open and receive a complete Welcome.
// There is no additional stepping loop, history, or mutable model context here.
session_open_complete :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    initial: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
    model: net.Model(S, C, A, E, N),
    options: Session_Options,
    allocator := context.allocator,
    ownership: Session_Ownership = {},
) -> (
    result: net.Error,
) {
    report: net.Setup_Report
    stage := "session.complete"

    defer {
        net.setup_finish(&report, result, stage, "complete Session initialization failed at this step")
        s.setup_report = report
    }

    if s.ready {
        return session_setup_fail(
            &report,
            .Invalid_Config,
            "session.ready",
            "close the current Session before opening another",
        )
    }

    if s.cleanup {
        return session_setup_fail(
            &report,
            .Wrong_Phase,
            "session.cleanup",
            "finish pending session_close cleanup before opening another Session",
        )
    }

    if !model.complete_state {
        return session_setup_fail(
            &report,
            .Invalid_Config,
            "model.complete_state",
            "must be true for session_open_complete",
        )
    }

    if initial == nil {
        return session_setup_fail(&report, .Invalid_Config, "initial", "a complete checkpoint is required")
    }

    if options.reuse_equal_corrections {
        return session_setup_fail(
            &report,
            .Invalid_Config,
            "options.reuse_equal_corrections",
            "game-value equality cannot establish complete physics equality; disable this option",
        )
    }

    if options.role != .Solo && options.role != .Host && options.role != .Server {
        return session_setup_fail(
            &report,
            .Invalid_Config,
            "options.role",
            "complete authority startup needs Solo, Host or Server; clients use session_open",
        )
    }

    if detail := session_options_check(options); detail.error != .None {
        report = detail
        return detail.error
    }

    if error := session_begin(s, model, options, allocator, ownership, &report); error != .None {
        return error
    }

    s.options = options
    s.options.address = nil
    s.options.rtc = {}
    s.options.steam.peer = nil

    if error := session_connect(s, options, setup = &report); error != .None {
        report.cleanup_error = session_close(s)
        return error
    }

    s.token = options.token

    if s.token == (net.Token{}) {
        s.token = storagegd.session_token()
    }

    if error := net.server_init_complete(
        &s.server,
        initial,
        model,
        s.wire,
        options.network,
        local_seat = options.role == .Server ? 0 : 1,
        permit = options.permit,
        incarnation = options.incarnation,
        allocator = s.allocator,
        ownership = session_runner_ownership(s, true),
        setup = &report,
    ); error != .None {
        report.cleanup_error = session_close(s)
        return error
    }

    s.server.epoch_discovery = options.discover_epoch

    if s.server.local_seat != 0 {
        stage = "options.token"

        if error := net.server_set_local_token(&s.server, s.token); error != .None {
            report.cleanup_error = session_close(s)
            return error
        }
    }

    r.clock_init(&s.clock, options.network.hz)
    s.ready = true
    return .None
}

// Latest projected simulation values, including player prediction. Draw interacting
// objects from session_render_sample. Use session_checkpoint for durable exports.
session_values :: proc(s: ^Session($S, $C, $A, $E, $N)) -> (r.Frame(S), bool) {
    if !s.ready {
        return {}, false
    }

    if s.authority {
        return r.current_values(&s.server.timeline)
    }

    if s.client.phase != .Running && !(s.client.recovering && s.client.has_world) {
        return {}, false
    }

    return r.current_values(&s.client.timeline)
}

session_checkpoint :: proc(
    s: ^Session($S, $C, $A, $E, $N),
    tick: u64,
) -> (
    r.Complete_Checkpoint(S, net.Net_Event(E)),
    net.Error,
) {
    if !s.ready {
        return {}, .Not_Initialized
    }

    checkpoint: r.Complete_Checkpoint(S, net.Net_Event(E))
    error: r.Error

    if s.authority {
        checkpoint, error = r.capture_complete(&s.server.timeline, tick, s.allocator)
    } else {
        checkpoint, error = r.capture_complete(&s.client.timeline, tick, s.allocator)
    }

    return checkpoint, error == .None ? net.Error.None : net.Error.Incomplete_State
}
