package box3d_authoring_pure_test

import "core:encoding/json"
import "core:testing"
import a "godot:box3d/authoring"
import b "godot:box3d"

// One borrowed input fixture; bake must copy it before this storage disappears.
Fixture :: struct {
 scene:a.Scene_Input,bodies:[8]a.Body_Input,shapes:[8]a.Shape_Input,
 hull:[4][3]f32,mesh:[4][3]f32,indices:[6]u32,heights:[4]f32,
}
fixture_init :: proc(f:^Fixture){
 f.scene=a.scene_input_default("authoring.test.world");f.scene.bodies=f.bodies[:]
 f.hull={{0,0,0},{1,0,0},{0,1,0},{0,0,1}}
 f.mesh={{0,0,0},{2,0,0},{0,0,2},{2,0,2}};f.indices={0,2,1,1,2,3};f.heights={0,0.2,0.5,0.7}
 kinds:=[8]string{"box","sphere","capsule","hull","mesh","heightfield","sphere","box"}
 keys:=[8]string{"box","sphere","capsule","hull","mesh","heightfield","sensor","transformed_box"}
 resource_keys:=[8]string{"box.geometry","sphere.geometry","capsule.geometry","hull.geometry","mesh.geometry","heightfield.geometry","sensor.geometry","transformed_box.geometry"}
 for &body,i in f.bodies{
  body=a.body_input_default(keys[i]);body.pose.position={f32(i)*4,3,0}
  if i<4{body.body_type="dynamic"}
  f.shapes[i]=a.shape_input_default(resource_keys[i],kinds[i]);body.shapes=f.shapes[i:i+1]
 }
 f.shapes[1].center={0.25,0.5,0};f.shapes[2].centers_a={-0.25,-0.5,0};f.shapes[2].centers_b={0.25,0.5,0}
 f.shapes[3].vertices=f.hull[:];f.shapes[4].vertices=f.mesh[:];f.shapes[4].indices=f.indices[:]
 f.shapes[5].columns=2;f.shapes[5].rows=2;f.shapes[5].heights=f.heights[:]
 f.bodies[6].sensor=true;f.shapes[6].radius=0.75;f.shapes[6].category_bits=4;f.shapes[6].mask_bits=7
 f.shapes[7].local_pose.position={1,0,0};f.shapes[7].local_pose.rotation={0,0,0.70710677,0.70710677};f.shapes[7].scale={2,1,1}
}
valid :: proc(t:^testing.T,problem:a.Diagnostic)->bool{testing.expect_value(t,problem.error,a.Error.None);return problem.error==.None}
reject :: proc(t:^testing.T,input:a.Scene_Input,wanted:a.Error){scene,problem:=a.bake(input);defer a.destroy(&scene);testing.expect_value(t,problem.error,wanted);testing.expect(t,len(problem.field)>0&&len(scene.data.bodies)==0)}

@(test)
stable_order_ids_copy_and_json_roundtrip :: proc(t:^testing.T){
 f:Fixture;fixture_init(&f);first,p:=a.bake(f.scene);defer a.destroy(&first);if !valid(t,p){return}
 for i in 0..<4{f.bodies[i],f.bodies[7-i]=f.bodies[7-i],f.bodies[i]}
 second,q:=a.bake(f.scene);defer a.destroy(&second);if !valid(t,q){return}
 testing.expect_value(t,first.content_hash,second.content_hash)
 for body,i in first.data.bodies{testing.expect_value(t,body.logical_id,second.data.bodies[i].logical_id)}
 for shape,i in first.data.shapes{testing.expect_value(t,shape.logical_id,second.data.shapes[i].logical_id)}
 bytes,error:=json.marshal(f.scene);testing.expect(t,error==nil);if error!=nil{return};defer delete(bytes)
 parsed,r:=a.parse_and_bake(bytes);defer a.destroy(&parsed);if !valid(t,r){return}
 testing.expect_value(t,parsed.content_hash,first.content_hash)
 old:=first.content_hash;f.hull[1][0]=2;f.heights[0]=4
 changed,s:=a.bake(f.scene);defer a.destroy(&changed);if !valid(t,s){return}
 testing.expect(t,changed.content_hash!=old&&first.content_hash==old&&a.content_id64(&first)!=0)
 for body,i in first.data.bodies{testing.expect_value(t,body.logical_id,changed.data.bodies[i].logical_id)}
}

@(test)
six_kinds_exact_transforms_and_sensor_flags :: proc(t:^testing.T){
 f:Fixture;fixture_init(&f);scene,p:=a.bake(f.scene);defer a.destroy(&scene);if !valid(t,p){return}
 seen:[a.Kind]bool;transformed,sphere,capsule,sensor:=false,false,false,false
 for asset in scene.data.assets{
  seen[asset.source_kind]=true
  if asset.source_kind==.Box&&asset.native_kind==.Hull{transformed=len(asset.vertices)==8;lo,hi:=asset.vertices[0],asset.vertices[0];for v in asset.vertices{lo={min(lo.x,v.x),min(lo.y,v.y),min(lo.z,v.z)};hi={max(hi.x,v.x),max(hi.y,v.y),max(hi.z,v.z)}};testing.expect(t,lo.x>0.49&&lo.x<0.51&&hi.x>1.49&&hi.x<1.51&&lo.y< -0.99&&hi.y>0.99)}
  if asset.source_kind==.Sphere&&asset.a==(b.Vec3{0.25,0.5,0}){sphere=true}
  if asset.source_kind==.Capsule{capsule=asset.a==(b.Vec3{-0.25,-0.5,0})&&asset.b==(b.Vec3{0.25,0.5,0})}
  if asset.source_kind==.Heightfield{testing.expect(t,asset.native_kind==.Mesh&&len(asset.vertices)==4&&len(asset.indices)==6&&asset.indices[1]==2&&asset.vertices[3].y==0.7)}
 }
 for kind in a.Kind{testing.expect(t,seen[kind])}
 for shape in scene.data.shapes{if shape.stable_key=="sensor.geometry"{sensor=shape.definition.is_sensor==1&&shape.definition.enable_sensor_events==1&&shape.definition.category_bits==4&&shape.definition.mask_bits==7}}
 testing.expect(t,transformed&&sphere&&capsule&&sensor)
 // Equivalent quaternion signs and lengths normalize to the same semantic hash.
 f.bodies[0].pose.rotation={0,0,0,-2};same,q:=a.bake(f.scene);defer a.destroy(&same);if valid(t,q){testing.expect_value(t,same.content_hash,scene.content_hash)}
}

@(test)
resource_geometry_dedup_duplicates_and_collisions :: proc(t:^testing.T){
 f:Fixture;fixture_init(&f);f.shapes[6]=f.shapes[1];f.shapes[6].stable_key="second_sphere_resource"
 scene,p:=a.bake(f.scene);defer a.destroy(&scene);if !valid(t,p){return}
 testing.expect(t,len(scene.data.assets)==7&&len(scene.data.resources)==8)
 sphere_id,second_id:u32
 for resource in scene.data.resources{if resource.stable_key=="sphere.geometry"{sphere_id=resource.catalog_id};if resource.stable_key=="second_sphere_resource"{second_id=resource.catalog_id}}
 testing.expect(t,sphere_id!=0&&sphere_id==second_id)
 scene.data.bodies[1].logical_id=scene.data.bodies[0].logical_id
 testing.expect_value(t,a.validate_ids(scene.data).error,a.Error.Collision)
 fixture_init(&f);f.bodies[1].stable_key=f.bodies[0].stable_key;reject(t,f.scene,.Duplicate)
 fixture_init(&f);f.shapes[1].stable_key=f.shapes[0].stable_key;reject(t,f.scene,.Duplicate)
 fixture_init(&f);f.bodies[0].shapes=f.shapes[:2];f.shapes[1].stable_key=f.shapes[0].stable_key;reject(t,f.scene,.Duplicate)
}

@(test)
finite_pose_scale_dimension_and_native_unsupported_controls :: proc(t:^testing.T){
 f:Fixture;fixture_init(&f);f.shapes[4].enable_sensor_events=true;reject(t,f.scene,.Unsupported)
 fixture_init(&f);f.bodies[4].body_type="dynamic";reject(t,f.scene,.Unsupported)
 fixture_init(&f);f.bodies[5].sensor=true;reject(t,f.scene,.Unsupported)
 fixture_init(&f);f.shapes[1].scale={1,2,1};reject(t,f.scene,.Unsupported)
 fixture_init(&f);f.shapes[0].scale[0]=0;reject(t,f.scene,.Scale)
 fixture_init(&f);f.shapes[1].radius=-1;reject(t,f.scene,.Dimension)
 fixture_init(&f);f.bodies[0].pose.rotation={};reject(t,f.scene,.Pose)
 fixture_init(&f);f.scene.gravity[0]=transmute(f32)u32(0x7fc00000);reject(t,f.scene,.Nonfinite)
 fixture_init(&f);f.shapes[4].indices[2]=99;reject(t,f.scene,.Geometry)
 fixture_init(&f);f.shapes[5].rows=3;reject(t,f.scene,.Geometry)
 fixture_init(&f);f.hull[3]={1,1,0};reject(t,f.scene,.Geometry)
 fixture_init(&f);too_many:[257][3]f32;f.shapes[3].vertices=too_many[:];reject(t,f.scene,.Geometry)
}

@(test)
schema_namespace_keys_bounds_and_invalid_json :: proc(t:^testing.T){
 f:Fixture;fixture_init(&f);f.scene.schema_version=99;reject(t,f.scene,.Schema)
 fixture_init(&f);f.scene.namespace="";reject(t,f.scene,.Key)
 fixture_init(&f);f.bodies[0].stable_key="";reject(t,f.scene,.Key)
 fixture_init(&f);f.scene.bodies={};reject(t,f.scene,.Capacity)
 for text in ([3]string{"{}","{\"schema_version\":2}","{"}){scene,p:=a.parse_and_bake(transmute([]u8)text);defer a.destroy(&scene);testing.expect(t,p.error!=.None&&len(p.field)>0)}
}
