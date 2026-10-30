package cave_upgrade
import r "godot:replay"
import net "godot:replay/net"
import p "godot:replay/play"
import game "../cave"
import sc "godot:replay/schema"
SEATS :: game.SEATS
Player :: game.Player
Dweller :: game.Dweller
Rock :: game.Rock
Pickup :: game.Pickup
Relic :: game.Relic
Director :: game.Director

Legacy_World :: struct {
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
}

CONTENT_1 :: u64(0x4341564552504c31)
convert_world :: proc(old:Legacy_World)->(game.World,bool) {
	world:=World_2{players=old.players,chest=old.chest,door_open=old.door_open,relic=old.relic,
		dwellers=old.dwellers,rocks=old.rocks,pickups=old.pickups,director=old.director,depth=old.depth,
		won=old.won,dens_used=old.dens_used,seed=old.seed,clock=old.clock,floors=game.FLOORS}
	return convert_world2(world)
}
// Validation descriptor only; these callbacks cannot run a game.
legacy_model :: proc()->net.Model(Legacy_World,game.Control,Legacy_Action,game.Event,SEATS) {
	return {control_valid=game.control_valid,action_valid=legacy_action_valid,
		state_valid=proc(old:Legacy_World)->bool {
			for stack in old.chest {if !p.stack_valid(stack,game.stack_limit(stack.item)) {return false}}
			_,ok:=convert_world(old);return ok
		},
		action=proc(_: ^Legacy_World,_:u16,_:Legacy_Action,_:^r.Step(game.Event))->bool {panic("archive-only model cannot execute")}}
}
convert_archive_unseeded :: proc(bytes:[]u8)->([]u8,net.Error) {
	meta,_,report:=sc.inspect(bytes);if report.error!=.None {return nil,.Invalid_Checkpoint}
	if meta.content==CONTENT_8 {return net.checkpoint_convert_state(bytes,model8(),CONTENT_8,game.model(),game.CONTENT,convert_world8)}
	if meta.content==CONTENT_4 {return net.checkpoint_convert(bytes,model4(),CONTENT_4,game.model(),game.CONTENT,convert_world4,convert_action3)}
	if meta.content==CONTENT_5 {return net.checkpoint_convert(bytes,model5(),CONTENT_5,game.model(),game.CONTENT,convert_world5,convert_action3)}
	if meta.content==CONTENT_6 {return net.checkpoint_convert(bytes,model6(),CONTENT_6,game.model(),game.CONTENT,convert_world6,convert_action3)}
	if meta.content==CONTENT_7 {return net.checkpoint_convert(bytes,model7(),CONTENT_7,game.model(),game.CONTENT,convert_world7,convert_action3)}
	if meta.content==CONTENT_3 {return net.checkpoint_convert(bytes,model3(),CONTENT_3,game.model(),game.CONTENT,convert_world3,convert_action3)}
	if meta.content==CONTENT_2 {return net.checkpoint_convert(bytes,model2(),CONTENT_2,game.model(),game.CONTENT,convert_world2,convert_action)}
	return net.checkpoint_convert(bytes,legacy_model(),CONTENT_1,game.model(),game.CONTENT,convert_world,convert_action)
}

// Seed the new observation from existing, validated checkpoint metadata. This
// preserves every prior world field and avoids guessing the host from a leader.
convert_archive :: proc(bytes:[]u8)->([]u8,net.Error) {
 converted,error:=convert_archive_unseeded(bytes);if error!=.None {return nil,error}
 meta,_,report:=sc.inspect(bytes)
 if report.error==.None && meta.content==CONTENT_8 {return converted,.None}
 defer delete(converted)
 cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 if err:=net.checkpoint_decode(&cp,converted,game.model(),game.CONTENT);err!=.None {return nil,err}
 cp.frame.state.authority_known=true;cp.frame.state.authority_seat=cp.header.local_seat
 return net.checkpoint_encode(&cp,game.model())
}
