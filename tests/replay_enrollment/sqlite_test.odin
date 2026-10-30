package enrollment_test

import "core:fmt"
import "core:testing"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"
import backing "godot:replay/godot/provision_sqlite"

DIRECTORY :: #config(REPLAY_ENROLLMENT_DIR, "/tmp")

@(test)
native_profiles_reopen_without_replacing_pending_or_ready_credentials :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/reopen.sqlite3", DIRECTORY); defer delete(path)
	s: db.Client_Store; e: rgd.Enrollment_Profile
	defer db.client_close(&s); defer rgd.enrollment_profile_close(&e)
	assert(db.client_open(&s, path, "active", 55, true) == .None)
	assert(rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)))
	assert(rgd.enrollment_profile_begin(&e, request()))
	_, ok := p.enrollment_request(&e.value); testing.expect(t, !ok)
	rgd.enrollment_profile_frame(&e)
	testing.expect_value(t, e.value.phase, p.Enrollment_Phase.Pending)
	rgd.enrollment_profile_close(&e); db.client_close(&s)
	assert(db.client_open(&s, path, "active", 55) == .None)
	assert(rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)))
	q, valid := p.enrollment_request(&e.value); testing.expect(t, valid && q == request())
	reply := response(&e.value); assert(p.enrollment_accept(&e.value, reply))
	rgd.enrollment_profile_frame(&e)
	g, ready := p.enrollment_grant(&e.value); testing.expect(t, ready && g == reply.grant)
	rgd.enrollment_profile_close(&e); db.client_close(&s)
	assert(db.client_open(&s, path, "active", 55) == .None)
	assert(rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)))
	g, ready = p.enrollment_grant(&e.value); testing.expect(t, ready && g == reply.grant)
}

@(test)
competing_creators_and_stale_completion_cannot_overwrite_an_enrollment :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/race.sqlite3", DIRECTORY); defer delete(path)
	a, b: db.Client_Store; first, second: rgd.Enrollment_Profile
	defer db.client_close(&a); defer db.client_close(&b); defer rgd.enrollment_profile_close(&first); defer rgd.enrollment_profile_close(&second)
	assert(db.client_open(&a, path, "active", 55, true) == .None); assert(db.client_open(&b, path, "active", 55) == .None)
	assert(rgd.enrollment_profile_open(&first, SERVICE, 55, "fixture", "active", backing.backing(&a)))
	assert(rgd.enrollment_profile_open(&second, SERVICE, 55, "fixture", "active", backing.backing(&b)))
	q := request(); assert(rgd.enrollment_profile_begin(&first, q)); q.claim[0] += 1
	assert(rgd.enrollment_profile_begin(&second, q))
	rgd.enrollment_profile_frame(&first); rgd.enrollment_profile_frame(&second)
	testing.expect(t, first.value.phase == .Pending && second.value.phase == .Failed && second.value.error == .Conflict)
	_, allowed := p.enrollment_request(&second.value); testing.expect(t, !allowed)
	rgd.enrollment_profile_close(&second)
	assert(rgd.enrollment_profile_open(&second, SERVICE, 55, "fixture", "active", backing.backing(&b)))
	assert(p.enrollment_accept(&first.value, response(&first.value))); assert(p.enrollment_accept(&second.value, response(&second.value)))
	rgd.enrollment_profile_frame(&first); rgd.enrollment_profile_frame(&second)
	testing.expect(t, first.value.phase == .Ready && second.value.phase == .Failed && second.value.error == .Conflict)
	stored, found, err := db.client_load(&b); testing.expect(t, found && err == .None && stored == first.value.record)
}

@(test)
native_scope_readonly_and_corrupt_records_fail_without_replacement :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/failure.sqlite3", DIRECTORY); defer delete(path)
	s: db.Client_Store; e: rgd.Enrollment_Profile
	defer db.client_close(&s); defer rgd.enrollment_profile_close(&e)
	assert(db.client_open(&s, path, "active", 55, true) == .None)
	assert(rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)))
	assert(rgd.enrollment_profile_begin(&e, request())); rgd.enrollment_profile_frame(&e)
	before := e.value.record
	rgd.enrollment_profile_close(&e)
	testing.expect(t, !rgd.enrollment_profile_open(&e, "wss://wrong.example.test", 55, "fixture", "active", backing.backing(&s)) && e.value.error == .Scope)
	rgd.enrollment_profile_close(&e)
	assert(rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)))
	assert(sql.sqlite3_exec(s.storage.connection.db, "PRAGMA query_only=ON;", nil, nil, nil) == 0)
	assert(p.enrollment_accept(&e.value, response(&e.value))); rgd.enrollment_profile_frame(&e)
	testing.expect(t, e.value.phase == .Failed && e.value.record == before)
	stored, found, err := db.client_load(&s); testing.expect(t, found && err == .None && stored == before)
	assert(sql.sqlite3_exec(s.storage.connection.db, "PRAGMA query_only=OFF; UPDATE replay_client_enrollment SET value=zeroblob(1);", nil, nil, nil) == 0)
	rgd.enrollment_profile_close(&e)
	testing.expect(t, !rgd.enrollment_profile_open(&e, SERVICE, 55, "fixture", "active", backing.backing(&s)) && e.value.error == .Corrupt)
	_, _, error := db.client_load(&s); testing.expect_value(t, error, db.Error.Read)
}

@(test)
recent_room_cursor_is_independent_and_rejects_a_stale_writer :: proc(t: ^testing.T) {
	path := fmt.aprintf("%s/cursor.sqlite3", DIRECTORY); defer delete(path)
	a, b: db.Client_Store; defer db.client_close(&a); defer db.client_close(&b)
	assert(db.client_open(&a, path, "active", 55, true) == .None); assert(db.client_open(&b, path, "active", 55) == .None)
	room, revision, err := db.cursor_load(&a, "service")
	testing.expect(t, err == .None && room == 0 && revision == 0)
	testing.expect_value(t, db.cursor_commit(&a, "service", 44, 0), db.Error.None)
	testing.expect_value(t, db.cursor_commit(&b, "service", 45, 0), db.Error.Conflict)
	room, revision, err = db.cursor_load(&b, "service"); testing.expect(t, err == .None && room == 44 && revision == 1)
	testing.expect_value(t, db.cursor_commit(&b, "service", 45, 1), db.Error.None)
	room, revision, err = db.cursor_load(&a, "service"); testing.expect(t, err == .None && room == 45 && revision == 2)
	_, found, error := db.client_load(&a); testing.expect(t, !found && error == .None)
}
