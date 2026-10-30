package main

import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import sc "godot:replay/schema"

ADMIN :: p.Secret{0 = 41}
INVITE :: p.Secret{0 = 42}
CLAIM :: p.Secret{0 = 43}
Owner :: struct {store: db.Store, stall: bool}
clock :: proc(_: rawptr) -> (u64, bool) {return 0, true}
address :: proc() -> auth.Endpoint {e, _ := auth.endpoint("127.0.0.1", 45001); return e}
commit :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
	o := cast(^Owner)user
	if !o.stall {return db.commit(&o.store, expected, next)}
	// Crash inside the actual SQLite transaction containing a valid full join.
	s := &o.store
	assert(sql.sqlite3_exec(s.connection.db, "BEGIN IMMEDIATE;", nil, nil, nil) == 0)
	assert(sc.pack(&s.codec, next, {kind = 0x5052, epoch = 1, tick = next.record.revision, content = 55}, s.buffer).error == .None)
	statement: sql.Statement
	assert(sql.sqlite3_prepare_v2(s.connection.db, "UPDATE replay_provision SET value=?1;", -1, &statement, nil) == 0)
	assert(sql.sqlite3_bind_blob(statement, 1, raw_data(s.buffer), i32(len(s.buffer)), nil) == 0)
	assert(sql.sqlite3_step(statement) == 101); sql.sqlite3_finalize(statement)
	fmt.println("REPLAY_PROVISION_UNCOMMITTED")
	for {time.sleep(100 * time.Millisecond)}
}
main :: proc() {
	assert(len(os.args) == 3)
	mode, path := os.args[1], os.args[2]
	o: Owner; r: p.Room
	assert(db.open(&o.store, path, mode == "create") == .None)
	defer db.close(&o.store); defer p.close(&r)
	if mode == "create" {
		b, err := p.make_room(44, 55, ADMIN, address()); assert(err == .None)
		assert(p.open(&r, b, commit, &o, {read = clock}) == .None)
		_, error := p.invite(&r, ADMIN, INVITE, .Trusted_Peer); assert(error == .None)
		assert(auth.coordinator_start(&r.service.coordinator, {1, 1}, 1, 0) == .None)
		fmt.println("REPLAY_PROVISION_CREATED"); return
	}
	b, found, err := db.load(&o.store, 44, 55); assert(found && err == .None)
	if mode == "verify-uncommitted" {assert(b.record.members[1] == (auth.Member{}) && b.invites[0].remaining == 1)}
	if mode == "verify-committed" {assert(b.record.members[1].identity.member == 2 && b.invites[0].remaining == 0)}
	assert(p.open(&r, b, commit, &o, {read = clock}) == .None)
	o.stall = mode == "uncommitted"
	g, error := p.join(&r, {44, INVITE}, CLAIM, address()); assert(error == .None)
	assert(g.identity == (auth.Identity{2, 1}) && g.can_host && g.trusted_authority)
	if mode == "committed" {fmt.println("REPLAY_PROVISION_COMMITTED"); for {time.sleep(100 * time.Millisecond)}}
	if mode == "verify-committed" {assert(g.key == b.enrollments[1].key && g.token == b.enrollments[1].token)}
	assert(r.bundle.record.epoch == 1 && r.service.coordinator.restarted && !r.service.coordinator.active)
	fmt.printf("REPLAY_PROVISION_CRASH_OK mode=%s epoch=%d generation=%d members=2 remaining=0\n", mode, r.bundle.record.epoch, r.bundle.record.coordinator_generation)
}
