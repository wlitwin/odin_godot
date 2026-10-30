package replay_scrapyard_test

import "core:testing"
import "core:math"
import r "godot:replay"
import game "godot:examples/replay_scrapyard/shared/game"
import flow "godot:examples/replay_scrapyard/shared/flow"

@(test)
area_fade_uses_displayed_lifetime_including_late_observation :: proc(t: ^testing.T) {
	color := [4]f32{0.5,0.75,1,0.5}
	first := flow.disc_view(100,117,150,color)
	late := flow.disc_view(108,117,150,color)
	testing.expect(t, first.visible && math.abs(first.scale-138)<0.001 && first.color==color)
	testing.expect(t, late.visible && late.scale>first.scale && late.color[3]<first.color[3])
	testing.expect_value(t, flow.disc_view(108,117,150,color), late)
	testing.expect(t, !flow.disc_view(117,117,150,color).visible && !flow.disc_view(118,117,150,color).visible)
}

@(test)
buff_bursts_are_once_per_new_cast_and_do_not_replay_after_rewind :: proc(t: ^testing.T) {
	w := game.initial(); w.clock=10; observer:flow.Buff_Observer; points:[4]flow.Buff_Point
	testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),0)
	flash:=game.Flash{kind=.Cast,ability=4,seat=1,generation=2,serial=3,origin={100,200},until=28}
	_,ok:=r.pool_insert(&w.flashes,flash);testing.expect(t,ok);w.clock=11
	testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),1)
	testing.expect_value(t, points[0].position,flash.origin)
	testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),0)
	w.clock=9;testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),0)
	w.clock=11;testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),0)
	w.clock=12;testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),0)
	flash.serial=4;flash.until=30;_,ok=r.pool_insert(&w.flashes,flash);testing.expect(t,ok);w.clock=13
	testing.expect_value(t, flow.buff_points(&observer,&w,1,points[:]),1)
}

@(test)
buff_restore_stale_epoch_and_capacity_do_not_invent_launches :: proc(t: ^testing.T) {
	w:=game.initial();w.clock=10;observer:flow.Buff_Observer;points:[1]flow.Buff_Point
	flash:=game.Flash{kind=.Cast,ability=4,seat=1,generation=1,serial=1,origin={100,200},until=27}
	_,ok:=r.pool_insert(&w.flashes,flash);testing.expect(t,ok)
	testing.expect_value(t,flow.buff_points(&observer,&w,1,points[:]),0)
	w.clock=11;testing.expect_value(t,flow.buff_points(&observer,&w,2,points[:]),0)
	before:=observer;testing.expect_value(t,flow.buff_points(&observer,&w,1,points[:]),0);testing.expect_value(t,observer,before)
	flash.serial=2;flash.until=29;_,ok=r.pool_insert(&w.flashes,flash);testing.expect(t,ok);w.clock=12
	testing.expect_value(t,flow.buff_points(&observer,&w,2,nil),0);testing.expect_value(t,observer.dropped,u64(1))
	testing.expect_value(t,flow.buff_points(&observer,&w,2,points[:]),0)
}
