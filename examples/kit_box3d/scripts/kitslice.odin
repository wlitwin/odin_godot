//gd:extends Node3D
//gd:class KitSlice
package kit_box3d

import "core:fmt"
import gd "godot:godot"
import common "godot:examples/box3d_common"
import k "godot:kit/sim"
import s "godot:kit/session"
import n "godot:kit/net"
import ng "godot:kit/netgd"

KitSlice :: struct {
    owner:                     gd.Node3d,
    rt:                        ^Runtime,
    meshes:                    [common.MAX_DYNAMIC]gd.Node3d,
    spheres, crates, capsules: [common.MAX_DYNAMIC]gd.Node3d,
    label:                     gd.Label,
    generation:                u32,
    rejoined:                  bool,
    rejoin_pending:            bool,
    rejoin_after:              f64,
    rejoin_guard:              Rejoin_Guard,
    presentation:              Consumer_View,
}

kit_slice_open :: proc(self: ^KitSlice, role: Role, rejoin: Rejoin_Guard = {}) {
    self.rt = runtime_create(self.owner, role, self.generation, rejoin)
}

kit_slice_ready :: proc(self: ^KitSlice) {
    generation := gd.env_int("B3_GENERATION", 1)

    if generation < 1 || generation > int(max(u32)) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    self.generation = u32(generation)
    // SERVICE_CADENCE49_BEGIN: configured cap only, not measured frame rate.
    requested_cap: i32

    switch gd.env_string("B3_SERVICE_FPS", "60") {
    case "60":
        requested_cap = 60
    case "120":
        requested_cap = 120
    case:
        generation_log(
            self.generation,
            "{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"service_cadence\",\"reason\":\"unsupported_B3_SERVICE_FPS\",\"before_runtime\":true}\n",
        )
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    engine := gd.singleton_engine()
    gd.engine_set_max_fps(engine, gd.Int(requested_cap))
    actual_cap := gd.engine_get_max_fps(engine)

    if actual_cap != requested_cap {
        generation_log(
            self.generation,
            "{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"service_cadence\",\"reason\":\"engine_cap_mismatch\",\"requested_cap\":%d,\"actual_cap\":%d,\"before_runtime\":true}\n",
            requested_cap,
            actual_cap,
        )
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    cadence_role := gd.env_string("B3_ROLE", "")

    if gd.env_int("B3_SCRIPTED", cadence_role != "" ? 1 : 0) != 0 {
        generation_log(
            self.generation,
            "{\"event\":\"STATUS\",\"stage\":\"service_cadence\",\"framework\":\"kit\",\"role\":\"%s\",\"requested_cap\":%d,\"actual_cap\":%d,\"scope\":\"configured_process_render_cap\",\"measured_fps\":false}\n",
            cadence_role,
            requested_cap,
            actual_cap,
        )
    }

    // SERVICE_CADENCE49_END
    self.label = cast(gd.Label)gd.get_node(self.owner, "HUD/Status")

    for &mesh, i in self.meshes {
        mesh = gd.get_node(self.owner, fmt.ctprintf("Bodies/B%d", i))
        self.spheres[i] = gd.get_node(mesh, "Sphere")
        self.crates[i] = gd.get_node(mesh, "Crate")
        self.capsules[i] = gd.get_node(mesh, "Capsule")
        gd.node3d_set_visible(mesh, false)
    }

    for action in ([]cstring {
            "b3_left",
            "b3_right",
            "b3_up",
            "b3_down",
            "b3_spawn",
            "b3_remove",
            "b3_motor",
            "b3_sleep",
            "b3_wake",
            "b3_query",
        }) {
        gd.add_action(action)
    }

    gd.action_add_key("b3_left", i64(gd.Key.Left))
    gd.action_add_key("b3_right", i64(gd.Key.Right))
    gd.action_add_key("b3_up", i64(gd.Key.Up))
    gd.action_add_key("b3_down", i64(gd.Key.Down))
    gd.action_add_key("b3_spawn", i64(gd.Key.Space))
    gd.action_add_key("b3_remove", i64('R'))
    gd.action_add_key("b3_motor", i64('M'))
    gd.action_add_key("b3_sleep", i64('F'))
    gd.action_add_key("b3_wake", i64('G'))
    gd.action_add_key("b3_query", i64('Q'))

    switch gd.env_string("B3_ROLE", "") {
    case "host":
        kit_slice_open(self, .Host)
    case "client":
        kit_slice_open(self, .Client)
    case "observer":
        kit_slice_open(self, .Observer)
    case "server", "dedicated":
        kit_slice_open(self, .Dedicated)
    }
}

@(gd_method)
kit_slice_on_host :: proc(self: ^KitSlice) {
    if self.rt == nil {
        kit_slice_open(self, .Host)
    }
}

@(gd_method)
kit_slice_on_join :: proc(self: ^KitSlice) {
    if self.rt == nil {
        kit_slice_open(self, .Client)
    }
}

@(gd_method)
kit_slice_on_reconnect :: proc(self: ^KitSlice) {
    if self.rt == nil || self.rejoin_pending {
        return
    }

    old := self.rt

    if old.role != .Client || !old.model_ready || !old.ses.joined || self.generation == max(u32) {
        gd.set_text(
            self.label,
            "Reconnect requires a seated client; immutable authority/observer changes are unsupported",
        )
        return
    }

    self.rejoin_guard = {
        player            = old.ses.me,
        players           = old.players,
        seat              = old.seat,
        epoch             = k.lane_world_epoch(&old.lane),
        token             = old.ses.token,
        source_generation = self.generation,
    }
    self.rt = nil

    if !runtime_destroy(old, false) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    gd.set_text(self.label, "REJOIN / old context closed; one fresh connection attempt pending")
    // A single bounded lobby delay lets the transport report departure. It is
    // not evidence that the authority saw it: a live-token race fails explicitly.
    self.generation += 1
    self.rejoin_pending = true
    self.rejoin_after = n.now_s() + .5
}

@(gd_method)
kit_slice_on_reset :: proc(self: ^KitSlice) {
    if self.rt == nil || !self.rt.model_ready || self.rt.ses.is_host || self.rt.recovering {
        return
    }

    rt := self.rt
    context.allocator = rt.allocator
    capture_ingress(rt)
    status, _ := request_reset_observed(rt, k.lane_world_status(&rt.lane), "manual_ui")

    if status == .Ok {
        rt.recovering = true
    }
}

@(gd_method)
kit_slice_on_packet :: proc(self: ^KitSlice, id: gd.Int, packet: gd.Packed_Byte_Array) {
    if self.rt == nil {
        return
    }

    context.allocator = self.rt.allocator
    ng.wire_receive(&self.rt.wire, id, packet)
}

@(gd_method)
kit_slice_on_peer_left :: proc(self: ^KitSlice, id: gd.Int) {
    if self.rt == nil {
        return
    }

    context.allocator = self.rt.allocator
    _ = ng.wire_peer_left(&self.rt.wire, s.Peer_Id(id))
    runtime_peer_left(self.rt, s.Peer_Id(id))
    s.session_peer_disconnected(&self.rt.ses, s.Peer_Id(id))
}

@(gd_method)
kit_slice_on_net_up :: proc(self: ^KitSlice) {
    if self.rt == nil {
        return
    }

    context.allocator = self.rt.allocator
    s.session_client_join(&self.rt.ses)
}

@(gd_method)
kit_slice_on_net_down :: proc(self: ^KitSlice) {
    if self.rt != nil {
        if self.rt.model_ready && self.rt.target > 0 && k.lane_world_confirmed(&self.rt.lane) >= self.rt.target {
            self.rt.finished = true
        } else {
            self.rt.failed = true
        }
    }
}

kit_slice_process :: proc(self: ^KitSlice, delta: f64) {
    if self.rejoin_pending && n.now_s() >= self.rejoin_after {
        self.rejoin_pending = false
        generation_log(
            self.generation,
            "{\"event\":\"REJOIN_OPEN\",\"framework\":\"kit\",\"source_generation\":%d,\"new_generation\":%d,\"player\":%d,\"token\":%d,\"old_scope_zero\":true,\"host_left_observed\":false}\n",
            self.rejoin_guard.source_generation,
            self.generation,
            self.rejoin_guard.player,
            self.rejoin_guard.token,
        )
        kit_slice_open(self, .Client, self.rejoin_guard)
    }

    rt := self.rt

    if rt == nil {
        return
    }

    context.allocator = rt.allocator

    if !rt.scripted {
        rt.control = {}

        if gd.is_action_pressed("b3_left") {
            rt.control.x -= 100
        }

        if gd.is_action_pressed("b3_right") {
            rt.control.x += 100
        }

        if gd.is_action_pressed("b3_up") {
            rt.control.z -= 100
        }

        if gd.is_action_pressed("b3_down") {
            rt.control.z += 100
        }

        if gd.is_action_just_pressed("b3_spawn") {
            rt.action = {.Spawn}
        }

        if gd.is_action_just_pressed("b3_remove") {
            rt.action = {.Remove}
        }

        if gd.is_action_just_pressed("b3_motor") {
            rt.action = {.Motor}
        }

        if gd.is_action_just_pressed("b3_sleep") {
            rt.action = {.Sleep}
        }

        if gd.is_action_just_pressed("b3_wake") {
            rt.action = {.Wake}
        }

        if gd.is_action_just_pressed("b3_query") {
            rt.action = {.Query}
        }
    }

    runtime_frame(rt, delta)

    if !rt.failed && rt.exit_at != 0 && rt.model_ready && k.lane_world_confirmed(&rt.lane) >= rt.exit_at {
        tick := k.lane_world_confirmed(&rt.lane)
        write_frame(rt, tick)
        runtime_log(
            rt,
            "{\"event\":\"REJOIN_SOURCE_STOP\",\"framework\":\"kit\",\"epoch\":%d,\"player\":%d,\"token\":%d,\"seat\":%d,\"players\":[%d,%d],\"head\":%d,\"confirmed\":%d}\n",
            k.lane_world_epoch(&rt.lane),
            rt.ses.me,
            rt.ses.token,
            rt.seat,
            rt.players[0],
            rt.players[1],
            rt.lane.ticker.tick,
            tick,
        )
        self.rt = nil
        clean := runtime_destroy(rt, false)
        gd.scene_tree_quit(gd.get_tree(self.owner), clean ? 0 : 1)
        return
    }

    if rt.model_ready {
        consumer_paint(self, rt)
    }

    if rt.failed && !rt.scripted && rt.target == 0 {
        gd.set_text(
            self.label,
            fmt.ctprintf(
                "HOLD / %s / error %v wire %v — Reconnect or Reset",
                role_name(rt.role),
                rt.error,
                ng.wire_status(&rt.wire).error,
            ),
        )
        return
    }

    if rt.failed || rt.finished {
        self.rt = nil
        failed := rt.failed
        runtime_destroy(rt)
        gd.scene_tree_quit(gd.get_tree(self.owner), failed ? 1 : 0)
    }
}

kit_slice_exit_tree :: proc(self: ^KitSlice) {
    if self.rt != nil {
        rt := self.rt
        self.rt = nil
        runtime_destroy(rt)
    }
}
