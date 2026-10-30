package replay_checkpoint

import "core:mem"
import auth "godot:replay/authority"
import tr "godot:replay/transport"

PUBLICATION_VERSION :: u16(1)
PUBLICATION_KIND :: u16(0x5053)
Publication :: struct {
	version: u16,
	revision, source_revision, coordinator_generation, contract: u64,
	publisher: auth.Identity,
	point: auth.Point,
}
Saved :: struct {ready: bool, publication: Publication, bytes: []u8, allocator: mem.Allocator,payload:[]u8}
saved_destroy :: proc(value: ^Saved) {delete(value.bytes, value.allocator);delete(value.payload,value.allocator);value^ = {}}
publication_valid :: proc(p: Publication) -> bool {
	return p.version == PUBLICATION_VERSION && p.revision != 0 && p.source_revision != 0 && p.coordinator_generation != 0 && auth.identity_valid(p.publisher) && auth.point_valid(p.point)
}

Error :: enum u8 {None, Invalid, Denied, Busy, Stale, Storage, Missing, Schema, Timeout, Clock, Capacity}
// Evaluated after validation/CAS immediately before durable commit. It may read
// the authority clock and owner, but must not reenter storage or mutate Record.
Commit_Guard :: struct {user:rawptr,allow:proc(user:rawptr,expected:auth.Record)->bool}
// Callbacks must validate against a deployment-selected game model. load returns
// owned bytes. publish commits metadata/bytes atomically and compares the entire
// expected authority Record plus publication revision. Neither grants authority.
Backend :: struct {
	user: rawptr,
	load: proc(user: rawptr, room, content: u64, allocator: mem.Allocator) -> (Saved, bool, Error),
	publish: proc(user: rawptr, expected: auth.Record, revision, contract: u64, point: auth.Point, bytes: []u8, guard:Commit_Guard,payload:[]u8) -> (Publication, Error),
	recover: proc(user:rawptr,service:^auth.Service,from:tr.Peer_Id,actor:auth.Identity,nonce:auth.Nonce,sequence:u64,digest:[32]u8,epoch:u64,publication:Publication)->(auth.Error,bool),
}
