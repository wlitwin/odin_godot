package main
import "core:os"
import tape "godot:replay/transport/trace"
import sc "godot:replay/schema"
import trace "godot:tests/replay_claimball_trace/shared"
main :: proc() {
 assert(len(os.args)==4 && (os.args[1]=="world" || os.args[1]=="effects"))
 bytes,error:=os.read_entire_file(os.args[2],context.allocator);assert(error==nil);defer delete(bytes)
 log:tape.Log;assert(tape.decode(&log,bytes)==.None);defer tape.destroy(&log)
 codec:sc.Schema;assert(sc.init(&codec,trace.Frame).error==.None);defer sc.destroy(&codec)
 changed:=false
 for e in log.entries {
  if e.operation!=.Mark || e.peer!=2 {continue}
  frame:trace.Frame;data:=tape.payload(&log,e);assert(sc.decode(&codec,&frame,data).error==.None)
  if frame.world_tick==0 || (os.args[1]=="effects" && frame.changes==0) {continue}
  if os.args[1]=="world" {frame.world_hash~=1} else {frame.changes_hash~=1}
  assert(sc.encode(&codec,frame,data).error==.None);changed=true;break
 }
 assert(changed)
 out,e:=tape.encode(&log);assert(e==.None);defer delete(out)
 assert(os.write_entire_file(os.args[3],out)==nil)
}
