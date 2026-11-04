package dockyard_round_test

import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import a "godot:box3d/authoring"
import bp "godot:box3d/presentation"
import bd "godot:box3d/diagnostics"
import ph "godot:replay/physics"
import net "godot:replay/net"
import r "godot:replay"
import rgd "godot:replay/godot"
import game "godot:examples/replay_dockyard/modules/dockyard"

DEFINITION :: #load(#config(DOCKYARD_DEFINITION,""))
Batch :: net.Batch(game.Control,game.Action,2)
Fixture :: struct{
 timeline:r.Timeline(game.Game,Batch,net.Net_Event(game.Event)),
 codec:game.Codec,model:net.Model(game.Game,game.Control,game.Action,game.Event,2),
 controllers:[2]game.Carry_Controller,
}
check :: proc(t:^testing.T,condition:bool,label:string)->bool{testing.expect(t,condition,label);return condition}
open :: proc(t:^testing.T,f:^Fixture,layout:u8,hazard:=false)->bool{
 baked,diagnostic:=a.parse_and_bake(DEFINITION);defer a.destroy(&baked)
 if !check(t,diagnostic.error==.None,"actual extracted shared definition bakes"){return false}
 built,problem:=a.build(&baked,game.PROFILE);defer a.built_destroy(&built)
 if !check(t,problem.error==.None,"actual Native shared builder"){return false}
 state,valid:=game.initial_game(&baked,&built)
 if !check(t,valid&&game.prepare_initial_round(built.world,&state,layout)&&game.state_valid(state),"actual authored19body game and selected layout"){return false}
 if hazard{
  // Test-only initial Native scene: one actual load starts beyond the dock.
  // Its fall/destruction still comes from ordinary fixed steps and game rules.
  body,status:=b.body_resolve(built.world,state.bodies[3]);if !check(t,status==.Ok,"hazard body"){return false}
  pose:=state.home[3];pose.position={11,3,0}
  if !check(t,b.body_set_pose(body,pose)==.Ok,"test scene pose before complete capture"){return false}
 }
 masses:[2]f32
 for key,i in state.bodies[1:3]{body,status:=b.body_resolve(built.world,key);if !check(t,status==.Ok,"robot mass source"){return false};mass,ms:=b.body_get_mass(body);if !check(t,ms==.Ok,"actual robot mass"){return false};masses[i]=mass}
 fmt.printf("ROUND_PHYSICS layout=%d actual_robot_masses=%v ramp_pose=%v\n",layout,masses,state.home[9])
 config,error:=ph.authoring_config(&baked);if !check(t,error==.None,"shared provider config"){return false}
 if !check(t,ph.network_codec_init(&f.codec,&built.catalog,config,game.rules())==.None,"actual complete codec"){return false}
 initial,initial_error:=ph.authoring_checkpoint(&built,config,r.Frame(game.Game){state=state},net.Net_Event(game.Event));defer r.complete_checkpoint_destroy(&initial)
 if !check(t,initial_error==.None,"actual complete source checkpoint"){return false}
 f.model=game.model(&f.codec)
 return check(t,r.init_complete(&f.timeline,&initial,net.model_callback(game.Game,game.Control,game.Action,game.Event,2),{128,96},user=&f.model)==.None,"actual complete Timeline")
}
close :: proc(t:^testing.T,f:^Fixture){
 r.destroy(&f.timeline)
 if f.codec.ready{check(t,ph.network_codec_destroy(&f.codec)==.None,"codec cleanup")}
 native,ns:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 check(t,ns==.Ok&&ws==.Ok&&native.live_bytes==0&&wrapper.live_bytes==0,"actual backend/wrapper zero after typed cleanup")
}
current :: proc(f:^Fixture)->game.Game{value,found:=r.current_values(&f.timeline);assert(found);return value.state}
frame :: proc(t:^testing.T,f:^Fixture)->(bp.Frame,bool){
 cp,error:=r.capture_complete(&f.timeline,f.timeline.head);if !check(t,error==.None,"owned current checkpoint"){return {},false};defer r.complete_checkpoint_destroy(&cp)
 value,projection_error,owner_error:=rgd.physics_presentation_frame(&cp,game.project,0,.Confirmed)
 return value,check(t,projection_error==.None&&owner_error==.None,"actual copied Native poses")
}
advance :: proc(t:^testing.T,f:^Fixture,batch:Batch)->bool{
 result:=r.advance(&f.timeline,batch)
 if result.error!=.None{fmt.printf("ROUND_ADVANCE_FAIL tick=%d status=%v\n",f.timeline.head+1,result.error)}
 return check(t,result.error==.None,"actual managed tick")&&check(t,r.confirm_through(&f.timeline,f.timeline.head)==.None,"actual authority confirmation")
}
@(test)
all_three_jobs_deliver_real_cargo_then_depart_and_retry :: proc(t:^testing.T){
 for layout in u8(0)..<3{
  f:=new(Fixture)
  if !open(t,f,layout){close(t,f);free(f);return}
  cue_count:=0
  for tick in 1..=int(game.ROUND_TICKS)+int(game.DEPARTURE_TICKS)+1{
   state:=current(f);if state.phase==.Results{break}
   poses,ok:=frame(t,f);if !ok{close(t,f);free(f);return}
   if tick%1200==0{
    robots:[2][3]f32;cargo_frame:[3][3]f32
    for row in poses.rows[:poses.count]{for key,index in state.bodies[1:3]{if row.body==bp.Body_Key(key){robots[index]=row.pose.position}}}
    for row in poses.rows[:poses.count]{for key,index in state.bodies[3:6]{if row.body==bp.Body_Key(key){cargo_frame[index]=row.pose.position}}}
    fmt.printf("ROUND_PROGRESS layout=%d tick=%d cargo=%v cached_cargo=%v robots=%v magnet=%v recovered=%v controller=%v\n",layout,tick,state.previous,cargo_frame,robots,state.magnet,state.recovered,f.controllers)
    cp,ce:=r.capture_complete(&f.timeline,f.timeline.head)
    if ce==.None{
     bodies:[35]b.Body_State;count,be:=ph.body_states(&cp,bodies[:])
     if be==.None{for body in bodies[:count]{if body.key==state.bodies[5]{fmt.printf("ROUND_LONG_BODY tick=%d type=%v mass=%v velocity=%v angular=%v pose=%v\n",tick,body.type,body.mass,body.linear_velocity,body.angular_velocity,body.pose)}}}
     _=r.complete_checkpoint_destroy(&cp)
    }
   }
   input:Batch
   for seat in 0..<2{input.controls[seat]=game.suggest_control(state,poses,u16(seat+1),&f.controllers[seat])}
   if !advance(t,f,input){close(t,f);free(f);return}
   events:[96]r.Occurrence(net.Net_Event(game.Event));count,error:=r.copy_events(&f.timeline,f.timeline.head,events[:])
   if !check(t,error==.None,"actual committed event rows"){close(t,f);free(f);return}
   for event in events[:count]{if event.value.kind==.Gameplay&&event.value.value.kind==2{cue_count+=1}}
  }
  state:=current(f)
  fmt.printf("ROUND_JOB layout=%d phase=%v score=%d payout=%d ticks=%d cues=%d lost=%v positions=%v\n",layout,state.phase,state.score,state.payout,state.round_ticks,cue_count,state.lost,state.previous)
  success:=check(t,state.phase==.Results&&state.score==3&&cue_count==3&&state.payout>=1200,"three real settled cargo deliveries, one cue each and actual departure/results")
  if success{
   saved,se:=r.capture_complete(&f.timeline,f.timeline.head)
   success=check(t,se==.None,"owned complete round results")
   if success{
    r.destroy(&f.timeline)
    success=check(t,r.init_complete(&f.timeline,&saved,net.model_callback(game.Game,game.Control,game.Action,game.Event,2),{128,96},user=&f.model)==.None,"source-free full round restoration")
    if success{
     restored,re:=r.capture_complete(&f.timeline,f.timeline.head)
     success=check(t,re==.None,"restored complete round")
     if success{
      left,le:=net.complete_view(f.codec.value,&saved,&f.codec.state,&f.codec.occurrence)
      right,rr:=net.complete_view(f.codec.value,&restored,&f.codec.state,&f.codec.occurrence)
      success=check(t,le==.None&&rr==.None,"source-free canonical views")
      if success{for part in bd.Part{success=check(t,mem.compare(left.frame.parts[part],right.frame.parts[part])==0,"source-free all five byte equality")&&success}}
      net.complete_view_destroy(&left);net.complete_view_destroy(&right)
     }
     _=r.complete_checkpoint_destroy(&restored)
    }
    _=r.complete_checkpoint_destroy(&saved)
   }
  }
  if success{
   input:=Batch{};input.has_action[0]=true;input.actions[0]={kind=.Next_Job};input.sequences[0]=1
   success=advance(t,f,input)
   after:=current(f);success=check(t,success&&after.round==2&&after.layout==(layout+1)%3&&after.phase==.Working&&after.round_ticks==0&&after.score==0,"same-session next job action resets real bodies and durable round")
   if success{_=advance(t,f,Batch{})}
  }
  close(t,f);free(f);if !success{return}
 }
}

@(test)
robot_falls_recover_once_and_lost_cargo_retries_with_a_new_native_lifetime :: proc(t:^testing.T){
 f:=new(Fixture);defer free(f);defer close(t,f);if !open(t,f,0,hazard=true){return}
 initial:=current(f);old_cargo:=initial.bodies[3];recovery_cues:=0
 for _ in 0..<600{
  state:=current(f)
  input:=Batch{};if state.recovered[0]==0{input.controls[0]={x=-100}}
  if !advance(t,f,input){return}
  events:[96]r.Occurrence(net.Net_Event(game.Event));count,error:=r.copy_events(&f.timeline,f.timeline.head,events[:])
  if !check(t,error==.None,"hazard event rows"){return}
  for event in events[:count]{if event.value.kind==.Gameplay&&event.value.value.kind==3{recovery_cues+=1}}
  state=current(f);if state.recovered[0]>0&&state.lost[0]{break}
 }
 state:=current(f)
 if !check(t,state.recovered[0]==1&&state.lives[1]==2&&recovery_cues==1,"actual driven fall recovers once with a new gameplay lifetime"){return}
 if !check(t,state.lost[0]&&state.bodies[3]==0&&state.shapes[3]==0&&state.score==0,"actual unsupported load falls and Native body is removed"){return}
 cp,ce:=r.capture_complete(&f.timeline,f.timeline.head)
 if !check(t,ce==.None,"post-loss complete checkpoint"){return}
 bodies:[35]b.Body_State;count,error:=ph.body_states(&cp,bodies[:]);_=r.complete_checkpoint_destroy(&cp)
 if !check(t,error==.None&&count==18,"Native source really contains eighteen bodies after cargo loss"){return}
 for state.phase!=.Results{if !advance(t,f,Batch{}){return};state=current(f)}
 input:=Batch{};input.has_action[0]=true;input.actions[0]={kind=.Retry};input.sequences[0]=1
 if !advance(t,f,input){return}
 state=current(f)
 if !check(t,state.round==2&&state.layout==0&&state.phase==.Working&&!state.lost[0]&&state.lives[3]==2&&state.bodies[3]!=0&&state.bodies[3]!=old_cargo&&state.logical[3]==initial.logical[3],"retry recreates the load with stable gameplay identity and a new Native key"){return}
 _=advance(t,f,Batch{})
}

@(test)
deadline_is_150_seconds_and_invalid_pose_preserves_complete_publication :: proc(t:^testing.T){
 f:=new(Fixture);defer free(f);defer close(t,f);if !open(t,f,0){return}
 before,error:=r.capture_complete(&f.timeline,0);if !check(t,error==.None,"complete baseline"){return};defer r.complete_checkpoint_destroy(&before)
 saved:=f.model;f.model.step=proc(state:^game.Game,_:[2]game.Control,_,_:u64,ctx:^r.Step(game.Event)){
  pose:=state.home[1];pose.position.x=math.nan_f32()
  if ph.body_pose_set(ctx.execution,state.bodies[1],pose)!=.None{r.abort(ctx)}
 }
 rejected:=r.advance(&f.timeline,Batch{});f.model=saved
 if !check(t,rejected.error!=.None&&f.timeline.head==0,"invalid pose aborts unpublished transaction"){return}
 after,ae:=r.capture_complete(&f.timeline,0);if !check(t,ae==.None,"baseline survives refusal"){return};defer r.complete_checkpoint_destroy(&after)
 left,le:=net.complete_view(f.codec.value,&before,&f.codec.state,&f.codec.occurrence);if !check(t,le==.None,"baseline canonical5"){return};defer net.complete_view_destroy(&left)
 right,re:=net.complete_view(f.codec.value,&after,&f.codec.state,&f.codec.occurrence);if !check(t,re==.None,"refused canonical5"){return};defer net.complete_view_destroy(&right)
 for part in bd.Part{if !check(t,mem.compare(left.frame.parts[part],right.frame.parts[part])==0,"all five unchanged after bad teleport"){return}}
 for _ in 0..<int(game.ROUND_TICKS)-1{if !advance(t,f,Batch{}){return}}
 if !check(t,current(f).phase==.Working&&current(f).round_ticks==game.ROUND_TICKS-1,"deadline does not occur early"){return}
 if !advance(t,f,Batch{}){return}
 if !check(t,current(f).phase==.Departing&&current(f).round_ticks==9000,"deadline occurs at exactly150s/fixed60"){return}
 for _ in 0..<int(game.DEPARTURE_TICKS){if !advance(t,f,Batch{}){return}}
 state:=current(f);check(t,state.phase==.Results&&state.score==0&&state.payout==0,"unfinished job departs with truthful zero payout")
}
