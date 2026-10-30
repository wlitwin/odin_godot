package fixture
import d "godot:replay/definitions"
import gd "godot:godot"
import scenegd "godot:replay/godot/scene"
fixture :: proc() {
 store:d.Store([2]f32);d.init(&store,2)
 ref,report:=scenegd.bake(&store,gd.Packed_Scene(nil),1,proc(scene:gd.Packed_Scene,ctx:^scenegd.Bake_Context)->[2]f32 {
  root:=scenegd.bake_scene2(ctx,scene,"$.scene");point,_:=scenegd.bake_marker2(ctx,root,"Spawn");return point
 })
 bytes,result:=d.artifact_export(&store,ref,7);defer delete(bytes)
 d.artifact_import(&store,bytes,1,7)
 registry:d.Registry([2]f32,u32);d.registry_init(&registry,8);defer d.registry_destroy(&registry)
 values:=[1]d.Archetype([2]f32,u32){{0,{1,2},3}}
 validator:proc(d.Archetype([2]f32,u32))->d.Report
 d.registry_publish(&registry,values[:],[]u32{0},validator)
 d.pin(&store,ref);d.unpin(&store,ref);d.destroy(&store)
}
