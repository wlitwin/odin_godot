//gd:extends Node
//gd:class AutoStack
package lifetime_probe
import gd "godot:godot"
import kboot "godot:kit/boot"
import ksess "godot:kit/session"
import kcomms "godot:kit/comms"

AutoStack :: struct {
    owner: gd.Node,
    boot:  kboot.Boot,
    ses:   ksess.Session,
    comms: kcomms.Comms,
}

auto_final_calls, auto_rider_before: int

auto_stack_ready :: proc(self: ^AutoStack) {
    if !auto_stack_net_attach(
        self,
        kboot.Options{methods = kboot.Methods{host = "noop", join = "noop", start = "noop"}},
    ) {
        return
    }
}

auto_stack_finalize :: proc(self: ^AutoStack) {
    auto_final_calls += 1

    if self.boot.ses == &self.ses && self.boot.ui_layer != nil {
        auto_rider_before += 1
    }

    // Deliberate explicit ordering; the standard tail must tolerate this.
    auto_stack_net_detach(self)
}

@(gd_method)
auto_stack_noop :: proc(self: ^AutoStack) {}

@(gd_method)
auto_stack_counts :: proc(self: ^AutoStack, which: i64) -> i64 {
    return which == 0 ? i64(auto_final_calls) : i64(auto_rider_before)
}

@(gd_method)
auto_stack_button :: proc(self: ^AutoStack) -> gd.Button {
    return self.boot.ui.host_btn
}
