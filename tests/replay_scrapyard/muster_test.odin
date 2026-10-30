package replay_scrapyard_test

import "core:testing"
import game "../../examples/replay_scrapyard/shared/game"
import content "../../examples/replay_scrapyard/shared/content"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
muster_cycles_sparse_catalog_both_ways_and_clears_readiness :: proc(t: ^testing.T) {
 w:=game.initial();c:=&w.catalog
 // Retain valid entries at separated IDs; cycling must skip missing rows and zero abilities.
 c.guns[1]={};c.guns[2]={};c.guns[3]={}
 testing.expect_value(t,content.cycle_gun(c,0,1),u8(4))
 testing.expect_value(t,content.cycle_gun(c,4,-1),u8(0))
 testing.expect_value(t,content.cycle_gun(c,0,-1),c.gun_count-1)
 c.abilities[2]={};c.abilities[3]={}
 testing.expect_value(t,content.cycle_ability(c,1,1),u8(4))
 testing.expect_value(t,content.cycle_ability(c,4,-1),u8(1))
 testing.expect_value(t,content.cycle_ability(c,1,-1),c.ability_count-1)
 profile:=game.Profile{ready=true,name=game.name("axle"),abilities={1,4}}
 for field in 0..<4 {
  next,mask:=flow.muster_pick(c,profile,field,1)
  testing.expect(t,!next.ready);testing.expect_value(t,next.name,profile.name)
  back,back_mask:=flow.muster_pick(c,next,field,-1,mask);back.ready=true
  testing.expect_value(t,back_mask,u8(0))
  testing.expect_value(t,back,profile)
 }
}

@(test)
muster_start_shortcut_needs_every_other_player_and_cannot_skip_simulation_readiness :: proc(t: ^testing.T) {
 w:=game.initial();w.players[0].connected=true;w.players[1].connected=true
 testing.expect(t,!flow.muster_can_start(&w,1))
 w.players[1].profile.ready=true
 testing.expect(t,flow.muster_can_start(&w,1));testing.expect(t,!game.all_ready(&w))
 testing.expect(t,!flow.muster_can_start(&w,0));testing.expect(t,!flow.muster_can_start(&w,2))
 w.players[0].profile.ready=true;testing.expect(t,game.all_ready(&w))
 w.stage=.Yard;testing.expect(t,!flow.muster_can_start(&w,1))
}
