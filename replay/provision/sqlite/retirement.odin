#+build darwin, linux
package replay_provision_sqlite

import "core:crypto"
import p "godot:replay/provision"
import sql "godot:replay/authority/sqlite"

// Archived IDs remain reserved, so stale recent-room credentials and short
// invitations can never refer to a newly created room with the same ID.
creation_guard :: proc(user: rawptr, room: u64) -> p.Error {
    s := cast(^Store)user
    if !s.ready || room == 0 {return .Storage}
    statement: sql.Statement
    if sql.sqlite3_prepare_v2(s.connection.db, "SELECT 1 FROM replay_provision_archive WHERE room=?1;", -1, &statement, nil) != 0 {return .Storage}
    defer sql.sqlite3_finalize(statement)
    key := room_key(room)
    if sql.sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) != 0 {return .Storage}
    result := sql.sqlite3_step(statement)
    if result == 100 {return .Denied}
    return result == 101 ? .None : .Storage
}

// Preserve the exact private canonical bundle while removing it from the
// resident inventory, in one FULL/WAL transaction. No credentials are logged.
archive :: proc(user: rawptr, expected: p.Bundle) -> bool {
    s := cast(^Store)user
    if !s.ready || s.connection.transaction || !p.bundle_valid(expected) {return false}
    if !execute(s, "BEGIN IMMEDIATE;") {s.error = .Write; return false}
    s.connection.transaction = true
    committed := false
    defer {
        if !committed {execute(s, "ROLLBACK;")}
        s.connection.transaction = false
        crypto.zero_explicit(raw_data(s.buffer), len(s.buffer))
    }
    current, found, error := load(s, expected.record.room, expected.record.content)
    defer crypto.zero_explicit(&current, size_of(current))
    if error != .None || !found || current != expected {s.error = .Conflict; return false}
    key := room_key(expected.record.room)
    for query in ([2]cstring{
        "INSERT INTO replay_provision_archive(room,value) SELECT room,value FROM replay_provision WHERE room=?1;",
        "DELETE FROM replay_provision WHERE room=?1;",
    }) {
        statement: sql.Statement
        if sql.sqlite3_prepare_v2(s.connection.db, query, -1, &statement, nil) != 0 {s.error = .Write; return false}
        ok := sql.sqlite3_bind_blob(statement, 1, raw_data(key[:]), 8, nil) == 0 && sql.sqlite3_step(statement) == 101
        sql.sqlite3_finalize(statement)
        if !ok {s.error = .Write; return false}
    }
    absent, still_present, verification := load(s, expected.record.room, expected.record.content)
    defer crypto.zero_explicit(&absent, size_of(absent))
    if verification != .None || still_present || creation_guard(s, expected.record.room) != .Denied {s.error = .Write; return false}
    if !execute(s, "COMMIT;") {s.error = .Write; return false}
    committed, s.error = true, .None
    return true
}
