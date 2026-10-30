package recovery_wasm

import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import sample "../shared/archive"

@(require)
instantiate :: proc() {
	s: sample.Server
	sample.authority(&s)
	cp: sample.Checkpoint
	net.checkpoint_capture(&s, &cp)
	sender: rec.Sender
	receiver: rec.Receiver(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS)
	scope := rec.Scope{11, 1, 22, sample.CONTENT}
	wire: tr.Transport
	rec.sender_init(&sender, scope, 2, wire)
	rec.receiver_init(&receiver, scope, 1, wire, sample.model())
	rec.sender_publish(&sender, &cp, sample.model(), 0)
	rec.sender_update(&sender, 1)
	rec.sender_receive(&sender, 2, nil, 1)
	rec.receiver_receive(&receiver, 1, nil, 1)
	rec.receiver_update(&receiver, 1)
	receipt, _ := rec.receiver_latest(&receiver)
	rec.receiver_checkpoint(&receiver, receipt.archive)
	link: rec.Link(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS)
	rec.link_init(&link, wire)
	rec.link_pump(&link, 0)
	s.wire = rec.link_game_transport(&link)
	rec.link_target(&link, &s, 2)
	rec.link_server(&link, &s, 0)
	// This fixture's authority archive has a deliberately large world. Runtime
	// owners stay at stable heap addresses instead of exhausting the WASM stack.
	client := new(net.Client(sample.World, sample.Control, sample.Action, sample.Event, sample.SEATS))
	defer free(client)
	rec.link_client(&link, client, 0)
	rec.link_untarget(&link)
	rec.link_destroy(&link)
	rec.sender_destroy(&sender); rec.receiver_destroy(&receiver)
	net.checkpoint_destroy(&cp); net.server_destroy(&s)
}
