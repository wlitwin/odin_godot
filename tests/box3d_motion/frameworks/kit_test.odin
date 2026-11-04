package box3d_motion_frameworks_test

import "core:testing"
import "core:reflect"
import b "godot:box3d"
import ba "godot:box3d/authoring"
import ks "godot:kit/session"
import k "godot:kit/sim"
import kp "godot:kit/physics"

Kit :: struct {
 session:ks.Session,lane:k.Lane,physics:kp.Instance(State),built:ba.Built_Scene,
 config:b.Character_Config,turn_tick:u64,invalid:bool,
}

kit_sample :: proc(user:rawptr,tick:u64,out:rawptr){
 box:=cast(^Kit)user;(cast(^Input)out)^={turn=tick==box.turn_tick ? 1:0,invalid=box.invalid}
}
kit_step :: proc(user:rawptr,tick:u64){
 box:=cast(^Kit)user;value:=kp.state(&box.physics)
 input,found:=k.lane_input_of(&box.lane,box.session.me,Input)
 if !found{k.lane_world_fail(&box.lane,.Invalid);return}
 value.character.velocity={1+f32(input.turn),-0.25,0.25}
 config:=box.config;if input.invalid{config.max_slides=0}
 result,error:=kp.character_step(&box.physics,config,value.character)
 if error!=.Ok{return};value.character=result.state
 hits:[b.MOTION_MAX_HITS]b.Motion_Hit
 count,qe:=kp.motion_ray(&box.physics,{-5,2,0},{10,0,0},config.filter,hits[:])
 if qe!=.Ok{k.lane_world_fail(&box.lane,qe);return}
 value.query_hash=query_hash(hits[:count]);value.query_count=count;value.tick=tick
}

kit_setup :: proc(t:^testing.T,box:^Kit,scene:^ba.Baked_Scene,turn:u64,live_session:=false)->bool{
 built,diagnostic:=ba.build(scene,PROFILE)
 testing.expect_value(t,diagnostic.error,ba.Error.None);if diagnostic.error!=.None{return false}
 box.built=built;box.config=built.characters[0].config;box.turn_tick=turn
 if !live_session{box.session.is_host=true;box.session.me=1}
 k.lane_init(&box.lane,&box.session,size_of(Input))
 k.lane_set_sim(&box.lane,box,kit_sample,kit_step)
 k.lane_class_set_type(&box.lane,0,Input)
 error:=kp.authoring_attach(&box.physics,&box.lane,&box.built,initial_state(&box.built),nil,{})
 testing.expect_value(t,error,k.World_Error.Ok);return error==.Ok
}
kit_destroy :: proc(t:^testing.T,box:^Kit){
 k.lane_destroy(&box.lane);testing.expect_value(t,kp.detach(&box.physics),k.World_Error.Ok)
 ks.session_destroy(&box.session);testing.expect_value(t,ba.built_destroy(&box.built),b.Status.Ok)
}
kit_advance :: proc(t:^testing.T,box:^Kit,count:int){
 for _ in 0..<count{testing.expect_value(t,k.lane_frame(&box.lane,1.0/60),1);testing.expect_value(t,k.lane_world_status(&box.lane),k.World_Error.Ok)}
}
kit_checkpoint :: proc(t:^testing.T,box:^Kit,tick:u64)->k.World_Checkpoint{
 checkpoint,error:=k.lane_world_checkpoint(&box.lane,tick);testing.expect_value(t,error,k.World_Error.Ok);return checkpoint
}
kit_same :: proc(t:^testing.T,left,right:^k.World_Checkpoint){
 equal,error:=k.world_checkpoint_equal(left,right)
 testing.expect_value(t,error,k.World_Error.Ok);testing.expect(t,equal,"complete solver, character Side, query values and joint state match")
}

@(test)
kit_all_joint_families_character_and_sorted_queries_reconcile_atomically :: proc(t:^testing.T){
 defer expect_cleanup(t)
 for kind in KINDS{
  input:=scene_input(kind);scene,diagnostic:=ba.bake(input);scene_input_destroy(&input)
  testing.expect_value(t,diagnostic.error,ba.Error.None);if diagnostic.error!=.None{return}
  a,z:=new(Kit),new(Kit)
  if !kit_setup(t,a,&scene,2)||!kit_setup(t,z,&scene,0){kit_destroy(t,a);kit_destroy(t,z);free(a);free(z);ba.destroy(&scene);return}
  ba.destroy(&scene)
  kit_advance(t,a,4);kit_advance(t,z,4)
  authority:=kit_checkpoint(t,a,4)
  kit_advance(t,a,4);kit_advance(t,z,4)
  before:=kit_checkpoint(t,z,8)
  rejected:=k.lane_world_reconcile(&z.lane,&authority,{allow=proc(rawptr,u64)->bool{return false}})
  testing.expect_value(t,rejected.error,k.World_Error.Rejected)
  after:=kit_checkpoint(t,z,8);kit_same(t,&before,&after);k.world_checkpoint_destroy(&after)
  result:=k.lane_world_reconcile(&z.lane,&authority)
  testing.expect_value(t,result.error,k.World_Error.Ok);testing.expect_value(t,result.steps,4)
  expected:=kit_checkpoint(t,a,8);actual:=kit_checkpoint(t,z,8);kit_same(t,&expected,&actual)
  values,available:=kp.read(&z.physics)
  testing.expect(t,available&&values.character.position.x>0&&values.query_hash!=0&&values.query_count>0&&values.joint!=0)
  _,outside:=kp.character_step(&z.physics,z.config,values.character);testing.expect_value(t,outside,k.World_Error.Busy)
  k.world_checkpoint_destroy(&actual);k.world_checkpoint_destroy(&expected);k.world_checkpoint_destroy(&before);k.world_checkpoint_destroy(&authority)
  kit_destroy(t,a);kit_destroy(t,z);free(a);free(z)
 }
}

@(test)
kit_ignored_invalid_character_result_cannot_publish_side_or_solver :: proc(t:^testing.T){
 defer expect_cleanup(t)
 input:=scene_input("wheel");defer scene_input_destroy(&input)
 scene,diagnostic:=ba.bake(input);testing.expect_value(t,diagnostic.error,ba.Error.None);if diagnostic.error!=.None{return};defer ba.destroy(&scene)
 box:=new(Kit);defer free(box);defer kit_destroy(t,box)
 if !kit_setup(t,box,&scene,0){return}
 kit_advance(t,box,1);before:=kit_checkpoint(t,box,1);defer k.world_checkpoint_destroy(&before)
 values,_:=kp.read(&box.physics);box.invalid=true
 testing.expect_value(t,k.lane_frame(&box.lane,1.0/60),0)
 after:=kit_checkpoint(t,box,1);defer k.world_checkpoint_destroy(&after);kit_same(t,&before,&after)
 unchanged,available:=kp.read(&box.physics);testing.expect(t,available&&reflect.equal(values,unchanged))
}
