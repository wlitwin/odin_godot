package replay_provision_sqlite_test

import "core:fmt"
import "core:os"
import "core:testing"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"

DIRECTORY :: #config(REPLAY_PROVISION_TEST_DIR, "/tmp")
ADMIN :: p.Secret{0 = 41}
INVITE :: p.Secret{0 = 42}
CLAIM :: p.Secret{0 = 43}
clock :: proc(_: rawptr) -> (u64, bool) {return 0, true}
address :: proc() -> auth.Endpoint {e, _ := auth.endpoint("127.0.0.1", 45001); return e}
setup :: proc(s: ^db.Store, r: ^p.Room, path: string) {
	assert(db.open(s, path, true) == .None)
	b, err := p.make_room(44, 55, ADMIN, address()); assert(err == .None)
	assert(p.open(r, b, db.commit, s, {read = clock}) == .None)
}

@(test)
durable_join_retry_and_authority_updates_share_one_revision :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/reopen.sqlite3", DIRECTORY); defer delete(path)
	s: db.Store; r: p.Room
	setup(&s, &r, path); defer db.close(&s); defer p.close(&r)
	ticket, err := p.invite(&r, ADMIN, INVITE, .Trusted_Peer); testing.expect_value(t, err, p.Error.None)
	g, error := p.join(&r, ticket, CLAIM, address()); testing.expect_value(t, error, p.Error.None)
	testing.expect_value(t, auth.coordinator_start(&r.service.coordinator, {1, 1}, 1, 0), auth.Error.None)
	testing.expect_value(t, auth.coordinator_nominate(&r.service.coordinator, {1, 1}, 1, g.identity, 9, 0), auth.Error.None)
	before := r.bundle
	p.close(&r); db.close(&s)
	testing.expect_value(t, db.open(&s, path), db.Error.None)
	loaded, found, load_error := db.load(&s, 44, 55)
	testing.expect(t, found && load_error == .None); testing.expect_value(t, loaded, before)
	testing.expect_value(t, p.open(&r, loaded, db.commit, &s, {read = clock}), p.Error.None)
	revision := r.bundle.record.revision
	retry, retry_error := p.join(&r, ticket, CLAIM, address())
	testing.expect_value(t, retry_error, p.Error.None); testing.expect_value(t, retry, g)
	testing.expect_value(t, r.bundle.record.revision, revision)
	testing.expect(t, r.service.coordinator.restarted && !r.service.coordinator.active)
	testing.expect_value(t, r.bundle.record.coordinator_generation, u64(2))
	testing.expect_value(t, r.bundle.record.epoch, u64(1))
	_, _, wrong_content := db.load(&s, 44, 56); testing.expect_value(t, wrong_content, db.Error.Read)
}

@(test)
another_process_revision_and_readonly_database_cannot_publish_join_credentials :: proc(t: ^testing.T) {
	for mode in 0 ..< 2 {
		path := fmt.aprintf("%s/conflict-%d.sqlite3", DIRECTORY, mode); defer delete(path)
		s, other: db.Store; r, restarted: p.Room
		setup(&s, &r, path)
		ticket, _ := p.invite(&r, ADMIN, INVITE, .Player)
		if mode == 0 {
			assert(db.open(&other, path) == .None)
			b, found, err := db.load(&other, 44, 55); assert(found && err == .None)
			assert(p.open(&restarted, b, db.commit, &other, {read = clock}) == .None)
		} else {assert(sql.sqlite3_exec(s.connection.db, "PRAGMA query_only=ON;", nil, nil, nil) == 0)}
		g, err := p.join(&r, ticket, CLAIM, address())
		testing.expect_value(t, err, p.Error.Storage); testing.expect_value(t, g, p.Grant{})
		testing.expect(t, r.service.coordinator.poisoned)
		b, found, error := db.load(&s, 44, 55)
		testing.expect(t, found && error == .None && b.record.members[1] == (auth.Member{}) && b.invites[0].remaining == 1)
		p.close(&restarted); p.close(&r); db.close(&other); db.close(&s)
	}
}

@(test)
private_file_modes_missing_files_and_corrupt_storage_fail_without_recreation :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/private.sqlite3", DIRECTORY); defer delete(path)
	s: db.Store; r: p.Room
	testing.expect_value(t, db.open(&s, path), db.Error.Open)
	setup(&s, &r, path); defer p.close(&r); defer db.close(&s)
	info, err := os.lstat(path, context.allocator); defer os.file_info_delete(info, context.allocator)
	testing.expect(t, err == nil && info.mode == (os.Permissions{.Read_User, .Write_User}))
	testing.expect_value(t, sql.sqlite3_exec(s.connection.db, "UPDATE replay_provision SET value=zeroblob(1);", nil, nil, nil), i32(0))
	_, found, error := db.load(&s, 44, 55)
	testing.expect(t, !found && error == .Read)
	p.close(&r); db.close(&s)
	testing.expect_value(t, db.open(&s, path, true), db.Error.None)
	_, found, error = db.load(&s, 44, 55); testing.expect(t, !found && error == .Read)
	db.close(&s)
	testing.expect(t, os.chmod(path, os.perm(0o644)) == nil)
	testing.expect_value(t, db.open(&s, path, true), db.Error.Configuration)
	info2, _ := os.lstat(path, context.allocator); defer os.file_info_delete(info2, context.allocator)
	testing.expect_value(t, info2.mode, os.perm(0o644))
}

@(test)
startup_inventory_is_bounded_and_transactional :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/inventory.sqlite3", DIRECTORY); defer delete(path)
	s: db.Store; r, second: p.Room
	setup(&s, &r, path); defer db.close(&s); defer p.close(&r); defer p.close(&second)
	b, err := p.make_room(45, 55, {0 = 49}, address()); testing.expect_value(t, err, p.Error.None)
	testing.expect_value(t, p.open(&second, b, db.commit, &s, {read = clock}), p.Error.None)
	dst: [2]p.Bundle
	count, error := db.load_all(&s, 55, dst[:]); testing.expect(t, error == .None && count == 2)
	testing.expect(t, dst[0].record.room == 44 && dst[1].record.room == 45)
	before := dst
	count, error = db.load_all(&s, 55, dst[:1]); testing.expect(t, error == .Configuration && count == 0 && dst == before)
	count, error = db.load_all(&s, 56, dst[:]); testing.expect(t, error == .Read && count == 0 && dst == before)
	testing.expect_value(t, sql.sqlite3_exec(s.connection.db, "UPDATE replay_provision SET value=zeroblob(1) WHERE room=x'2d00000000000000';", nil, nil, nil), i32(0))
	count, error = db.load_all(&s, 55, dst[:]); testing.expect(t, error == .Read && count == 0 && dst == before)
}
