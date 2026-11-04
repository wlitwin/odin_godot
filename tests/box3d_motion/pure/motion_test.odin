package box3d_motion_pure_test

import "core:encoding/json"
import "core:testing"
import a "godot:box3d/authoring"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"

KINDS :: [8]string{"pin","hinge","slider","spherical","distance","motor","weld","wheel"}
Fixture :: struct {scene:a.Scene_Input,bodies:[3]a.Body_Input,shapes:[3]a.Shape_Input,joints:[1]a.Joint_Input,characters:[1]a.Character_Input}
fixture_init :: proc(f:^Fixture,kind:string=""){
 f.scene=a.scene_input_default("motion.test.world",2);f.scene.gravity={};f.scene.bodies=f.bodies[:]
 keys:=[3]string{"floor","mover","wall"};resources:=[3]string{"floor.box","mover.box","wall.box"}
 for &body,i in f.bodies{body=a.body_input_default(keys[i]);f.shapes[i]=a.shape_input_default(resources[i],"box");body.shapes=f.shapes[i:i+1]}
 f.bodies[0].pose.position={0,-0.5,0};f.shapes[0].half_extents={4,0.5,4}
 f.bodies[1].body_type="dynamic";f.bodies[1].pose.position={0,1,0};f.shapes[1].half_extents={0.25,0.25,0.25}
 f.bodies[2].pose.position={2,1.5,0};f.shapes[2].half_extents={0.25,1.5,4}
 if kind!=""{f.joints[0]=a.joint_input_default("constraint",kind,"floor","mover");f.joints[0].local_frame_a.position={0,1.5,0};f.scene.joints=f.joints[:]}
 f.characters[0]=a.character_input_default("player");f.characters[0].exclude_body="mover";f.characters[0].initial.position={0,1,0};f.characters[0].initial.velocity={2,-2,1}
 f.characters[0].config.capsule={{0,0.3,0},{0,0.9,0},0.3};f.scene.characters=f.characters[:]
}
valid :: proc(t:^testing.T,problem:a.Diagnostic)->bool{testing.expect_value(t,problem.error,a.Error.None);return problem.error==.None}
reject :: proc(t:^testing.T,input:a.Scene_Input,error:a.Error){scene,problem:=a.bake(input);defer a.destroy(&scene);testing.expect_value(t,problem.error,error);testing.expect(t,len(problem.field)>0&&len(scene.data.bodies)==0)}

@(test)
all_joint_families_stable_refs_and_schema2_json_copy :: proc(t:^testing.T){
 for kind,index in KINDS{
  input:Fixture;fixture_init(&input,kind);scene,p:=a.bake(input.scene);if !valid(t,p){a.destroy(&scene);return}
  testing.expect(t,len(scene.data.joints)==1&&scene.data.joints[0].definition.kind==b.Motion_Joint_Kind(index+1)&&scene.data.joints[0].logical_id!=0)
  testing.expect(t,scene.data.joints[0].body_a_id!=scene.data.joints[0].body_b_id&&scene.data.joints[0].definition.body_a==0&&scene.data.joints[0].definition.body_b==0)
  bytes,error:=json.marshal(input.scene);testing.expect(t,error==nil);if error!=nil{a.destroy(&scene);return}
  parsed,pp:=a.parse_and_bake(bytes);delete(bytes);if valid(t,pp){testing.expect_value(t,parsed.content_hash,scene.content_hash)};a.destroy(&parsed)
  input.bodies[0],input.bodies[2]=input.bodies[2],input.bodies[0]
  reordered,rp:=a.bake(input.scene);if valid(t,rp){testing.expect_value(t,reordered.content_hash,scene.content_hash)};a.destroy(&reordered)
  input.joints[0].constraint_hertz=30
  changed,cp:=a.bake(input.scene);if valid(t,cp){testing.expect(t,changed.content_hash!=scene.content_hash&&changed.data.joints[0].logical_id==scene.data.joints[0].logical_id)};a.destroy(&changed)
  a.destroy(&scene)
 }
}

@(test)
joint_references_limits_flags_capacity_and_finite_reject_before_publish :: proc(t:^testing.T){
 input:Fixture;fixture_init(&input,"hinge");input.joints[0].body_b="missing";reject(t,input.scene,.Reference)
 fixture_init(&input,"hinge");input.joints[0].body_b="floor";reject(t,input.scene,.Reference)
 fixture_init(&input,"hinge");input.joints[0].body_b="wall";reject(t,input.scene,.Unsupported)
 fixture_init(&input,"hinge");input.joints[0].stable_key="";reject(t,input.scene,.Key)
 fixture_init(&input,"hinge");input.joints[0].axis.flags=8;reject(t,input.scene,.Dimension)
 fixture_init(&input,"hinge");input.joints[0].axis.lower=2;input.joints[0].axis.upper=1;reject(t,input.scene,.Dimension)
 fixture_init(&input,"hinge");input.joints[0].axis.upper=3.14;reject(t,input.scene,.Dimension)
 fixture_init(&input,"hinge");input.joints[0].wheel.flags=1;reject(t,input.scene,.Unsupported)
 fixture_init(&input,"hinge");input.joints[0].local_frame_a.rotation={};reject(t,input.scene,.Pose)
 fixture_init(&input,"hinge");input.joints[0].constraint_hertz=transmute(f32)u32(0x7fc00000);reject(t,input.scene,.Dimension)
 fixture_init(&input,"pin");input.joints[0].spherical.flags=1;reject(t,input.scene,.Dimension)
 fixture_init(&input,"distance");input.joints[0].distance.length=0;reject(t,input.scene,.Dimension)
 fixture_init(&input,"distance");input.joints[0].distance.axis.flags=2;reject(t,input.scene,.Dimension)
 fixture_init(&input,"wheel");input.joints[0].wheel.lower_steering=1;reject(t,input.scene,.Dimension)
 fixture_init(&input,"weld");two:=[2]a.Joint_Input{input.joints[0],input.joints[0]};input.scene.joints=two[:];reject(t,input.scene,.Capacity)
}

@(test)
character_copied_pod_configuration_references_order_and_failures :: proc(t:^testing.T){
 input:Fixture;fixture_init(&input);input.characters[0].config.up={0,2,0}
 scene,p:=a.bake(input.scene);defer a.destroy(&scene);if !valid(t,p){return}
 testing.expect(t,len(scene.data.characters)==1&&scene.data.characters[0].config.up==(b.Vec3{0,1,0})&&scene.data.characters[0].config.filter.exclude_body==0&&scene.data.characters[0].initial.grounded==0&&scene.data.characters[0].initial.ground_shape==0)
 old:=scene.data.characters[0].initial.position;input.characters[0].initial.position={9,9,9};testing.expect_value(t,scene.data.characters[0].initial.position,old)
 fixture_init(&input);input.characters[0].exclude_body="missing";reject(t,input.scene,.Reference)
 fixture_init(&input);input.characters[0].config.up={};reject(t,input.scene,.Dimension)
 fixture_init(&input);input.characters[0].config.capsule.radius=-1;reject(t,input.scene,.Dimension)
 fixture_init(&input);input.characters[0].config.max_slides=9;reject(t,input.scene,.Dimension)
 fixture_init(&input);input.characters[0].config.floor_cosine=1.1;reject(t,input.scene,.Dimension)
 fixture_init(&input);input.characters[0].initial.velocity[0]=transmute(f32)u32(0x7f800000);reject(t,input.scene,.Nonfinite)
 fixture_init(&input);two:=[2]a.Character_Input{input.characters[0],input.characters[0]};input.scene.characters=two[:];reject(t,input.scene,.Duplicate)
}

@(test)
legacy_schema1_identity_and_new_motion_collision_checks :: proc(t:^testing.T){
 input:Fixture;fixture_init(&input);input.scene.schema_version=1;input.scene.characters={}
 scene,p:=a.bake(input.scene);defer a.destroy(&scene);if !valid(t,p){return}
 legacy:=struct{schema_version:u32,namespace:string,world:b.World_Def,bodies:[]a.Baked_Body,shapes:[]a.Baked_Shape,assets:[]a.Baked_Asset,resources:[]a.Baked_Resource}{1,scene.data.namespace,scene.data.world,scene.data.bodies,scene.data.shapes,scene.data.assets,scene.data.resources}
 bytes,error:=json.marshal(legacy);testing.expect(t,error==nil);if error==nil{testing.expect_value(t,scene.content_hash,bd.hash_bytes(bytes));delete(bytes)}
 input.scene.characters=input.characters[:];reject(t,input.scene,.Schema)
 fixture_init(&input,"slider");v2,vp:=a.bake(input.scene);defer a.destroy(&v2);if !valid(t,vp){return}
 v2.data.joints[0].logical_id=v2.data.characters[0].logical_id;testing.expect_value(t,a.validate_ids(v2.data).error,a.Error.Collision)
 fixture_init(&input);input.scene.schema_version=99;reject(t,input.scene,.Schema)
}
