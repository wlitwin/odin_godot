package cave_owner_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import o "godot:replay/owned"
import sc "godot:replay/schema"
import base "../../examples/replay_cavecrawl/shared/cave"
import game "../../examples/replay_cavecrawl/shared/owner_cave"

Server :: net.Server(game.World,game.Control,game.Action,game.Event,game.SEATS)
start :: proc(s:^Server) {
 cfg:=net.DEFAULT_CONFIG;cfg.content=game.CONTENT;cfg.hz=game.HZ
 w:=game.initial();for &floor in w.floors {floor.waves={};floor.wave_count=1;floor.rests={}}
 assert(net.server_init(s,r.Frame(game.World){state=w},game.model(),{},cfg,local_seat=1)==.None)
 assert(net.server_set_local_token(s,net.Token{0=11})==.None)
 assert(net.server_step(s)==.None)
}
sample :: proc(body:o.State(o.Pose2),position:[2]f32)->o.Sample(o.Pose2) {
 return {o.scope(body),body.sequence+1,body.produced+1,{position=position,linear={30,0}}}
}

@(test)
owner_profile_has_a_distinct_contract_and_reuses_inventory_rules :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline)
 c:=game.Control{avatar=sample(frame.state.avatars[0],{300,180}),move={-1,0}}
 testing.expect_value(t,net.server_local(&s,c),net.Error.None)
 testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);testing.expect_value(t,frame.state.players[0].position,([2]f32{300,180}))
 _,issued:=net.server_issue(&s,game.Action{verb=.Take,index=0});testing.expect_value(t,issued,net.Error.None)
 testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);testing.expect_value(t,frame.state.players[0].bag[0].count,u16(3));testing.expect_value(t,game.world_items(&frame.state,game.GEM),u32(3))
 testing.expect_value(t,frame.state.avatars[0].value.linear,([2]f32{30,0}))
 testing.expect_value(t,game.model().control_timing,net.Control_Timing.Latest_Observation)
 a,ae:=net.model_contract(base.model(),net.DEFAULT_CONFIG);b,be:=net.model_contract(game.model(),net.DEFAULT_CONFIG)
 testing.expect(t,ae==.None && be==.None && a!=b)
 testing.expect_value(t,r.audit(&s.timeline,2).error,r.Error.None)
}

@(test)
carry_records_external_prop_motion_and_drop_rejects_old_scope :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline)
 net.server_local(&s,game.Control{avatar=sample(frame.state.avatars[0],{120,80})});net.server_step(&s)
 net.server_issue(&s,game.Action{verb=.Carry});testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);testing.expect_value(t,frame.state.prop.owner,u16(1))
 old:=sample(frame.state.prop,{220,140})
 net.server_local(&s,game.Control{prop=old});testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);testing.expect_value(t,frame.state.relic.position,([2]f32{220,140}))
 // A prop observation is independent of avatar integration. No reducer silently
 // snaps it back to the avatar's position before accepting gameplay actions.
 testing.expect_value(t,frame.state.players[0].position,([2]f32{120,80}))
 net.server_issue(&s,game.Action{verb=.Set_Down});testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);scope:=o.scope(frame.state.prop);testing.expect_value(t,frame.state.prop.owner,u16(0))
 old.sequence+=1;old.produced+=1;old.value.position={999,999}
 net.server_local(&s,game.Control{prop=old});testing.expect_value(t,net.server_step(&s),net.Error.None)
 frame,_=r.current(&s.timeline);testing.expect(t,o.scope(frame.state.prop)==scope && frame.state.relic.position==([2]f32{220,140}))
}

@(test)
checkpoint_installs_exact_frame_then_fences_old_owner_samples :: proc(t:^testing.T) {
 s,resumed:Server;start(&s);defer net.server_destroy(&s);defer net.server_destroy(&resumed)
 frame,_:=r.current(&s.timeline)
 control:=game.Control{avatar=sample(frame.state.avatars[0],{120,80})}
 net.server_local(&s,control);net.server_step(&s);net.server_issue(&s,game.Action{verb=.Carry});net.server_step(&s)
 cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 testing.expect_value(t,net.checkpoint_capture(&s,&cp),net.Error.None)
 bytes,encoded:=net.checkpoint_encode(&cp,game.model());defer delete(bytes);testing.expect_value(t,encoded,net.Error.None)
 decoded:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&decoded)
 testing.expect_value(t,net.checkpoint_decode(&decoded,bytes,game.model(),game.CONTENT),net.Error.None)
 testing.expect_value(t,net.server_restore(&resumed,&decoded,game.model(),{}, {epoch=2,local_seat=1,retain_membership=true}),net.Error.None)
 before,_:=r.current(&resumed.timeline);testing.expect(t,reflect.equal(before,cp.frame))
 control.avatar.sequence+=1;control.avatar.produced+=1;control.avatar.value.position={600,300}
 net.server_local(&resumed,control);testing.expect_value(t,net.server_step(&resumed),net.Error.None)
 after,_:=r.current(&resumed.timeline)
 testing.expect(t,after.state.epoch==2 && after.state.players[0].position==cp.frame.state.players[0].position && after.state.prop.owner==1)
 testing.expect(t,after.state.avatars[0].epoch==2 && after.state.avatars[0].sequence==0 && after.state.avatars[0].value.linear==cp.frame.state.avatars[0].value.linear)
 net.server_local(&resumed,game.Control{avatar=sample(after.state.avatars[0],{140,80})});testing.expect_value(t,net.server_step(&resumed),net.Error.None)
 after,_=r.current(&resumed.timeline);testing.expect_value(t,after.state.players[0].position,([2]f32{140,80}))
 testing.expect_value(t,r.audit(&resumed.timeline,cp.frame.tick+1).error,r.Error.None)
}

@(test)
foreign_owner_and_recycled_avatar_samples_cannot_move_a_player :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline);w:=frame.state
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=frame.tick,epoch=1,events=storage[:]}
 game.reset_player(&w,2,&ctx);w.players[1].connected=true
 stolen:=sample(w.avatars[1],{444,222})
 control:[game.SEATS]game.Control;control[0].avatar=stolen
 ctx.tick+=1;game.step(&w,control,0,0,&ctx)
 testing.expect_value(t,w.players[1].position,([2]f32{102,120}));testing.expect_value(t,w.players[0].position,([2]f32{80,120}))
 old:=sample(w.avatars[0],{300,100});generation:=w.avatars[0].key.generation
 game.reset_player(&w,1,&ctx);w.players[0].connected=true;control[0].avatar=old
 ctx.tick+=1;game.step(&w,control,0,0,&ctx)
 testing.expect(t,w.avatars[0].key.generation==generation+1 && w.players[0].position==([2]f32{80,120}) && game.state_valid(w))
 codec:sc.Schema;defer sc.destroy(&codec);testing.expect_value(t,sc.init(&codec,game.World).error,sc.Error.None)
}

@(test)
respawn_at_the_same_position_still_retires_previous_life_samples :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline);w:=frame.state
 w.players[0].hp=0;w.players[0].respawn_at=frame.tick+1
 old:=sample(w.avatars[0],{400,200});revision:=w.avatars[0].revision
 events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=frame.tick+1,epoch=1,events=events[:]}
 control:[game.SEATS]game.Control
 game.step(&w,control,0,0,&ctx)
 control[0].avatar=old
 testing.expect(t,w.players[0].hp==base.MAX_HP && w.avatars[0].revision>revision)
 ctx.tick+=1;ctx.count=0;game.step(&w,control,0,0,&ctx)
 testing.expect_value(t,w.players[0].position,([2]f32{80,120}))
 game.reset_player(&w,2,&ctx);w.players[1].connected=true;w.players[1].hp=0;w.players[1].respawn_at=ctx.tick+60
 old_friend:=sample(w.avatars[1],{500,300});friend_revision:=w.avatars[1].revision
 testing.expect(t,game.act(&w,1,game.Action{verb=.Revive,index=1},&ctx))
 testing.expect(t,w.players[1].hp==30 && w.avatars[1].revision>friend_revision)
 control={};control[1].avatar=old_friend;ctx.tick+=1;ctx.count=0;game.step(&w,control,0,0,&ctx)
 testing.expect_value(t,w.players[1].position,([2]f32{102,120}))
}

@(test)
descent_preserves_inventory_and_carrier_but_cuts_both_motion_scopes :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline)
 net.server_local(&s,game.Control{avatar=sample(frame.state.avatars[0],{120,80})});net.server_step(&s)
 net.server_issue(&s,game.Action{verb=.Carry});net.server_step(&s)
 frame,_=r.current(&s.timeline);w:=frame.state
 w.players[0].bag[0]={game.TORCH,1};w.chest[1].count-=1
 w.director.done=true;w.director.wave=w.floors[0].wave_count;w.director.remaining=0;w.door_open=true
 old_avatar,old_prop:=w.avatars[0].revision,w.prop.revision;version:=w.relic.version
 controls:[game.SEATS]game.Control
 controls[0]={avatar=sample(w.avatars[0],w.floors[0].door),prop=sample(w.prop,w.floors[0].door+[2]f32{10,-12})}
 events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=frame.tick+1,epoch=1,events=events[:]}
 game.step(&w,controls,0,0,&ctx)
 testing.expect(t,ctx.error==.None && w.depth==2 && w.players[0].bag[0].count==1 && w.relic.carrier==1 && w.relic.version==version)
 testing.expect(t,w.avatars[0].revision>old_avatar && w.prop.revision>old_prop && game.state_valid(w))
 ctx.tick+=1;ctx.count=0;game.step(&w,controls,0,0,&ctx)
 testing.expect_value(t,w.players[0].position,([2]f32{80,120}));testing.expect_value(t,w.relic.position,([2]f32{90,108}))
 testing.expect(t,w.avatars[0].sequence==0 && w.prop.sequence==0)
}

@(test)
late_owner_poses_settle_independently_of_authority_health_and_victory :: proc(t:^testing.T) {
 s:Server;start(&s);defer net.server_destroy(&s)
 frame,_:=r.current(&s.timeline);w:=frame.state
 w.players[0].hp=0;w.players[0].respawn_at=100
 controls:[game.SEATS]game.Control;controls[0].avatar=sample(w.avatars[0],{112,88})
 events:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=frame.tick+1,epoch=1,events=events[:]}
 game.step(&w,controls,0,0,&ctx)
 testing.expect(t,w.players[0].hp==0 && w.players[0].position==([2]f32{112,88}) && w.avatars[0].sequence==1)
 w.won=true;controls[0].avatar=sample(w.avatars[0],{114,90});ctx.tick+=1;ctx.count=0
 game.step(&w,controls,0,0,&ctx)
 testing.expect(t,w.players[0].position==([2]f32{114,90}) && w.avatars[0].sequence==2 && game.state_valid(w))
}
