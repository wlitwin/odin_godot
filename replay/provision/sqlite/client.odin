#+build darwin, linux
package replay_provision_sqlite

import "core:crypto"
import "core:mem"
import "core:strings"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import sc "godot:replay/schema"

// Optional native client database. Own it separately from the server's private
// room database. This reuses its checked private-file/WAL/FULL connection setup.
Client_Store :: struct {
	storage: Store,
	codec: sc.Schema,
	buffer: [p.ENROLLMENT_BYTES]u8,
	slot: string,
	content: u64,
	allocator: mem.Allocator,
	ready, local_development: bool,
	error: Error,
}
client_open :: proc(s: ^Client_Store, path, slot: string, content: u64, create: bool = false, local_development: bool = false, allocator := context.allocator) -> Error {
	if s.ready || s.storage.ready || content == 0 || len(slot) < 1 || len(slot) > 128 {return .Invalid}
	for b in slot {if !((b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || (b >= '0' && b <= '9') || b == '_' || b == '-' || b == '.' || b == '/') {return .Invalid}}
	s.allocator = allocator
	if err := open(&s.storage, path, create, allocator = allocator); err != .None {return err}
	if sql.sqlite3_exec(s.storage.connection.db, "CREATE TABLE IF NOT EXISTS replay_client_enrollment(slot BLOB PRIMARY KEY NOT NULL, value BLOB NOT NULL);", nil, nil, nil) != 0 ||
	   !p.enrollment_codec_init(&s.codec, allocator) {client_close(s); return .Schema}
	s.slot, s.content, s.local_development, s.ready = strings.clone(slot, allocator), content, local_development, true
	return .None
}
client_close :: proc(s: ^Client_Store) {
	delete(s.slot, s.allocator); sc.destroy(&s.codec); close(&s.storage)
	crypto.zero_explicit(s, size_of(Client_Store))
}
client_load :: proc(s: ^Client_Store) -> (record: p.Enrollment_Record, found: bool, error: Error) {
	if !s.ready {return {}, false, .Invalid}
	statement: sql.Statement
	if sql.sqlite3_prepare_v2(s.storage.connection.db, "SELECT value FROM replay_client_enrollment WHERE slot=?1;", -1, &statement, nil) != 0 {return {}, false, .Read}
	defer sql.sqlite3_finalize(statement)
	if sql.sqlite3_bind_blob(statement, 1, raw_data(s.slot), i32(len(s.slot)), nil) != 0 {return {}, false, .Read}
	result := sql.sqlite3_step(statement)
	if result == 101 {return {}, false, .None}
	if result != 100 {return {}, false, .Read}
	count := sql.sqlite3_column_bytes(statement, 0); ptr := sql.sqlite3_column_blob(statement, 0)
	if count != i32(sc.HEADER_BYTES + s.codec.wire_size) || ptr == nil {return {}, false, .Read}
	r, ok := p.enrollment_decode(&s.codec, (cast([^]u8)ptr)[:count], s.content, s.local_development)
	if !ok || sql.sqlite3_step(statement) != 101 {return {}, false, .Read}
	return r, true, .None
}
client_commit :: proc(s: ^Client_Store, expected: u64, next: p.Enrollment_Record) -> Error {
	if !s.ready || s.storage.connection.transaction || next.request.content != s.content {return .Invalid}
	if sql.sqlite3_exec(s.storage.connection.db, "BEGIN IMMEDIATE;", nil, nil, nil) != 0 {return .Write}
	s.storage.connection.transaction = true
	committed := false
	defer {
		if !committed {sql.sqlite3_exec(s.storage.connection.db, "ROLLBACK;", nil, nil, nil)}
		s.storage.connection.transaction = false
		crypto.zero_explicit(&s.buffer, size_of(s.buffer))
	}
	previous, found, err := client_load(s)
	defer crypto.zero_explicit(&previous, size_of(previous))
	if err != .None {return err}
	if !p.enrollment_transition(previous, found, expected, next, s.local_development) {return .Conflict}
	count := p.enrollment_encode(&s.codec, next, s.buffer[:], s.local_development)
	if count == 0 {return .Schema}
	statement: sql.Statement
	query: cstring = found ? "UPDATE replay_client_enrollment SET value=?2 WHERE slot=?1;" : "INSERT INTO replay_client_enrollment(slot,value) VALUES(?1,?2);"
	if sql.sqlite3_prepare_v2(s.storage.connection.db, query, -1, &statement, nil) != 0 {return .Write}
	ok := sql.sqlite3_bind_blob(statement, 1, raw_data(s.slot), i32(len(s.slot)), nil) == 0 &&
	      sql.sqlite3_bind_blob(statement, 2, raw_data(s.buffer[:]), i32(count), nil) == 0 && sql.sqlite3_step(statement) == 101
	sql.sqlite3_finalize(statement)
	if !ok || sql.sqlite3_exec(s.storage.connection.db, "COMMIT;", nil, nil, nil) != 0 {return .Write}
	committed = true; return .None
}
