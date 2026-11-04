//gd:extends Node
//gd:class SteamRoomFailureProbe
package steam_room_failure
import gd "godot:godot"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import auth "godot:replay/authority"
import r "godot:replay"
import transportgd "godot:replay/godot/transport"

SteamRoomFailureProbe :: struct {
    owner: gd.Node,
}

steam_room_failure_probe_ready :: proc(self: ^SteamRoomFailureProbe) {
    fake := cast(gd.Object)gd.get_node(self.owner, "FakeSteam")
    runtime: transportgd.Steam_Runtime
    assert(transportgd.steam_runtime_initialize(&runtime, fake, 480) == .None)
    defer transportgd.steam_runtime_release(&runtime)
    config := transportgd.STEAM_CONFIG
    config.runtime = &runtime
    config.peer_factory = proc(_: rawptr) -> gd.Variant {
        return {}
    }
    steam: transportgd.Steam
    assert(transportgd.steam_open(&steam, config, true) == .Interface && steam.packets.peer == nil)
    config.factory_user = fake
    config.peer_factory = proc(raw: rawptr) -> gd.Variant {
        method := gd.new_string_name("new_peer")
        defer gd.free_string_name(method)
        result := gd.object_call(cast(gd.Object)raw, method)
        gd.set_bool(gd.variant_to_object(&result), "fail_creation", true)
        return result
    }
    assert(
        transportgd.steam_open(&steam, config, true) == .Create &&
        steam.packets.peer == nil &&
        steam.packets.buffer == nil,
    )
    transportgd.steam_close(&steam)
    // Invalid local endpoint is refused before a control connection or allocation.
    room: rgd.Room(u8, u8, u8, u8, 1)
    options := rgd.Room_Options {
        identity     = {1, 101},
        room         = 44,
        coordinator  = "127.0.0.1",
        control_port = 45000,
        session      = rgd.SESSION_OPTIONS,
    }
    options.session.backend = .Steam
    options.session.steam = config
    options.registration_endpoint, _ = transportgd.steam_endpoint(runtime.steam_id + 1, 0)
    assert(
        rgd.room_open(&room, r.Frame(u8){}, net.Model(u8, u8, u8, u8, 1){}, options) == .Invalid_Config && !room.ready,
    )
    // Destination validation in the public redirect path preserves a live runtime
    // when the signed authority endpoint is not a valid Steam endpoint.
    session: rgd.Session(u8, u8, u8, u8, 1)
    session.ready = true
    session.options.backend = .Steam
    session.client.cfg.content = 55
    session.client.cfg.epoch = 1
    clock := auth.Clock_Source {
        read = proc(_: rawptr) -> (u64, bool) {
            return 100, true
        },
    }
    lease: auth.Lease
    assert(auth.lease_init(&lease, {2, 102}, 44, 55, clock, false) == .None)
    sequence, error := auth.lease_request(&lease)
    assert(error == .None)
    endpoint, _ := auth.endpoint("127.0.0.1", 1)
    assert(
        auth.lease_accept(
            &lease,
            sequence,
            {
                room = 44,
                content = 55,
                revision = 1,
                epoch = 2,
                coordinator_generation = 1,
                owner = {1, 101},
                endpoint = endpoint,
                remaining_ms = 1000,
                policy = auth.DEFAULT_POLICY,
            },
        ) ==
        .None,
    )
    target := rgd.Migration_Transport {
        backend = .Steam,
        steam   = config,
    }
    assert(
        rgd.session_redirect(&session, &lease, &target) == .Invalid_Config &&
        session.ready &&
        session.client.cfg.epoch == 1,
    )
    gd.print_str("REPLAY_STEAM_ROOM_FAILURES_OK")
    gd.scene_tree_quit(gd.get_tree(self.owner), 0)
}
