package replay_transfer_wasm
import tf "godot:replay/transfer"

check :: proc() {
    s: tf.Sender
    r: tf.Blob_Receiver
    tf.sender_init(&s, {1, 1, 1, 1}, 1, {}, archive_kind = 777, max_bytes = 4096)
    tf.blob_init(&r, {1, 1, 1, 1}, 1, {}, 777, proc(user: rawptr, a: tf.Archive, b: []u8) -> bool {
            return true
        }, nil, max_bytes = 4096)
    tf.sender_destroy(&s)
    tf.blob_destroy(&r)
}
