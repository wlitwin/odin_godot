package replay_godot_scene

import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import d "godot:replay/definitions"
import r "godot:replay"

// Stable-address configuration for the low-level pool API. Script is an ordinary
// generated Odin Node script. Godot owns its instance and normal lifecycle.
// The optional validator reports the exact failed component or field.
Script_View :: struct($Value, $Script: typeid) {
    present:  proc(_: ^Script, _: Value),
    validate: proc(_: ^Script) -> d.Report,
    retired:  proc(_: ^Script),
    problem:  d.Report,
}

@(private)
script_view_resolve :: proc(config: ^Script_View($Value, $Script), node: gd.Node2d) -> (^Script, d.Report) {
    if !r.value_supported(Value) {
        return nil, d.problem(.Invalid, "$binding.value", "display must be a bounded value without references")
    }

    if config.present == nil {
        return nil, d.problem(.Invalid, "$binding.present", "missing presentation callback")
    }

    script := rt.script_of(cast(gd.Object)node, Script)

    if script == nil {
        return nil, d.problem(.Invalid, "$script", fmt.tprintf("expected scene script %v", typeid_of(Script)))
    }

    if config.validate != nil {
        if report := config.validate(script); report.error != .None {
            return script, report
        }
    }

    return script, {}
}

script_view_binding :: proc(config: ^Script_View($Value, $Script)) -> View_Binding(Value, ^Script) {
    return {user = config, attach = proc(raw: rawptr, node: gd.Node2d) -> (^Script, bool) {
            binding := cast(^Script_View(Value, Script))raw
            script, report := script_view_resolve(binding, node)
            binding.problem = report
            return script, report.error == .None
        }, paint = proc(raw: rawptr, script: ^^Script, value: Value) {
            binding := cast(^Script_View(Value, Script))raw
            binding.present(script^, value)
        }, detach = proc(raw: rawptr, script: ^^Script) {
            binding := cast(^Script_View(Value, Script))raw

            if script^ != nil && binding.retired != nil {
                binding.retired(script^)
            }

            script^ = nil
        }, diagnose = proc(raw: rawptr) -> d.Report {
            binding := cast(^Script_View(Value, Script))raw
            return binding.problem
        }}
}

// A borrowed authored/permanent scene. Binding does not spawn/free the node or
// choose its lifetime. Call release before the node is freed/rebound. It stores
// the descriptor by value and needs no external callback configuration address.
Script_Binding :: struct($Value, $Script: typeid) {
    script: ^Script,
    config: Script_View(Value, Script),
}

script_bind :: proc(
    binding: ^Script_Binding($Value, $Script),
    node: gd.Node2d,
    config: Script_View(Value, Script),
) -> d.Report {
    if binding.script != nil {
        return d.problem(.Invalid, "$binding", "release existing binding before rebinding")
    }

    descriptor := config
    script, report := script_view_resolve(&descriptor, node)

    if report.error != .None {
        if script != nil && descriptor.retired != nil {
            descriptor.retired(script)
        }

        return report
    }

    binding.script, binding.config = script, descriptor
    return {}
}

script_present :: proc(binding: ^Script_Binding($Value, $Script), value: Value) -> bool {
    if binding.script == nil {
        return false
    }

    binding.config.present(binding.script, value)
    return true
}

script_release :: proc(binding: ^Script_Binding($Value, $Script)) {
    if binding.script != nil && binding.config.retired != nil {
        binding.config.retired(binding.script)
    }

    binding^ = {}
}
