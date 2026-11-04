package replay_recovery

import net "godot:replay/net"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

sender_init :: proc(
    s: ^Sender,
    scope: Scope,
    target: tr.Peer_Id,
    wire: tr.Transport,
    cfg := DEFAULT_CONFIG,
    allocator := context.allocator,
    archive_kind: u16 = net.CHECKPOINT_KIND,
    ownership: tf.Ownership = {},
) -> Error {
    return tf.sender_init(
        s,
        scope,
        target,
        wire,
        cfg,
        allocator,
        archive_kind,
        KIND_BASE,
        net.MAX_CHECKPOINT_BYTES,
        ownership = ownership,
    )
}

sender_destroy :: tf.sender_destroy
sender_begin :: tf.sender_begin
sender_cancel :: tf.sender_cancel
sender_update :: tf.sender_update
sender_receive :: tf.sender_receive

sender_publish :: proc(
    s: ^Sender,
    cp: ^net.Checkpoint($S, $C, $A, $N),
    model: net.Model(S, C, A, $E, N),
    now_ms: u64,
    codec: ^net.Checkpoint_Codec = nil,
    channel: tr.Channel = .Unreliable,
) -> Error {
    if !s.ready || s.phase == .Sending {
        return .Wrong_Phase
    }

    if model.complete_state {
        if model.complete_codec.transfer_budget.reserve == nil {
            return .Invalid_Config
        }

        if error := tf.sender_budget_attach(s, model.complete_codec.transfer_budget); error != .None {
            return error
        }
    }

    owned, err := net.checkpoint_encode_owned(cp, model, s.allocator, codec)
    defer net.complete_data_destroy(&owned)
    bytes := owned.bytes

    if err != .None {
        return .Invalid_Archive
    }

    s.layout = {}

    if schema, offset, ready := net.checkpoint_frame_layout(codec); ready && !model.complete_state {
        s.layout = {schema, offset}
    }

    return sender_begin(s, bytes, now_ms, channel)
}
