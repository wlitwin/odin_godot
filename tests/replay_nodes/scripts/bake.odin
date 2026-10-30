package nodes_probe
import "core:fmt"
import gd "godot:godot"
import d "godot:replay/definitions"
import rgd "godot:replay/godot"

when !LEGACY {
Bake_Source :: struct {scene:gd.Packed_Scene,fail,top:bool}
bake_check :: proc(self:^ReplayNodesProbe) {
    scene:=gd.load_scene("res://bake_scene.tscn");assert(scene!=nil);defer gd.release_ref(scene)
    store:d.Store([2]f32);assert(d.init(&store,2).error==.None);defer d.destroy(&store)
    extract:=proc(source:Bake_Source,ctx:^rgd.Bake_Context)->[2]f32 {
        root:=rgd.bake_scene2(ctx,source.scene,"$.scene")
        if source.top && root!=nil {gd.canvas_item_set_as_top_level(cast(gd.Canvas_Item)gd.get_node(root,"Offset"),true)}
        path:=source.fail ? "Missing" : "Offset/Spawn"
        point,_:=rgd.bake_marker2(ctx,root,path);return point
    }
    ref,report:=rgd.bake(&store,Bake_Source{scene=scene},1,extract)
    assert(report.error==.None)
    value,found:=d.get(&store,ref);assert(found && value==([2]f32{18,35}))
    same,_:=rgd.bake(&store,Bake_Source{scene=scene},1,extract);assert(same==ref)
    rejected:d.Ref
    rejected,report=rgd.bake(&store,Bake_Source{scene=scene,fail=true},1,extract)
    assert(report.error==.Invalid && rejected==(d.Ref{}) && d.report_path(&report)=="Missing")
    _,report=rgd.bake(&store,Bake_Source{scene=scene,top=true},1,extract)
    assert(report.error==.Invalid && d.report_path(&report)=="Offset/Spawn")
    unchanged,_:=d.get(&store,ref);assert(unchanged==value)
    gd.print_str(fmt.tprintf("REPLAY_BAKE_OK point=%v retained_after_failure=true",value))
}
}
