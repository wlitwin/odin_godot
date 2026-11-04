package box3d_common

import b "godot:box3d"

// Read-only example projection. Frame status, interpolation and UI remain in
// the separate adapter/presentation layer. This never touches a native world.
Presentation_Row :: struct {
	lifetime:u64,
	key:b.Body_Key,
	asset:u32,
	seat:u16,
	pose:b.Pose,
	alive,awake:bool,
}

// A Game and its body cache must come from the SAME owned complete checkpoint.
// Failed capacity/key validation leaves caller output unchanged.
presentation_rows :: proc(game:^Game,states:[]b.Body_State,out:[]Presentation_Row)->bool {
	if game==nil || len(out)<MAX_DYNAMIC{return false}
	rows:[MAX_DYNAMIC]Presentation_Row
	for alive,i in game.alive {
		if !alive{continue}
		found:=false
		for state in states {
			if state.key!=game.bodies[i]{continue}
			asset:=CRATE_ASSET;if i<2{asset=PLAYER_ASSET};if i==int(game.initial){asset=SPAWN_ASSET}
			rows[i]={lifetime=game.lifetimes[i],key=state.key,asset=asset,seat=i<2?u16(i+1):0,pose=state.pose,alive=true,awake=state.is_awake!=0}
			found=true;break
		}
		if !found{return false}
	}
	copy(out,rows[:]);return true
}
