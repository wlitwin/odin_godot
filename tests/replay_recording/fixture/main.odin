package main

import "core:os"
import "core:fmt"
import r "godot:replay"
import d "godot:replay/diagnostic"
import game "../../../examples/replay_hello/shared/hello"

main :: proc() {
 assert(len(os.args)==2)
 timeline:game.Timeline;r.init(&timeline,r.Frame(game.World){state=game.initial()},game.step);defer r.destroy(&timeline)
 for i in 0..<160 {
  input:game.Input;input.players[0]={move={i8(i%3)-1,0},fire=i%4==0}
  assert(r.advance(&timeline,input).error==.None)
 }
 recording:d.Recording(game.World,game.Input,game.Event);defer d.recording_destroy(&recording)
 assert(d.recording_capture(&recording,&timeline,game.RECORDING_CONTEXT).error==.None)
 bytes,error:=d.recording_encode(&recording);defer delete(bytes);assert(error==.None)
 assert(os.write_entire_file(os.args[1],bytes)==nil)
 d.recording_destroy(&recording);r.reset_checkpoint(&timeline,r.Frame(game.World){tick=900},2)
 assert(d.recording_capture(&recording,&timeline,game.RECORDING_CONTEXT).error==.None)
 empty,empty_error:=d.recording_encode(&recording);defer delete(empty);assert(empty_error==.None)
 assert(os.write_entire_file(fmt.tprintf("%s.empty.rplrec",os.args[1]),empty)==nil)
}
