package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import a "godot:replay/assets"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
spray_reference_and_placement_are_ordinary_checkpoint_values :: proc(t: ^testing.T) {
 w:=yard();w.players[0].position={700,1040}
 bytes:=[4]u8{1,2,3,4};ref:=a.reference(bytes[:])
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){epoch=1,tick=1,events=storage[:]}
 game.step(&w,[game.SEATS]game.Control{},0,0,&ctx)
 testing.expect(t,game.action_valid(game.Action{kind=.Set_Spray,image=ref}))
 testing.expect(t,game.action(&w,1,game.Action{kind=.Set_Spray,image=ref},&ctx))
 testing.expect(t,game.action(&w,1,game.Action{kind=.Stamp},&ctx))
 testing.expect_value(t,w.players[0].spray.image,ref)
 testing.expect_value(t,w.players[0].spray.position,[2]f32{700,1040})
 snapshot:=r.Frame(game.World){tick=1,state=w}
 ctx.tick,ctx.count=2,0
 controls:[game.SEATS]game.Control;controls[0].move={1,0};game.step(&w,controls,0,0,&ctx)
 game.action(&w,1,game.Action{kind=.Stamp},&ctx)
 testing.expect_value(t,w.players[0].spray.stamp,u32(2))
 testing.expect_value(t,snapshot.state.players[0].spray.stamp,u32(1))
 bytes[0]=9;next:=a.reference(bytes[:]);position:=w.players[0].spray.position
 game.action(&w,1,game.Action{kind=.Set_Spray,image=next},&ctx)
 testing.expect_value(t,w.players[0].spray.position,position)
 testing.expect(t,game.state_valid(w))
 ref.bytes=game.SPRAY_MAX+1
 testing.expect(t,!game.action_valid(game.Action{kind=.Set_Spray,image=ref}))
}

@(test)
floor_change_removes_placement_and_keeps_the_players_signature :: proc(t:^testing.T) {
 w:=clear_world();bytes:=[4]u8{1,2,3,4};ref:=a.reference(bytes[:])
 w.players[0].spray={image=ref,position=w.players[0].position,stamp=4,floor=w.floor}
 before:=w.players[0].spray
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){epoch=1,tick=1,events=storage[:]}
 game.turn_floor(&w,false,&ctx)
 testing.expect_value(t,w.players[0].spray.stamp,u32(0));testing.expect_value(t,w.players[0].spray.image,ref)
 testing.expect(t,!reflect.equal(w.players[0].spray,before) && game.state_valid(w))
}
