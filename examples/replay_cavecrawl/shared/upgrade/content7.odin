package cave_upgrade
import r "godot:replay"
import p "godot:replay/play"
import lb "godot:replay/lobby"
import net "godot:replay/net"
import game "../cave"

World_7 :: struct {
	players: [SEATS]Player,
	chest: [8]p.Stack,
	door_open: bool,
	relic: Relic,
	dwellers: r.Pool(Dweller, 16),
	rocks: r.Pool(Rock, 64),
	pickups: r.Pool(Pickup, 48),
	director: Director,
	depth: u8,
	won: bool,
	dens_used: u32,
	seed: u32,
	clock: u64,
	floors:[2]Floor,
	lobby:lb.Lobby(SEATS),
}
CONTENT_7 :: u64(0x4341564552504c37)
convert_world7 :: proc(old:World_7)->(game.World,bool) {
 world:=game.World{players=old.players,chest=old.chest,door_open=old.door_open,relic=old.relic,dwellers=old.dwellers,rocks=old.rocks,pickups=old.pickups,director=old.director,depth=old.depth,won=old.won,dens_used=old.dens_used,seed=old.seed,clock=old.clock,floors=old.floors,lobby=old.lobby}
 return world,game.state_valid(world)
}
world7_valid :: proc(old:World_7)->bool {_,ok:=convert_world7(old);return ok}
model7 :: proc()->net.Model(World_7,game.Control,game.Action,game.Event,game.SEATS) {
 return {control_valid=game.control_valid,action_valid=game.action_valid,state_valid=world7_valid,
  action=proc(_: ^World_7,_:u16,_:game.Action,_:^r.Step(game.Event))->bool {panic("archive-only C7 model cannot execute")}}
}
