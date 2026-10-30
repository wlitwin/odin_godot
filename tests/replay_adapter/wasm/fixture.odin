package adapter_wasm
import gd "godot:godot"
import d "godot:replay/definitions"
import v "godot:replay/view"
import r "godot:replay"
import scenegd "godot:replay/godot/scene"
Script :: struct {owner:gd.Node2d,value:u8}
Style :: struct {owner:gd.Resource,color:gd.Color}
fixture :: proc(parent:gd.Node,scene:gd.Packed_Scene,style:gd.Resource) {
 assets:scenegd.Archetype_Assets(u8);scenegd.archetype_assets_init(&assets,8);defer scenegd.archetype_assets_destroy(&assets)
 values:=[1]d.Archetype(u8,scenegd.Archetype_Visual){{0,1,{scene,style}}}
 scenegd.archetype_assets_publish(&assets,values[:],[]u32{0})
 descriptor:=scenegd.Script_Archetype(u8,Script,Style){
  view={present=proc(s:^Script,v:u8){s.value=v},validate=proc(s:^Script)->d.Report{return {}}},
  configure=proc(s:^Script,a:^Style)->d.Report{return {}},
 }
 owner:scenegd.Script_Archetypes(u8,u8,Script,Style);defer scenegd.script_archetypes_destroy(&owner)
 scenegd.script_archetypes_init(&owner,&assets,parent,4,proc(v:u8)->u32{return 0},descriptor)
 items:=[1]v.View_Item(u8,u8){{handle={0,1},view={scale={1,1},color={1,1,1,1}}}}
 scenegd.script_archetypes_present(&owner,{1,1},items[:])
 user:=u8(0);scenegd.script_archetypes_visit(&owner,&user,proc(p:^u8,h:r.Handle(u8),s:^Script){p^+=s.value})
 scenegd.script_archetypes_stats(&owner)
 binding:scenegd.Script_Binding(u8,Script);scenegd.script_bind(&binding,cast(gd.Node2d)parent,descriptor.view);scenegd.script_present(&binding,1);scenegd.script_release(&binding)
 batch:scenegd.Resource_Batch;scenegd.resource_batch_load(&batch,"res://data",8);scenegd.resource_batch_destroy(&batch)
}
