#+build darwin, linux
package replay_duel

import gd "godot:godot"
import "godot:gdext"
import adapter "godot:replay/godot/provision_sqlite"
import rgd "godot:replay/godot"
import game "../shared/duel"

duel_online_storage_open :: proc(self: ^ReplayDuel, local: bool) -> (rgd.Party_Storage, bool) {
    store := new(adapter.Party_Store)
    self.online_storage = store
    path := gd.new_string_odin(duel_param("RDP_ROOMS_DB", "user://p2p-rooms.sqlite3"))
    defer gd.free_string(path)
    absolute := gd.project_settings_globalize_path(gd.singleton_project_settings(), path)
    defer gd.free_string(absolute)

    if !adapter.party_store_open(store, gd.gd_string_to_odin(absolute), game.CONTENT, true, local) {
        return {}, false
    }

    cert_path := duel_param("RDP_CA", "")

    if cert_path != "" {
        cert := gd.new_x509_certificate()
        gd.ref_counted_init_ref(cert)

        defer if gd.ref_counted_unreference(cert) {
            gdext.object_destroy(cert)
        }

        cp := gd.new_string_odin(cert_path)
        defer gd.free_string(cp)

        if gd.x509_certificate_load(cert, cp) != .Ok {
            return {}, false
        }

        self.online_tls = gd.tls_options_client(cert, gd.string_empty())

        if self.online_tls == nil {
            return {}, false
        }
    }

    return adapter.party_storage(store), true
}

duel_online_storage_close :: proc(self: ^ReplayDuel) {
    if self.online_storage != nil {
        store := cast(^adapter.Party_Store)self.online_storage
        adapter.party_store_close(store)
        free(store)
        self.online_storage = nil
    }

    if self.online_tls != nil {
        if gd.ref_counted_unreference(self.online_tls) {
            gdext.object_destroy(self.online_tls)
        }

        self.online_tls = nil
    }
}
