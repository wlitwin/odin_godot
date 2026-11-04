package replay_slice_unit_test
import "core:testing"
import "core:mem"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
Game :: struct {body:b.Body_Key,shape:b.Shape_Key}
spawn_tick :: proc(game:^Game,mode:u32,ctx:^r.Step(u32)){
 definition:=b.body_def_default();definition.type=.Dynamic;definition.pose.position={1,3,0}
 error:r.Error
 if mode==0{game.body,error=ph.spawn(ctx.execution,1,definition)}else{game.body,game.shape,error=ph.spawn_with_shape(ctx.execution,mode==2?999:u32(1),definition)}
 if error!=.None{return}
 ph.step(ctx.execution)
}
@(test)
spawn_with_shape_matches_old_path_and_failed_candidate_preserves_complete_state :: proc(t:^testing.T){
 world,status:=b.world_create(b.world_def_default());testing.expect_value(t,status,b.Status.Ok)
 definition:=b.body_def_default();definition.type=.Dynamic;definition.pose.position={0,3,0}
 body,bs:=b.body_create(world,definition);testing.expect_value(t,bs,b.Status.Ok)
 _,ss:=b.shape_box(body,b.shape_def_default(),{.25,.25,.25});testing.expect_value(t,ss,b.Status.Ok)
 config:=ph.config_default(17,b.build_fingerprint());config.initial_dynamic_bodies=1
 initial,error:=ph.checkpoint_make(r.Frame(Game){},u32,world,config);testing.expect_value(t,error,r.Error.None);b.world_destroy(&world)
 left,right:r.Timeline(Game,u32,u32)
 testing.expect_value(t,r.init_complete(&left,&initial,spawn_tick,{128,0}),r.Error.None)
 testing.expect_value(t,r.init_complete(&right,&initial,spawn_tick,{128,0}),r.Error.None)
 r.complete_checkpoint_destroy(&initial)
 testing.expect_value(t,r.advance(&left,u32(0)).error,r.Error.None);testing.expect_value(t,r.advance(&right,u32(1)).error,r.Error.None)
 a,ae:=r.capture_complete(&left,1);z,ze:=r.capture_complete(&right,1);testing.expect_value(t,ae,r.Error.None);testing.expect_value(t,ze,r.Error.None)
 testing.expect_value(t,a.frame.state.body,z.frame.state.body);testing.expect(t,z.frame.state.shape!=0)
 before,_:=b.engine_allocation_stats();before_wrapper,_:=b.snapshot_allocation_stats()
 count,query_error:=ph.body_states(&z,nil);testing.expect_value(t,query_error,r.Error.None);testing.expect_value(t,count,u32(2))
 short:=[1]b.Body_State{{key=123}}
 required,capacity_error:=ph.body_states(&z,short[:]);testing.expect_value(t,required,count);testing.expect_value(t,capacity_error,r.Error.Output_Too_Small);testing.expect_value(t,short[0].key,b.Body_Key(123))
 states:[35]b.Body_State;actual,read_error:=ph.body_states(&z,states[:]);testing.expect_value(t,actual,count);testing.expect_value(t,read_error,r.Error.None)
 for state in states[:count]{single,single_error:=ph.body_state(&z,state.key);testing.expect_value(t,single_error,r.Error.None);testing.expect_value(t,single,state)}
 saved_owner:=z.owner;z.owner.realm=999;_,guard_error:=ph.body_states(&z,states[:]);testing.expect(t,guard_error!=.None);z.owner=saved_owner
 after,_:=b.engine_allocation_stats();after_wrapper,_:=b.snapshot_allocation_stats()
 testing.expect_value(t,after.total_calls,before.total_calls);testing.expect_value(t,after_wrapper.total_calls,before_wrapper.total_calls)
 n,_:=ph.dump(&a,nil);m,_:=ph.dump(&z,nil);testing.expect_value(t,n,m)
 x,y:=make([]u8,int(n)),make([]u8,int(m));ph.dump(&a,x);ph.dump(&z,y);testing.expect_value(t,mem.compare(x,y),0)
 testing.expect_value(t,r.advance(&right,u32(2)).error,r.Error.Invalid_Config)
 current,found:=r.current_values(&right);testing.expect(t,found);testing.expect_value(t,current,z.frame)
 preserved,pe:=r.capture_complete(&right,1);testing.expect_value(t,pe,r.Error.None);ph.dump(&preserved,y);testing.expect_value(t,mem.compare(x,y),0)
 delete(x);delete(y);r.complete_checkpoint_destroy(&a);r.complete_checkpoint_destroy(&z);r.complete_checkpoint_destroy(&preserved)
 r.destroy(&left);r.destroy(&right);testing.expect_value(t,ph.allocation_stats().live_bytes,u64(0))
}
