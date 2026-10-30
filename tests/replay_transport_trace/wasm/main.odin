package trace_wasm
import tape "godot:replay/transport/trace"
import tr "godot:replay/transport"
exercise :: proc() {
 log:tape.Log;tape.init(&log);defer tape.destroy(&log)
 c:tape.Capture;wire:=tape.capture(&c,&log,tr.Transport{})
 tr.poll(&wire);tape.mark(&log,1,2)
 data,_:=tape.encode(&log);defer delete(data)
 decoded:tape.Log;defer tape.destroy(&decoded);tape.decode(&decoded,data)
 p:tape.Replay;wire=tape.replay(&p,&decoded);tr.status(&wire);tape.read_mark(&p,1)
}
