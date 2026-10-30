package replay_authority_sqlite_test

import "core:fmt"
import "core:testing"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"

DIRECTORY :: #config(REPLAY_SQLITE_TEST_DIR, "/tmp")

@(test)
sqlite_reopen_preserves_epoch_and_rejects_stale_cas_from_another_connection :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/reopen.sqlite3", DIRECTORY); defer delete(path)
	s, other: db.Store
	defer db.close(&s); defer db.close(&other)
	testing.expect_value(t, db.open(&s, path), db.Error.Open)
	testing.expect_value(t, db.open(&s, path, true), db.Error.None)
	record := auth.record_make(17, 18, {1, 1})
	address, _ := auth.endpoint("127.0.0.1", 45500)
	record.members[0] = {identity = {1, 1}, endpoint = address, enabled = true, can_host = true, trusted_authority = true}
	c: auth.Coordinator
	testing.expect_value(t, auth.coordinator_init(&c, record, db.commit, &s, 0), auth.Error.None)
	testing.expect_value(t, auth.coordinator_start(&c, {1, 1}, 1, 0), auth.Error.None)
	testing.expect_value(t, db.open(&other, path), db.Error.None)
	loaded, found, err := db.load(&other, 17, 18)
	testing.expect(t, found); testing.expect_value(t, err, db.Error.None)
	testing.expect_value(t, loaded.epoch, u64(1))
	restarted: auth.Coordinator
	testing.expect_value(t, auth.coordinator_init(&restarted, loaded, db.commit, &other, 100), auth.Error.None)
	testing.expect_value(t, auth.coordinator_renew(&c, {1, 1}, 1, 2, 10, 100), auth.Error.Storage)
	testing.expect_value(t, s.error, db.Error.Conflict)
	db.close(&other); db.close(&s)
	testing.expect_value(t, db.open(&s, path), db.Error.None)
	loaded, found, err = db.load(&s, 17, 18)
	testing.expect(t, found && err == .None)
	testing.expect_value(t, loaded.epoch, u64(1))
	testing.expect_value(t, loaded.coordinator_generation, u64(2))
}

@(test)
sqlite_write_failure_cannot_publish_a_grant_or_replace_the_prior_record :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/failure.sqlite3", DIRECTORY); defer delete(path)
	s: db.Store; defer db.close(&s)
	db.open(&s, path, true)
	record := auth.record_make(19, 20, {1, 1})
	address, _ := auth.endpoint("127.0.0.1", 45500)
	record.members[0] = {identity = {1, 1}, endpoint = address, enabled = true, can_host = true, trusted_authority = true}
	c: auth.Coordinator
	auth.coordinator_init(&c, record, db.commit, &s, 0)
	testing.expect_value(t, db.sqlite3_exec(s.db, "PRAGMA query_only=ON;", nil, nil, nil), i32(0))
	testing.expect_value(t, auth.coordinator_start(&c, {1, 1}, 1, 0), auth.Error.Storage)
	loaded, found, err := db.load(&s, 19, 20)
	testing.expect(t, found && err == .None)
	testing.expect_value(t, loaded.epoch, u64(0))
	testing.expect(t, c.poisoned)
}
