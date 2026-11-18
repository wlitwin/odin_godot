package replay_godot

import "core:fmt"
import net "godot:replay/net"

// The last open/resume attempt, copied independently of the Session's runtime.
// Failed setup cleanup does not erase it. A new attempt or explicit close does.
session_setup_report :: proc(s: ^Session($S, $C, $A, $E, $N)) -> net.Setup_Report {
    return s.setup_report
}

session_setup_message :: proc(s: ^Session($S, $C, $A, $E, $N), allocator := context.temp_allocator) -> string {
    return net.setup_describe(&s.setup_report, allocator)
}

@(private)
session_setup_fail :: proc(out: ^net.Setup_Report, error: net.Error, path, message: string) -> net.Error {
    if out != nil {
        out^ = net.setup_problem(error, path, message)
    }

    return error
}

// Pure option checks that can run before opening engine transports. Actual
// model/state/schema checks remain in the network runner's owned setup path.
session_options_check :: proc(options: Session_Options) -> net.Setup_Report {
    if options.role > .Observer {
        return net.setup_problem(.Invalid_Config, "options.role", "choose Solo, Host, Server, Client or Observer")
    }

    if options.discover_epoch && options.network.require_permit {
        return net.setup_problem(
            .Invalid_Config,
            "options.discover_epoch",
            "must be false when network.require_permit is true",
        )
    }

    if report := net.config_check(options.network); report.error != .None {
        return report
    }

    if options.role == .Solo {
        return {}
    }

    if options.backend > .Steam {
        return net.setup_problem(.Invalid_Config, "options.backend", "choose Enet, Rtc or Steam")
    }

    if options.backend == .Enet {
        if options.port == 0 {
            return net.setup_problem(.Invalid_Config, "options.port", "ENet needs a port in 1..65535")
        }

        if (options.role == .Client || options.role == .Observer) &&
           (options.address == nil || string(options.address) == "") {
            return net.setup_problem(
                .Invalid_Config,
                "options.address",
                "ENet clients need a nonempty authority address",
            )
        }
    }

    names := [?]string {
        "options.latency_ms",
        "options.jitter_ms",
        "options.loss_permyriad",
        "options.duplicate_permyriad",
    }
    values := [?]u32{options.latency_ms, options.jitter_ms, options.loss_permyriad, options.duplicate_permyriad}

    for value, i in values {
        if value > 10000 {
            return net.setup_problem(.Invalid_Config, names[i], fmt.tprintf("expected 0..10000, got %d", value))
        }
    }

    if options.replication.room == 0 {
        return net.setup_problem(
            .Invalid_Config,
            "options.replication.room",
            "must be nonzero; start with SESSION_OPTIONS or DEFAULT_LINK_CONFIG",
        )
    }

    return {}
}
