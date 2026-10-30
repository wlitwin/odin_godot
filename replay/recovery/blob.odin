package replay_recovery

import net "godot:replay/net"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

blob_init :: proc(r: ^Blob_Receiver, scope: Scope, source: tr.Peer_Id, wire: tr.Transport, archive_kind: u16,
                  accept: proc(user: rawptr, archive: Archive, bytes: []u8) -> bool, user: rawptr,
                  cfg := DEFAULT_CONFIG, allocator := context.allocator) -> Error {
	return tf.blob_init(r, scope, source, wire, archive_kind, accept, user, cfg, allocator, KIND_BASE, net.MAX_CHECKPOINT_BYTES)
}
blob_destroy :: tf.blob_destroy
blob_receive :: tf.blob_receive
blob_update :: tf.blob_update
