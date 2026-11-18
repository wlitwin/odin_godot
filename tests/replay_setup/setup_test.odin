package replay_setup_test

import "core:testing"
import "core:strings"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import sc "godot:replay/schema"

State :: struct {
    score: u32,
}

Control :: struct {
    move: i8,
}

model :: proc($S: typeid) -> net.Model(S, Control, u8, u8, 1) {
    return {
        step = proc(state: ^S, controls: [1]Control, joins, leaves: u64, step: ^r.Step(u8)) {},
        state_valid = proc(state: S) -> bool {
            return true
        },
        control_valid = proc(value: Control) -> bool {
            return value.move >= -1 && value.move <= 1
        },
        hold = proc(value: Control) -> Control {
            return value
        },
    }
}

expect_problem :: proc(t: ^testing.T, report: ^net.Setup_Report, error: net.Error, path: string) {
    testing.expect_value(t, report.error, error)
    testing.expect_value(t, net.setup_path(report), path)
    testing.expect(t, len(net.setup_message(report)) > 0)
    testing.expect(t, strings.contains(net.setup_describe(report), path))
}

@(test)
config_constraints_explain_actual_values :: proc(t: ^testing.T) {
    testing.expect_value(t, net.config_check(net.DEFAULT_CONFIG).error, net.Error.None)
    cfg := net.DEFAULT_CONFIG
    cfg.history = 32 // still has the default 96-tick prediction window
    report := net.config_check(cfg)
    expect_problem(t, &report, .Invalid_Config, "network.max_prediction")
    testing.expect(t, strings.contains(net.setup_message(&report), "history - 2"))
    testing.expect(t, strings.contains(net.setup_message(&report), "96"))
    cfg = net.DEFAULT_CONFIG
    cfg.timeout_ms = max(u64)
    report = net.config_check(cfg)
    expect_problem(t, &report, .Invalid_Config, "network.timeout_ms")
    testing.expect(t, strings.contains(net.setup_message(&report), "18446744073709551615"))
    cfg = net.DEFAULT_CONFIG
    cfg.history = min(int)
    report = net.config_check(cfg)
    expect_problem(t, &report, .Invalid_Config, "network.history")
}

@(test)
model_callbacks_and_values_have_distinct_paths :: proc(t: ^testing.T) {
    server := new(net.Server(State, Control, u8, u8, 1))
    defer free(server)
    defer net.server_destroy(server)
    report: net.Setup_Report
    m := model(State)
    m.hold = nil
    testing.expect_value(t, net.server_init(server, r.Frame(State){}, m, {}, setup = &report), net.Error.Invalid_Model)
    expect_problem(t, &report, .Invalid_Model, "model.hold")
    m = model(State)
    m.neutral.move = 9
    testing.expect_value(t, net.server_init(server, r.Frame(State){}, m, {}, setup = &report), net.Error.Invalid_Model)
    expect_problem(t, &report, .Invalid_Model, "model.neutral")
    m = model(State)
    m.state_valid = proc(value: State) -> bool {
        return value.score <= 5
    }
    testing.expect_value(
        t,
        net.server_init(server, r.Frame(State){state = {99}}, m, {}, setup = &report),
        net.Error.Invalid_Model,
    )
    expect_problem(t, &report, .Invalid_Model, "initial.state")
    testing.expect(t, !server.initialized)
    testing.expect_value(
        t,
        net.server_init(server, r.Frame(State){state = {3}}, m, {}, setup = &report),
        net.Error.None,
    )
    testing.expect_value(t, report.error, net.Error.None)
}

Bad_State :: struct {
    inventory: struct {
        name: string,
    },
}

Platform_State :: struct {
    count: int,
}

@(test)
schema_reports_survive_failed_runner_cleanup_and_copy :: proc(t: ^testing.T) {
    server := new(net.Server(Bad_State, Control, u8, u8, 1))
    defer free(server)
    report: net.Setup_Report
    error := net.server_init(server, r.Frame(Bad_State){}, model(Bad_State), {}, setup = &report)
    testing.expect_value(t, error, net.Error.Invalid_Schema)
    expect_problem(t, &report, error, "State.inventory.name")
    testing.expect_value(t, report.schema_error, sc.Error.Unsupported_Type)
    saved := report
    testing.expect_value(t, net.server_destroy(server), net.Error.None)
    client := new(net.Client(Platform_State, Control, u8, u8, 1))
    defer free(client)

    for _ in 0 ..< 4 {
        testing.expect_value(
            t,
            net.client_init(client, model(Platform_State), {}, net.Token{0 = 1}, setup = &report),
            net.Error.Invalid_Schema,
        )
        expect_problem(t, &report, .Invalid_Schema, "State.count")
        testing.expect_value(t, report.schema_error, sc.Error.Platform_Integer)
        testing.expect(t, strings.contains(net.setup_message(&report), "fixed-width"))
        testing.expect_value(t, net.client_destroy(client), net.Error.None)
    }

    expect_problem(t, &saved, .Invalid_Schema, "State.inventory.name")
    testing.expect_value(t, saved.schema_error, sc.Error.Unsupported_Type)
}

@(test)
contract_and_client_identity_are_actionable :: proc(t: ^testing.T) {
    report: net.Setup_Report
    _, error := net.model_contract(model(Platform_State), net.DEFAULT_CONFIG, setup = &report)
    testing.expect_value(t, error, net.Error.Invalid_Schema)
    expect_problem(t, &report, error, "State.count")
    client := new(net.Client(State, Control, u8, u8, 1))
    defer free(client)
    testing.expect_value(t, net.client_init(client, model(State), {}, {}, setup = &report), net.Error.Invalid_Config)
    expect_problem(t, &report, .Invalid_Config, "token")
    testing.expect_value(
        t,
        net.client_init(client, model(State), {}, net.Token{0 = 1}, authority = 0, setup = &report),
        net.Error.Invalid_Config,
    )
    expect_problem(t, &report, .Invalid_Config, "authority")
}

@(test)
session_preserves_reports_and_clears_them_on_success :: proc(t: ^testing.T) {
    session := new(rgd.Session(State, Control, u8, u8, 1))
    defer free(session)
    options := rgd.SESSION_OPTIONS
    options.token = {
        0 = 1,
    } // pure solo setup does not need a Godot identity lookup
    options.network.history = 0
    testing.expect_value(
        t,
        rgd.session_open(session, r.Frame(State){}, model(State), options),
        net.Error.Invalid_Config,
    )
    report := rgd.session_setup_report(session)
    expect_problem(t, &report, .Invalid_Config, "network.history")
    testing.expect(t, strings.contains(rgd.session_setup_message(session), "network.history"))
    testing.expect(t, !session.ready)
    options = rgd.SESSION_OPTIONS
    options.token = {
        0 = 1,
    }
    m := model(State)
    m.control_valid = nil
    testing.expect_value(t, rgd.session_open(session, r.Frame(State){}, m, options), net.Error.Invalid_Model)
    report = rgd.session_setup_report(session)
    expect_problem(t, &report, .Invalid_Model, "model.control_valid")
    testing.expect_value(t, rgd.session_open(session, r.Frame(State){}, model(State), options), net.Error.None)
    testing.expect_value(t, rgd.session_setup_report(session).error, net.Error.None)
    testing.expect_value(t, rgd.session_close(session), net.Error.None)
    expect_problem(t, &report, .Invalid_Model, "model.control_valid")
}

@(test)
session_schema_and_complete_startup_reports :: proc(t: ^testing.T) {
    session := new(rgd.Session(Bad_State, Control, u8, u8, 1))
    defer free(session)
    options := rgd.SESSION_OPTIONS
    options.token = {
        0 = 1,
    }
    testing.expect_value(
        t,
        rgd.session_open(session, r.Frame(Bad_State){}, model(Bad_State), options),
        net.Error.Invalid_Schema,
    )
    report := rgd.session_setup_report(session)
    expect_problem(t, &report, .Invalid_Schema, "State.inventory.name")
    testing.expect_value(t, report.schema_error, sc.Error.Unsupported_Type)
    testing.expect(t, !session.ready)
    testing.expect_value(t, rgd.session_close(session), net.Error.None)
    m := model(Bad_State)
    m.complete_state = true
    testing.expect_value(t, rgd.session_open_complete(session, nil, m, options), net.Error.Invalid_Config)
    report = rgd.session_setup_report(session)
    expect_problem(t, &report, .Invalid_Config, "initial")
}

@(test)
transport_options_can_be_checked_without_opening_a_socket :: proc(t: ^testing.T) {
    options := rgd.SESSION_OPTIONS
    options.role = .Client
    options.address = nil
    report := rgd.session_options_check(options)
    expect_problem(t, &report, .Invalid_Config, "options.address")
    options.address = "localhost"
    options.loss_permyriad = 10001
    report = rgd.session_options_check(options)
    expect_problem(t, &report, .Invalid_Config, "options.loss_permyriad")
}

@(test)
bounded_diagnostics_mark_truncation :: proc(t: ^testing.T) {
    path: [700]u8

    for &b in path {
        b = 'x'
    }

    report := net.setup_problem(.Invalid_Model, string(path[:]), "invalid")
    testing.expect(t, report.truncated)
    testing.expect_value(t, len(net.setup_path(&report)), 512)
    testing.expect(t, strings.contains(net.setup_describe(&report), "truncated"))
    report = {}
    report.cleanup_error = .Wrong_Phase
    net.setup_finish(&report, .Transport, "transport", "open failed")
    testing.expect_value(t, report.cleanup_error, net.Error.Wrong_Phase)
}

@(test)
restore_checks_report_model_and_epoch_before_generic_checkpoint_failure :: proc(t: ^testing.T) {
    server, restored: net.Server(State, Control, u8, u8, 1)
    defer net.server_destroy(&server)
    defer net.server_destroy(&restored)
    testing.expect_value(
        t,
        net.server_init(&server, r.Frame(State){}, model(State), {}, local_seat = 1),
        net.Error.None,
    )
    token := net.Token {
        0 = 1,
    }
    testing.expect_value(t, net.server_set_local_token(&server, token), net.Error.None)
    point: net.Checkpoint(State, Control, u8, 1)
    defer net.checkpoint_destroy(&point)
    testing.expect_value(t, net.checkpoint_capture(&server, &point), net.Error.None)
    report: net.Setup_Report
    resume := net.Resume_Options {
        epoch      = 2,
        local_seat = 1,
    }
    bad := model(State)
    bad.state_valid = nil
    testing.expect_value(
        t,
        net.server_restore(&restored, &point, bad, {}, resume, setup = &report),
        net.Error.Invalid_Model,
    )
    expect_problem(t, &report, .Invalid_Model, "model.state_valid")
    resume.epoch = 1
    testing.expect_value(
        t,
        net.server_restore(&restored, &point, model(State), {}, resume, setup = &report),
        net.Error.Invalid_Config,
    )
    expect_problem(t, &report, .Invalid_Config, "resume.epoch")
    resume.epoch = 2
    session := new(rgd.Session(State, Control, u8, u8, 1))
    defer free(session)
    options := rgd.SESSION_OPTIONS
    options.token = token
    testing.expect_value(t, rgd.session_resume(session, &point, bad, options, resume), net.Error.Invalid_Model)
    report = rgd.session_setup_report(session)
    expect_problem(t, &report, .Invalid_Model, "model.state_valid")
    testing.expect_value(t, rgd.session_close(session), net.Error.None)
}
