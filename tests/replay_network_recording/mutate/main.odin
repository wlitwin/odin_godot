package main

import "core:fmt"
import "core:os"
import d "godot:replay/diagnostic"
import net "godot:replay/net"
import game "../../../examples/replay_scrapyard/shared/game"
import recording "../../../examples/replay_scrapyard/shared/recording"
import upgrade "../../../examples/replay_scrapyard/shared/upgrade"
LEGACY_48 :: #config(REPLAY_RECORDING_CONTENT48,false)
when LEGACY_48 {
 World :: upgrade.World_48
 IDENTITY :: upgrade.RECORDING_48
 source_model :: upgrade.model_48
} else {
 World :: game.World
 IDENTITY :: recording.CONTEXT
 source_model :: game.model
}
Archive :: d.Recording(World,net.Batch(game.Control,game.Action,game.SEATS),net.Net_Event(game.Event))

main :: proc() {
 if len(os.args)!=3 {os.exit(2)}
 bytes,error:=os.read_entire_file(os.args[1],context.allocator);assert(error==nil);defer delete(bytes)
 archive:Archive;defer d.recording_destroy(&archive)
 assert(d.recording_decode(&archive,bytes,IDENTITY)==.None && len(archive.ticks)>0)
 last:=&archive.ticks[len(archive.ticks)-1]
 last.frame.state.players[0].shots+=1
 changed,changed_error:=d.recording_encode(&archive);assert(changed_error==.None);defer delete(changed)
 assert(os.write_entire_file(fmt.tprintf("%s.state.rplrec",os.args[2]),changed)==nil)
 last.frame.state.players[0].shots-=1;last.input.controls[0].move[0]=2
 invalid,invalid_error:=d.recording_encode(&archive);assert(invalid_error==.None);defer delete(invalid)
 assert(os.write_entire_file(fmt.tprintf("%s.input.rplrec",os.args[2]),invalid)==nil)
}
