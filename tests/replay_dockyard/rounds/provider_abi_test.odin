package dockyard_round_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import a "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import ph "godot:replay/physics"
import net "godot:replay/net"
import r "godot:replay"
import game "godot:examples/replay_dockyard/modules/dockyard"
import legacy "legacy_provider"

@(private) refused:r.Error
@(test)
legacy_native_producer_rejects_current_commands_before_private_table_access :: proc(t:^testing.T){
 if !check(t,legacy.IDENTITY!=ph.IDENTITY&&ph.IDENTITY==0x5245504c42334432,"versioned private physics provider ABI"){return}
 baked,diagnostic:=a.parse_and_bake(DEFINITION);defer a.destroy(&baked)
 if !check(t,diagnostic.error==.None,"actual authored input"){return}
 built,problem:=a.build(&baked,game.PROFILE);defer a.built_destroy(&built)
 if !check(t,problem.error==.None,"actual legacy producer Native world"){return}
 state,valid:=game.initial_game(&baked,&built)
 if !check(t,valid&&game.prepare_initial_round(built.world,&state,0),"actual game setup"){return}
 config,ce:=legacy.authoring_config(&baked);if !check(t,ce==.None,"legacy provider config"){return}
 codec:=new(legacy.Network_Codec(game.Game,game.Control,game.Action,game.Event,2));defer free(codec)
 if !check(t,legacy.network_codec_init(codec,&built.catalog,config,game.rules())==.None,"actual legacy complete codec"){return};defer legacy.network_codec_destroy(codec)
 initial,ie:=legacy.authoring_checkpoint(&built,config,r.Frame(game.Game){state=state},net.Net_Event(game.Event));if !check(t,ie==.None,"legacy owned Native image"){return};defer r.complete_checkpoint_destroy(&initial)
 bodies:[35]b.Body_State
 _,read_error:=ph.body_states(&initial,bodies[:]);if !check(t,read_error!=.None,"current consumer refuses legacy image before cast"){return}
 model:=net.Model(game.Game,game.Control,game.Action,game.Event,2){complete_state=true,complete_codec=codec.value,
  step=proc(state:^game.Game,_:[2]game.Control,_,_:u64,ctx:^r.Step(game.Event)){
   refused=ph.body_type(ctx.execution,state.bodies[3],.Kinematic)
   r.abort(ctx)
  },control_valid=game.control_valid,action_valid=game.action_valid,state_valid=game.state_valid,
 }
 timeline:r.Timeline(game.Game,Batch,net.Net_Event(game.Event));defer r.destroy(&timeline)
 if !check(t,r.init_complete(&timeline,&initial,net.model_callback(game.Game,game.Control,game.Action,game.Event,2),{128,96},user=&model)==.None,"real ABI1 execution context"){return}
 refused=.None;result:=r.advance(&timeline,Batch{})
 if !check(t,refused==.External_State&&result.error!=.None&&timeline.head==0,"current helper rejects ABI1 before reading its smaller table"){return}
 after,ae:=r.capture_complete(&timeline,0);if !check(t,ae==.None,"legacy publication survives rejected access"){return};defer r.complete_checkpoint_destroy(&after)
 left,le:=net.complete_view(codec.value,&initial,&codec.state,&codec.occurrence);if !check(t,le==.None,"legacy baseline canonical5"){return};defer net.complete_view_destroy(&left)
 right,re:=net.complete_view(codec.value,&after,&codec.state,&codec.occurrence);if !check(t,re==.None,"legacy refused canonical5"){return};defer net.complete_view_destroy(&right)
 for part in bd.Part{if !check(t,mem.compare(left.frame.parts[part],right.frame.parts[part])==0,"ABI refusal preserves all5"){return}}
}

@(test)
current_native_execution_refuses_legacy_identity_and_current_commands_continue :: proc(t:^testing.T){
 f:=new(Fixture);defer free(f);defer close(t,f);if !open(t,f,0){return}
 f.model.step=proc(state:^game.Game,controls:[2]game.Control,joins,leaves:u64,ctx:^r.Step(game.Event)){
  pointer,error:=r.execution_pointer(ctx.execution,legacy.IDENTITY)
  refused=error
  if pointer!=nil||error!=.External_State{r.abort(ctx);return}
  game.model_step(state,controls,joins,leaves,ctx)
 }
 refused=.None
 if advance(t,f,Batch{}){check(t,refused==.External_State&&f.timeline.head==1,"ABI2 accepts current commands after refusing the old identity")}
}
