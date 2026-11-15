package replay_net

import sc "godot:replay/schema"

// Explicit application conversion when the world schema changes. Inputs, action
// and event schemas and seat count remain shared. Common session/action ledgers
// are retained; the caller maps the complete source world into a target value.
// This grants no authority and leaves source bytes unchanged.
checkpoint_convert_state :: proc(
    bytes: []u8,
    source_model: Model($S, $C, $A, $E, $N),
    source_content: u64,
    target_model: Model($T, C, A, E, N),
    target_content: u64,
    convert: proc(_: S) -> (T, bool),
    allocator := context.allocator,
) -> (
    []u8,
    Error,
) {
    if convert == nil ||
       target_content == 0 ||
       source_model.control_timing != target_model.control_timing ||
       target_model.control_timing > .Latest_Observation ||
       source_model.state_valid == nil ||
       source_model.control_valid == nil ||
       target_model.state_valid == nil ||
       target_model.control_valid == nil {
        return nil, .Invalid_Model
    }

    source: Checkpoint(S, C, A, N)
    defer checkpoint_destroy(&source)

    if err := checkpoint_decode(&source, bytes, source_model, source_content, allocator); err != .None {
        return nil, err
    }

    state, ok := convert(source.frame.state)

    if !ok {
        return nil, .Invalid_Frame
    }

    codec: Checkpoint_Codec
    defer checkpoint_codec_destroy(&codec)

    if err := checkpoint_codec_init(&codec, T, C, A, E, N, true, allocator); err != .None {
        return nil, err
    }

    // Borrow common sections only while encoding the owned target output.
    target := Checkpoint(T, C, A, N) {
        allocator = allocator,
        ready = true,
        header = source.header,
        settings = source.settings,
        frame = {tick = source.frame.tick, state = state},
        held = source.held,
        held_views = source.held_views,
        peers = source.peers,
        actions = source.actions,
        inputs = source.inputs,
        outcomes = source.outcomes,
        banned = source.banned,
        policy_data = source.policy_data,
    }
    target.header.content = target_content
    target.header.contract = contract_hash(
        &codec.network,
        checkpoint_config(target.header, target.settings),
        N,
        target_model.control_timing,
        replication = target_model.replication.id,
        action_timing = target_model.action_timing,
        action_schedule = target_model.action_schedule.id,
        authority_policy = target_model.authority.id,
    )
    maximum :=
        max(codec.network.welcome.wire_size, max(codec.network.snapshot.wire_size, codec.network.facts.wire_size)) +
        sc.HEADER_BYTES

    if int(target.settings.egress_bytes_per_pump) < maximum {
        return nil, .Checkpoint_Contract
    }

    return checkpoint_encode(&target, target_model, allocator, &codec)
}
