#+build darwin, linux
package replay_authority_sqlite

import "core:mem"
import "core:strings"
import auth "godot:replay/authority"
import sc "godot:replay/schema"

Error :: enum {None, Invalid, Open, Configuration, Schema, Read, Conflict, Write}
Store :: struct {
	allocator: mem.Allocator,
	db: DB,
	ready, transaction: bool,
	codec: sc.Schema,
	buffer: []u8,
	error: Error,
	sqlite_error: i32,
}

// Native local-file store. Creation must be explicit; a missing production file
// is not silently recreated with an empty epoch floor. This owner is not copyable.
open :: proc(s: ^Store, path: string, create: bool = false, busy_ms: u32 = 100, allocator := context.allocator) -> Error {
	if s.ready || s.db != nil || len(path) == 0 || len(path) > 4096 || path == ":memory:" || busy_ms > 1000 {return .Invalid}
	for b in path {if b == 0 {return .Invalid}}
	s.allocator = allocator
	name := strings.clone_to_cstring(path, allocator); defer delete(name, allocator)
	s.sqlite_error = sqlite3_open_v2(name, &s.db, 2 | 0x10000 | (create ? 4 : 0), nil)
	if s.sqlite_error != 0 {close(s); return .Open}
	if sqlite3_busy_timeout(s.db, i32(busy_ms)) != 0 ||
	   !execute(s, "PRAGMA journal_mode=WAL;") || !pragma_text(s, "PRAGMA journal_mode;", "wal") ||
	   !execute(s, "PRAGMA synchronous=FULL;") || !pragma_int(s, "PRAGMA synchronous;", 2) ||
	   !execute(s, "PRAGMA fullfsync=ON;") || !pragma_int(s, "PRAGMA fullfsync;", 1) ||
	   !execute(s, "PRAGMA checkpoint_fullfsync=ON;") {close(s); return .Configuration}
	if !execute(s, "CREATE TABLE IF NOT EXISTS replay_authority(room BLOB PRIMARY KEY NOT NULL, value BLOB NOT NULL);") {close(s); return .Schema}
	if sc.init(&s.codec, auth.Record, allocator = allocator).error != .None {close(s); return .Schema}
	s.buffer = make([]u8, sc.HEADER_BYTES + s.codec.wire_size, allocator)
	s.ready = true
	return .None
}

close :: proc(s: ^Store) {
	if s.db != nil {
		if s.transaction {execute(s, "ROLLBACK;")}
		sqlite3_close_v2(s.db)
	}
	sc.destroy(&s.codec)
	delete(s.buffer, s.allocator)
	s^ = {}
}

load :: proc(s: ^Store, room, content: u64) -> (record: auth.Record, found: bool, error: Error) {
	if !s.ready || room == 0 || content == 0 {return {}, false, .Invalid}
	statement: Statement
	if sqlite3_prepare_v2(s.db, "SELECT value FROM replay_authority WHERE room=?1;", -1, &statement, nil) != 0 {return {}, false, .Read}
	defer sqlite3_finalize(statement)
	key := room_key(room)
	if sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) != 0 {return {}, false, .Read}
	result := sqlite3_step(statement)
	if result == 101 {return {}, false, .None}
	if result != 100 {return {}, false, .Read}
	count := sqlite3_column_bytes(statement, 0)
	ptr := sqlite3_column_blob(statement, 0)
	if count != i32(len(s.buffer)) || ptr == nil {return {}, false, .Read}
	bytes := (cast([^]u8)ptr)[:count]
	meta, report := sc.unpack(&s.codec, &record, bytes, {kind = 0x4152, epoch = 1, content = content})
	if report.error != .None || !auth.record_valid(record) || record.room != room || meta.tick != record.revision {return {}, false, .Read}
	if sqlite3_step(statement) != 101 {return {}, false, .Read}
	return record, true, .None
}

// Implements authority.Commit. BEGIN IMMEDIATE serializes the read/compare/write
// across processes; FULL WAL sync completes before this returns true. The record
// and its RPC replay frontiers occupy the same canonical blob/transaction.
commit :: proc(user: rawptr, expected: u64, next: auth.Record) -> bool {
	s := cast(^Store)user
	if !s.ready || s.transaction || expected == max(u64) || next.revision != expected + 1 || !auth.record_valid(next) {s.error = .Invalid; return false}
	if !execute(s, "BEGIN IMMEDIATE;") {s.error = .Write; return false}
	s.transaction = true
	committed := false
	defer {
		if !committed {execute(s, "ROLLBACK;")}
		s.transaction = false
	}
	current, found, err := load(s, next.room, next.content)
	if err != .None {s.error = err; return false}
	if (found && (current.revision != expected || next.epoch < current.epoch || next.coordinator_generation < current.coordinator_generation)) ||
	   (!found && (expected != 0 || next.epoch != 0 || next.coordinator_generation != 1)) {s.error = .Conflict; return false}
	if sc.pack(&s.codec, next, {kind = 0x4152, epoch = 1, tick = next.revision, content = next.content}, s.buffer).error != .None {s.error = .Schema; return false}
	statement: Statement
	sql: cstring = found ? "UPDATE replay_authority SET value=?2 WHERE room=?1;" : "INSERT INTO replay_authority(room,value) VALUES(?1,?2);"
	if sqlite3_prepare_v2(s.db, sql, -1, &statement, nil) != 0 {s.error = .Write; return false}
	key := room_key(next.room)
	ok := sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) == 0 &&
	      sqlite3_bind_blob(statement, 2, raw_data(s.buffer), i32(len(s.buffer)), nil) == 0 && sqlite3_step(statement) == 101
	sqlite3_finalize(statement)
	if !ok || !execute(s, "COMMIT;") {s.error = .Write; return false}
	committed, s.error = true, .None
	return true
}

@(private)
execute :: proc(s: ^Store, sql: cstring) -> bool {s.sqlite_error = sqlite3_exec(s.db, sql, nil, nil, nil); return s.sqlite_error == 0}
@(private)
room_key :: proc(room: u64) -> [8]u8 {key: [8]u8; for i in 0 ..< 8 {key[i] = u8(room >> uint(8 * i))}; return key}
@(private)
pragma_int :: proc(s: ^Store, sql: cstring, expected: i32) -> bool {
	statement: Statement
	if sqlite3_prepare_v2(s.db, sql, -1, &statement, nil) != 0 {return false}
	defer sqlite3_finalize(statement)
	return sqlite3_step(statement) == 100 && sqlite3_column_int(statement, 0) == expected
}
@(private)
pragma_text :: proc(s: ^Store, sql: cstring, expected: string) -> bool {
	statement: Statement
	if sqlite3_prepare_v2(s.db, sql, -1, &statement, nil) != 0 {return false}
	defer sqlite3_finalize(statement)
	return sqlite3_step(statement) == 100 && string(sqlite3_column_text(statement, 0)) == expected
}
