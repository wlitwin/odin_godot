//gd:extends Node2D
//gd:class ReplayDebugProbe
package replay_debug_probe

import gd "godot:godot"
import r "godot:replay"
import debuggd "godot:replay/godot/debug"

World :: struct {
    counter:   u32,
    inventory: [2]u32,
}

ReplayDebugProbe :: struct {
    owner:    gd.Node2d,
    timeline: r.Timeline(World, u8, u32),
    debug:    debuggd.Debug_Overlay,
    fault:    u32,
}

step :: proc(w: ^World, input: u8, ctx: ^r.Step(u32)) {
    w.counter += u32(input)

    if ctx.tick == 2 {
        w.inventory[1] += (cast(^u32)ctx.user)^
    }

    r.emit(ctx, 1, 1, w.counter)
}

replay_debug_probe_ready :: proc(self: ^ReplayDebugProbe) {
    r.init(&self.timeline, r.Frame(World){state = {inventory = {5, 7}}}, step, user = &self.fault)

    for _ in 0 ..< 3 {
        r.advance(&self.timeline, u8(1))
    }

    debuggd.debug_overlay_init(&self.debug, self.owner, true)
}

replay_debug_probe_process :: proc(self: ^ReplayDebugProbe, dt: f64) {
    debuggd.debug_timeline_frame(&self.debug, &self.timeline)
}

replay_debug_probe_exit_tree :: proc(self: ^ReplayDebugProbe) {
    debuggd.debug_overlay_destroy(&self.debug)
    r.destroy(&self.timeline)
}

@(gd_method)
replay_debug_probe_set_fault :: proc(self: ^ReplayDebugProbe, enabled: bool) {
    self.fault = enabled ? 1 : 0
}

@(gd_method)
replay_debug_probe_report :: proc(self: ^ReplayDebugProbe) -> gd.Label {
    return self.debug.label
}

@(gd_method)
replay_debug_probe_probe :: proc(self: ^ReplayDebugProbe, key: string) -> gd.Int {
    frame, _ := r.current(&self.timeline)

    switch key {
    case "inventory":
        return gd.Int(frame.state.inventory[1])
    case "audits":
        return gd.Int(self.debug.audits)
    case "tick":
        return gd.Int(self.debug.last_audit.tick)
    case "error":
        return gd.Int(self.debug.last_audit.error)
    case "visible":
        return gd.Int(self.debug.visible)
    }

    return -1
}
