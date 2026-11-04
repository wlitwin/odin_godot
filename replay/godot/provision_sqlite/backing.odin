#+build darwin, linux
package replay_godot_provision_sqlite

import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"

// Borrows an open, slot/content-scoped Client_Store. Close the profile first.
backing :: proc(store: ^db.Client_Store) -> rgd.Enrollment_Backing {
    return {store, load, commit}
}

@(private)
load :: proc(user: rawptr) -> (p.Enrollment_Record, bool, p.Enrollment_Error) {
    s := cast(^db.Client_Store)user
    record, found, error := db.client_load(s)
    return record, found, convert(error)
}

@(private)
commit :: proc(user: rawptr, expected: u64, next: p.Enrollment_Record) -> (u64, p.Enrollment_Error) {
    error := db.client_commit(cast(^db.Client_Store)user, expected, next)
    return error == .None ? next.revision : 0, convert(error)
}

@(private)
convert :: proc(error: db.Error) -> p.Enrollment_Error {
    if error == .None {
        return .None
    }

    if error == .Conflict {
        return .Conflict
    }

    if error == .Read || error == .Schema {
        return .Corrupt
    }

    return .Store
}
