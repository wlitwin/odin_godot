package replay_godot_storage

import gd "godot:godot"
import "godot:gdext"
import "core:crypto/sha2"
import net "godot:replay/net"

// Session tokens are random in normal play; deterministic labels are for tests.
session_token :: proc(test_label: string = "") -> net.Token {
    token: net.Token

    if test_label != "" {
        ctx: sha2.Context_256
        sha2.init_256(&ctx)
        sha2.update(&ctx, transmute([]u8)test_label)
        digest: [32]u8
        sha2.final(&ctx, digest[:])
        copy(token[:], digest[:16])
        return token
    }

    crypto := gd.new_crypto()
    gd.ref_counted_init_ref(crypto)
    bytes := gd.crypto_generate_random_bytes(crypto, 16)
    copy(token[:], gd.packed_byte_array_view(&bytes))
    gd.free_packed_byte_array(bytes)

    if gd.ref_counted_unreference(crypto) {
        gdext.object_destroy(crypto)
    }

    return token
}
