package nodes_probe
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import inputgd "godot:replay/godot/input"

when !LEGACY {
    Bound_Control :: struct {
        held, pressed: bool,
    }

    Bound_Action :: struct {
        amount: i32,
    }

    Bound_Source :: struct {
        amount:        i32,
        calls, issued: int,
        sequence:      u64,
        reject:        bool,
    }

    bound_submit :: proc(raw: rawptr, value: Bound_Action) -> (u64, net.Error) {
        source := cast(^Bound_Source)raw
        source.calls += 1

        if source.reject {
            return 0, .Fenced
        }

        source.sequence += 1
        source.issued += int(value.amount)
        return source.sequence, .None
    }

    input_check :: proc(self: ^ReplayNodesProbe) {
        controls: inputgd.Input_Binding(Bound_Control)
        actions := [1]inputgd.Input_Action{{"ui_accept", 0}}
        assert(
            inputgd.input_binding_init(
                &controls,
                actions[:],
                Bound_Control{},
                proc(_: rawptr, b: r.Buttons) -> Bound_Control {
                    return {b.held & 1 != 0, b.pressed & 1 != 0}
                },
            ),
        )
        defer inputgd.input_binding_destroy(&controls)
        name := gd.new_string_name("ui_accept")
        defer gd.free_string_name(name)
        input := gd.singleton_input()
        gd.input_action_press(input, name, 1)
        assert(inputgd.input_binding_sample(&controls))
        value := inputgd.input_binding_read(&controls)
        assert(value.held && value.pressed)
        inputgd.input_binding_consume(&controls)
        value = inputgd.input_binding_read(&controls)
        assert(value.held && !value.pressed)
        assert(inputgd.input_binding_sample(&controls, {.Menu}))
        assert(inputgd.input_binding_read(&controls) == (Bound_Control{}))
        gd.input_action_release(input, name)
        button := gd.new_button()
        gd.add_child(self.owner, button)
        defer gd.node_queue_free(button)
        source := Bound_Source {
            amount = 7,
            reject = true,
        }
        binding: inputgd.Signal_Action(Bound_Action)
        assert(inputgd.signal_action_init(&binding, button, "pressed", proc(raw: rawptr) -> (Bound_Action, bool) {
                    return {(cast(^Bound_Source)raw).amount}, true
                }, &source))
        defer inputgd.signal_action_destroy(&binding)
        pressed := gd.new_string_name("pressed")
        defer gd.free_string_name(pressed)
        assert(gd.object_emit_signal(button, pressed) == .Ok)
        source.amount = 99
        assert(gd.object_emit_signal(button, pressed) == .Ok)
        assert(binding.intent.captured && binding.intent.value.amount == 7 && binding.refused == 1)
        sequence, error := net.intent_submit(&binding.intent, 1, bound_submit, &source)
        assert(sequence == 0 && error == .Fenced && binding.intent.captured)
        source.reject = false
        sequence, error = net.intent_submit(&binding.intent, 1, bound_submit, &source)
        assert(sequence == 1 && error == .None && !binding.intent.captured && source.issued == 7)
        assert(!net.intent_resolve(&binding.intent, 2, {sequence = 1, tick = 1, applied = true}))
        assert(net.intent_resolve(&binding.intent, 1, {sequence = 1, tick = 1, applied = true}))
        assert(!net.intent_resolve(&binding.intent, 1, {sequence = 1, tick = 1, applied = true}))
        inputgd.signal_action_gate(&binding, {.Paused})
        assert(gd.object_emit_signal(button, pressed) == .Ok)
        assert(!binding.intent.captured)
        inputgd.signal_action_gate(&binding, {})
        assert(gd.object_emit_signal(button, pressed) == .Ok)
        inputgd.signal_action_gate(&binding, {.Menu}, .Keep)
        assert(binding.intent.captured)
        inputgd.signal_action_gate(&binding, {.Menu})
        assert(!binding.intent.captured)
        // Recovery still settles/rebinds tickets while UI submission is paused.
        inputgd.signal_action_gate(&binding, {})
        assert(gd.object_emit_signal(button, pressed) == .Ok)
        sequence, error = net.intent_submit(&binding.intent, 1, bound_submit, &source)
        assert(error == .None && sequence == 2)
        session: rgd.Session(u32, u8, Bound_Action, u8, 1)
        session.ready = true
        session.recovery_serial = 1
        session.recovery = {
            from_epoch = 1,
            to_epoch   = 2,
            received   = 2,
            settled    = 1,
            count      = 1,
        }
        session.recovery.actions[0] = {
            epoch       = 1,
            sequence    = 2,
            disposition = .Retained,
        }
        inputgd.signal_action_gate(&binding, {.Paused})
        _, error = inputgd.session_bound_action(&session, &binding)
        assert(error == .Fenced)
        assert(binding.intent.pending[0] == (net.Intent_Ticket{2, 2}))
        assert(!net.intent_resolve(&binding.intent, 1, {sequence = 2, tick = 2, applied = true}))
        assert(net.intent_resolve(&binding.intent, 2, {sequence = 2, tick = 2, applied = true}))
        // Disconnect leaves no signal connection or subsequent capture.
        inputgd.signal_action_destroy(&binding)
        connections := gd.object_get_signal_connection_list(button, pressed)
        assert(gd.array_size(&connections) == 0)
        gd.free_array(connections)
        gd.object_emit_signal(button, pressed)
        assert(!binding.intent.captured)
        gd.print_str("REPLAY_INPUT_BINDINGS_OK copied=7 retry=true epoch_fenced=true disconnect=true")
    }
}
