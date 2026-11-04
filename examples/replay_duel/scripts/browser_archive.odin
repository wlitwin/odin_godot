package replay_duel

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import rb "godot:replay/p2p"
import storagegd "godot:replay/godot/storage"

// The browser upload is asynchronous. Wait before installing transport mappings
// or a runner so repeated frames cannot partially install a restored session.
duel_archive_ready :: proc(self: ^ReplayDuel) -> bool {
    when gd.IS_WEB {
        code := gd.new_string_odin("globalThis.replayDuelArchiveState || 0")
        defer gd.free_string(code)
        value := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), code, true)
        defer gd.variant_destroy(&value)
        status := gd.variant_to_int(&value)

        if status < 0 {
            duel_fail(self, "participant file import")
        }

        return status == 1
    } else {
        return true
    }
}

duel_archive_read :: proc(self: ^ReplayDuel) -> ([]u8, storagegd.Storage_Error) {
    when gd.IS_WEB {
        js := gd.singleton_java_script_bridge()
        name := gd.new_string_odin("replayDuelArchive")
        defer gd.free_string(name)
        object := gd.java_script_bridge_get_interface(js, name)

        if object == nil {
            return nil, .Read
        }

        defer if gd.ref_counted_unreference(object) {
            gdext.object_destroy(object)
        }

        if !gd.java_script_bridge_is_js_buffer(js, object) {
            return nil, .Read
        }

        packet := gd.java_script_bridge_js_buffer_to_packed_byte_array(js, object)
        defer gd.free_packed_byte_array(packet)
        bytes := gd.packed_byte_array_view(&packet)

        if len(bytes) == 0 || len(bytes) > rb.MAX_ARCHIVE_BYTES {
            return nil, .Size
        }

        owned := make([]u8, len(bytes))
        copy(owned, bytes)
        return owned, .None
    } else {
        return storagegd.storage_read(self.archive_path, rb.MAX_ARCHIVE_BYTES)
    }
}

duel_archive_write :: proc(self: ^ReplayDuel, bytes: []u8) -> storagegd.Storage_Error {
    when gd.IS_WEB {
        if len(bytes) == 0 || len(bytes) > rb.MAX_ARCHIVE_BYTES {
            return .Size
        }

        packet := gd.new_packed_byte_array()
        defer gd.free_packed_byte_array(packet)

        if gd.packed_byte_array_resize(&packet, gd.Int(len(bytes))) != 0 {
            return .Size
        }

        copy(gd.packed_byte_array_view(&packet), bytes)
        name := gd.new_string_odin(fmt.tprintf("duel-seat-%d.rply", self.peer.local))
        defer gd.free_string(name)
        mime := gd.new_string_odin("application/octet-stream")
        defer gd.free_string(mime)
        gd.java_script_bridge_download_buffer(gd.singleton_java_script_bridge(), packet, name, mime)
        // Request accepted by the engine, not a filesystem durability receipt. The
        // browser/user owns download completion; the acceptance driver verifies files.
        return .None
    } else {
        return storagegd.storage_write(self.archive_path, bytes, rb.MAX_ARCHIVE_BYTES)
    }
}
