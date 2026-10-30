package replay_cave_test
import "core:testing"
import r "godot:replay"
import lb "godot:replay/lobby"
import cave "../../examples/replay_cavecrawl/shared/cave"
@(test)
waiting_world_has_no_combat_and_restart_preserves_profiles_and_ledger :: proc(t:^testing.T) {
	w:=cave.initial(staging=true)
	events:[32]r.Occurrence(cave.Event);ctx:=r.Step(cave.Event){epoch=1,events=events[:]}
	for tick in 1..=100 {
		ctx.tick,ctx.count=u64(tick),0;cave.step(&w,[cave.SEATS]cave.Control{0={move={1,0}}},tick==1 ? 3 : 0,0,&ctx)
	}
	testing.expect_value(t,w.players[0].position,([2]f32{80,120}));testing.expect_value(t,w.dwellers.count,u32(0))
	testing.expect(t,!cave.act(&w,1,{verb=.Throw,aim={1,0}},&ctx))
	name,_:=lb.name("Scout")
	for seat in 1..=2 {testing.expect(t,cave.act(&w,u16(seat),{verb=.Lobby,lobby={verb=.Ready,name=name,ready=true}},&ctx))}
	testing.expect(t,!cave.act(&w,2,{verb=.Lobby,lobby={verb=.Start}},&ctx))
	testing.expect(t,cave.act(&w,1,{verb=.Lobby,lobby={verb=.Start}},&ctx))
	testing.expect_value(t,w.director.wave,u8(0));testing.expect_value(t,w.director.next_spawn,u64(0))
	w.players[0].kills=3;w.players[0].deaths=2;w.players[0].bag[0]={cave.GEM,5};w.won=true;w.depth=2
	testing.expect(t,cave.act(&w,1,{verb=.Lobby,lobby={verb=.Restart}},&ctx))
	testing.expect_value(t,w.lobby.run,u32(2));testing.expect_value(t,w.lobby.names[0],name)
	testing.expect_value(t,w.players[0].kills,u32(3));testing.expect_value(t,w.players[0].deaths,u32(2))
	testing.expect_value(t,w.players[0].bag[0].count,u16(0));testing.expect(t,!w.won && w.depth==1 && cave.state_valid(w))
}
