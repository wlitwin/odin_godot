//gd:extends Node
//gd:class ManualStack
//gd:kit_cleanup manual
package lifetime_probe
import gd "godot:godot"
import kboot "godot:kit/boot"
import ksess "godot:kit/session"
import kcomms "godot:kit/comms"

ManualStack :: struct {
    owner: gd.Node,
    boot:  kboot.Boot,
    ses:   ksess.Session,
    comms: kcomms.Comms,
}

manual_stack_ready :: proc(self: ^ManualStack) {
    if !manual_stack_net_attach(
        self,
        kboot.Options{methods = kboot.Methods{host = "noop", join = "noop", start = "noop"}},
    ) {
        return
    }
}

@(gd_method)
manual_stack_noop :: proc(self: ^ManualStack) {}

@(gd_method)
manual_stack_close :: proc(self: ^ManualStack) {
    manual_stack_net_detach(self)
    ksess.session_destroy(&self.ses)
}
