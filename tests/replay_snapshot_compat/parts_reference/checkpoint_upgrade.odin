package replay_net_parts_reference

// Explicit archive conversion, never an automatic load fallback. Protocol 7
// changed only scheduled-input framing: archive layout 4, model semantics and
// logical schemas are unchanged. Validate the complete old archive and its old
// contract before changing either protocol or contract stamp.
checkpoint_upgrade_v6 :: proc(
    bytes: []u8,
    model: Model($S, $C, $A, $E, $N),
    content: u64,
    allocator := context.allocator,
) -> (
    []u8,
    Error,
) {
    when PROTOCOL_VERSION != 7 {
        return nil, .Checkpoint_Contract
    }

    codec: Checkpoint_Codec
    defer checkpoint_codec_destroy(&codec)

    if err := checkpoint_codec_init(&codec, S, C, A, E, N, true, allocator); err != .None {
        return nil, err
    }

    cp: Checkpoint(S, C, A, N)
    defer checkpoint_destroy(&cp)

    if err := checkpoint_decode_protocol(&cp, bytes, model, content, 6, allocator, &codec); err != .None {
        return nil, err
    }

    cp.header.protocol = PROTOCOL_VERSION
    cp.header.contract = contract_hash(
        &codec.network,
        checkpoint_config(cp.header, cp.settings),
        N,
        model.control_timing,
        replication = model.replication.id,
    )
    return checkpoint_encode(&cp, model, allocator, &codec)
}
