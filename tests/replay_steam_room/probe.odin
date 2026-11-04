package replay_cavecrawl
import gd "godot:godot"
import rgd "godot:replay/godot"
import transportgd "godot:replay/godot/transport"

steam_room_configure :: proc(self: ^ReplayCave, options: ^rgd.Session_Options) -> bool {
    fake := cast(gd.Object)gd.get_node(self.owner, "FakeSteam")

    if !self.test_steam.ready && transportgd.steam_runtime_initialize(&self.test_steam, fake, 480) != .None {
        return false
    }

    options.backend = .Steam
    options.steam = transportgd.STEAM_CONFIG
    options.steam.runtime = &self.test_steam
    options.steam.virtual_port = u16(cave_int("STEAM_VIRTUAL_PORT", 0))
    options.steam.factory_user = self
    options.steam.peer_factory = proc(raw: rawptr) -> gd.Variant {
        self := cast(^ReplayCave)raw
        fake := cast(gd.Object)gd.get_node(self.owner, "FakeSteam")
        method := gd.new_string_name("new_peer")
        defer gd.free_string_name(method)
        return gd.object_call(fake, method)
    }
    return true
}

@(gd_method)
replay_cave_steam_room_probe :: proc(self: ^ReplayCave, key: string) -> gd.Int {
    switch key {
    case "backend":
        return gd.Int(self.session.options.backend)
    case "steam_id":
        return gd.Int(self.test_steam.steam_id)
    case "target":
        return gd.Int(self.session.options.steam.host_steam_id)
    }

    return -1
}
