//gd:extends Node
//gd:class MultiplayerGenerationProbe
package multiplayer_generation
import gd "godot:godot"
import tr "godot:replay/transport"
import transportgd "godot:replay/godot/transport"

MultiplayerGenerationProbe :: struct {
    owner:     gd.Node,
    transport: transportgd.Multiplayer_Transport,
    wire:      tr.Transport,
    last:      tr.Received,
    first:     u8,
    delay:     tr.Delay,
    delayed:   bool,
}

@(gd_method)
multiplayer_generation_probe_attach :: proc(self: ^MultiplayerGenerationProbe, peer: gd.Multiplayer_Peer) -> bool {
    if !transportgd.multiplayer_attach(&self.transport, peer, 2) {
        return false
    }

    self.wire = transportgd.multiplayer_transport(&self.transport)
    return true
}

@(gd_method)
multiplayer_generation_probe_generation :: proc(self: ^MultiplayerGenerationProbe, id: gd.Int) -> gd.Int {
    return gd.Int(tr.peer_generation(&self.wire, tr.Peer_Id(id)))
}

@(gd_method)
multiplayer_generation_probe_read :: proc(self: ^MultiplayerGenerationProbe, capacity: gd.Int) -> gd.Int {
    bytes: [8]u8
    self.last = tr.receive(&self.wire, bytes[:clamp(int(capacity), 0, 8)])
    self.first = bytes[0]
    return gd.Int(self.last.state)
}

@(gd_method)
multiplayer_generation_probe_delay :: proc(self: ^MultiplayerGenerationProbe) -> bool {
    if !tr.delay_init(&self.delay, self.wire, 100, 4) {
        return false
    }

    self.wire = tr.delay_transport(&self.delay)
    self.delayed = true
    return true
}

@(gd_method)
multiplayer_generation_probe_poll :: proc(self: ^MultiplayerGenerationProbe, now: gd.Int) {
    if self.delayed {
        tr.delay_time(&self.delay, u64(now))
    }

    tr.poll(&self.wire)
}

@(gd_method)
multiplayer_generation_probe_value :: proc(self: ^MultiplayerGenerationProbe, key: string) -> gd.Int {
    switch key {
    case "from":
        return gd.Int(self.last.from)
    case "generation":
        return gd.Int(self.last.generation)
    case "byte":
        return gd.Int(self.first)
    case "retired":
        return gd.Int(self.transport.retired_packets)
    case "rejected":
        return gd.Int(self.transport.rejected_connections)
    case "peers":
        return gd.Int(len(self.transport.remotes))
    case "delayed_retired":
        return gd.Int(self.delay.retired)
    }

    return -1
}

@(gd_method)
multiplayer_generation_probe_exhaust :: proc(self: ^MultiplayerGenerationProbe) {
    self.transport.connection_serial = max(u64)
}

@(gd_method)
multiplayer_generation_probe_close :: proc(self: ^MultiplayerGenerationProbe) {
    tr.close(&self.wire)
}

multiplayer_generation_probe_exit_tree :: proc(self: ^MultiplayerGenerationProbe) {
    tr.close(&self.wire)
}
