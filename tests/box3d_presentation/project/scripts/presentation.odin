//gd:extends Node3D
//gd:class PresentationValues
package presentation_values

import gd "godot:godot"
import p "godot:box3d/presentation"

PresentationValues :: struct {owner:gd.Node}

// The owner supplies authored ordinary Node3D proxies. No Godot PhysicsServer,
// rigid body, Native handle, solver step or render restore is involved.
paint :: proc(nodes:[2]gd.Node3d,changes:[]p.Change)->bool {
    for change in changes {
        if change.token.slot>=2 {return false}
        node:=nodes[change.token.slot]
        gd.node3d_set_visible(node,change.kind!=.Remove)
        if change.kind==.Remove {continue}
        gd.node3d_set_position(node,transmute(gd.Vector3)change.row.pose.position)
        gd.node3d_set_quaternion(node,transmute(gd.Quaternion)change.row.pose.rotation)
    }
    return true
}

@(gd_method)
presentation_values_verify :: proc(self:^PresentationValues)->gd.Int {
    nodes:=[2]gd.Node3d{cast(gd.Node3d)gd.get_node(self.owner,"Proxy0"),cast(gd.Node3d)gd.get_node(self.owner,"Proxy1")}
    if nodes[0]==nil || nodes[1]==nil {return 1}
    binding:=[1]p.Binding{{id={7,1},body=44,asset=1,seat=1,alive=true}}
    samples:=[1]p.Body_Sample{{body=44,pose={{0,1,0},{0,0,0,1}},awake=true}}
    previous,pe:=p.frame_make(1,1,0,.Predicted,binding[:],samples[:]);if pe!=.None {return 2}
    samples[0].pose.position.x=10
    current,ce:=p.frame_make(1,2,0,.Predicted,binding[:],samples[:]);if ce!=.None {return 3}
    view:p.View;changes:[p.MAX_CHANGES]p.Change
    n,e:=p.present(&view,&previous,&current,.25,changes[:]);if e!=.None || !paint(nodes,changes[:n]) {return 4}
    if gd.node3d_get_position(nodes[0]).x!=2.5 {return 5}
    first:=changes[0].token
    // Rendering a revision snaps the same proxy instead of integrating a body.
    current.revision=1;current.rows[0].pose.position.x=-3
    n,e=p.present(&view,&previous,&current,.1,changes[:]);if e!=.None || changes[0].interpolated || !paint(nodes,changes[:n]) {return 6}
    if gd.node3d_get_position(nodes[0]).x != -3 {return 7}
    // Recycled numerical key still means a new game lifetime and pool token.
    current.tick=3;current.rows[0].id.lifetime=2
    n,e=p.present(&view,nil,&current,1,changes[:]);if e!=.None || changes[0].kind!=.Rebind || changes[0].token==first || !paint(nodes,changes[:n]) {return 8}
    // Values remain valid after all projection scratch is discarded.
    binding={};samples={};previous={}
    current.epoch=2;current.tick=0;current.revision=0
    n,e=p.present(&view,nil,&current,0,changes[:]);if e!=.None || n!=2 || !paint(nodes,changes[:n]) {return 9}
    overlay:=cast(gd.Label)gd.get_node(self.owner,"Overlay")
    buffer:[2048]u8
    written,oe:=p.status_text({epoch=2,head=0,confirmed=0,ready=true},buffer[:]);if oe!=.None {return 10}
    text:=gd.new_string(string(buffer[:written]));gd.label_set_text(overlay,text);gd.free_string(text)
    n,e=p.view_clear(&view,changes[:]);if e!=.None || !paint(nodes,changes[:n]) {return 11}
    return 0
}
