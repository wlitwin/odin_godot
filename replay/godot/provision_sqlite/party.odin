#+build darwin, linux
package replay_godot_provision_sqlite

import "core:strings"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"

Party_Store :: struct {
    store:             db.Client_Store,
    path:              string,
    content:           u64,
    local_development: bool,
}

party_store_open :: proc(
    s: ^Party_Store,
    path: string,
    content: u64,
    create: bool = false,
    local_development: bool = false,
) -> bool {
    if s.path != "" {
        return false
    }

    if db.client_open(&s.store, path, "cursor", content, create, local_development) != .None {
        return false
    }

    s.path, s.content, s.local_development = strings.clone(path), content, local_development
    return true
}

party_store_close :: proc(s: ^Party_Store) {
    db.client_close(&s.store)
    delete(s.path)
    s^ = {}
}

party_storage :: proc(s: ^Party_Store) -> rgd.Party_Storage {
    return {s, party_slot, party_recent, party_select}
}

@(private)
party_slot :: proc(user: rawptr, slot: string) -> (rgd.Enrollment_Backing, bool) {
    s := cast(^Party_Store)user
    db.client_close(&s.store)

    if db.client_open(&s.store, s.path, slot, s.content, false, s.local_development) != .None {
        return {}, false
    }

    return backing(&s.store), true
}

@(private)
party_recent :: proc(user: rawptr, key: string) -> (u64, u64, rgd.Party_Error) {
    s := cast(^Party_Store)user
    room, revision, error := db.cursor_load(&s.store, key)
    return room, revision, error == .None ? .None : .Storage
}

@(private)
party_select :: proc(user: rawptr, key: string, room, expected: u64) -> rgd.Party_Error {
    error := db.cursor_commit(&(cast(^Party_Store)user).store, key, room, expected)
    return error == .None ? .None : error == .Conflict ? .Conflict : .Storage
}
