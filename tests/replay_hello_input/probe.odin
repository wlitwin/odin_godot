package replay_hello
import gd "godot:godot"

// Test-only explicit frame delivery still executes the production device sampler,
// fixed clock, shared reducer, journal and renderer without a second input path.
@(gd_method)
replay_hello_input_frame :: proc(self:^ReplayHello,dt:gd.Float) {replay_hello_process(self,dt)}
@(gd_method)
replay_hello_input_metric :: proc(self:^ReplayHello,key:string)->gd.Float {
 switch key {
 case "pressed":return gd.Float(self.buttons.pressed)
 case "held":return gd.Float(self.buttons.held)
 case "gate":return self.debug_input_gate ? 1 : 0
 case "accumulator":return self.clock.accumulator
 case "dropped":return self.clock.dropped_seconds
 }
 return -1
}
