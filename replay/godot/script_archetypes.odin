package replay_godot

import "core:mem"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import d "godot:replay/definitions"

Script_Archetype :: struct($Value,$Script,$Appearance:typeid) {
    view:Script_View(Value,Script),
    configure:proc(^Script,^Appearance)->d.Report,
}
@(private)
Script_Archetype_Context :: struct($Value,$Script,$Appearance:typeid) {
    descriptor:Script_Archetype(Value,Script,Appearance),appearance:gd.Resource,problem:d.Report,
}
// Owns stable callback contexts and retains appearance resources independently
// of the source registry. Pool scene references are already owned by View_Pool2.
// Keep this owner stable; destroy before its parent or script module disappears.
Script_Archetypes :: struct($Entity,$Value,$Script,$Appearance:typeid) {
    pool:Archetype_Pool2(Entity,Value,^Script),
    contexts:[]Script_Archetype_Context(Value,Script,Appearance),allocator:mem.Allocator,
}
script_archetypes_init :: proc(owner:^Script_Archetypes($Entity,$Value,$Script,$Appearance),assets:^Archetype_Assets($Definition),parent:gd.Node,capacity:int,
                              select:proc(Value)->u32,descriptor:Script_Archetype(Value,Script,Appearance),allocator:=context.allocator)->d.Report {
    if len(owner.contexts)!=0 || descriptor.view.present==nil || descriptor.configure==nil || assets.registry.count==0 {return d.problem(.Invalid,"$binding","invalid or initialized script archetype owner")}
    owner.allocator=allocator
    owner.contexts=make([]Script_Archetype_Context(Value,Script,Appearance),len(assets.registry.entries),allocator)
    for slot,i in assets.registry.entries {if slot.present {
        owner.contexts[i].descriptor=descriptor;owner.contexts[i].appearance=slot.value.local.appearance
        if slot.value.local.appearance!=nil {gd.ref_counted_reference(slot.value.local.appearance)}
    }}
    ok:=archetype_pool_init(&owner.pool,assets,parent,capacity,select,
        proc(raw:rawptr,id:u32,_:Definition,_:Archetype_Visual)->View_Binding(Value,^Script) {
            owner:=cast(^Script_Archetypes(Entity,Value,Script,Appearance))raw
            return {
                user=&owner.contexts[id],
                attach=proc(raw:rawptr,node:gd.Node2d)->(^Script,bool) {
                    config:=cast(^Script_Archetype_Context(Value,Script,Appearance))raw
                    script,report:=script_view_resolve(&config.descriptor.view,node)
                    config.problem=report;if report.error!=.None {return script,false}
                    style: ^Appearance
                    style,report=resource_script(config.appearance,Appearance,"$appearance")
                    config.problem=report;if report.error!=.None {return script,false}
                    config.problem=config.descriptor.configure(script,style)
                    return script,config.problem.error==.None
                },
                paint=proc(raw:rawptr,script:^^Script,value:Value){config:=cast(^Script_Archetype_Context(Value,Script,Appearance))raw;config.descriptor.view.present(script^,value)},
                detach=proc(raw:rawptr,script:^^Script) {
                    config:=cast(^Script_Archetype_Context(Value,Script,Appearance))raw
                    if script^!=nil && config.descriptor.view.retired!=nil {config.descriptor.view.retired(script^)};script^=nil
                },
                diagnose=proc(raw:rawptr)->d.Report{config:=cast(^Script_Archetype_Context(Value,Script,Appearance))raw;return config.problem},
            }
        },owner,allocator)
    if !ok {script_archetypes_destroy(owner);return d.problem(.Invalid,"$binding","could not initialize archetype scene pools")}
    return {}
}
script_archetypes_destroy :: proc(owner:^Script_Archetypes($Entity,$Value,$Script,$Appearance)) {
    archetype_pool_destroy(&owner.pool)
    for slot in owner.contexts {gd.release_ref(slot.appearance)}
    delete(owner.contexts,owner.allocator);owner^={}
}
script_archetypes_present :: proc(owner:^Script_Archetypes($Entity,$Value,$Script,$Appearance),scope:v.View_Scope,items:[]v.View_Item(Entity,Value))->d.Report {
    error:=archetype_pool_present(&owner.pool,scope,items)
    return error==.None ? d.Report{} : archetype_pool_problem(&owner.pool)
}
script_archetypes_visit :: proc(owner:^Script_Archetypes($Entity,$Value,$Script,$Appearance),user:^$User,visit:proc(^User,r.Handle(Entity),^Script)) {
    archetype_pool_visit(&owner.pool,user,visit)
}
script_archetypes_stats :: proc(owner:^Script_Archetypes($Entity,$Value,$Script,$Appearance))->View_Stats {return archetype_pool_stats(&owner.pool)}
