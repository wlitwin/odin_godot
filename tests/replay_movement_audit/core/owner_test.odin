package owner_audit

import "core:fmt"
import "core:testing"
import net "godot:kit/net"

Actor :: struct {x:f32,simulation:f32,ammo,clock:i32}
fields := [?]net.Field_Desc{
 {offset=offset_of(Actor,x),size=size_of(f32),flags={.Owner_Stream}},
 {offset=offset_of(Actor,simulation),size=size_of(f32),flags={.Predicted}},
 {offset=offset_of(Actor,ammo),size=size_of(i32)},
 {offset=offset_of(Actor,clock),size=size_of(i32)},
}
FIRE :: net.Cmd_Id(0x9137)
commands := [?]net.Command_Desc{{name="fire",id=FIRE,policy=net.ACTION_ANY_SEAT_PREDICTED,invoke=proc(entity:rawptr,r:^net.Reader,env:^net.Command_Env)->bool {
 actor:=cast(^Actor)entity
 if actor.ammo<=0 {return false};actor.ammo-=1;return true
}}}

@(test)
delta_unwind_must_preserve_live_owner_motion :: proc(t:^testing.T) {
 for predicted_owner in ([2]bool{false,true}) {
  desc:=net.Entity_Desc{fields=fields[:]};set:=net.Command_Set{entity_desc=&desc,commands=commands[:]}
  server,client:=net.registry_make(),net.registry_make();defer net.registry_destroy(&server);defer net.registry_destroy(&client)
  source:=Actor{x=100,simulation=200,ammo=10};mine:=source
  owner:=net.Player_Id(predicted_owner ? 8 : 7)
  id:=net.registry_spawn(&server,&source,&set,owner);net.registry_insert(&client,id,&mine,&set,owner)
  if predicted_owner {net.registry_predict_owner(&client,id)}
  net.registry_commit_shadows(&server)
  ctx:=net.command_ctx_make();defer net.command_ctx_destroy(&ctx);ctx.me=7
  ctx.send=proc(_:rawptr,_:[]u8) {}
  net.command_begin(&ctx,id,FIRE);testing.expect(t,net.command_issue(&ctx,&mine,&set,FIRE).prediction_applied)
  mine.x=120;mine.simulation=220
  net.command_begin(&ctx,id,FIRE);testing.expect(t,net.command_issue(&ctx,&mine,&set,FIRE).prediction_applied)
  mine.x=140;mine.simulation=240
  source.clock=1
  writer:=net.writer_make();defer net.writer_destroy(&writer);net.registry_write_deltas(&writer,&server)
  reader:=net.reader_make(net.writer_bytes(&writer));testing.expect_value(t,net.registry_apply_deltas(&reader,&client,&ctx),1)
  fmt.printf("OWNER_UNWIND predicted_owner=%v x=%.1f simulation=%.1f ammo=%d clock=%d\n",predicted_owner,mine.x,mine.simulation,mine.ammo,mine.clock)
  testing.expect(t,!reader.err)
  testing.expect_value(t,mine.x,f32(140))
  testing.expect_value(t,mine.simulation,f32(240))
  testing.expect_value(t,mine.ammo,i32(8));testing.expect_value(t,mine.clock,i32(1))
  testing.expect_value(t,net.pending_count(&ctx.pending),2)
 }
}
