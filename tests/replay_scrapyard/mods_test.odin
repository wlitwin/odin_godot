package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import c "../../examples/replay_scrapyard/shared/content"
import mods "../../examples/replay_scrapyard/shared/mods"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
original_mod_act_data_replaces_full_rows_and_preserves_combo_precedence :: proc(t:^testing.T) {
 catalog:=c.stock()
 result:=mods.apply(&catalog,transmute([]u8)#load("fixtures/mod-junk.json"))
 testing.expect_value(t,result.error,mods.Error.None)
 testing.expect_value(t,result.counts,mods.Counts{guns=1,mobs=1})
 testing.expect_value(t,catalog.guns[0].damage,u8(9));testing.expect_value(t,catalog.mobs[1].hp,u16(30))
 testing.expect_value(t,c.name_string(&catalog.guns[0].name),string("junkcannon"))
 catalog=c.stock()
 result=mods.apply(&catalog,transmute([]u8)#load("fixtures/mod-chain.json"))
 testing.expect_value(t,result.error,mods.Error.None)
 testing.expect_value(t,catalog.combo_count,u8(9))
 row,found:=c.combo_find(&catalog,2,1);testing.expect(t,found && row.reaction==.Transmute && row.output==3)
 row,found=c.combo_find(&catalog,1,2);testing.expect(t,found && row.reaction==.Detonate && row.damage==16)
 catalog=c.stock()
 result=mods.apply(&catalog,transmute([]u8)#load("fixtures/mod-delivery.json"))
 testing.expect_value(t,result.error,mods.Error.None)
 testing.expect_value(t,catalog.abilities[1].family,c.Ability_Family.Buff)
 testing.expect_value(t,catalog.abilities[2].family,c.Ability_Family.Nova)
 testing.expect_value(t,catalog.abilities[2].pulse,u16(1))
 testing.expect_value(t,catalog.statuses[5].dealt_mult,f32(2))
 catalog=c.stock()
 result=mods.apply(&catalog,transmute([]u8)#load("fixtures/mod-zone.json"))
 testing.expect_value(t,result.error,mods.Error.None)
 testing.expect_value(t,catalog.abilities[2].family,c.Ability_Family.Zone)
 testing.expect_value(t,catalog.abilities[2].duration,u16(2400))
}

@(test)
invalid_mods_are_transactional_and_parser_work_is_bounded :: proc(t:^testing.T) {
 stock:=c.stock();catalog:=stock
 bads:=[6]string{
  `{"guns":[{"id":0,"name":"oops","cooldown":20,"speed":16,"ttl":40,"sprite_size":[32,16]}],"mobs":[{"id":999}]}`,
  `{"guns":[{"id":0.5}]}`,
  `{"status":[{"id":3,"name":"oops","duration":1,"max_stacks":1,"move_mult":NaN}]}`,
  `{"abilities":[{"id":7,"name":"bad","family":"zone","speed":1,"cooldown":1,"duration":0}]}`,
  `{"combos":[{"present":1,"incoming":15,"output":0}]}`,
  `{"guns":`,
 }
 for text in bads {
  result:=mods.apply(&catalog,transmute([]u8)text)
  testing.expect(t,result.error!=.None && reflect.equal(catalog,stock))
 }
 nested:[66]u8;for &b,i in nested {b=i<33 ? u8('[') : u8(']')}
 testing.expect(t,!mods.bounded_text(nested[:]))
 commented:=`{/* [ { ignored */ "guns":[] // }
 }`
 testing.expect_value(t,mods.apply(&catalog,transmute([]u8)commented).error,mods.Error.None)
 testing.expect(t,reflect.equal(catalog,stock))
}

@(test)
sparse_guns_and_abilities_are_selectable_but_holes_are_not :: proc(t:^testing.T) {
 catalog:=c.stock()
 text:=`{
 guns:[{id:9,name:'spare',kind:'bolt',cooldown:20,dmg:9,mag:8,reload_ticks:72,jam_per_mille:0,jam_taps:1,speed:16,ttl:40,sprite_pos:[32,48],sprite_size:[32,16]}],
 status:[{id:12,name:'focus',duration:600,max_stacks:1,move_mult:1,dot_dmg:0,dot_every:0,taken_mult:1,dealt_mult:2,tint:[1,1,1,0.5]}],
 abilities:[{id:11,name:'focus',family:'buff',cooldown:120,range:200,radius:0,arc_cos:0,speed:1,dmg:0,status:12,self_buff:true}]
 }`
 testing.expect_value(t,mods.apply(&catalog,transmute([]u8)text).error,mods.Error.None)
 testing.expect(t,c.valid(catalog) && !c.gun_present(&catalog,7) && !c.ability_present(&catalog,9))
 testing.expect_value(t,c.next_gun(&catalog,6),u8(9));testing.expect_value(t,c.next_gun(&catalog,9),u8(0))
 testing.expect_value(t,c.next_ability(&catalog,6),u8(7));testing.expect_value(t,c.next_ability(&catalog,7),u8(11));testing.expect_value(t,c.next_ability(&catalog,11),u8(1))
 w:=game.initial();w.catalog=catalog;w.players[0].connected=true
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){epoch=1,events=storage[:]}
 profile:=game.Profile{iron=9,abilities={11,2}}
 testing.expect(t,game.profile_valid(profile) && game.action(&w,1,game.Action{kind=.Profile,profile=profile},&ctx))
 profile.iron=7;testing.expect(t,!game.action(&w,1,game.Action{kind=.Profile,profile=profile},&ctx))
 w.stage=.Yard;game.enter(&w,1,&ctx)
 testing.expect_value(t,w.players[0].gun.ammo,u16(8));testing.expect(t,game.state_valid(w))
}

@(test)
parsed_chain_delivery_and_zone_mods_execute_their_authored_effects :: proc(t:^testing.T) {
 storage:[32]r.Occurrence(game.Event);ctx:=r.Step(game.Event){epoch=1,tick=1,events=storage[:]}
 w:=yard();w.clock=1
 testing.expect_value(t,mods.apply(&w.catalog,transmute([]u8)#load("fixtures/mod-chain.json")).error,mods.Error.None)
 w.catalog.mobs[1].hp,w.catalog.mobs[1].speed=100,0;game.spawn_mob(&w,1,{700,1040})
 notices:game.Notices
 game.apply_status(&w,game.mob_target(&w,0),2,game.Credit{1,1},&notices,&ctx)
 game.apply_status(&w,game.mob_target(&w,0),1,game.Credit{1,1},&notices,&ctx)
 testing.expect_value(t,w.mobs.values[0].fx[0].kind,u8(3));testing.expect_value(t,w.reactions,u32(1))
 for tick in 2..=21 {ctx.tick,ctx.count=u64(tick),0;game.step(&w,[game.SEATS]game.Control{},0,0,&ctx)}
 testing.expect_value(t,w.mobs.values[0].hp,u16(98));testing.expect_value(t,w.players[0].damage,u32(2))
 testing.expect(t,game.state_valid(w))
 w=yard();w.clock=1;ctx.tick,ctx.count=1,0
 testing.expect_value(t,mods.apply(&w.catalog,transmute([]u8)#load("fixtures/mod-delivery.json")).error,mods.Error.None)
 w.catalog.mobs[1].hp,w.catalog.mobs[1].speed=100,0;game.spawn_mob(&w,1,{600,1040})
 testing.expect(t,game.cast_ability(&w,1,0,{},false,&ctx));testing.expect(t,game.cast_ability(&w,1,1,{},false,&ctx))
 testing.expect_value(t,w.players[0].damage,u32(6));testing.expect_value(t,w.mobs.values[0].hp,u16(94))
 testing.expect(t,game.state_valid(w))
 w=yard();w.clock=1;w.players[0].position={400,1040};ctx.tick,ctx.count=1,0
 testing.expect_value(t,mods.apply(&w.catalog,transmute([]u8)#load("fixtures/mod-zone.json")).error,mods.Error.None)
 w.catalog.mobs[1].hp,w.catalog.mobs[1].speed=30,0;game.spawn_mob(&w,1,{600,1040})
 testing.expect(t,game.cast_ability(&w,1,1,{650,1040},true,&ctx))
 for tick in 2..=301 {ctx.tick,ctx.count=u64(tick),0;game.step(&w,[game.SEATS]game.Control{},0,0,&ctx)}
 testing.expect_value(t,w.players[0].kills,u32(1));testing.expect_value(t,w.players[0].hp,u8(10));testing.expect_value(t,w.zones.count,u32(1))
 w.players[0].position={650,1040}
 for tick in 302..=317 {ctx.tick,ctx.count=u64(tick),0;game.step(&w,[game.SEATS]game.Control{},0,0,&ctx)}
 testing.expect(t,w.players[0].hp<10 && game.state_valid(w))
}
