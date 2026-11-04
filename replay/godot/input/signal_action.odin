package replay_godot_input

import replaygd "godot:replay/godot"

import gd "godot:godot"
import "godot:gdext"
import net "godot:replay/net"
import r "godot:replay"
import view "godot:replay/view"

Unsubmitted_Policy :: enum {
    Cancel,
    Keep,
}

@(private)
Action_Callback :: struct {
    user:   rawptr,
    invoke: proc(_: rawptr),
}

// Stable-address owner. The emitter and user must outlive this connection.
// One copied unsubmitted action, followed by ordinary epoch-scoped intent tickets.
Signal_Action :: struct($Action: typeid) {
    intent:                     net.Action_Intent(Action),
    emitter:                    gd.Object,
    signal:                     gd.String_Name,
    call:                       gd.Callable,
    callback:                   Action_Callback,
    make:                       proc(_: rawptr) -> (Action, bool),
    user:                       rawptr,
    ready, connected, blocked:  bool,
    captures, refused, ignored: u64,
    capture_error:              net.Error,
}

signal_action_init :: proc(
    b: ^Signal_Action($Action),
    emitter: gd.Object,
    signal: string,
    make: proc(_: rawptr) -> (Action, bool),
    user: rawptr = nil,
) -> bool {
    if b.ready || emitter == nil || len(signal) == 0 || make == nil || !r.value_supported(Action) {
        return false
    }

    b.emitter, b.signal, b.make, b.user = emitter, gd.new_string_name(signal), make, user
    b.callback = {
        user = b,
        invoke = proc(raw: rawptr) {
            signal_action_capture(cast(^Signal_Action(Action))raw)
        },
    }
    info := gdext.ExtensionCallableCustomInfo2 {
        token             = gdext.library,
        call_func         = signal_action_callback,
        callable_userdata = &b.callback,
    }
    gdext.callable_custom_create2(&b.call, &info)
    b.ready = true
    b.connected = gd.object_connect(emitter, b.signal, b.call, 0) == .Ok

    if !b.connected {
        signal_action_destroy(b)
        return false
    }

    return true
}

signal_action_destroy :: proc(b: ^Signal_Action($Action)) {
    if b.connected {
        gd.object_disconnect(b.emitter, b.signal, b.call)
    }

    if b.ready {
        gd.free_callable(b.call)
        gd.free_string_name(b.signal)
    }

    b^ = {}
}

// Signals and explicit local calls share this single-slot capture path. Payload
// construction happens at the click, not later during a retry.
signal_action_capture :: proc(b: ^Signal_Action($Action)) -> net.Error {
    if !b.ready {
        return .Not_Initialized
    }

    if b.blocked {
        b.ignored += 1
        return .Fenced
    }

    if b.intent.captured {
        b.refused += 1
        b.capture_error = .Capacity
        return .Capacity
    }

    value, ok := b.make(b.user)

    if !ok {
        b.ignored += 1
        return .Invalid_Input
    }

    error := net.intent_capture(&b.intent, value)
    b.capture_error = error

    if error == .None {
        b.captures += 1
    } else {
        b.refused += 1
    }

    return error
}

signal_action_gate :: proc(b: ^Signal_Action($Action), gates: r.Input_Gates, policy: Unsubmitted_Policy = .Cancel) {
    b.blocked = gates != {}

    if b.blocked && policy == .Cancel {
        net.intent_cancel(&b.intent)
    }
}

session_bound_action :: proc(s: ^replaygd.Session($S, $C, $A, $E, $N), b: ^Signal_Action(A)) -> (u64, net.Error) {
    if !b.ready {
        return 0, .Not_Initialized
    }

    if s.recovery_serial != 0 {
        if error := net.intent_recover(&b.intent, s.recovery); error != .None {
            return 0, error
        }
    }

    if b.blocked {
        return 0, .Fenced
    }

    return session_intent(s, &b.intent)
}

room_bound_action :: proc(room: ^replaygd.Room($S, $C, $A, $E, $N), b: ^Signal_Action(A)) -> (u64, net.Error) {
    if !b.ready {
        return 0, .Not_Initialized
    }

    if room.session.recovery_serial != 0 {
        if error := net.intent_recover(&b.intent, room.session.recovery); error != .None {
            return 0, error
        }
    }

    if b.blocked {
        return 0, .Fenced
    }

    return room_intent(room, &b.intent)
}

bound_action_observe :: proc(
    b: ^Signal_Action($A),
    s: ^replaygd.Session($S, $C, A, $E, $N),
    change: view.Change(net.Net_Event(E)),
) -> bool {
    return intent_observe(&b.intent, s, change)
}

@(private)
signal_action_callback :: proc "c" (
    raw: rawptr,
    args: [^]gdext.VariantPtr,
    argc: i64,
    ret: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()
    gdext.variant_new_nil(ret)
    error^ = {}

    // This binding deliberately supports no-argument signals such as pressed.
    if argc != 0 {
        return
    }

    callback := cast(^Action_Callback)raw
    callback.invoke(callback.user)
}
