package replay_godot
import "core:fmt"
import gd "godot:godot"
import d "godot:replay/definitions"

// Called only on error. Owned diagnostics remain readable after nodes/resources
// are retired. This is local reporting, never part of a replayable value.
view_pool_fail :: proc(p:^View_Pool2($Entity,$Value,$Rig),error:View_Pool_Error,key:u64,detail:d.Report={})->View_Pool_Error {
    detail:=detail;key:=key
    if error==.Scene && p.nodes.invalid_root_key!=0 {key=p.nodes.invalid_root_key;detail=d.problem(.Invalid,"$scene.root","expected Node2D scene root")}
    path:=gd.String{}
    if p.nodes.scene!=nil {path=gd.resource_get_path(p.nodes.scene)}
    defer gd.free_string(path)
    scene:=p.nodes.scene!=nil ? gd.gd_string_to_odin(path) : "<unbound>"
    field:=detail.error!=.None ? d.report_path(&detail) : "$view"
    message:=detail.error!=.None ? d.report_message(&detail) : fmt.tprintf("view binding failed: %v",error)
    p.problem=d.problem(.Invalid,fmt.tprintf("scene=%s entity=%d %s",scene,key,field),message)
    return error
}
view_pool_problem :: proc(p:^View_Pool2($Entity,$Value,$Rig))->d.Report {return p.problem}
archetype_pool_problem :: proc(p:^Archetype_Pool2($Entity,$Value,$Rig))->d.Report {return p.problem}
