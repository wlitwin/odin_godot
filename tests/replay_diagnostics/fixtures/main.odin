package main

import "core:os"
import "core:fmt"
import net "godot:replay/net"
import assets "godot:replay/assets"
import game "../../../examples/replay_scrapyard/shared/game"

main :: proc() {
	assert(len(os.args)==3)
	bytes,read:=os.read_entire_file(os.args[1],context.allocator);defer delete(bytes);assert(read==nil)
	bundle,bundled:=assets.bundle_decode(bytes,game.CONTENT);assert(bundled==.None)
	cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
	assert(net.checkpoint_decode(&cp,bundle.root,game.model(),game.CONTENT)==.None)
	cp.frame.state.players[0].hp-=1
	cp.frame.state.players[0].scrap+=7
	cp.frame.state.players[0].ability_cd[0].remaining-=1
	cp.frame.state.shots.generations[game.MAX_SHOTS-1]+=1
	assert(game.state_valid(cp.frame.state))
	encoded,err:=net.checkpoint_encode(&cp,game.model());defer delete(encoded);assert(err==.None)
	out,reframed:=assets.bundle_replace_root(bytes,encoded,game.CONTENT);defer delete(out);assert(reframed==.None)
	assert(os.write_entire_file(os.args[2],out)==nil)
	fmt.println("REPLAY_DIAGNOSTIC_FIXTURE_OK")
}
