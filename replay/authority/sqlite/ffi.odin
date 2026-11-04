#+build darwin, linux
package replay_authority_sqlite

// Explicit static archives let strict native SDKs retain the existing dependency
// admission policy. The ordinary dynamic default remains unchanged.
SQLITE_LIBRARY :: #config(REPLAY_SQLITE_LIBRARY, "system:sqlite3")
SQLITE_LINK_LIBRARY :: "system:"+SQLITE_LIBRARY when len(SQLITE_LIBRARY)>0&&SQLITE_LIBRARY[0]=='/' else SQLITE_LIBRARY
foreign import sqlite {SQLITE_LINK_LIBRARY}
DB :: distinct rawptr
Statement :: distinct rawptr
foreign sqlite {
	sqlite3_open_v2 :: proc "c" (path: cstring, db: ^DB, flags: i32, vfs: cstring) -> i32 ---
	sqlite3_close_v2 :: proc "c" (db: DB) -> i32 ---
	sqlite3_busy_timeout :: proc "c" (db: DB, ms: i32) -> i32 ---
	sqlite3_exec :: proc "c" (db: DB, sql: cstring, callback: rawptr, user: rawptr, error: ^cstring) -> i32 ---
	sqlite3_prepare_v2 :: proc "c" (db: DB, sql: cstring, bytes: i32, statement: ^Statement, tail: ^cstring) -> i32 ---
	sqlite3_finalize :: proc "c" (s: Statement) -> i32 ---
	sqlite3_step :: proc "c" (s: Statement) -> i32 ---
	sqlite3_bind_blob :: proc "c" (s: Statement, index: i32, data: rawptr, bytes: i32, destroy: proc "c" (p: rawptr)) -> i32 ---
	sqlite3_column_blob :: proc "c" (s: Statement, column: i32) -> rawptr ---
	sqlite3_column_bytes :: proc "c" (s: Statement, column: i32) -> i32 ---
	sqlite3_column_text :: proc "c" (s: Statement, column: i32) -> cstring ---
	sqlite3_column_int :: proc "c" (s: Statement, column: i32) -> i32 ---
}
