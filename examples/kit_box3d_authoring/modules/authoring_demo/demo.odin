//gd:extends Node3D
//gd:class KitAuthoringDemo
package kit_authoring_demo

import base "base:runtime"
import "core:encoding/json"
import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import p "godot:kit/physics"
import owned "godot:kit/godot/physics"
import k "godot:kit/sim"
import s "godot:kit/session"
import ng "godot:kit/netgd"

KitAuthoringDemo :: struct {
    owner: gd.Node3d,
    owned: Demo_Owner,
    rt:    ^Demo,
    last:  Result,
}

json_string :: proc(value: $T) -> gd.String {
    bytes, error := json.marshal(value)

    if error != nil {
        return gd.new_string_odin("{\"error\":\"json.allocation\"}")
    }

    defer delete(bytes)
    return gd.new_string_odin(string(bytes))
}

kit_authoring_demo_ready :: proc(self: ^KitAuthoringDemo) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    self.rt = demo_create(self.owner,&self.owned)

    if self.rt == nil {
        self.last.ok = false
        self.last.errors[0] = {"physics.owner.open", self.owned.report.error}
        self.last.error_count = 1

        if gd.env_int("BOX3D_SAMPLE_SCRIPTED", 0) == 1 {
            gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        }
    }
}

kit_authoring_demo_process :: proc(self: ^KitAuthoringDemo, delta: f64) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt == nil {
        return
    }

    demo_frame(rt, delta)

    if rt.scripted && (rt.failed || rt.finished) {
        success := kit_authoring_demo_close(self)
        gd.scene_tree_quit(gd.get_tree(self.owner), success && self.last.ok ? 0 : 1)
    }
}

@(gd_method = "owned_return")
kit_authoring_demo_status :: proc(self: ^KitAuthoringDemo) -> gd.String {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt != nil {
        context.allocator = rt.allocator
    }

    bytes := sample_status_json(rt, self.last.role, self.last.ok ? "" : "closed_or_failed")

    if len(bytes) == 0 {
        return gd.new_string_odin(
            "{\"version\":1,\"framework\":\"kit\",\"phase\":\"Unavailable\",\"error\":\"status.json\"}",
        )
    }

    defer delete(bytes)
    return gd.new_string_odin(string(bytes))
}

@(gd_method = "owned_return")
kit_authoring_demo_presentation :: proc(self: ^KitAuthoringDemo) -> gd.String {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt == nil || !rt.model_ready {
        return gd.new_string_odin("{\"version\":1,\"bodies\":[]}")
    }

    context.allocator = rt.allocator
    checkpoint, error := owned.authored_checkpoint(&self.owned, rt.lane.ticker.tick)

    if error != .Ok {
        return gd.new_string_odin("{\"version\":1,\"bodies\":[]}")
    }

    defer {
        if error := owned.authored_checkpoint_release(&self.owned); error != .Ok { fail(rt,"presentation.checkpoint_release",error) }
    }
    states: [35]b.Body_State
    count, ce := p.checkpoint_body_states(checkpoint, states[:], Side)

    if ce != .Ok {
        return gd.new_string_odin("{\"version\":1,\"bodies\":[]}")
    }

    values: [35]struct {
        key:      string,
        position: [3]f32,
        rotation: [4]f32,
    }
    written := 0

    for state in states[:count] {
        for body, i in rt.built.bodies {
            if body.key == state.key {
                v := state.pose
                values[written] = {
                    rt.body_names[i],
                    {v.position.x, v.position.y, v.position.z},
                    {v.rotation.x, v.rotation.y, v.rotation.z, v.rotation.w},
                }
                written += 1
                break
            }
        }
    }

    return json_string(struct {
        version: u32,
        bodies:  []struct {
            key:      string,
            position: [3]f32,
            rotation: [4]f32,
        },
    }{1, values[:written]})
}

@(gd_method)
kit_authoring_demo_control :: proc(self: ^KitAuthoringDemo, x, z: i32, pulse: bool) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)

    if self.rt == nil {
        return
    }

    self.rt.input = {
        x = i16(clamp(x, -1, 1)),
        z = i16(clamp(z, -1, 1)),
    }
    self.rt.pulse_pending = self.rt.pulse_pending || pulse
}

@(gd_method)
kit_authoring_demo_request_reset :: proc(self: ^KitAuthoringDemo) -> bool {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt == nil || !rt.model_ready || rt.host || rt.failed {
        return false
    }

    context.allocator = rt.allocator
    status := k.lane_world_request_reset(&rt.lane)

    if status != .Ok {
        fail(rt, "request_reset", status)
        return false
    }

    return true
}

@(gd_method)
kit_authoring_demo_close :: proc(self: ^KitAuthoringDemo) -> bool {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)

    if self.rt == nil && self.owned.storage.memory == nil { return true }
    consumed := demo_close(&self.owned,&self.last)
    context = base.default_context()
    self.rt = self.owned.storage.data
    result := self.last

    print_result(result)
    return consumed && result.ok
}

@(gd_method)
kit_authoring_demo_on_packet :: proc(self: ^KitAuthoringDemo, id: gd.Int, packet: gd.Packed_Byte_Array) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)

    if self.rt == nil {
        return
    }

    context.allocator = self.rt.allocator
    ng.wire_receive(&self.rt.wire, id, packet)
}

@(gd_method)
kit_authoring_demo_on_peer_left :: proc(self: ^KitAuthoringDemo, id: gd.Int) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt == nil || rt.closing {
        return
    }

    context.allocator = rt.allocator
    peer := s.Peer_Id(id)
    _ = ng.wire_peer_left(&rt.wire, peer)

    if rt.model_ready {
        _ = k.lane_world_protocol_peer_disconnected(&rt.lane, peer)
    }

    s.session_peer_disconnected(&rt.ses, peer)

    if !rt.exported {
        fail(rt, "peer_left_before_final", .Invalid)
    }
}

@(gd_method)
kit_authoring_demo_on_net_up :: proc(self: ^KitAuthoringDemo) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)

    if self.rt == nil {
        return
    }

    context.allocator = self.rt.allocator
    s.session_client_join(&self.rt.ses)
}

@(gd_method)
kit_authoring_demo_on_net_down :: proc(self: ^KitAuthoringDemo) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)
    rt := self.rt

    if rt == nil || rt.closing {
        return
    }

    if !rt.exported {
        fail(rt, "transport_disconnected", .Invalid)
    }
}

kit_authoring_demo_finalize :: proc(self: ^KitAuthoringDemo) {
    context = base.default_context()
    temp := base.default_temp_allocator_temp_begin()
    defer base.default_temp_allocator_temp_end(temp)

    _ = kit_authoring_demo_close(self)
    if self.owned.storage.memory != nil { gd.print_str("SAMPLE_CLOSE_ERROR Kit owner remains retained") }
}
