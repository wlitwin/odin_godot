package box3d_authoring

import "core:crypto/sha2"
import "core:encoding/json"
import "core:math"
import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"

@(private)
fail :: proc(error:Error,field:string,body:int=-1,shape:int=-1,element:int=-1)->Diagnostic{return {error,body,shape,element,field,.Ok}}
@(private)
finite :: proc(v:f32)->bool{return !math.is_nan(v)&&!math.is_inf(v)}
@(private)
clean :: proc(v:f32)->f32{return v==0?0:v}
@(private)
vector :: proc(v:[3]f32)->b.Vec3{return {clean(v[0]),clean(v[1]),clean(v[2])}}
@(private)
finite3 :: proc(v:[3]f32)->bool{for x in v{if !finite(x){return false}};return true}
@(private)
key_valid :: proc(s:string)->bool{if len(s)==0||len(s)>MAX_KEY_BYTES{return false};for c in s{if c<32||c==127{return false}};return true}
@(private)
allocate :: proc($T:typeid,n:int,a:mem.Allocator)->([]T,bool){
 if n==0{return {},true}
 bytes,error:=mem.alloc_bytes(n*size_of(T),align_of(T),a)
 if error!=.None{return {},false};for &v in bytes{v=0}
 return (cast([^]T)raw_data(bytes))[:n],true
}
@(private)
copy_key :: proc(s:string,a:mem.Allocator)->(string,bool){
 bytes,error:=mem.alloc_bytes(len(s),allocator=a);if error!=.None{return "",false}
 copy(bytes,transmute([]u8)s);return string(bytes),true
}
// Length-delimited SHA256: no struct padding, addresses, insertion order or
// process seed enters a logical ID. Zero/truncated collisions are rejected.
stable_id :: proc(namespace,domain,key:string,parent:string="")->u64{
 h:sha2.Context_256;sha2.init_256(&h)
 for text in ([5]string{"ogb3.authoring.id.v1",namespace,domain,parent,key}){
  n:=u64(len(text));bytes:[8]u8;for i in 0..<8{bytes[i]=u8(n>>uint(i*8))}
  sha2.update(&h,bytes[:]);sha2.update(&h,transmute([]u8)text)
 }
 digest:bd.Digest;sha2.final(&h,digest[:]);id:u64;for i in 0..<8{id|=u64(digest[i])<<uint(i*8)};return id
}
content_id64 :: proc(scene:^Baked_Scene)->u64{
 if scene==nil{return 0};id:u64;for i in 0..<8{id|=u64(scene.content_hash[i])<<uint(i*8)};return id
}
@(private)
normalize_pose :: proc(input:Pose_Input)->(b.Pose,bool){
 if !finite3(input.position){return {},false};norm:f64
 for v in input.rotation{if !finite(v){return {},false};norm+=f64(v)*f64(v)}
 if norm<1e-20||math.is_nan(norm)||math.is_inf(norm){return {},false}
 q:=input.rotation;inverse:=1/math.sqrt(norm)
 for &v in q{v=clean(f32(f64(v)*inverse))}
 // q and -q are the same rigid pose. Canonical hemisphere, including w==0.
 negate:=false
 for i in ([4]int{3,2,1,0}){if q[i]!=0{negate=q[i]<0;break}}
 if negate{for &v in q{v=clean(-v)}}
 return {position=vector(input.position),rotation={q[0],q[1],q[2],q[3]}},true
}
@(private)
cross :: proc(a,z:b.Vec3)->b.Vec3{return {a.y*z.z-a.z*z.y,a.z*z.x-a.x*z.z,a.x*z.y-a.y*z.x}}
@(private)
subtract :: proc(a,z:b.Vec3)->b.Vec3{return {a.x-z.x,a.y-z.y,a.z-z.z}}
@(private)
dot :: proc(a,z:b.Vec3)->f64{return f64(a.x)*f64(z.x)+f64(a.y)*f64(z.y)+f64(a.z)*f64(z.z)}
@(private)
transform :: proc(v:[3]f32,scale:[3]f32,pose:b.Pose)->(b.Vec3,bool){
 p:=b.Vec3{v[0]*scale[0],v[1]*scale[1],v[2]*scale[2]};q:=pose.rotation
 u:=b.Vec3{q.x,q.y,q.z};uv:=cross(u,p);uuv:=cross(u,uv)
 result:=b.Vec3{clean(p.x+2*(q.w*uv.x+uuv.x)+pose.position.x),clean(p.y+2*(q.w*uv.y+uuv.y)+pose.position.y),clean(p.z+2*(q.w*uv.z+uuv.z)+pose.position.z)}
 return result,finite3({result.x,result.y,result.z})
}
@(private)
point_less :: proc(a,z:b.Vec3)->bool{return a.x<z.x||(a.x==z.x&&(a.y<z.y||(a.y==z.y&&a.z<z.z)))}
@(private)
sort_points :: proc(points:[]b.Vec3){for i in 1..<len(points){j:=i;for j>0&&point_less(points[j],points[j-1]){points[j],points[j-1]=points[j-1],points[j];j-=1}}}
@(private)
volume_valid :: proc(points:[]b.Vec3)->bool{
 if len(points)<4{return false};axis:b.Vec3;normal:b.Vec3;axis_found,normal_found:=false,false
 for p in points[1:]{v:=subtract(p,points[0]);if !axis_found&&dot(v,v)>1e-20{axis=v;axis_found=true};if axis_found&&!normal_found{n:=cross(axis,v);if dot(n,n)>1e-20{normal=n;normal_found=true}}}
 if !normal_found{return false}
 for p in points[1:]{if math.abs(dot(normal,subtract(p,points[0])))>1e-10{return true}};return false
}
@(private)
asset_destroy :: proc(a:^Baked_Asset,allocator:mem.Allocator){delete(a.stable_key,allocator);delete(a.vertices,allocator);delete(a.indices,allocator);a^={}}
destroy :: proc(scene:^Baked_Scene){
 if scene==nil{return};a:=scene.allocator
 for &asset in scene.data.assets{asset_destroy(&asset,a)}
 for body in scene.data.bodies{delete(body.stable_key,a)}
 for shape in scene.data.shapes{delete(shape.stable_key,a)}
 for resource in scene.data.resources{delete(resource.stable_key,a)}
 for joint in scene.data.joints{delete(joint.stable_key,a)}
 for character in scene.data.characters{delete(character.stable_key,a)}
 delete(scene.data.namespace,a);delete(scene.data.bodies,a);delete(scene.data.shapes,a)
 delete(scene._asset_storage,a);delete(scene._resource_storage,a);delete(scene.data.joints,a);delete(scene.data.characters,a);scene^={}
}
@(private)
same_geometry :: proc(a,z:Baked_Asset)->bool{
 if a.native_kind!=z.native_kind||a.a!=z.a||a.b!=z.b||a.radius!=z.radius||len(a.vertices)!=len(z.vertices)||len(a.indices)!=len(z.indices){return false}
 for v,i in a.vertices{if v!=z.vertices[i]{return false}};for v,i in a.indices{if v!=z.indices[i]{return false}};return true
}
@(private)
geometry_id :: proc(namespace:string,asset:Baked_Asset)->(u64,u32,bool){
 geometry:=struct{kind:Native_Kind,a,b:Native_Vec3,radius:f32,vertices:[]Native_Vec3,indices:[]u32}{asset.native_kind,asset.a,asset.b,asset.radius,asset.vertices,asset.indices}
 bytes,error:=json.marshal(geometry);if error!=nil{return 0,0,false};defer delete(bytes)
 digest,de:=bd.hash_descriptors("ogb3.authoring.geometry.v1",[]bd.Descriptor{{"geometry",bytes},{"namespace",transmute([]u8)namespace}})
 if de!=.None{return 0,0,false};id:u64;for i in 0..<8{id|=u64(digest[i])<<uint(i*8)};catalog:=u32(id&0xffffffff);return id,catalog,id!=0&&catalog!=0
}
@(private)
bake_asset :: proc(input:Shape_Input,body_type:b.Body_Type,sensor:bool,allocator:mem.Allocator)->(published:Baked_Asset,problem:Diagnostic){
 result:Baked_Asset;
 pose,pose_ok:=normalize_pose(input.local_pose);if !pose_ok{return {},fail(.Pose,"local_pose")}
 for v in input.scale{if !finite(v)||v<=0{return {},fail(.Scale,"scale")}}
 if !finite(input.density)||!finite(input.friction)||!finite(input.restitution){return {},fail(.Nonfinite,"material")}
 if input.density<0||input.friction<0||input.restitution<0||input.restitution>1{return {},fail(.Dimension,"material")}
 mesh:=input.kind=="mesh"||input.kind=="heightfield"
 if mesh&&(body_type!=.Static||sensor||input.is_sensor||input.enable_sensor_events){return {},fail(.Unsupported,"mesh.static_non_sensor_no_sensor_events")}
 ok:=false;committed:=false;defer if !committed{asset_destroy(&result,allocator)}
 switch input.kind {
 case "box":
  result.source_kind=.Box
  for v in input.half_extents{if !finite(v)||v<=0{return {},fail(.Dimension,"half_extents")}}
  if pose==b.IDENTITY_POSE {
   result.native_kind=.Box;result.a=vector({input.half_extents[0]*input.scale[0],input.half_extents[1]*input.scale[1],input.half_extents[2]*input.scale[2]})
   if !finite3({result.a.x,result.a.y,result.a.z}){return {},fail(.Nonfinite,"scaled_half_extents")}
  } else {
   result.native_kind=.Hull;result.vertices,ok=allocate(b.Vec3,8,allocator);if !ok{return {},fail(.Allocation,"box.vertices")}
   for i in 0..<8{v:=[3]f32{(i&1)!=0?input.half_extents[0]:-input.half_extents[0],(i&2)!=0?input.half_extents[1]:-input.half_extents[1],(i&4)!=0?input.half_extents[2]:-input.half_extents[2]};result.vertices[i],ok=transform(v,input.scale,pose);if !ok{return {},fail(.Nonfinite,"box.vertices",element=i)}}
   sort_points(result.vertices)
  }
 case "sphere","capsule":
  if input.scale[0]!=input.scale[1]||input.scale[1]!=input.scale[2]{return {},fail(.Unsupported,"sphere_capsule.uniform_scale")}
  if !finite(input.radius)||input.radius<=0{return {},fail(.Dimension,"radius")};result.radius=input.radius*input.scale[0]
  if !finite(result.radius)||result.radius<=0{return {},fail(.Dimension,"scaled_radius")}
  if input.kind=="sphere"{
   result.source_kind=.Sphere;result.native_kind=.Sphere
   if !finite3(input.center){return {},fail(.Nonfinite,"center")};result.a,ok=transform(input.center,input.scale,pose)
  }else{
   result.source_kind=.Capsule;result.native_kind=.Capsule
   if !finite3(input.centers_a)||!finite3(input.centers_b){return {},fail(.Nonfinite,"centers_a/centers_b")}
   result.a,ok=transform(input.centers_a,input.scale,pose);if !ok{return {},fail(.Nonfinite,"centers_a")};result.b,ok=transform(input.centers_b,input.scale,pose)
   if result.a==result.b{return {},fail(.Dimension,"capsule.distinct_endpoints")}
  }
  if !ok{return {},fail(.Nonfinite,"transformed_center")}
 case "hull","mesh":
  minimum:=input.kind=="hull"?4:3;maximum:=input.kind=="hull"?MAX_HULL_POINTS:MAX_VERTICES
  if len(input.vertices)<minimum||len(input.vertices)>maximum{return {},fail(.Geometry,"vertices.count")}
  result.source_kind=input.kind=="hull"?.Hull:.Mesh;result.native_kind=input.kind=="hull"?.Hull:.Mesh
  result.vertices,ok=allocate(b.Vec3,len(input.vertices),allocator);if !ok{return {},fail(.Allocation,"vertices")}
  for v,i in input.vertices{if !finite3(v){return {},fail(.Nonfinite,"vertices",element=i)};result.vertices[i],ok=transform(v,input.scale,pose);if !ok{return {},fail(.Nonfinite,"transformed_vertices",element=i)}}
  if input.kind=="hull"{
   if len(input.indices)!=0{return {},fail(.Geometry,"hull.indices_must_be_empty")}
   sort_points(result.vertices);if !volume_valid(result.vertices){return {},fail(.Geometry,"hull.volume")}
  }else{
   if len(input.indices)<3||len(input.indices)>MAX_INDICES||len(input.indices)%3!=0{return {},fail(.Geometry,"indices.count")}
   result.indices,ok=allocate(u32,len(input.indices),allocator);if !ok{return {},fail(.Allocation,"indices")};copy(result.indices,input.indices)
  }
 case "heightfield":
  result.source_kind=.Heightfield;result.native_kind=.Mesh
  if input.columns<2||input.rows<2||input.columns>MAX_GRID_SIDE||input.rows>MAX_GRID_SIDE||len(input.heights)!=int(input.columns)*int(input.rows){return {},fail(.Geometry,"heightfield.grid_count")}
  for v in input.spacing{if !finite(v)||v<=0{return {},fail(.Dimension,"heightfield.spacing")}}
  result.vertices,ok=allocate(b.Vec3,len(input.heights),allocator);if !ok{return {},fail(.Allocation,"heightfield.vertices")}
  for h,i in input.heights{if !finite(h){return {},fail(.Nonfinite,"heights",element=i)};v:=[3]f32{f32(i%int(input.columns))*input.spacing[0],h,f32(i/int(input.columns))*input.spacing[1]};result.vertices[i],ok=transform(v,input.scale,pose);if !ok{return {},fail(.Nonfinite,"heightfield.vertices",element=i)}}
  count:=int(input.columns-1)*int(input.rows-1)*6
  result.indices,ok=allocate(u32,count,allocator);if !ok{return {},fail(.Allocation,"heightfield.indices")}
  at:=0;for z in 0..<input.rows-1{for x in 0..<input.columns-1{a:=z*input.columns+x;c:=a+input.columns;for index in ([6]u32{a,c,a+1,a+1,c,c+1}){result.indices[at]=index;at+=1}}}
 case:return {},fail(.Unsupported,"kind")
 }
 if result.native_kind==.Mesh{
  for index,i in result.indices{if index>=u32(len(result.vertices)){return {},fail(.Geometry,"indices.range",element=i)}}
  for i in 0..<len(result.indices)/3{a,z,c:=result.indices[i*3],result.indices[i*3+1],result.indices[i*3+2];normal:=cross(subtract(result.vertices[z],result.vertices[a]),subtract(result.vertices[c],result.vertices[a]));if a==z||z==c||a==c||dot(normal,normal)<=1e-20{return {},fail(.Geometry,"triangle.area",element=i)}}
 }
 committed=true;return result,{}
}

bake :: proc(input:Scene_Input,allocator:=context.allocator)->(published:Baked_Scene,problem:Diagnostic){
 scene:Baked_Scene;
 if !schema_supported(input.schema_version){return {},fail(.Schema,"schema_version")}
 if len(input.joints)>MAX_JOINTS||len(input.characters)>MAX_CHARACTERS{return {},fail(.Capacity,"motion.counts")}
 if input.schema_version==LEGACY_SCHEMA_VERSION&&(len(input.joints)>0||len(input.characters)>0){return {},fail(.Schema,"schema1.motion_not_supported")}
 if !key_valid(input.namespace){return {},fail(.Key,"namespace")}
 if !finite3(input.gravity){return {},fail(.Nonfinite,"gravity")}
 if len(input.bodies)==0||len(input.bodies)>MAX_BODIES{return {},fail(.Capacity,"bodies.count")}
 count:=0;dynamic_count:=0
 for body,i in input.bodies{
  if !key_valid(body.stable_key){return {},fail(.Key,"stable_key",i)}
  for prior in input.bodies[:i]{if prior.stable_key==body.stable_key{return {},fail(.Duplicate,"body.stable_key",i)}}
  if body.body_type=="dynamic"{dynamic_count+=1}
  if len(body.shapes)==0||len(body.shapes)>MAX_SHAPES-count{return {},fail(.Capacity,"shapes.count",i)};count+=len(body.shapes)
  for shape,j in body.shapes{if !key_valid(shape.stable_key){return {},fail(.Key,"shape.stable_key",i,j)};for prior in body.shapes[:j]{if prior.stable_key==shape.stable_key{return {},fail(.Duplicate,"shape.stable_key",i,j)}}}
 }
 if dynamic_count>b.ALPHA_INITIAL_DYNAMIC_BODIES{return {},fail(.Capacity,"dynamic_bodies.count")}
 scene.allocator=allocator;committed:=false;defer if !committed{destroy(&scene)}
 ok:=false;scene.data.namespace,ok=copy_key(input.namespace,allocator);if !ok{return {},fail(.Allocation,"namespace")}
 scene.data.schema_version=input.schema_version;scene.data.world={gravity=vector(input.gravity),enable_sleep=u32(input.enable_sleep),enable_continuous=1}
 scene.data.bodies,ok=allocate(Baked_Body,len(input.bodies),allocator);if !ok{return {},fail(.Allocation,"bodies")}
 scene.data.shapes,ok=allocate(Baked_Shape,count,allocator);if !ok{return {},fail(.Allocation,"shapes")}
 scene._asset_storage,ok=allocate(Baked_Asset,count,allocator);if !ok{return {},fail(.Allocation,"assets")}
 scene._resource_storage,ok=allocate(Baked_Resource,count,allocator);if !ok{return {},fail(.Allocation,"resources")}
 body_order:[MAX_BODIES]int;for i in 0..<len(input.bodies){body_order[i]=i}
 for i in 1..<len(input.bodies){j:=i;for j>0&&input.bodies[body_order[j]].stable_key<input.bodies[body_order[j-1]].stable_key{body_order[j],body_order[j-1]=body_order[j-1],body_order[j];j-=1}}
 shape_at:=0;asset_count,resource_count:=0,0;geometry_bytes:=0
 for body_index,i in body_order[:len(input.bodies)]{
  body:=input.bodies[body_index];out:=&scene.data.bodies[i]
  out.stable_key,ok=copy_key(body.stable_key,allocator);if !ok{return {},fail(.Allocation,"body.stable_key",body_index)}
  out.logical_id=stable_id(input.namespace,"body",body.stable_key)
  pose,pok:=normalize_pose(body.pose);if !pok{return {},fail(.Pose,"body.pose",body_index)}
  kind:b.Body_Type;switch body.body_type{case "static":kind=.Static;case "kinematic":kind=.Kinematic;case "dynamic":kind=.Dynamic;case:return {},fail(.Unsupported,"body_type",body_index)}
  if !finite3(body.linear_velocity)||!finite3(body.angular_velocity){return {},fail(.Nonfinite,"body.velocity",body_index)}
  for v in ([4]f32{body.linear_damping,body.angular_damping,body.gravity_scale,body.sleep_threshold}){if !finite(v){return {},fail(.Nonfinite,"body.settings",body_index)}}
  if body.linear_damping<0||body.angular_damping<0||body.sleep_threshold<0{return {},fail(.Dimension,"body.settings",body_index)}
  out.definition={type=kind,pose=pose,linear_velocity=vector(body.linear_velocity),angular_velocity=vector(body.angular_velocity),linear_damping=clean(body.linear_damping),angular_damping=clean(body.angular_damping),gravity_scale=clean(body.gravity_scale),sleep_threshold=clean(body.sleep_threshold),enable_sleep=u32(body.enable_sleep),is_awake=u32(body.is_awake),is_bullet=u32(body.is_bullet),is_enabled=u32(body.is_enabled)}
  shape_order:[MAX_SHAPES]int;for j in 0..<len(body.shapes){shape_order[j]=j}
  for j in 1..<len(body.shapes){k:=j;for k>0&&body.shapes[shape_order[k]].stable_key<body.shapes[shape_order[k-1]].stable_key{shape_order[k],shape_order[k-1]=shape_order[k-1],shape_order[k];k-=1}}
  for shape_index in shape_order[:len(body.shapes)]{
   s:=body.shapes[shape_index];asset,err:=bake_asset(s,kind,body.sensor,allocator)
   if err.error!=.None{err.body=body_index;err.shape=shape_index;return {},err}
   asset.logical_id,asset.catalog_id,ok=geometry_id(input.namespace,asset)
   if !ok{asset_destroy(&asset,allocator);return {},fail(.Collision,"catalog_id",body_index,shape_index)}
   resource_found:=false
   for resource in scene.data.resources{if resource.stable_key==s.stable_key{resource_found=true;if resource.catalog_id!=asset.catalog_id{asset_destroy(&asset,allocator);return {},fail(.Duplicate,"conflicting_resource_geometry",body_index,shape_index)}}}
   asset_found:=false
   for existing in scene.data.assets{
    if existing.catalog_id==asset.catalog_id||existing.logical_id==asset.logical_id{
     if !same_geometry(existing,asset){asset_destroy(&asset,allocator);return {},fail(.Collision,"native_geometry_id",body_index,shape_index)};asset_found=true
    }
   }
   asset_id:=asset.catalog_id
   if asset_found{asset_destroy(&asset,allocator)}else{
    if asset_count==MAX_ASSETS{asset_destroy(&asset,allocator);return {},fail(.Capacity,"assets.count",body_index,shape_index)}
    bytes:=len(asset.vertices)*size_of(b.Vec3)+len(asset.indices)*size_of(u32)
    if bytes>MAX_DEFINITION_BYTES-geometry_bytes{asset_destroy(&asset,allocator);return {},fail(.Capacity,"geometry.bytes",body_index,shape_index)};geometry_bytes+=bytes
    scene._asset_storage[asset_count]=asset;asset_count+=1;scene.data.assets=scene._asset_storage[:asset_count]
   }
   if !resource_found{
    resource:=&scene._resource_storage[resource_count];resource.stable_key,ok=copy_key(s.stable_key,allocator);if !ok{return {},fail(.Allocation,"resource.key",body_index,shape_index)}
    resource.logical_id=stable_id(input.namespace,"resource",s.stable_key);resource.catalog_id=asset_id
    resource_count+=1;scene.data.resources=scene._resource_storage[:resource_count]
   }
   shape:=&scene.data.shapes[shape_at];shape_at+=1
   shape.stable_key,ok=copy_key(s.stable_key,allocator);if !ok{return {},fail(.Allocation,"shape.key",body_index,shape_index)}
   shape.logical_id=stable_id(input.namespace,"shape",s.stable_key,body.stable_key);shape.body_id=out.logical_id;shape.asset_id=asset_id
   shape.definition={category_bits=s.category_bits,mask_bits=s.mask_bits,group_index=s.group_index,density=clean(s.density),friction=clean(s.friction),restitution=clean(s.restitution),is_sensor=u32(body.sensor||s.is_sensor),enable_sensor_events=u32(s.enable_sensor_events),enable_contact_events=u32(s.enable_contact_events)}
  }
 }
 // Native catalog ABI requires numeric-ID order; all other definitions use keys.
 for i in 1..<asset_count{j:=i;for j>0&&scene.data.assets[j].catalog_id<scene.data.assets[j-1].catalog_id{scene.data.assets[j],scene.data.assets[j-1]=scene.data.assets[j-1],scene.data.assets[j];j-=1}}
 for i in 1..<resource_count{j:=i;for j>0&&scene.data.resources[j].stable_key<scene.data.resources[j-1].stable_key{scene.data.resources[j],scene.data.resources[j-1]=scene.data.resources[j-1],scene.data.resources[j];j-=1}}
 problem=bake_motion(&scene,input);if problem.error!=.None{return}
 problem=validate_ids(scene.data);if problem.error!=.None{return}
 scene.content_hash,ok=scene_hash(scene.data);if !ok{return {},fail(.Allocation,"content_hash")};if content_id64(&scene)==0{return {},fail(.Collision,"content_id64")}
 committed=true;return scene,{}
}

validate_ids :: proc(data:Scene_Data)->Diagnostic{
 ids:[MAX_BODIES+MAX_SHAPES+MAX_SHAPES+MAX_ASSETS+MAX_JOINTS+MAX_CHARACTERS]u64;count:=0
 if len(data.bodies)>MAX_BODIES||len(data.shapes)>MAX_SHAPES||len(data.resources)>MAX_SHAPES||len(data.assets)>MAX_ASSETS{return fail(.Capacity,"definition.counts")}
 if len(data.joints)>MAX_JOINTS||len(data.characters)>MAX_CHARACTERS{return fail(.Capacity,"motion.counts")}
 if !schema_supported(data.schema_version)||(data.schema_version==LEGACY_SCHEMA_VERSION&&(len(data.joints)>0||len(data.characters)>0)){return fail(.Schema,"schema_version")}
 for body in data.bodies{if body.logical_id==0{return fail(.Collision,"body.id")};ids[count]=body.logical_id;count+=1}
 for shape in data.shapes{if shape.logical_id==0{return fail(.Collision,"shape.id")};ids[count]=shape.logical_id;count+=1}
 for resource in data.resources{if resource.logical_id==0{return fail(.Collision,"resource.id")};ids[count]=resource.logical_id;count+=1}
 for asset in data.assets{if asset.logical_id==0{return fail(.Collision,"asset.id")};ids[count]=asset.logical_id;count+=1}
 for joint in data.joints{if joint.logical_id==0{return fail(.Collision,"joint.id")};ids[count]=joint.logical_id;count+=1}
 for character in data.characters{if character.logical_id==0{return fail(.Collision,"character.id")};ids[count]=character.logical_id;count+=1}
 for id,i in ids[:count]{for prior in ids[:i]{if id==prior{return fail(.Collision,"logical_id")}}}
 for shape in data.shapes{body_found,asset_found:=false,false;for body in data.bodies{if body.logical_id==shape.body_id{body_found=true}};for asset in data.assets{if asset.catalog_id==shape.asset_id{asset_found=true}};if !body_found||!asset_found{return fail(.Reference,"shape.body_asset")}}
 for resource in data.resources{asset_found:=false;for asset in data.assets{if asset.catalog_id==resource.catalog_id{asset_found=true}};if !asset_found{return fail(.Reference,"resource.asset")}}
 for joint in data.joints{found_a,found_b:=false,false;for body in data.bodies{if body.logical_id==joint.body_a_id{found_a=true};if body.logical_id==joint.body_b_id{found_b=true}};if !found_a||!found_b||joint.body_a_id==joint.body_b_id||joint.definition.body_a!=0||joint.definition.body_b!=0{return fail(.Reference,"joint.body_keys")}}
 for character in data.characters{if character.config.filter.exclude_body!=0||character.initial.ground_shape!=0||character.initial.grounded!=0{return fail(.Reference,"character.unbound_initial_keys")};if character.exclude_body_id!=0{found:=false;for body in data.bodies{if body.logical_id==character.exclude_body_id{found=true}};if !found{return fail(.Reference,"character.exclude_body")}}}
 for asset,i in data.assets{if asset.catalog_id==0||asset.logical_id==0{return fail(.Collision,"catalog.id")};for prior in data.assets[:i]{if asset.catalog_id==prior.catalog_id||asset.logical_id==prior.logical_id{return fail(.Collision,"catalog.id")}}}
 return {}
}

// Parsing uses one finite scratch arena, then bake copies every surviving value.
parse_and_bake :: proc(bytes:[]u8,allocator:=context.allocator)->(Baked_Scene,Diagnostic){
 if len(bytes)==0||len(bytes)>MAX_DEFINITION_BYTES{return {},fail(.Capacity,"json.bytes")}
 depth:=0;quoted,escaped:=false,false
 for c in bytes{if quoted{if escaped{escaped=false}else if c=='\\'{escaped=true}else if c=='"'{quoted=false};continue};if c=='"'{quoted=true}else if c=='{'||c=='['{depth+=1;if depth>32{return {},fail(.Capacity,"json.depth")}}else if c=='}'||c==']'{depth-=1;if depth<0{return {},fail(.Schema,"json")}}}
 if quoted||depth!=0{return {},fail(.Schema,"json")}
 scratch,error:=mem.alloc_bytes(MAX_DEFINITION_BYTES*4,allocator=allocator);if error!=.None{return {},fail(.Allocation,"json.scratch")};defer delete(scratch,allocator)
 arena:mem.Arena;mem.arena_init(&arena,scratch);input:Scene_Input
 if json.unmarshal(bytes,&input,allocator=mem.arena_allocator(&arena))!=nil{return {},fail(.Schema,"json.fields")}
 return bake(input,allocator)
}
