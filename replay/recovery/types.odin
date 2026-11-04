package replay_recovery

import r "godot:replay"
import net "godot:replay/net"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

KIND_BASE :: u16(0x5100)
CHUNK_BYTES :: tf.CHUNK_BYTES
PROTOCOL_VERSION :: tf.PROTOCOL_VERSION
MAX_CHUNKS :: tf.MAX_CHUNKS
GROUPS :: tf.GROUPS
OFFER_GROUP :: tf.OFFER_GROUP
Scope :: tf.Scope
Archive :: tf.Archive
Receipt :: tf.Receipt
Config :: tf.Config
DEFAULT_CONFIG :: tf.DEFAULT_CONFIG
Error :: tf.Error
Phase :: tf.Phase
Received :: tf.Received
Failure :: tf.Failure
Stats :: tf.Stats
Sender :: tf.Sender
Blob_Receiver :: tf.Blob_Receiver

Receiver_Ownership :: struct {
 transfer:tf.Ownership,
 model,policy:r.Owned_Context,
 codec:net.Container_Ownership,
}

Receiver :: struct($State, $Control, $Action, $Event: typeid, $Seats: int) {
	using transfer: tf.Blob_Receiver,
 receiver_ownership:Receiver_Ownership,
 receiver_retains:r.Owner_Retains,
 receiver_cleanup:bool,
	model: net.Model(State, Control, Action, Event, Seats),
	policy_user: rawptr,
	policy_valid: proc(user: rawptr, id: u64, bytes: []u8) -> bool,
	archive_codec: net.Checkpoint_Codec,
	current, previous: Stored(State, Control, Action, Seats),
}

@(private)
Stored :: struct($S, $C, $A: typeid, $N: int) {receipt: Receipt, checkpoint: net.Checkpoint(S, C, A, N)}

handles :: proc(bytes: []u8) -> bool {return tf.handles(bytes, KIND_BASE)}
@(private)
config_valid :: proc(scope: Scope, peer: tr.Peer_Id, cfg: Config) -> bool {return tf.config_valid(scope, peer, cfg, KIND_BASE, net.MAX_CHECKPOINT_BYTES)}
