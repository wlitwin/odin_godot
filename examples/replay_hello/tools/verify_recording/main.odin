package main

import "core:fmt"
import "core:os"
import r "godot:replay"
import d "godot:replay/diagnostic"
import game "../../shared/hello"

main :: proc() {os.exit(run())}
run :: proc()->int {
 if len(os.args)!=2 {fmt.eprintln("usage: verify_recording FILE.rplrec");return 2}
 bytes,ok:=read_file(os.args[1]);if !ok {fmt.eprintln("Cannot read a complete bounded recording");return 2};defer delete(bytes)
 recording:d.Recording(game.World,game.Input,game.Event);defer d.recording_destroy(&recording)
 if error:=d.recording_decode(&recording,bytes,game.RECORDING_CONTEXT);error!=.None {fmt.eprintf("Recording rejected: %v\n",error);return 2}
 capture:r.Audit_Capture(game.World,game.Input,game.Event);defer r.audit_capture_destroy(&capture)
 result:=d.recording_verify(&recording,game.RECORDING_CONTEXT,game.recording_model(),&capture)
 if result.error!=.None {
  text:=d.audit_text(result.replay,&capture);defer delete(text)
  fmt.eprintf("Recording verification failed: %v\n%s",result.error,text);return 1
 }
 final:=recording.base;if len(recording.ticks)>0 {final=recording.ticks[len(recording.ticks)-1].frame}
 actor,present:=r.pool_get(&final.state.actors,final.state.players[0]);x:f32;if present {x=actor.body.position[0]}
 fmt.printf("REPLAY_RECORDING_OK first=%d head=%d steps=%d events=%d epoch=%d bytes=%d shots=%d x=%.5f\n",recording.base.tick,recording.header.head,len(recording.ticks),len(recording.events),recording.epoch,len(bytes),final.state.shots,x)
 return 0
}

read_file :: proc(path:string)->([]u8,bool) {
 file,error:=os.open(path);if error!=nil {return nil,false};defer os.close(file)
 size,size_error:=os.file_size(file);if size_error!=nil || size<1 || size>d.MAX_RECORDING_BYTES {return nil,false}
 bytes:=make([]u8,int(size));success:=false;defer if !success {delete(bytes)}
 at:=0
 for at<len(bytes) {n,error:=os.read(file,bytes[at:]);at+=n;if n==0 || error!=nil && error!=.EOF {return nil,false}}
 extra:[1]u8;n,tail_error:=os.read(file,extra[:]);if n!=0 || tail_error!=nil && tail_error!=.EOF {return nil,false}
 success=true;return bytes,true
}
