package adapter_wasm
import gd "godot:godot"
import rgd "godot:replay/godot"
import d "godot:replay/definitions"
import v "godot:replay/view"
import r "godot:replay"
Script :: struct {owner:gd.Node2d,value:u8}
Style :: struct {owner:gd.Resource,color:gd.Color}
fixture :: proc(parent:gd.Node,scene:gd.Packed_Scene,style:gd.Resource) {
 assets:rgd.Archetype_Assets(u8);rgd.archetype_assets_init(&assets,8);defer rgd.archetype_assets_destroy(&assets)
 values:=[1]d.Archetype(u8,rgd.Archetype_Visual){{0,1,{scene,style}}}
 rgd.archetype_assets_publish(&assets,values[:],[]u32{0})
 descriptor:=rgd.Script_Archetype(u8,Script,Style){
  view={present=proc(s:^Script,v:u8){s.value=v},validate=proc(s:^Script)->d.Report{return {}}},
  configure=proc(s:^Script,a:^Style)->d.Report{return {}},
 }
 owner:rgd.Script_Archetypes(u8,u8,Script,Style);defer rgd.script_archetypes_destroy(&owner)
 rgd.script_archetypes_init(&owner,&assets,parent,4,proc(v:u8)->u32{return 0},descriptor)
 items:=[1]v.View_Item(u8,u8){{handle={0,1},view={scale={1,1},color={1,1,1,1}}}}
 rgd.script_archetypes_present(&owner,{1,1},items[:])
 user:=u8(0);rgd.script_archetypes_visit(&owner,&user,proc(p:^u8,h:r.Handle(u8),s:^Script){p^+=s.value})
 rgd.script_archetypes_stats(&owner)
 binding:rgd.Script_Binding(u8,Script);rgd.script_bind(&binding,cast(gd.Node2d)parent,descriptor.view);rgd.script_present(&binding,1);rgd.script_release(&binding)
 batch:rgd.Resource_Batch;rgd.resource_batch_load(&batch,"res://data",8);rgd.resource_batch_destroy(&batch)
}
