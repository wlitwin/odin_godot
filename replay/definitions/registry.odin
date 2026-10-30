package replay_definitions

import "core:mem"
import "core:fmt"
import r "godot:replay"

Archetype :: struct($Definition,$Local:typeid) {id:u32,definition:Definition,local:Local}
Registry_Slot :: struct($Definition,$Local:typeid) {value:Archetype(Definition,Local),present:bool}
// Single presentation/authoring owner. Local may contain borrowed engine assets;
// Definition is always an owned replayable value. IDs include zero and are bounded.
Registry :: struct($Definition,$Local:typeid) {
    entries,scratch:[]Registry_Slot(Definition,Local),
    allocator:mem.Allocator,count:int,
}
registry_init :: proc(registry:^Registry($Definition,$Local),id_limit:int,allocator:=context.allocator)->bool {
    if len(registry.entries)!=0 || id_limit<1 || id_limit>65536 || !r.value_supported(Definition) {return false}
    registry.allocator=allocator
    registry.entries=make([]Registry_Slot(Definition,Local),id_limit,allocator);registry.scratch=make([]Registry_Slot(Definition,Local),id_limit,allocator)
    return true
}
registry_destroy :: proc(registry:^Registry($Definition,$Local)) {delete(registry.entries,registry.allocator);delete(registry.scratch,registry.allocator);registry^={}}
registry_publish :: proc(registry:^Registry($Definition,$Local),values:[]Archetype(Definition,Local),required:[]u32,
                         validate:proc(Archetype(Definition,Local))->Report)->Report {
    if len(registry.entries)==0 {return problem(.Invalid,"$","registry is not ready")}
    if len(values)>len(registry.entries) {return problem(.Capacity,"$","too many archetypes")}
    for &slot in registry.scratch {slot={}}
    for value in values {
        path:=fmt.tprintf("$archetypes[%d]",value.id)
        if u64(value.id)>=u64(len(registry.entries)) {return problem(.Invalid,path,"archetype ID exceeds the registry limit")}
        if registry.scratch[value.id].present {return problem(.Invalid,path,"duplicate archetype ID")}
        if validate!=nil {if report:=validate(value);report.error!=.None {return report}}
        registry.scratch[value.id]={value,true}
    }
    for id in required {
        if u64(id)>=u64(len(registry.entries)) || !registry.scratch[id].present {return problem(.Missing,fmt.tprintf("$archetypes[%d]",id),"required archetype has no registration")}
    }
    registry.entries,registry.scratch=registry.scratch,registry.entries;registry.count=len(values)
    return {}
}
registry_get :: proc(registry:^Registry($Definition,$Local),id:u32)->(Archetype(Definition,Local),bool) {
    if u64(id)>=u64(len(registry.entries)) || !registry.entries[id].present {return {},false}
    return registry.entries[id].value,true
}
