package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import view "godot:replay/view"
import game "../../examples/replay_scrapyard/shared/game"
import arena "../../examples/replay_scrapyard/shared/arena"
import sound "../../examples/replay_scrapyard/shared/audio"

@(test)
wall_contact_preserves_entry_rules_and_outward_normals :: proc(t: ^testing.T) {
 layout: arena.Layout; layout.covers[0] = {100, 100, 40, 40, 0}
 cases := [?]struct {from, delta, normal: [2]f32, fraction: f32, hit: bool}{
  {{80, 120}, {40, 0}, {-1, 0}, 0.5, true}, {{160, 120}, {-40, 0}, {1, 0}, 0.5, true},
  {{120, 80}, {0, 40}, {0, -1}, 0.5, true}, {{120, 160}, {0, -40}, {0, 1}, 0.5, true},
  {{80, 80}, {40, 40}, {-1, 0}, 0.5, true}, {{80, 120}, {20, 0}, {-1, 0}, 1, true},
  {{120, 120}, {40, 0}, {}, 1, false}, {{80, 80}, {0, 40}, {}, 1, false},
  {{80, 80}, {0, 0}, {}, 1, false},
 }
 for c in cases {
  fraction, hit, normal := arena.contact(&layout, c.from, c.delta)
  old_fraction, old_hit := arena.clip(&layout, c.from, c.delta)
  testing.expect_value(t, fraction, c.fraction); testing.expect_value(t, hit, c.hit)
  testing.expect_value(t, normal, c.normal); testing.expect(t, old_fraction == fraction && old_hit == hit)
 }
}

@(test)
wall_facts_distinguish_cover_body_and_expiry_and_pool_reuse :: proc(t: ^testing.T) {
 for kind in ([2]game.Shot_Kind{.Ballistic, .Spit}) {
  w := yard(); w.layout.covers = {}; w.layout.covers[0] = {600, 1000, 20, 60, 0}
  shot := game.Shot{kind=kind,seat=kind == .Spit ? 0 : 1,generation=1,serial=1,position={550,1040},velocity={100,0},ttl=3,damage=1}
  for pass in 0 ..< 4 {
   // pass 0: cover, 1: reused slot, 2: earlier body, 3: free flight expiry.
   if pass == 2 {
    if kind == .Spit {w.players[0].position={580,1040}} else {game.spawn_mob(&w,0,{580,1040})}
   }
   if pass == 3 {shot.position={700,1040}; shot.ttl=1}
   handle, inserted := r.pool_insert(&w.shots,shot); testing.expect(t,inserted)
   storage:[net.GAME_EVENTS]r.Occurrence(game.Event); ctx:=r.Step(game.Event){tick=u64(pass+1),epoch=1,events=storage[:]}
   notices:game.Notices; game.shot_step(&w,&notices,&ctx); game.flush(&w,&notices,&ctx)
   testing.expect_value(t,ctx.error,r.Error.None); testing.expect_value(t,w.shots.count,u32(0))
   walls:=0
   for occurrence in storage[:ctx.count] {if occurrence.value.kind==.Wall {
    walls+=1; event:=occurrence.value
    testing.expect_value(t,event.position,[2]f32{600,1040}); testing.expect_value(t,game.wall_normal(event),[2]f32{-1,0})
    testing.expect_value(t,event.detail,kind==.Spit ? u8(4) : u8(0))
    testing.expect_value(t,event.generation,handle.generation); testing.expect_value(t,event.serial,handle.index+1)
    testing.expect_value(t,occurrence.id.source,u64(handle.generation)<<32|u64(handle.index+1))
    testing.expect_value(t,game.model().event_policy(event),view.Policy.Confirmed)
    cue,ok:=sound.gameplay(event); testing.expect(t,ok && cue.kind==.Hit && cue.position==event.position && cue.spatial)
   }}
   testing.expect_value(t,walls,pass<2 ? 1 : 0)
  }
 }
}

@(test)
dense_wall_contacts_reserve_later_action_feedback :: proc(t: ^testing.T) {
 w:=yard(); w.layout.covers={}; w.layout.covers[0]={600,1000,20,60,0}
 for i in 0 ..< game.MAX_SHOTS {r.pool_insert(&w.shots,game.Shot{seat=1,generation=1,serial=u32(i+1),position={550,1040},velocity={100,0},ttl=3,damage=1})}
 storage:[net.GAME_EVENTS]r.Occurrence(game.Event);ctx:=r.Step(game.Event){tick=1,epoch=1,events=storage[:]}
 notices:game.Notices;game.shot_step(&w,&notices,&ctx);game.flush(&w,&notices,&ctx)
 testing.expect_value(t,ctx.error,r.Error.None);testing.expect_value(t,ctx.count,7)
 testing.expect_value(t,notices.wall_dropped,game.MAX_SHOTS-7);testing.expect_value(t,w.shots.count,u32(0))
 before:=w
 // Fill the complete conservative future-action envelope, then fold actual
 // admitted damage into that existing identity. Neither can be crowded out.
 for seat in u16(1) ..= game.SEATS {
  for kind in ([6]game.Event_Kind{.Hit,.Killed,.Hurt,.Healed,.Blast,.Entered}) {
   r.emit(&ctx,u64(w.players[seat-1].generation)<<32|u64(seat),u64(kind),game.Event{kind=kind,seat=seat,generation=w.players[seat-1].generation})
  }
 }
 r.emit(&ctx,100,u64(game.Event_Kind.Started),game.Event{kind=.Started})
 testing.expect_value(t,ctx.count,net.GAME_EVENTS);testing.expect_value(t,ctx.error,r.Error.None)
 testing.expect(t,game.development_apply(&w,1,{kind=.Hurt,seat=1,amount=1},&ctx))
 testing.expect_value(t,ctx.error,r.Error.None);testing.expect_value(t,w.players[0].hp,before.players[0].hp-1)
 testing.expect(t,!reflect.equal(w,before))
}
