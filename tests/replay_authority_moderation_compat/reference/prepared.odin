package authority_reference

import "core:mem"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

// Owned copy held across coordinator preparation/claim. Ongoing replication may
// recycle its older slots without invalidating this exact proposed recovery point.
Prepared :: struct {allocator: mem.Allocator, ready: bool, point: Point, bytes: []u8}

prepared_destroy :: proc(p: ^Prepared) {delete(p.bytes, p.allocator); p^ = {}}

// A still-running former owner can retain its frozen world across coordinator
// restart. It must obtain a new epoch through Recover_Owner before restoring it.
prepared_capture :: proc(p: ^Prepared, server: ^net.Server($S, $C, $A, $E, $N), room, binding: u64,
                         codec: ^net.Checkpoint_Codec = nil, allocator := context.allocator) -> Error {
	if p.ready {return .Busy}
	if !server.initialized || !server.cfg.require_permit || room == 0 || binding == 0 {return .Invalid}
	cp: net.Checkpoint(S, C, A, N); defer net.checkpoint_destroy(&cp)
	if net.checkpoint_capture(server, &cp, allocator = allocator) != .None {return .Invalid}
	bytes, err := net.checkpoint_encode(&cp, server.model, allocator, codec)
	if err != .None {return .Invalid}
	p^ = {allocator = allocator, ready = true, bytes = bytes,
	      point = {{room, server.cfg.epoch, binding, server.cfg.content}, {sequence = 1, tick = cp.frame.tick, bytes = u32(len(bytes)), hash = rec.hash(bytes)}}}
	return .None
}

prepared_copy :: proc(p: ^Prepared, receiver: ^rec.Receiver($S, $C, $A, $E, $N), archive: rec.Archive,
                      allocator := context.allocator) -> Error {
	if p.ready {return .Busy}
	cp, found := rec.receiver_checkpoint(receiver, archive)
	if !found {return .No_Checkpoint}
	bytes, err := net.checkpoint_encode(cp, receiver.model, allocator, &receiver.archive_codec)
	if err != .None {return .Invalid}
	if rec.hash(bytes) != archive.hash || len(bytes) != int(archive.bytes) {delete(bytes, allocator); return .Invalid}
	p^ = {allocator, true, {receiver.scope, archive}, bytes}
	return .None
}

prepared_restore :: proc(p: ^Prepared, server: ^net.Server($S, $C, $A, $E, $N), model: net.Model(S, C, A, E, N),
                         wire: tr.Transport, lease: ^Lease, local_seat: u16, preserve_pending: bool = false,
                         options: net.Resume_Options = {}, allocator := context.allocator, codec: ^net.Checkpoint_Codec = nil) -> net.Error {
	cp: net.Checkpoint(S, C, A, N)
	defer net.checkpoint_destroy(&cp)
	if err := prepared_decode(p, &cp, model, lease, allocator, codec); err != .None {return err}
	resume := options
	resume.epoch, resume.local_seat, resume.preserve_pending, resume.permit = lease.view.epoch, local_seat, preserve_pending, lease_permit(lease)
	if !cp.settings.require_permit {return .Invalid_Config}
	return net.server_restore(server, &cp, model, wire, resume, allocator)
}

prepared_decode :: proc(p: ^Prepared, cp: ^net.Checkpoint($S, $C, $A, $N), model: net.Model(S, C, A, $E, N),
                        lease: ^Lease, allocator := context.allocator, codec: ^net.Checkpoint_Codec = nil) -> net.Error {
	if !p.ready || !lease.require_owner || lease.view.recovered != p.point || !lease_live(lease, lease.view.epoch) {return .Fenced}
	if rec.hash(p.bytes) != p.point.archive.hash {return .Invalid_Checkpoint}
	if err := net.checkpoint_decode(cp, p.bytes, model, lease.content, allocator, codec); err != .None {return err}
	if !cp.settings.require_permit {net.checkpoint_destroy(cp); return .Invalid_Config}
	return .None
}
