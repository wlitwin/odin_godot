#+build darwin, linux
package replay_p2p_provision_sqlite

import "core:crypto"
import "core:mem"
import "core:os"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/p2p/provision"
import sc "godot:replay/schema"

Error :: sql.Error
Store :: struct {
	connection: sql.Store,
	codec: sc.Schema,
	buffer: []u8,
	allocator: mem.Allocator,
	ready: bool,
	error: Error,
}

// Use a private deployment directory (including its backups). New files are
// exclusive-created with mode 0600; existing symlinks/non-private files fail.
// The connection shares the authority store's checked FULL/WAL configuration,
// but bundles live in a separate table and never import credential-less records.
open :: proc(s: ^Store, path: string, create: bool = false, busy_ms: u32 = 100, allocator := context.allocator) -> Error {
	if s.ready || s.connection.db != nil || len(path) == 0 || len(path) > 4096 || path == ":memory:" || busy_ms > 1000 {return .Invalid}
	for b in path {if b == 0 {return .Invalid}}
	info, err := os.lstat(path, allocator)
	if err != nil {
		if !create {return .Open}
		file, error := os.open(path, {.Read, .Write, .Create, .Excl}, {.Read_User, .Write_User})
		if error != nil {return .Open}
		os.close(file)
		info, err = os.lstat(path, allocator)
	}
	defer os.file_info_delete(info, allocator)
	if err != nil || info.type != .Regular || info.mode & os.perm(0o077) != (os.Permissions{}) {return .Configuration}
	s.allocator = allocator
	if error := sql.open(&s.connection, path, false, busy_ms, allocator); error != .None {return error}
	if !execute(s, "CREATE TABLE IF NOT EXISTS replay_p2p_provision(room BLOB PRIMARY KEY NOT NULL, value BLOB NOT NULL);") ||
	   sc.init(&s.codec, p.Bundle, allocator = allocator).error != .None {close(s); return .Schema}
	s.buffer = make([]u8, sc.HEADER_BYTES + s.codec.wire_size, allocator)
	s.ready = true
	return .None
}

close :: proc(s: ^Store) {
	if len(s.buffer) != 0 {crypto.zero_explicit(raw_data(s.buffer), len(s.buffer))}
	delete(s.buffer, s.allocator)
	sc.destroy(&s.codec)
	sql.close(&s.connection)
	s^ = {}
}

load :: proc(s: ^Store, room, content: u64) -> (bundle: p.Bundle, found: bool, error: Error) {
	if !s.ready || room == 0 || content == 0 {return {}, false, .Invalid}
	statement: sql.Statement
	if sql.sqlite3_prepare_v2(s.connection.db, "SELECT value FROM replay_p2p_provision WHERE room=?1;", -1, &statement, nil) != 0 {return {}, false, .Read}
	defer sql.sqlite3_finalize(statement)
	key := room_key(room)
	if sql.sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) != 0 {return {}, false, .Read}
	result := sql.sqlite3_step(statement)
	if result == 101 {return {}, false, .None}
	if result != 100 {return {}, false, .Read}
	count := sql.sqlite3_column_bytes(statement, 0)
	ptr := sql.sqlite3_column_blob(statement, 0)
	if count != i32(len(s.buffer)) || ptr == nil {return {}, false, .Read}
	meta, report := sc.unpack(&s.codec, &bundle, (cast([^]u8)ptr)[:count], {kind = 0x5050, epoch = u64(p.VERSION), content = content})
	if report.error != .None || !p.bundle_valid(bundle) || bundle.enrollment.record.room != room || meta.tick != bundle.enrollment.record.revision {return {}, false, .Read}
	if sql.sqlite3_step(statement) != 101 {return {}, false, .Read}
	return bundle, true, .None
}

// Startup inventory for one content deployment. Fail transactionally if the
// database contains corrupt/wrong-content rows or more rooms than the owner can
// retain. No public request invokes this scan or lazily restarts a coordinator.
load_all :: proc(s: ^Store, content: u64, dst: []p.Bundle) -> (count: int, error: Error) {
	if !s.ready || content == 0 || len(dst) < 1 || len(dst) > 32 {return 0, .Invalid}
	staged: [32]p.Bundle
	defer crypto.zero_explicit(&staged, size_of(staged))
	statement: sql.Statement
	if sql.sqlite3_prepare_v2(s.connection.db, "SELECT room,value FROM replay_p2p_provision ORDER BY room;", -1, &statement, nil) != 0 {return 0, .Read}
	defer sql.sqlite3_finalize(statement)
	for {
		result := sql.sqlite3_step(statement)
		if result == 101 {copy(dst, staged[:count]); return count, .None}
		if result != 100 {return 0, .Read}
		if count == len(dst) {return 0, .Configuration}
		key_ptr := sql.sqlite3_column_blob(statement, 0)
		ptr := sql.sqlite3_column_blob(statement, 1)
		if key_ptr == nil || ptr == nil || sql.sqlite3_column_bytes(statement, 0) != 8 || sql.sqlite3_column_bytes(statement, 1) != i32(len(s.buffer)) {return 0, .Read}
		bytes := (cast([^]u8)ptr)[:len(s.buffer)]
		meta, report := sc.unpack(&s.codec, &staged[count], bytes, {kind = 0x5050, epoch = u64(p.VERSION), content = content})
		b := &staged[count]
		key := room_key(b.enrollment.record.room)
		if report.error != .None || !p.bundle_valid(b^) || meta.tick != b.enrollment.record.revision || crypto.compare_constant_time(key[:], (cast([^]u8)key_ptr)[:8]) != 1 {return 0, .Read}
		count += 1
	}
}

commit :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
	s := cast(^Store)user
	if !s.ready || s.connection.transaction || expected == max(u64) || next.enrollment.record.revision != expected + 1 || !p.bundle_valid(next) {s.error = .Invalid; return false}
	if !execute(s, "BEGIN IMMEDIATE;") {s.error = .Write; return false}
	s.connection.transaction = true
	committed := false
	defer {
		if !committed {execute(s, "ROLLBACK;")}
		s.connection.transaction = false
		crypto.zero_explicit(raw_data(s.buffer), len(s.buffer))
	}
	current, found, err := load(s, next.enrollment.record.room, next.enrollment.record.content)
	defer crypto.zero_explicit(&current, size_of(current))
	if err != .None {s.error = err; return false}
	if (found && (current.enrollment.record.revision != expected || next.players != current.players ||
	              next.enrollment.record.coordinator_generation < current.enrollment.record.coordinator_generation)) ||
	   (!found && (expected != 0 || next.enrollment.record.epoch != 0 || next.enrollment.record.coordinator_generation != 1)) {s.error = .Conflict; return false}

	if sc.pack(&s.codec, next, {kind = 0x5050, epoch = u64(p.VERSION), tick = next.enrollment.record.revision, content = next.enrollment.record.content}, s.buffer).error != .None {s.error = .Schema; return false}
	statement: sql.Statement
	query: cstring = found ? "UPDATE replay_p2p_provision SET value=?2 WHERE room=?1;" : "INSERT INTO replay_p2p_provision(room,value) VALUES(?1,?2);"
	if sql.sqlite3_prepare_v2(s.connection.db, query, -1, &statement, nil) != 0 {s.error = .Write; return false}
	key := room_key(next.enrollment.record.room)
	ok := sql.sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) == 0 &&
	      sql.sqlite3_bind_blob(statement, 2, raw_data(s.buffer), i32(len(s.buffer)), nil) == 0 && sql.sqlite3_step(statement) == 101
	sql.sqlite3_finalize(statement)
	if !ok || !execute(s, "COMMIT;") {s.error = .Write; return false}
	committed, s.error = true, .None
	return true
}

@(private)
execute :: proc(s: ^Store, query: cstring) -> bool {return sql.sqlite3_exec(s.connection.db, query, nil, nil, nil) == 0}
@(private)
room_key :: proc(room: u64) -> [8]u8 {key: [8]u8; for i in 0 ..< 8 {key[i] = u8(room >> uint(8 * i))}; return key}
