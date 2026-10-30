package replay_recovery

import net "godot:replay/net"
import tr "godot:replay/transport"

receiver_init :: proc(r: ^Receiver($S, $C, $A, $E, $N), scope: Scope, source: tr.Peer_Id, wire: tr.Transport,
                      model: net.Model(S, C, A, E, N), cfg := DEFAULT_CONFIG, allocator := context.allocator) -> Error {
	if r.ready || !config_valid(scope, source, cfg) || (model.step == nil && model.step_view == nil) || model.hold == nil ||
	   model.control_valid == nil || model.state_valid == nil || !model.control_valid(model.neutral) {return .Invalid_Config}
	r.model = model
	if net.checkpoint_codec_init(&r.archive_codec, S, C, A, E, N, allocator = allocator) != .None {receiver_destroy(r); return .Invalid_Archive}
	accept := proc(user: rawptr, archive: Archive, bytes: []u8) -> bool {return receiver_accept(cast(^Receiver(S, C, A, E, N))user, archive, bytes)}
	if err := blob_init(&r.transfer, scope, source, wire, net.CHECKPOINT_KIND, accept, r, cfg, allocator); err != .None {receiver_destroy(r); return err}
	schema,offset,ready:=net.checkpoint_frame_layout(&r.archive_codec)
 if !ready {receiver_destroy(r);return .Invalid_Archive}
 r.transfer.layout={schema,offset}
 return .None
}

receiver_destroy :: proc(r: ^Receiver($S, $C, $A, $E, $N)) {
	net.checkpoint_destroy(&r.current.checkpoint)
	net.checkpoint_destroy(&r.previous.checkpoint)
	blob_destroy(&r.transfer)
	net.checkpoint_codec_destroy(&r.archive_codec)
	r^ = {}
}

// Latest fully validated candidate. The previous acknowledged archive can also
// remain available; takeover must request the exact receipt authorized by the
// room coordinator, rather than assuming latest implies legitimate leadership.
receiver_latest :: proc(r: ^Receiver($S, $C, $A, $E, $N)) -> (Receipt, bool) {
	return r.current.receipt, r.ready && r.current.checkpoint.ready
}

// Read-only borrow until the next receive/destroy. Never destroy or mutate it.
// This supports persisting the archive and restoring into a separate runtime.
receiver_checkpoint :: proc(r: ^Receiver($S, $C, $A, $E, $N), archive: Archive) -> (^net.Checkpoint(S, C, A, N), bool) {
	if !r.ready {return nil, false}
	if r.current.checkpoint.ready && r.current.receipt.archive == archive {return &r.current.checkpoint, true}
	if r.previous.checkpoint.ready && r.previous.receipt.archive == archive {return &r.previous.checkpoint, true}
	return nil, false
}

receiver_receive :: proc(r: ^Receiver($S, $C, $A, $E, $N), from: tr.Peer_Id, bytes: []u8, now_ms: u64, channel: tr.Channel = .Unreliable) -> Received {
	return blob_receive(&r.transfer, from, bytes, now_ms,channel)
}

receiver_update :: proc(r: ^Receiver($S, $C, $A, $E, $N), now_ms: u64) -> Error {
	return blob_update(&r.transfer, now_ms)
}

@(private)
receiver_accept :: proc(r: ^Receiver($S, $C, $A, $E, $N), archive: Archive, bytes: []u8) -> bool {
	candidate: net.Checkpoint(S, C, A, N)
	if net.checkpoint_decode(&candidate, bytes, r.model, r.scope.content, r.allocator, &r.archive_codec) != .None {
		net.checkpoint_destroy(&candidate); return false
	}
	if candidate.header.epoch != r.scope.epoch || candidate.header.tick != archive.tick ||
	   (candidate.header.policy_id != 0 && r.policy_valid == nil) ||
	   (r.policy_valid != nil && !r.policy_valid(r.policy_user, candidate.header.policy_id, candidate.policy_data)) {
		net.checkpoint_destroy(&candidate); return false
	}
	if r.offer.retain_sequence == 0 || r.offer.retain_sequence == r.current.receipt.archive.sequence {
		net.checkpoint_destroy(&r.previous.checkpoint)
		r.previous = r.current; r.current = {}
	} else {net.checkpoint_destroy(&r.current.checkpoint)}
	r.current.checkpoint = candidate
	r.current.receipt = {archive, r.clock.now}
	return true
}
