//gd:extends Node
//gd:class RotationProbe
package rotation_probe

import "core:math"
import "core:math/linalg"
import "core:fmt"
import gd "godot:godot"
import own "godot:replay/owned"
import scenegd "godot:replay/godot/scene"

RotationProbe :: struct {owner:gd.Node,frames:int,ok:bool,body2:[1]scenegd.Body2,body3:[1]scenegd.Body3}
near2 :: proc(a,b:[2]f32)->bool {return linalg.length(a-b)<0.001}
near3 :: proc(a,b:[3]f32)->bool {return linalg.length(a-b)<0.0001}
rot2 :: proc(p:[2]f32,a:f32)->[2]f32 {c,s:=math.cos(a),math.sin(a);return {c*p[0]-s*p[1],s*p[0]+c*p[1]}}
yaw :: proc(a:f32)->[4]f32 {return {0,math.sin(a/2),0,math.cos(a/2)}}
orientation :: proc(a,b:[4]f32)->bool {return abs(abs(linalg.dot(a,b))-1)<0.0001}
global_rotation :: proc(node:gd.Node3d)->[4]f32 {xf:=gd.node3d_get_global_transform(node);return transmute([4]f32)gd.basis_get_rotation_quaternion(&xf.basis)}

exercise2 :: proc(self:^RotationProbe)->bool {
 parent:=self.owner
 node:=scenegd.scene_instance(parent,"res://body2.tscn");if node==nil {return false}
 skin:=cast(gd.Node2d)gd.get_node(node,"Look");gd.node2d_set_position(skin,{3,4});gd.node2d_set_rotation(skin,0.2)
 body:=&self.body2[0];if !scenegd.body2_attach(body,cast(gd.Physics_Body2d)node,.Rigid,skin) {return false}
 state:=own.State(own.Pose2){key={1,0,1},epoch=1,revision=1,owner=2,value={position={100,100},linear={5,7},angular=0.8}}
 if scenegd.body2_sync(body,state,1,1,0,true,0)!=.None {return false}
 first:=gd.node2d_get_global_position(skin);angle:=f32(gd.node2d_get_global_rotation(skin))
 state.value.position[0]+=2;state.value.rotation=0.4;saved:=state
 if scenegd.body2_sync(body,state,1,1,1,true,0)!=.None {return false}
 physical:=scenegd.body2_read(body)
 if !near2(physical.linear,{5,7}) || abs(physical.angular-0.8)>0.001 {gd.print_str("ROTATION_FAIL 2d velocity write");return false}
 if !near2(gd.node2d_get_global_position(skin),first) || abs(f32(gd.node2d_get_global_rotation(skin))-angle)>0.001 {gd.print_str("ROTATION_FAIL 2d skin continuity");return false}
 if scenegd.body2_sync(body,state,1,1,1,true,0.063)!=.None {return false}
 expected:=[2]f32{101,100}+rot2({3,4},0.2)
 if !near2(gd.node2d_get_global_position(skin),expected) || abs(f32(gd.node2d_get_global_rotation(skin))-0.4)>0.001 {gd.print_str("ROTATION_FAIL 2d half-life");return false}
 if state!=saved {return false}
 if scenegd.body2_read(body)!=physical {gd.print_str("ROTATION_FAIL 2d presentation changed solver");return false}
 state.epoch=2
 if scenegd.body2_sync(body,state,1,2,0,true,0)!=.None {return false}
 if !near2(gd.node2d_get_position(skin),{3,4}) || abs(f32(gd.node2d_get_rotation(skin))-0.2)>0.001 {gd.print_str("ROTATION_FAIL 2d epoch cut");return false}
 sample,err:=scenegd.body2_sample(body,1);if err!=.None || sample.sequence!=0 {return false}
 gd.print_str("ROTATION_BODY2_OK continuity=true offset=true half_life=true physics_unchanged=true epoch_cut=true observer_not_publishing=true")
 return true
}
exercise3 :: proc(self:^RotationProbe)->bool {
 parent:=self.owner
 node:=scenegd.scene_instance(parent,"res://body3.tscn");if node==nil {return false}
 skin:=cast(gd.Node3d)gd.get_node(node,"Look");origin:=[3]f32{0.3,0.4,0.2};rest:=transmute(gd.Quaternion)yaw(0.2)
 gd.node3d_set_position(skin,origin);gd.node3d_set_quaternion(skin,rest)
 body:=&self.body3[0];if !scenegd.body3_attach(body,cast(gd.Physics_Body3d)node,.Rigid,skin) {return false}
 state:=own.State(own.Pose3){key={1,0,1},epoch=1,revision=1,owner=2,value={position={1,2,3},rotation={0,0,0,1},linear={0.2,0.3,0.4},angular={0,0.8,0}}}
 if scenegd.body3_sync(body,state,1,1,0,true,0)!=.None {return false}
 first:=gd.node3d_get_global_position(skin);angle:=global_rotation(skin)
 state.value.position[0]+=0.2;state.value.rotation=yaw(0.4);saved:=state
 if scenegd.body3_sync(body,state,1,1,1,true,0)!=.None {return false}
 physical:=scenegd.body3_read(body)
 if !near3(physical.linear,{0.2,0.3,0.4}) || !near3(physical.angular,{0,0.8,0}) {gd.print_str("ROTATION_FAIL 3d velocity write");return false}
 if !near3(gd.node3d_get_global_position(skin),first) || !orientation(global_rotation(skin),angle) {gd.print_str("ROTATION_FAIL 3d skin continuity");return false}
 if scenegd.body3_sync(body,state,1,1,1,true,0.063)!=.None {return false}
 expected:=[3]f32{1.1,2,3}+gd.quaternion_multiply(transmute(gd.Quaternion)yaw(0.2),origin)
 if !near3(gd.node3d_get_global_position(skin),expected) || !orientation(global_rotation(skin),yaw(0.4)) {gd.print_str(fmt.tprintf("ROTATION_FAIL 3d half-life actual=%v expected=%v",gd.node3d_get_global_position(skin),expected));return false}
 if state!=saved {return false}
 if scenegd.body3_read(body)!=physical {gd.print_str("ROTATION_FAIL 3d presentation changed solver");return false}
 state.epoch=2
 if scenegd.body3_sync(body,state,1,2,0,true,0)!=.None {return false}
 if !near3(gd.node3d_get_position(skin),origin) || !orientation(transmute([4]f32)gd.node3d_get_quaternion(skin),yaw(0.2)) {gd.print_str("ROTATION_FAIL 3d epoch cut");return false}
 sample,err:=scenegd.body3_sample(body,1);if err!=.None || sample.sequence!=0 {return false}
 gd.print_str("ROTATION_BODY3_OK continuity=true offset=true half_life=true physics_unchanged=true epoch_cut=true observer_not_publishing=true")
 return true
}
rotation_probe_ready :: proc(self:^RotationProbe) {self.ok=exercise2(self) && exercise3(self)}
rotation_probe_process :: proc(self:^RotationProbe,_:f64) {
 self.frames+=1;if self.frames<3 {return}
 if self.ok {
  p2:=scenegd.body2_read(&self.body2[0]);p3:=scenegd.body3_read(&self.body3[0])
  self.ok=near2(p2.position,{102,100}) && abs(p2.rotation-0.4)<0.001 && near3(p3.position,{1.2,2,3}) && orientation(p3.rotation,yaw(0.4))
  if self.ok {gd.print_str("REPLAY_ROTATION_GODOT_OK solver_caught_up=true")} else {gd.print_str("ROTATION_FAIL deferred solver pose")}
 }
 when gd.IS_WEB {gd.node_set_process(self.owner,false)} else {gd.scene_tree_quit(gd.node_get_tree(self.owner),self.ok ? 0 : 1)}
}

rotation_probe_exit_tree :: proc(self:^RotationProbe) {scenegd.body2_destroy(&self.body2[0]);scenegd.body3_destroy(&self.body3[0])}
