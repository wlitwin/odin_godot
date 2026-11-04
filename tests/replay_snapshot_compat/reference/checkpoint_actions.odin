package replay_net_legacy

// Explicit application conversion for an action-schema change. State, controls,
// seats and control timing stay the same. Event schemas may change because no
// event history is serialized in these archives. Decode validates the complete
// source contract before the caller maps any accepted-but-unexecuted action.
// This returns owned bytes, grants no authority, and never modifies the source.
checkpoint_convert_actions :: proc(
    bytes: []u8,
    source_model: Model($S, $C, $A, $E, $N),
    source_content: u64,
    target_model: Model(S, C, $B, $F, N),
    target_content: u64,
    convert: proc(_: A) -> (B, bool),
    allocator := context.allocator,
) -> (
    []u8,
    Error,
) {
    if convert == nil ||
       target_content == 0 ||
       source_model.control_timing != target_model.control_timing ||
       source_model.control_timing > .Latest_Observation ||
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

    codec: Checkpoint_Codec
    defer checkpoint_codec_destroy(&codec)

    if err := checkpoint_codec_init(&codec, S, C, B, F, N, true, allocator); err != .None {
        return nil, err
    }

    // Common sections are borrowed only until encoding finishes. The mapped
    // action array is the sole temporary section owned by target.
    target := Checkpoint(S, C, B, N) {
        allocator   = allocator,
        ready       = true,
        header      = source.header,
        settings    = source.settings,
        frame       = source.frame,
        held        = source.held,
        held_views  = source.held_views,
        peers       = source.peers,
        inputs      = source.inputs,
        outcomes    = source.outcomes,
        banned      = source.banned,
        policy_data = source.policy_data,
    }
    target.actions = make([dynamic]Checkpoint_Action(B), len(source.actions), allocator)
    defer delete(target.actions)

    for entry, i in source.actions {
        value, ok := convert(entry.value)

        if !ok {
            return nil, .Invalid_Input
        }

        target.actions[i] = {entry.peer, entry.sequence, entry.tick, value, entry.reason}
    }

    target.header.content = target_content
    target.header.contract = contract_hash(
        &codec.network,
        checkpoint_config(target.header, target.settings),
        N,
        target_model.control_timing,
        replication = target_model.replication.id,
    )
    return checkpoint_encode(&target, target_model, allocator, &codec)
}
