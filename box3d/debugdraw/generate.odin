package box3d_debugdraw

import p "godot:box3d/presentation"
import intrinsics "base:intrinsics"

stamp_of :: proc "contextless"(frame:^p.Frame)->Stamp{
 if frame==nil{return {}}
 return {frame.epoch,frame.tick,frame.revision,frame.source}
}
@(private)
segments_value :: proc "contextless"(requested:u32)->(int,bool){
 value:=requested;if value==0{value=16};return int(value),value>=8&&value<=64&&(value%2)==0
}
@(private)
frame_valid :: proc "contextless"(frame:^p.Frame)->bool{
 if frame==nil||frame.epoch==0||frame.source>.Observed||frame.count>p.MAX_BODIES{return false}
 for row,i in frame.rows[:frame.count]{
  if row.id.entity==0||row.id.lifetime==0||row.body==0||row.asset==0||!pose_valid(row.pose){return false}
  for previous in frame.rows[:i]{if previous.body==row.body||previous.id.entity==row.id.entity{return false}}
 }
 return true
}
@(private)
body_pose :: proc "contextless"(frame:^p.Frame,key:p.Body_Key)->(p.Pose,bool){
 for row in frame.rows[:frame.count]{if row.body==key{return row.pose,true}}
 return {},false
}
@(private)
geometry_valid :: proc "contextless"(g:Geometry)->Error{
 if g.id==0||g.kind>.Mesh||!vector_valid(g.a)||!vector_valid(g.b)||!finite(g.radius){return .Invalid}
 if len(g.vertices)>MAX_VERTICES||len(g.indices)>3*MAX_TRIANGLES{return .Capacity}
 for vertex in g.vertices{if !vector_valid(vertex){return .Invalid}}
 switch g.kind{
 case .Box:
  if g.a.x<=0||g.a.y<=0||g.a.z<=0||g.b!=(Vec3{})||g.radius!=0||len(g.vertices)!=0||len(g.indices)!=0{return .Invalid}
 case .Sphere:
  if g.radius<=0||g.b!=(Vec3{})||len(g.vertices)!=0||len(g.indices)!=0{return .Invalid}
 case .Capsule:
  if g.radius<=0||len(g.vertices)!=0||len(g.indices)!=0{return .Invalid}
 case .Hull:
  if g.a!=(Vec3{})||g.b!=(Vec3{})||g.radius!=0||len(g.indices)!=0{return .Invalid}
  _,error:=hull_build(g.vertices);if error!=.None{return error}
 case .Mesh:
  if g.a!=(Vec3{})||g.b!=(Vec3{})||g.radius!=0||len(g.vertices)<3||len(g.indices)<3||len(g.indices)%3!=0{return .Invalid}
  for i in 0..<len(g.indices)/3{
   a,b,c:=g.indices[i*3],g.indices[i*3+1],g.indices[i*3+2]
   if u64(a)>=u64(len(g.vertices))||u64(b)>=u64(len(g.vertices))||u64(c)>=u64(len(g.vertices))||a==b||b==c||a==c{return .Invalid}
   normal:=dcross(dvec(g.vertices[b])-dvec(g.vertices[a]),dvec(g.vertices[c])-dvec(g.vertices[a]))
   if dot(normal,normal)==0{return .Invalid}
  }
 }
 return .None
}
@(private)
geometry_lines :: proc "contextless"(w:^Writer,g:Geometry,pose:p.Pose,segments:int,color:Color){
 switch g.kind{
 case .Box:box(w,pose,g.a,color)
 case .Sphere:sphere(w,pose,g.a,g.radius,segments,color)
 case .Capsule:capsule(w,pose,g.a,g.b,g.radius,segments,color)
 case .Hull:hull_lines(w,g.vertices,pose,color)
 case .Mesh:
  for i in 0..<len(g.indices)/3{
   a,b,c:=g.vertices[g.indices[i*3]],g.vertices[g.indices[i*3+1]],g.vertices[g.indices[i*3+2]]
   local_line(w,pose,a,b,color);local_line(w,pose,b,c,color);local_line(w,pose,c,a,color)
   if w.error!=.None{return}
  }
 }
}
@(private)
scene_valid :: proc "contextless"(frame:^p.Frame,scene:Scene)->Error{
 if len(scene.geometries)>MAX_GEOMETRIES||len(scene.bindings)>MAX_BINDINGS||len(scene.joints)>MAX_JOINTS||len(scene.characters)>MAX_CHARACTERS{return .Capacity}
 for g,i in scene.geometries{
  if error:=geometry_valid(g);error!=.None{return error}
  for previous in scene.geometries[:i]{if previous.id==g.id{return .Duplicate}}
 }
 for binding,i in scene.bindings{
  if binding.id==0||binding.body==0||binding.geometry==0||!pose_valid(binding.local)||!color_valid(binding.color){return .Invalid}
  if _,ok:=body_pose(frame,binding.body);!ok{return .Missing_Body}
  found:=false;for g in scene.geometries{if g.id==binding.geometry{found=true;break}};if !found{return .Missing_Geometry}
  for previous in scene.bindings[:i]{if previous.id==binding.id{return .Duplicate}}
 }
 for joint,i in scene.joints{
  if joint.id==0||joint.kind>.Wheel||joint.body_a==0||joint.body_b==0||joint.body_a==joint.body_b||!pose_valid(joint.local_a)||!pose_valid(joint.local_b)||!color_valid(joint.color){return .Invalid}
  if _,ok:=body_pose(frame,joint.body_a);!ok{return .Missing_Body};if _,ok:=body_pose(frame,joint.body_b);!ok{return .Missing_Body}
  for previous in scene.joints[:i]{if previous.id==joint.id{return .Duplicate}}
 }
 for character,i in scene.characters{
  if character.id==0||!pose_valid(character.pose)||!vector_valid(character.a)||!vector_valid(character.b)||!finite(character.radius)||character.radius<=0||!vector_valid(character.up)||!vector_valid(character.ground_normal)||!color_valid(character.color){return .Invalid}
  if character.body!=0{if _,ok:=body_pose(frame,character.body);!ok{return .Missing_Body}}
  if character.grounded&&dot(dvec(character.ground_normal),dvec(character.ground_normal))==0{return .Invalid}
  for previous in scene.characters[:i]{if previous.id==character.id{return .Duplicate}}
 }
 return .None
}
@(private)
scene_lines :: proc "contextless"(w:^Writer,frame:^p.Frame,scene:Scene,segments:int){
 // Sort fixed copies of bindings/overlays by stable logical ID. Neither frame
 // order nor mutable scene traversal becomes a presentation runtime here.
 bindings:[MAX_BINDINGS]Binding
 for binding,i in scene.bindings{at:=i;for at>0&&bindings[at-1].id>binding.id{bindings[at]=bindings[at-1];at-=1};bindings[at]=binding}
 for binding in bindings[:len(scene.bindings)]{
  pose,_:=body_pose(frame,binding.body)
  for g in scene.geometries{if g.id==binding.geometry{geometry_lines(w,g,compose(pose,binding.local),segments,binding.color);break}}
  if w.error!=.None{return}
 }
 for joint in scene.joints{
  a,_:=body_pose(frame,joint.body_a);b,_:=body_pose(frame,joint.body_b)
  a=compose(a,joint.local_a);b=compose(b,joint.local_b)
  line(w,a.position,b.position,joint.color);axes(w,a,joint.color);axes(w,b,joint.color)
  if w.error!=.None{return}
 }
 characters:[MAX_CHARACTERS]Character
 for character,i in scene.characters{at:=i;for at>0&&characters[at-1].id>character.id{characters[at]=characters[at-1];at-=1};characters[at]=character}
 for character in characters[:len(scene.characters)]{
  pose:=character.pose;if character.body!=0{parent,_:=body_pose(frame,character.body);pose=compose(parent,pose)}
  capsule(w,pose,character.a,character.b,character.radius,segments,character.color)
  if character.up!=(Vec3{}){line(w,pose.position,pose.position+character.up,character.color)}
  if character.grounded{line(w,pose.position,pose.position+character.ground_normal,character.color)}
  if w.error!=.None{return}
 }
}
generate :: proc "contextless"(frame:^p.Frame,scene:Scene,options:Options,out:[]Line)->(Batch,Error){
 if !options.enabled{return Batch{stamp=options.expected},.None}
 if !frame_valid(frame){return {},.Invalid}
 stamp:=stamp_of(frame);batch:=Batch{stamp=stamp}
 if options.expected!=stamp{return batch,.Stale}
 segments,ok:=segments_value(options.segments);if !ok{return batch,.Invalid}
 if error:=scene_valid(frame,scene);error!=.None{return batch,error}
 count:Writer;scene_lines(&count,frame,scene,segments)
 if count.error!=.None{if count.error==.Capacity{batch.required=u32(count.count)};return batch,count.error}
 batch.required=u32(count.count)
 if len(out)<count.count{return batch,.Capacity}
 writer:=Writer{out=out,emit=true};scene_lines(&writer,frame,scene,segments)
 // Inputs cannot change during the call and output must not alias them. The
 // exact same allocation-free pass already validated every generated endpoint.
 if writer.error!=.None||writer.count!=count.count{intrinsics.trap()}
 batch.count=batch.required;return batch,.None
}
// Editor-only authored preview: deliberately has no epoch/tick/revision stamp
// and makes no claim to represent a live or historical presentation frame.
preview_geometry :: proc "contextless"(geometry:Geometry,pose:p.Pose,color:Color,segments:u32,out:[]Line)->(required:u32,error:Error){
 if !pose_valid(pose)||!color_valid(color){return 0,.Invalid}
 steps,ok:=segments_value(segments);if !ok{return 0,.Invalid}
 if error:=geometry_valid(geometry);error!=.None{return 0,error}
 count:Writer;geometry_lines(&count,geometry,pose,steps,color)
 if count.error!=.None{return count.error==.Capacity?u32(count.count):0,count.error}
 if len(out)<count.count{return u32(count.count),.Capacity}
 writer:=Writer{out=out,emit=true};geometry_lines(&writer,geometry,pose,steps,color)
 if writer.error!=.None||writer.count!=count.count{intrinsics.trap()};return u32(count.count),.None
}
