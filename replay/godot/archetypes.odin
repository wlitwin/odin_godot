package replay_godot
import "core:fmt"
import gd "godot:godot"
import d "godot:replay/definitions"

Archetype_Visual :: struct {scene:gd.Packed_Scene,appearance:gd.Resource}
Archetype_Assets :: struct($Definition:typeid) {registry:d.Registry(Definition,Archetype_Visual)}
archetype_assets_init :: proc(owner:^Archetype_Assets($Definition),id_limit:int,allocator:=context.allocator)->bool {
 return d.registry_init(&owner.registry,id_limit,allocator)
}
archetype_assets_destroy :: proc(owner:^Archetype_Assets($Definition)) {
 for slot in owner.registry.entries {if slot.present {gd.release_ref(slot.value.local.scene);gd.release_ref(slot.value.local.appearance)}}
 d.registry_destroy(&owner.registry);owner^={}
}
// Candidate resources are borrowed for the call. On success the owner retains
// its own references. Destroy dependent views before replacing/closing assets.
archetype_assets_publish :: proc(owner:^Archetype_Assets($Definition),values:[]d.Archetype(Definition,Archetype_Visual),required:[]u32)->d.Report {
 // Keep prior resource refs separately because the pure registry's scratch may
 // have been used by a failed candidate. This is an authoring operation, not hot.
 prior:=make([]Archetype_Visual,owner.registry.count);defer delete(prior)
 count:=0;for slot in owner.registry.entries {if slot.present {prior[count]=slot.value.local;count+=1}}
 report:=d.registry_publish(&owner.registry,values,required,proc(value:d.Archetype(Definition,Archetype_Visual))->d.Report {
  if !bake_is_class(cast(gd.Object)value.local.scene,"PackedScene") {return d.problem(.Invalid,fmt.tprintf("$archetypes[%d].scene",value.id),"expected PackedScene")}
  if value.local.appearance!=nil && !bake_is_class(cast(gd.Object)value.local.appearance,"Resource") {return d.problem(.Invalid,fmt.tprintf("$archetypes[%d].appearance",value.id),"expected Resource")}
  return {}
 })
 if report.error!=.None {return report}
 for value in values {gd.ref_counted_reference(value.local.scene);if value.local.appearance!=nil {gd.ref_counted_reference(value.local.appearance)}}
 for visual in prior {gd.release_ref(visual.scene);gd.release_ref(visual.appearance)}
 return {}
}
