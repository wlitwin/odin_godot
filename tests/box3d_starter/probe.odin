//gd:extends Node
//gd:class StarterProbe
package scripts

import "core:fmt"
import "core:mem"
import b "godot:box3d"
import physics "godot:box3d/godot/scene"
import gd "godot:godot"

StarterProbe :: struct {
    owner: gd.Node,
    scene: physics.Scene,
    tracker: mem.Tracking_Allocator,
    tracking: bool,
    saved_node: gd.Node3d,
}

@(gd_method)
starter_probe_live_bytes :: proc(self: ^StarterProbe) -> i64 {
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    if es != .Ok || ws != .Ok { return -1 }
    return i64(engine.live_bytes + wrapper.live_bytes)
}

@(gd_method)
starter_probe_close :: proc(self: ^StarterProbe) -> bool {
    if physics.destroy(&self.scene) != .Ok { return false }
    if self.tracking {
        if self.tracker.current_memory_allocated != 0 { return false }
        mem.tracking_allocator_destroy(&self.tracker)
        self.tracker = {}
        self.tracking = false
    }
    return true
}

starter_probe_finalize :: proc(self: ^StarterProbe) {
    if !starter_probe_close(self) { gd.error("STARTER_PROBE_LEAK") }
}

@(gd_method = "owned_return")
starter_probe_open_world :: proc(self: ^StarterProbe, source: gd.Node3d) -> gd.String {
    if !starter_probe_close(self) { return gd.new_string_odin("PriorCleanup") }
    mem.tracking_allocator_init(&self.tracker, context.allocator, context.allocator)
    self.tracking = true
    diagnostic: physics.Diagnostic
    self.scene, diagnostic = physics.open(source, mem.tracking_allocator(&self.tracker))
    defer physics.diagnostic_destroy(&diagnostic)
    return gd.new_string_odin(fmt.tprintf("%v", diagnostic.error))
}

@(gd_method = "owned_return")
starter_probe_step_world :: proc(self: ^StarterProbe) -> gd.String {
    diagnostic := physics.step_fixed(&self.scene)
    defer physics.diagnostic_destroy(&diagnostic)
    return gd.new_string_odin(fmt.tprintf("%v", diagnostic.error))
}

@(gd_method = "owned_return")
starter_probe_reset_world :: proc(self: ^StarterProbe) -> gd.String {
    diagnostic := physics.reset(&self.scene)
    defer physics.diagnostic_destroy(&diagnostic)
    return gd.new_string_odin(fmt.tprintf("%v", diagnostic.error))
}

@(gd_method)
starter_probe_body_count :: proc(self: ^StarterProbe) -> i64 {
    return i64(len(self.scene._runtime.bodies))
}

@(gd_method)
starter_probe_position :: proc(self: ^StarterProbe, node: gd.Node3d) -> gd.Vector3 {
    body, found := physics.body_for_node(&self.scene, node)
    if !found { return {999,999,999} }
    pose, status := b.body_get_pose(body)
    if status != .Ok { return {999,999,999} }
    return {pose.position.x,pose.position.y,pose.position.z}
}

@(gd_method)
starter_probe_rotation :: proc(self: ^StarterProbe, node: gd.Node3d) -> gd.Quaternion {
    body, found := physics.body_for_node(&self.scene, node)
    if !found { return {} }
    pose, status := b.body_get_pose(body)
    if status != .Ok { return {} }
    return transmute(gd.Quaternion)[4]f32{pose.rotation.x,pose.rotation.y,pose.rotation.z,pose.rotation.w}
}

@(gd_method)
starter_probe_first_position :: proc(self: ^StarterProbe) -> gd.Vector3 {
    if len(self.scene._runtime.bodies) == 0 { return {999,999,999} }
    pose, status := b.body_get_pose(self.scene._runtime.bodies[0].handle)
    if status != .Ok { return {999,999,999} }
    return {pose.position.x,pose.position.y,pose.position.z}
}

@(gd_method)
starter_probe_remember :: proc(self: ^StarterProbe, node: gd.Node3d) { self.saved_node = node }

@(gd_method)
starter_probe_lookup_saved :: proc(self: ^StarterProbe) -> bool {
    _, found := physics.body_for_node(&self.scene, self.saved_node)
    return found
}
