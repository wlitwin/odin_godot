package main

import "core:os"
import "core:fmt"
import r "godot:replay"
import d "godot:replay/diagnostic"
import game "../../../examples/replay_hello/shared/hello"

main :: proc() {
 assert(len(os.args)==4)
 original,read:=os.read_entire_file(os.args[1],context.allocator);assert(read==nil);defer delete(original)
 branch,read_branch:=os.read_entire_file(os.args[2],context.allocator);assert(read_branch==nil);defer delete(branch)
 out:=os.args[3]
 assert(os.write_entire_file(fmt.tprintf("%s/original.rplrec",out),original)==nil)
 assert(os.write_entire_file(fmt.tprintf("%s/branch.rplrec",out),branch)==nil)
 recording:d.Recording(game.World,game.Input,game.Event);defer d.recording_destroy(&recording)
 assert(d.recording_decode(&recording,original,game.RECORDING_CONTEXT)==.None)
 recording.ticks[len(recording.ticks)-1].frame.state.shots+=1
 mismatch,error:=d.recording_encode(&recording);defer delete(mismatch);assert(error==.None)
 assert(os.write_entire_file(fmt.tprintf("%s/mismatch.rplrec",out),mismatch)==nil)
 original[len(original)-1]~=1;assert(os.write_entire_file(fmt.tprintf("%s/bad.rplrec",out),original)==nil)
 // Read-only imported checkpoint has no actors; rendering/branching must cope.
 d.recording_destroy(&recording)
 tl:game.Timeline;r.init(&tl,r.Frame(game.World){tick=900},game.step);defer r.destroy(&tl)
 assert(d.recording_capture(&recording,&tl,game.RECORDING_CONTEXT).error==.None)
 empty,empty_error:=d.recording_encode(&recording);defer delete(empty);assert(empty_error==.None)
 assert(os.write_entire_file(fmt.tprintf("%s/empty.rplrec",out),empty)==nil)
}
