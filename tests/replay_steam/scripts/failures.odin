//gd:extends Node
//gd:class SteamFailureProbe
package steam_probe
import gd "godot:godot"
import transportgd "godot:replay/godot/transport"

SteamFailureProbe :: struct {
    owner: gd.Node,
}

steam_failure_probe_ready :: proc(self: ^SteamFailureProbe) {
    fake := cast(gd.Object)gd.get_node(self.owner, "FakeSteam")

    for behavior in 1 ..= 3 {
        gd.set_int(fake, "behavior", gd.Int(behavior))
        runtime: transportgd.Steam_Runtime
        error := transportgd.steam_runtime_initialize(&runtime, fake, 480)

        if runtime.ready ||
           error != (behavior == 1 ? transportgd.Steam_Error.Interface : transportgd.Steam_Error.Initialization) {
            gd.print_str("REPLAY_STEAM_FAILURE_FAIL runtime")
            gd.scene_tree_quit(gd.get_tree(self.owner), 1)
            return
        }
    }

    gd.set_int(fake, "behavior", 0)
    runtime: transportgd.Steam_Runtime

    if transportgd.steam_runtime_initialize(&runtime, fake, 480) != .None {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    method := gd.new_string_name("new_peer")
    defer gd.free_string_name(method)
    value := gd.object_call(fake, method)
    defer gd.variant_destroy(&value)
    peer := gd.variant_to_object(&value)
    gd.set_bool(peer, "fail_creation", true)
    s: transportgd.Steam
    config := transportgd.STEAM_CONFIG
    config.runtime = &runtime

    if transportgd.steam_open_peer(&s, cast(gd.Multiplayer_Peer)peer, config, true) != .Create ||
       s.packets.peer != nil ||
       s.packets.buffer != nil {
        gd.print_str("REPLAY_STEAM_FAILURE_FAIL cleanup")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    transportgd.steam_close(&s)
    transportgd.steam_close(&s)
    transportgd.steam_runtime_release(&runtime)
    gd.print_str("REPLAY_STEAM_FAILURES_OK malformed_status=true failed_init=true failed_create_cleanup=true")
    gd.scene_tree_quit(gd.get_tree(self.owner), 0)
}
