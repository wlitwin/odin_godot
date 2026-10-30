package replay_schema_wasm

import sc "godot:replay/schema"
import r "godot:replay"
import tr "godot:replay/transport"
import game "../../../examples/replay_hello/shared/hello"
import transportgd "godot:replay/godot/transport"

@(require)
instantiate :: proc() {
	s: sc.Schema
	sc.init(&s, r.Frame(game.World))
	frame := r.Frame(game.World){state = game.initial()}
	bytes: [16384]u8
	sc.pack(&s, frame, sc.Envelope_Meta{kind = 1, epoch = 1}, bytes[:])
	sc.unpack(&s, &frame, bytes[:sc.HEADER_BYTES + s.wire_size], sc.Envelope_Meta{kind = 1, epoch = 1})
	sc.edit_scalar(&s,&frame,0,"1",nil)
	text,_:=sc.scalar_text(&s,frame,0);delete(text)
	sc.destroy(&s)
	tl: game.Timeline
	r.init(&tl, frame, game.step)
	r.advance(&tl, game.Input{})
	r.correct(&tl, frame, nil)
	r.reset_checkpoint(&tl, frame, 2)
	r.destroy(&tl)
	m: tr.Memory
	tr.memory_init(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	ta, tb := tr.memory_transport(&a), tr.memory_transport(&b)
	tr.send(&ta, 2, .Reliable, bytes[:8])
	tr.memory_advance(&m, 1)
	tr.receive(&tb, bytes[:])
	tr.close(&ta)
	tr.close(&tb)
	tr.memory_destroy(&m)
	e: transportgd.Enet
	transportgd.enet_host(&e, 0)
	transportgd.enet_join(&e, "127.0.0.1", 1)
	transport := transportgd.enet_transport(&e)
	tr.poll(&transport)
	tr.receive(&transport, bytes[:])
	tr.close(&transport)
}
