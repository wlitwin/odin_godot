package box3d_debugdraw

import "core:math"
import p "godot:box3d/presentation"

@(private)
finite :: proc "contextless"(v:f32)->bool{return !math.is_nan(v)&&!math.is_inf(v)}
@(private)
vector_valid :: proc "contextless"(v:Vec3)->bool{for x in v{if !finite(x)||abs(x)>1e9{return false}};return true}
@(private)
color_valid :: proc "contextless"(v:Color)->bool{for x in v{if !finite(x)||x<0||x>1{return false}};return true}
@(private)
pose_valid :: proc "contextless"(pose:p.Pose)->bool{
 if !vector_valid(pose.position){return false};norm:=f64(0)
 for x in pose.rotation{if !finite(x){return false};norm+=f64(x)*f64(x)}
 return abs(norm-1)<0.0001
}
@(private)
cross :: proc "contextless"(a,b:Vec3)->Vec3{return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x}}
@(private)
unit :: proc "contextless"(v:Vec3)->(Vec3,bool){
 n:=f64(0);for x in v{n+=f64(x)*f64(x)};if n==0{return {},false}
 return v/f32(math.sqrt(n)),true
}
@(private)
rotate :: proc "contextless"(q:[4]f32,v:Vec3)->Vec3{
 u:=Vec3{q.x,q.y,q.z};t:=2*cross(u,v);return v+q.w*t+cross(u,t)
}
@(private)
point :: proc "contextless"(pose:p.Pose,v:Vec3)->Vec3{return pose.position+rotate(pose.rotation,v)}
@(private)
compose :: proc "contextless"(a,b:p.Pose)->p.Pose{
 av:=Vec3{a.rotation.x,a.rotation.y,a.rotation.z};bv:=Vec3{b.rotation.x,b.rotation.y,b.rotation.z}
 xyz:=a.rotation.w*bv+b.rotation.w*av+cross(av,bv)
 w:=a.rotation.w*b.rotation.w-(av.x*bv.x+av.y*bv.y+av.z*bv.z)
 return {point(a,b.position),{xyz.x,xyz.y,xyz.z,w}}
}
@(private)
Writer :: struct{out:[]Line,count:int,emit:bool,error:Error}
@(private)
line :: proc "contextless"(w:^Writer,a,b:Vec3,color:Color){
 if w.error!=.None{return}
 if !vector_valid(a)||!vector_valid(b){w.error=.Invalid;return}
 if w.count>=MAX_LINES{w.count=MAX_LINES+1;w.error=.Capacity;return}
 if w.emit{w.out[w.count]={a,b,color}};w.count+=1
}
@(private)
local_line :: proc "contextless"(w:^Writer,pose:p.Pose,a,b:Vec3,color:Color){line(w,point(pose,a),point(pose,b),color)}
@(private)
circle :: proc "contextless"(w:^Writer,pose:p.Pose,center,u,v:Vec3,radius:f32,segments:int,color:Color){
 for i in 0..<segments{
  a:=f32(2*math.PI)*f32(i)/f32(segments);b:=f32(2*math.PI)*f32(i+1)/f32(segments)
  local_line(w,pose,center+radius*(math.cos(a)*u+math.sin(a)*v),center+radius*(math.cos(b)*u+math.sin(b)*v),color)
 }
}
@(private)
sphere :: proc "contextless"(w:^Writer,pose:p.Pose,center:Vec3,radius:f32,segments:int,color:Color){
 circle(w,pose,center,{1,0,0},{0,1,0},radius,segments,color)
 circle(w,pose,center,{0,1,0},{0,0,1},radius,segments,color)
 circle(w,pose,center,{0,0,1},{1,0,0},radius,segments,color)
}
@(private)
capsule :: proc "contextless"(w:^Writer,pose:p.Pose,a,b:Vec3,radius:f32,segments:int,color:Color){
 axis,nonzero:=unit(b-a);if !nonzero{sphere(w,pose,a,radius,segments,color);return}
 ref:=Vec3{1,0,0};if abs(axis.y)<abs(axis.x)&&abs(axis.y)<=abs(axis.z){ref={0,1,0}}else if abs(axis.z)<abs(axis.x)&&abs(axis.z)<abs(axis.y){ref={0,0,1}}
 u,_:=unit(cross(axis,ref));v:=cross(axis,u)
 circle(w,pose,a,u,v,radius,segments,color);circle(w,pose,b,u,v,radius,segments,color)
 for direction in ([4]Vec3{u,-u,v,-v}){local_line(w,pose,a+radius*direction,b+radius*direction,color)}
 for tangent in ([2]Vec3{u,v}){for i in 0..<segments/2{
  ta:=f32(math.PI)*f32(i)/f32(segments/2);tb:=f32(math.PI)*f32(i+1)/f32(segments/2)
  local_line(w,pose,a+radius*(math.cos(ta)*tangent-math.sin(ta)*axis),a+radius*(math.cos(tb)*tangent-math.sin(tb)*axis),color)
  local_line(w,pose,b+radius*(math.cos(ta)*tangent+math.sin(ta)*axis),b+radius*(math.cos(tb)*tangent+math.sin(tb)*axis),color)
 }}
}
@(private)
box :: proc "contextless"(w:^Writer,pose:p.Pose,extent:Vec3,color:Color){
 corners:[8]Vec3
 for i in 0..<8{corners[i]={((i&1)!=0?1:-1)*extent.x,((i&2)!=0?1:-1)*extent.y,((i&4)!=0?1:-1)*extent.z}}
 for i in 0..<8{for bit in ([3]int{1,2,4}){if (i&bit)==0{local_line(w,pose,corners[i],corners[i|bit],color)}}}
}
@(private)
axes :: proc "contextless"(w:^Writer,pose:p.Pose,color:Color){
 for end in ([3]Vec3{{0.25,0,0},{0,0.25,0},{0,0,0.25}}){local_line(w,pose,{},end,color)}
}
