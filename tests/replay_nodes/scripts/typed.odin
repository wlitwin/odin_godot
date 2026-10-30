package nodes_probe

import "core:fmt"
import "core:strings"
import d "godot:replay/definitions"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import rgd "godot:replay/godot"

when !LEGACY {
Typed_Actor :: struct {x:f32,hp:i32}
Typed_Rig :: struct {label:gd.Label}
Typed_Counts :: struct {attached,painted,detached,animated:int,refuse:bool}
typed_project :: proc(actor:Typed_Actor)->(v.Entity_View(i32),bool) {return {pose={position={actor.x,0}},scale={1,1},color={1,1,1,1},value=actor.hp},true}
typed_check :: proc(self:^ReplayNodesProbe) {
    counts:Typed_Counts;views:rgd.View_Pool2(Typed_Actor,i32,Typed_Rig)
    binding:=rgd.View_Binding(i32,Typed_Rig){user=&counts,
        attach=proc(user:rawptr,node:gd.Node2d)->(Typed_Rig,bool) {
            c:=cast(^Typed_Counts)user;c.attached+=1
            return {label=cast(gd.Label)gd.get_node(node,"Value")},!c.refuse
        },
        paint=proc(user:rawptr,rig:^Typed_Rig,hp:i32) {c:=cast(^Typed_Counts)user;c.painted+=1;gd.set_text(rig.label,fmt.ctprintf("%d",hp))},
        frame=proc(user:rawptr,rig:^Typed_Rig,hp:i32,dt:f64) {(cast(^Typed_Counts)user).animated+=1;assert(hp==7)},
        detach=proc(user:rawptr,rig:^Typed_Rig) {(cast(^Typed_Counts)user).detached+=1;rig^={}},
    }
    assert(rgd.view_pool_load(&views,self.owner,"res://typed_view.tscn",4,binding));defer rgd.view_pool_destroy(&views)
    pool:r.Pool(Typed_Actor,4);first,_:=r.pool_insert(&pool,Typed_Actor{x=4,hp=7})
    projection:v.Projection(Typed_Actor,i32);assert(v.projection_init(&projection,4));defer v.projection_destroy(&projection)
    assert(v.project_pool(&projection,pool,{1,0},1,.Predicted,typed_project)==.None)
    assert(rgd.view_pool_present(&views,projection.scope,v.projection_values(&projection))==.None)
    node,found:=rgd.view_pool_get(&views,first);assert(found)
    assert(counts.attached==1 && counts.painted==1 && counts.detached==0)
    label:=cast(gd.Label)gd.get_node(node,"Value");text:=gd.label_get_text(label)
    assert(gd.gd_string_to_odin(text)=="7");gd.free_string(text)
    assert(rgd.view_pool_present(&views,projection.scope,v.projection_values(&projection))==.None)
    assert(counts.attached==1 && counts.painted==1)
    assert(rgd.view_pool_frame(&views,.1) && rgd.view_pool_frame(&views,.1));assert(counts.animated==2 && counts.painted==1)
    assert(!rgd.view_pool_frame(&views,-1) && counts.animated==2)
    pool.values[0].hp=3;assert(v.project_pool(&projection,pool,{1,0},2,.Predicted,typed_project)==.None)
    assert(rgd.view_pool_present(&views,projection.scope,v.projection_values(&projection))==.None)
    assert(counts.painted==2);text=gd.label_get_text(label);assert(gd.gd_string_to_odin(text)=="3");gd.free_string(text)
    // Invalid scope/batch cannot retire an existing view or invoke callbacks.
    invalid:=[2]v.View_Item(Typed_Actor,i32){projection.items[0],projection.items[0]}
    assert(rgd.view_pool_present(&views,{2,0},invalid[:])==.Duplicate)
    assert(views.scope.epoch==1 && counts.detached==0)
    rgd.view_pool_invalidate(&views,first)
    assert(rgd.view_pool_present(&views,projection.scope,v.projection_values(&projection))==.None && counts.painted==3)
    // An epoch change recreates the rig even for the same numeric handle.
    assert(rgd.view_pool_present(&views,{2,0},v.projection_values(&projection))==.None)
    replacement,_:=rgd.view_pool_get(&views,first)
    assert(replacement!=node && counts.attached==2 && counts.detached==1)
    assert(rgd.view_pool_present(&views,{1,0},v.projection_values(&projection))==.Invalid)
    assert(r.pool_remove(&pool,first));next,_:=r.pool_insert(&pool,Typed_Actor{x=5,hp=9})
    assert(v.project_pool(&projection,pool,{2,0},3,.Predicted,typed_project)==.None)
    assert(rgd.view_pool_present(&views,projection.scope,v.projection_values(&projection))==.None)
    _,found=rgd.view_pool_get(&views,first);assert(!found)
    _,found=rgd.view_pool_get(&views,next);assert(found && counts.attached==3 && counts.detached==2)
    counts.refuse=true
    assert(rgd.view_pool_present(&views,{3,0},v.projection_values(&projection))==.Attach)
    assert(views.nodes.count==0 && counts.attached==4 && counts.detached==4)
    invalid_root:rgd.View_Pool2(Typed_Actor,i32,Typed_Rig)
    assert(rgd.view_pool_load(&invalid_root,self.owner,"res://invalid_root.tscn",1,binding));defer rgd.view_pool_destroy(&invalid_root)
    assert(rgd.view_pool_present(&invalid_root,{1,0},v.projection_values(&projection))==.Scene)
    report:=rgd.view_pool_problem(&invalid_root)
    assert(strings.contains(d.report_path(&report),"invalid_root.tscn") && strings.contains(d.report_path(&report),"$scene.root") && strings.contains(d.report_message(&report),"expected Node2D"))
    assert(invalid_root.nodes.count==0 && counts.attached==4)
    gd.print_str("REPLAY_VIEW_ROOT_VALIDATION_OK")
    gd.print_str(fmt.tprintf("REPLAY_TYPED_VIEWS_OK attach=%d detach=%d paints=%d",counts.attached,counts.detached,counts.painted))
}

}
