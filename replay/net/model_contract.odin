package replay_net

// Compute the negotiated schema/config contract without allocating a simulation
// timeline or creating a connection. Used before downloading a durable world.
model_contract :: proc(
    model: Model($S, $C, $A, $E, $N),
    cfg: Config,
    allocator := context.allocator,
    setup: ^Setup_Report = nil,
) -> (
    u64,
    Error,
) {
    if setup != nil {
        setup^ = {}
    }

    if report := config_check(cfg); report.error != .None {
        return 0, setup_assign(setup, report)
    }

    if N < 1 || N > 8 {
        return 0, setup_fail(setup, .Invalid_Config, "Seats", "expected 1..8 seats")
    }

    if report := model_policy_check(model, include_group = false); report.error != .None {
        return 0, setup_assign(setup, report)
    }

    codecs: Codecs
    defer codecs_destroy(&codecs)

    if report := codecs_init(&codecs, S, C, A, E, N, allocator, model.replication.id != 0); report.error != .None {
        return 0, setup_assign(setup, report)
    }

    return contract_hash(
            &codecs,
            cfg,
            N,
            model.control_timing,
            replication = model.replication.id,
            action_timing = model.action_timing,
            action_schedule = model.action_schedule.id,
            authority_policy = model.authority.id,
        ),
        .None
}
