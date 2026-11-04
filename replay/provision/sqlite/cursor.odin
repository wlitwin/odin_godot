#+build darwin, linux
package replay_provision_sqlite

import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"

// Small mutable navigation reference, separate from immutable credentials.
// The caller chooses a key scoped to the exact service/content.
cursor_load :: proc(s: ^Client_Store, key: string) -> (room, revision: u64, error: Error) {
    if !s.ready || len(key) < 1 || len(key) > 128 {
        return 0, 0, .Invalid
    }

    if sql.sqlite3_exec(
           s.storage.connection.db,
           "CREATE TABLE IF NOT EXISTS replay_client_cursor(key BLOB PRIMARY KEY NOT NULL,value BLOB NOT NULL);",
           nil,
           nil,
           nil,
       ) !=
       0 {
        return 0, 0, .Schema
    }

    statement: sql.Statement

    if sql.sqlite3_prepare_v2(
           s.storage.connection.db,
           "SELECT value FROM replay_client_cursor WHERE key=?1;",
           -1,
           &statement,
           nil,
       ) !=
       0 {
        return 0, 0, .Read
    }

    defer sql.sqlite3_finalize(statement)

    if sql.sqlite3_bind_blob(statement, 1, raw_data(key), i32(len(key)), nil) != 0 {
        return 0, 0, .Read
    }

    result := sql.sqlite3_step(statement)

    if result == 101 {
        return 0, 0, .None
    }

    if result != 100 || sql.sqlite3_column_bytes(statement, 0) != 16 {
        return 0, 0, .Read
    }

    ptr := sql.sqlite3_column_blob(statement, 0)

    if ptr == nil {
        return 0, 0, .Read
    }

    bytes := (cast([^]u8)ptr)[:16]

    for i in 0 ..< 8 {
        room |= u64(bytes[i]) << uint(8 * i)
        revision |= u64(bytes[8 + i]) << uint(8 * i)
    }

    if room == 0 || revision == 0 || revision >= p.ENROLLMENT_REVISION_MAX || sql.sqlite3_step(statement) != 101 {
        return 0, 0, .Read
    }

    return room, revision, .None
}

cursor_commit :: proc(s: ^Client_Store, key: string, room, expected: u64) -> Error {
    if !s.ready || room == 0 || expected >= p.ENROLLMENT_REVISION_MAX - 1 || s.storage.connection.transaction {
        return .Invalid
    }

    if sql.sqlite3_exec(s.storage.connection.db, "BEGIN IMMEDIATE;", nil, nil, nil) != 0 {
        return .Write
    }

    s.storage.connection.transaction = true
    committed := false

    defer {
        if !committed {
            sql.sqlite3_exec(s.storage.connection.db, "ROLLBACK;", nil, nil, nil)
        }

        s.storage.connection.transaction = false
    }

    _, revision, err := cursor_load(s, key)

    if err != .None {
        return err
    }

    if revision != expected {
        return .Conflict
    }

    bytes: [16]u8

    for i in 0 ..< 8 {
        bytes[i] = u8(room >> uint(8 * i))
        bytes[8 + i] = u8((expected + 1) >> uint(8 * i))
    }

    statement: sql.Statement
    query: cstring =
        revision == 0 ? "INSERT INTO replay_client_cursor(key,value) VALUES(?1,?2);" : "UPDATE replay_client_cursor SET value=?2 WHERE key=?1;"

    if sql.sqlite3_prepare_v2(s.storage.connection.db, query, -1, &statement, nil) != 0 {
        return .Write
    }

    ok :=
        sql.sqlite3_bind_blob(statement, 1, raw_data(key), i32(len(key)), nil) == 0 &&
        sql.sqlite3_bind_blob(statement, 2, raw_data(bytes[:]), 16, nil) == 0 &&
        sql.sqlite3_step(statement) == 101
    sql.sqlite3_finalize(statement)

    if !ok || sql.sqlite3_exec(s.storage.connection.db, "COMMIT;", nil, nil, nil) != 0 {
        return .Write
    }

    committed = true
    return .None
}
