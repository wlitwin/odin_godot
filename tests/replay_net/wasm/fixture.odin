package replay_net_wasm

import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import game "../../../examples/replay_hello/shared/hello"
import d "godot:replay/diagnostic"

@(require)
instantiate :: proc() {
	s: net.Server(game.World, game.Controls, game.Action, game.Event, 2)
	c: net.Client(game.World, game.Controls, game.Action, game.Event, 2)
	m: tr.Memory
	tr.memory_init(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	net.server_init(&s, r.Frame(game.World){}, game.network_model(), tr.memory_transport(&a))
	token: net.Token
	token[0] = 1
	net.client_init(&c, game.network_model(), tr.memory_transport(&b), token)
	net.server_pump(&s, 0)
	net.client_pump(&c, 0)
	net.server_step(&s)
	archive:d.Recording(game.World,net.Batch(game.Controls,game.Action,2),net.Net_Event(game.Event))
	d.recording_capture(&archive,&s.timeline,d.Recording_Context{1,1,60})
	capture:r.Audit_Capture(game.World,net.Batch(game.Controls,game.Action,2),net.Net_Event(game.Event))
	d.recording_verify(&archive,d.Recording_Context{1,1,60},net.recording_model(&s.model),&capture)
	d.recording_destroy(&archive);r.audit_capture_destroy(&capture)
	net.client_step(&c, game.Controls{})
	net.client_issue(&c, game.Action{fire = true})
	intent:net.Action_Intent(game.Action)
	net.intent_capture(&intent,game.Action{fire=true})
	net.client_intent(&c,&intent);net.server_intent(&s,&intent)
	net.intent_resolve(&intent,1,{sequence=1,tick=1,applied=true})
	net.intent_recover(&intent,net.Client_Recovery{from_epoch=1,to_epoch=2})
	net.intent_cancel(&intent);net.intent_reset(&intent)
	net.client_observed(&c)
	net.client_authority(&c, 2, tr.memory_transport(&b))
	net.client_recovery(&c)
	cp, decoded: net.Checkpoint(game.World, game.Controls, game.Action, 2)
	net.checkpoint_capture(&s, &cp)
	bytes, _ := net.checkpoint_encode(&cp, game.network_model())
	net.checkpoint_decode(&decoded, bytes, game.network_model(), 1)
	converted,_:=net.checkpoint_upgrade_v6(bytes,game.network_model(),1);delete(converted)
	mapped,_:=net.checkpoint_convert_actions(bytes,game.network_model(),1,game.network_model(),2,proc(a:game.Action)->(game.Action,bool){return a,true});delete(mapped)
	resumed: net.Server(game.World, game.Controls, game.Action, game.Event, 2)
	net.server_restore(&resumed, &decoded, game.network_model(), {}, {epoch = 2})
	net.server_destroy(&resumed)
	net.checkpoint_destroy(&decoded)
	net.checkpoint_destroy(&cp)
	delete(bytes)
	net.client_destroy(&c)
	net.server_destroy(&s)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	tr.close(&wa)
	tr.close(&wb)
	tr.memory_destroy(&m)
}
