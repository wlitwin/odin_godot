#+build darwin, linux
package replay_claimball
import gd "godot:godot"
import adapter "godot:replay/godot/provision_sqlite"
import rgd "godot:replay/godot"
import game "../shared/pitch"

online_native_init :: proc(self: ^ReplayClaimball, local: bool) -> (rgd.Party_Storage, bool) {
    store := new(adapter.Party_Store)
    self.online.native = store
    path := gd.new_string_odin(claimball_param("RCB_ROOMS_DB", "user://claimball_rooms.sqlite3"))
    defer gd.free_string(path)
    absolute := gd.project_settings_globalize_path(gd.singleton_project_settings(), path)
    defer gd.free_string(absolute)

    if !adapter.party_store_open(store, gd.gd_string_to_odin(absolute), game.CONTENT, true, local) {
        return {}, false
    }

    cert_path := claimball_param("RCB_ROOM_CA", "")

    if cert_path != "" {
        cert := gd.new_x509_certificate()
        gd.ref_counted_init_ref(cert)
        defer online_unref(cert)
        cp := gd.new_string_odin(cert_path)
        defer gd.free_string(cp)

        if gd.x509_certificate_load(cert, cp) != .Ok {
            return {}, false
        }

        self.online.tls = gd.tls_options_client(cert, gd.string_empty())
    }

    return adapter.party_storage(store), true
}

online_native_close :: proc(self: ^ReplayClaimball) {
    if self.online.native != nil {
        store := cast(^adapter.Party_Store)self.online.native
        adapter.party_store_close(store)
        free(store)
    }
}
