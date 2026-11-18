package replay_net

import "core:fmt"
import "core:strings"
import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

// Copied diagnostic data. It remains valid after failed initialization destroys
// codecs, temporary schemas, or the partially constructed runner. No destroy
// call or allocator is needed. Paths/messages larger than the buffers are
// explicitly marked truncated rather than retaining a borrowed pointer.
Setup_Report :: struct {
    error:                     Error,
    schema_error:              sc.Error,
    frame_error:               r.Error,
    cleanup_error:             Error,
    path, message:             [512]u8,
    path_count, message_count: u16,
    truncated:                 bool,
}

setup_problem :: proc(error: Error, path, message: string) -> (report: Setup_Report) {
    report.error = error
    report.path_count = setup_copy(report.path[:], path)
    report.message_count = setup_copy(report.message[:], message)
    report.truncated = int(report.path_count) != len(path) || int(report.message_count) != len(message)
    return
}

@(private)
setup_copy :: proc(destination: []u8, text: string) -> u16 {
    count := min(len(destination), len(text))

    if count < len(text) {
        for count > 0 && text[count] & 0xc0 == 0x80 {
            count -= 1
        }
    }

    return u16(copy(destination, transmute([]u8)text[:count]))
}

setup_path :: proc(report: ^Setup_Report) -> string {
    return report == nil ? "" : transmute(string)report.path[:report.path_count]
}

setup_message :: proc(report: ^Setup_Report) -> string {
    return report == nil ? "" : transmute(string)report.message[:report.message_count]
}

setup_describe :: proc(report: ^Setup_Report, allocator := context.temp_allocator) -> string {
    if report == nil || report.error == .None {
        return ""
    }

    if report.cleanup_error != .None {
        return fmt.aprintf(
            "%s: %s (%v); cleanup still needs attention (%v)%s",
            setup_path(report),
            setup_message(report),
            report.error,
            report.cleanup_error,
            report.truncated ? " [diagnostic truncated]" : "",
            allocator = allocator,
        )
    }

    return fmt.aprintf(
        "%s: %s (%v)%s",
        setup_path(report),
        setup_message(report),
        report.error,
        report.truncated ? " [diagnostic truncated]" : "",
        allocator = allocator,
    )
}

@(private)
setup_fail :: proc(out: ^Setup_Report, error: Error, path, message: string) -> Error {
    if out != nil {
        out^ = setup_problem(error, path, message)
    }

    return error
}

@(private)
setup_assign :: proc(out: ^Setup_Report, report: Setup_Report) -> Error {
    if out != nil {
        out^ = report
    }

    return report.error
}

// Fallback for an underlying owner/transport/allocation failure. More detailed
// checks populate the report first; this never replaces that original cause.
setup_finish :: proc(out: ^Setup_Report, error: Error, path, message: string) {
    if out != nil && error != .None && out.error == .None {
        cleanup := out.cleanup_error
        out^ = setup_problem(error, path, message)
        out.cleanup_error = cleanup
    }
}

@(private)
Setup_Range :: struct {
    path:             string,
    value, low, high: i64,
    rule:             string,
}

@(private)
setup_range :: proc(check: Setup_Range) -> (report: Setup_Report) {
    _ = setup_range_valid(check, &report)
    return
}

@(private)
setup_range_valid :: proc(check: Setup_Range, out: ^Setup_Report) -> bool {
    if check.value >= check.low && check.value <= check.high {
        return true
    }

    if out != nil {
        out^ = setup_problem(
            .Invalid_Config,
            check.path,
            fmt.tprintf("%s; expected %d..%d, got %d", check.rule, check.low, check.high, check.value),
        )
    }

    return false
}

// The same checks used by startup and checkpoint validation, available before
// opening a transport. Begin with DEFAULT_CONFIG and change only needed fields.
config_check :: proc(cfg: Config) -> (report: Setup_Report) {
    _ = config_validate(cfg, &report)
    return
}

@(private)
config_validate :: proc(cfg: Config, out: ^Setup_Report = nil) -> bool {
    if cfg.epoch == 0 {
        setup_fail(out, .Invalid_Config, "network.epoch", "must be nonzero; start with DEFAULT_CONFIG")
        return false
    }

    if cfg.content == 0 {
        setup_fail(out, .Invalid_Config, "network.content", "must be a nonzero game content identity")
        return false
    }

    for check in ([]Setup_Range {
            {"network.hz", i64(cfg.hz), 1, 240, "supported tick rate"},
            {"network.history", i64(cfg.history), 32, 1024, "supported retained history"},
        }) {
        if !setup_range_valid(check, out) {
            return false
        }
    }

    if !setup_range_valid(
        {"network.lead", i64(cfg.lead), 2, i64(cfg.history) - 1, "lead must be less than history"},
        out,
    ) {
        return false
    }

    if !setup_range_valid(
        {"network.input_delay_max", i64(cfg.input_delay_max), 0, INPUT_DELAY_MAX, "supported local input delay"},
        out,
    ) {
        return false
    }

    for check in ([]Setup_Range {
            {
                "network.max_prediction",
                i64(cfg.max_prediction),
                i64(cfg.lead) + 2,
                i64(cfg.history) - 3,
                "must be at least lead + 2 and less than history - 2",
            },
            {
                "network.max_future",
                i64(cfg.max_future),
                max(i64(cfg.lead), i64(cfg.input_delay_max)) + 2,
                i64(cfg.history) - 1,
                "must cover lead + 2 and input_delay_max + 2, and be less than history",
            },
            {"network.snapshot_every", i64(cfg.snapshot_every), 1, 30, "supported snapshot interval"},
            {
                "network.watch_delay",
                i64(cfg.watch_delay),
                0,
                i64(cfg.history / 2) - 1,
                "must be less than history / 2",
            },
            {"network.packets_per_pump", i64(cfg.packets_per_pump), 1, 256, "supported packet budget"},
            {"network.bytes_per_pump", i64(cfg.bytes_per_pump), 65536, 1024 * 1024, "supported receive byte budget"},
            {"network.snapshot_history", i64(cfg.snapshot_history), 2, 64, "supported snapshot cache size"},
            {
                "network.egress_bytes_per_second",
                i64(cfg.egress_bytes_per_second),
                8192,
                16 * 1024 * 1024,
                "supported send rate",
            },
            {
                "network.egress_bytes_per_pump",
                i64(cfg.egress_bytes_per_pump),
                8192,
                1024 * 1024,
                "supported send byte budget",
            },
            {
                "network.unreliable_packet_limit",
                i64(cfg.unreliable_packet_limit),
                512,
                65536,
                "supported unreliable packet size",
            },
            {"network.max_rewind", i64(cfg.max_rewind), 0, i64(cfg.history) - 1, "must be less than history"},
            {
                "network.max_view_span",
                i64(cfg.max_view_span),
                1,
                i64(cfg.history) - 1,
                "must be nonzero and less than history",
            },
            {"network.view_slack", i64(cfg.view_slack), 0, 30, "supported view slack"},
        }) {
        if !setup_range_valid(check, out) {
            return false
        }
    }

    if cfg.timeout_ms < 1000 || cfg.timeout_ms > 120000 {
        if out != nil {
            out^ = setup_problem(
                .Invalid_Config,
                "network.timeout_ms",
                fmt.tprintf("expected 1000..120000 milliseconds, got %d", cfg.timeout_ms),
            )
        }

        return false
    }

    return true
}

// Structural model preflight. No gameplay callbacks are invoked here; startup
// checks initial state/neutral input only after acquiring their execution owners.
model_check :: proc(model: Model($S, $C, $A, $E, $N)) -> Setup_Report {
    if model.step == nil && model.step_view == nil {
        return setup_problem(.Invalid_Model, "model.step", "provide step or step_view")
    }

    if model.control_valid == nil {
        return setup_problem(.Invalid_Model, "model.control_valid", "required control validation callback is missing")
    }

    if model.hold == nil {
        return setup_problem(.Invalid_Model, "model.hold", "required held-input callback is missing")
    }

    if model.state_valid == nil {
        return setup_problem(.Invalid_Model, "model.state_valid", "required state validation callback is missing")
    }

    return model_policy_check(model)
}

@(private)
model_policy_check :: proc(model: Model($S, $C, $A, $E, $N), include_group := true) -> Setup_Report {
    if include_group && !group_config_valid(model.group) {
        if model.group.id == 0 {
            return setup_problem(
                .Invalid_Model,
                "model.group.id",
                "provide a nonzero policy id when group callbacks are set",
            )
        }

        if model.group.project == nil {
            return setup_problem(.Invalid_Model, "model.group.project", "required when group.id is nonzero")
        }

        return setup_problem(.Invalid_Model, "model.group.valid", "required when group.id is nonzero")
    }

    if !replication_config_valid(model.replication) {
        if model.replication.id == 0 {
            return setup_problem(
                .Invalid_Model,
                "model.replication.id",
                "provide a nonzero policy id when replication callbacks are set",
            )
        }

        if model.replication.project == nil {
            return setup_problem(
                .Invalid_Model,
                "model.replication.project",
                "required when replication.id is nonzero",
            )
        }

        if model.replication.valid == nil {
            return setup_problem(.Invalid_Model, "model.replication.valid", "required when replication.id is nonzero")
        }

        return setup_problem(.Invalid_Model, "model.replication.event", "required when replication.id is nonzero")
    }

    if model.control_timing > .Latest_Observation {
        return setup_problem(.Invalid_Model, "model.control_timing", "choose Scheduled or Latest_Observation")
    }

    if model.action_timing > .Receipt {
        return setup_problem(.Invalid_Model, "model.action_timing", "choose a supported Action_Timing value")
    }

    if !action_schedule_valid(model.action_schedule) {
        return setup_problem(
            .Invalid_Model,
            model.action_schedule.id == 0 ? "model.action_schedule.id" : "model.action_schedule.timing",
            "a nonzero id and timing callback must be supplied together",
        )
    }

    if !authority_policy_valid(model.authority) {
        return setup_problem(
            .Invalid_Model,
            model.authority.id == 0 ? "model.authority.id" : "model.authority.apply",
            "a nonzero id and apply callback must be supplied together",
        )
    }

    return {}
}

@(private)
schema_setup :: proc(
    schema: ^sc.Schema,
    type: typeid,
    name: string,
    options: sc.Options,
    allocator: mem.Allocator,
) -> Setup_Report {
    detail := sc.init(schema, type, options, allocator)

    if detail.error == .None {
        return {}
    }

    hint := "schema initialization failed; inspect the schema error"

    #partial switch detail.error {
    case .Platform_Integer:
        hint = "use a fixed-width integer such as i32, u32, i64 or u64"
    case .Unsupported_Type:
        hint = "use bounded value state; pointers, strings, slices and maps cannot be encoded"
    case .Invalid_Tag:
        hint = "the replay field tag is invalid; check its spelling and supported options"
    case .Limit:
        hint = "schema field count, nesting or wire bytes exceed the configured limits"
    case .Allocation_Failed:
        hint = "schema metadata allocation failed; check the allocator and its capacity"
    case:
    }

    report := setup_problem(
        .Invalid_Schema,
        fmt.tprintf("%s%s", name, strings.trim_prefix(detail.path, "$")),
        fmt.tprintf("%v: %s", detail.error, hint),
    )
    report.schema_error = detail.error
    return report
}
