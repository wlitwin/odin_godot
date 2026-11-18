//gd:extends Node3D
//gd:class Box3DStarter
package scripts

import gd "godot:godot"
import b "godot:box3d"
import physics "godot:box3d/godot/scene"

Starter :: struct {
    owner: gd.Node3d,
    world: gd.Node3d `gd:"onready=World"`,
    crate: gd.Node3d `gd:"onready=World/Crate"`,
    help:  gd.Label  `gd:"onready=HUD/Help"`,
    scene: physics.Scene,
    failed: bool,
}

starter_ready :: proc(self: ^Starter) {
    problem: physics.Diagnostic
    self.scene, problem = physics.open(self.world)
    check(self, problem)
}

starter_physics_process :: proc(self: ^Starter, _delta: f64) {
    if self.failed { return }
    if gd.is_action_just_pressed("reset") {
        if !check(self, physics.reset(&self.scene)) { return }
    }
    if gd.is_action_just_pressed("jump") {
        body, found := physics.body_for_node(&self.scene, self.crate)
        if found {
            status := b.body_apply_impulse(body, {0, 1600, 0})
            if status != .Ok { check(self, {error = .Native, native_status = status}); return }
        }
    }
    check(self, physics.step_fixed(&self.scene))
}

// Temporary tree exit/re-entry keeps the world. Finalization owns cleanup,
// including script removal or node destruction while outside the tree.
starter_finalize :: proc(self: ^Starter) {
    if status := physics.destroy(&self.scene); status != .Ok {
        gd.error_str(physics.describe({error = .Native, native_status = status}))
    }
}

check :: proc(self: ^Starter, diagnostic: physics.Diagnostic) -> bool {
    diagnostic := diagnostic
    defer physics.diagnostic_destroy(&diagnostic)
    if diagnostic.error == .None { return true }
    if diagnostic.error == .Interrupted { return false }
    message := physics.describe(diagnostic)
    gd.error_str(message)
    text := gd.new_string_odin(message)
    defer gd.free_string(text)
    gd.label_set_text(self.help, text)
    self.failed = true
    gd.node_set_physics_process(self.owner, false)
    return false
}
