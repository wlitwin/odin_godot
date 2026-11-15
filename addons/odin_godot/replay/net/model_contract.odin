package replay_net

// Compute the negotiated schema/config contract without allocating a simulation
// timeline or creating a connection. Used before downloading a durable world.
model_contract :: proc(model: Model($S, $C, $A, $E, $N), cfg: Config, allocator := context.allocator) -> (u64, Error) {
    if !config_valid(cfg) ||
       N < 1 ||
       N > 8 ||
       model.control_timing > .Latest_Observation ||
       model.action_timing > .Receipt ||
       !action_schedule_valid(model.action_schedule) ||
       !authority_policy_valid(model.authority) ||
       !replication_config_valid(model.replication) {
        return 0, .Invalid_Config
    }

    codecs: Codecs
    defer codecs_destroy(&codecs)

    if !codecs_init(&codecs, S, C, A, E, N, allocator, model.replication.id != 0) {
        return 0, .Invalid_Schema
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
