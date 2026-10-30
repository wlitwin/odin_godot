package replay_godot

import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import d "godot:replay/definitions"
import r "godot:replay"

// Stable-address configuration for the low-level pool API. Script is an ordinary
// generated Odin Node script. Godot owns its instance and normal lifecycle.
// validate adds field-level diagnostics; valid remains for existing callers.
Script_View :: struct($Value,$Script:typeid) {
    present:proc(^Script,Value),
    valid:proc(^Script)->bool,
    retired:proc(^Script),
    validate:proc(^Script)->d.Report,
    problem:d.Report,
}
script_view_resolve :: proc(config:^Script_View($Value,$Script),node:gd.Node2d)->(^Script,d.Report) {
    if !r.value_supported(Value) {return nil,d.problem(.Invalid,"$binding.value","display must be a bounded value without references")}
    if config.present==nil {return nil,d.problem(.Invalid,"$binding.present","missing presentation callback")}
    script:=rt.script_of(cast(gd.Object)node,Script)
    if script==nil {return nil,d.problem(.Invalid,"$script",fmt.tprintf("expected scene script %v",typeid_of(Script)))}
    if config.validate!=nil {if report:=config.validate(script);report.error!=.None {return script,report}}
    if config.valid!=nil && !config.valid(script) {return script,d.problem(.Invalid,"$script",fmt.tprintf("%v rejected required components or configuration",typeid_of(Script)))}
    return script,{}
}
script_view_binding :: proc(config:^Script_View($Value,$Script))->View_Binding(Value,^Script) {
    return {
        user=config,
        attach=proc(raw:rawptr,node:gd.Node2d)->(^Script,bool) {
            config:=cast(^Script_View(Value,Script))raw
            script,report:=script_view_resolve(config,node);config.problem=report
            return script,report.error==.None
        },
        paint=proc(raw:rawptr,script:^^Script,value:Value) {
            config:=cast(^Script_View(Value,Script))raw;config.present(script^,value)
        },
        detach=proc(raw:rawptr,script:^^Script) {
            config:=cast(^Script_View(Value,Script))raw
            if script^!=nil && config.retired!=nil {config.retired(script^)}
            script^=nil
        },
        diagnose=proc(raw:rawptr)->d.Report {config:=cast(^Script_View(Value,Script))raw;return config.problem},
    }
}
// A borrowed authored/permanent scene. Binding does not spawn/free the node or
// choose its lifetime. Call release before the node is freed/rebound. It stores
// the descriptor by value and needs no external callback configuration address.
Script_Binding :: struct($Value,$Script:typeid) {script:^Script,config:Script_View(Value,Script)}
script_bind :: proc(binding:^Script_Binding($Value,$Script),node:gd.Node2d,config:Script_View(Value,Script))->d.Report {
    if binding.script!=nil {return d.problem(.Invalid,"$binding","release existing binding before rebinding")}
    config:=config
    script,report:=script_view_resolve(&config,node)
    if report.error!=.None {
        if script!=nil && config.retired!=nil {config.retired(script)}
        return report
    }
    binding.script,binding.config=script,config;return {}
}
script_present :: proc(binding:^Script_Binding($Value,$Script),value:Value)->bool {
    if binding.script==nil {return false};binding.config.present(binding.script,value);return true
}
script_release :: proc(binding:^Script_Binding($Value,$Script)) {
    if binding.script!=nil && binding.config.retired!=nil {binding.config.retired(binding.script)}
    binding^={}
}
