package replay_provision_sqlite_test
import "core:testing"
import "core:fmt"
import "core:slice"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import r "godot:replay"
import f "publication_fixture"

@(test)
publication_advances_atomically_and_rejects_old_sequences_and_typed_contracts :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/publication-advance.sqlite3", DIRECTORY)
    defer delete(path)
    x: f.Fixture
    f.open(&x, path)
    defer f.close(&x)
    first, bytes := f.checkpoint(&x, 1)
    defer delete(bytes)
    _, error := db.checkpoint_publish(&x.store, x.room.bundle.record, 0, first, bytes, f.model())
    testing.expect_value(t, error, db.Error.None)
    second, next := f.checkpoint(&x, 2)
    defer delete(next)
    publication, advanced := db.checkpoint_publish(&x.store, x.room.bundle.record, 1, second, next, f.model())
    testing.expect(t, advanced == .None && publication.revision == 2 && publication.point == second)
    stale := second
    stale.archive.sequence = 1
    _, older := db.checkpoint_publish(&x.store, x.room.bundle.record, 2, stale, next, f.model())
    testing.expect_value(t, older, db.Error.Conflict)
    stale = first
    stale.archive.sequence = 3
    _, rewound := db.checkpoint_publish(&x.store, x.room.bundle.record, 2, stale, bytes, f.model())
    testing.expect_value(t, rewound, db.Error.Conflict)
    wrong_model := f.model()
    wrong_model.action_schedule = {
        id = 7,
        timing = proc(_: u8) -> net.Action_Timing {
            return .Receipt
        },
    }
    bad, exists, invalid := db.checkpoint_load(&x.store, 44, 55, wrong_model)
    defer db.stored_checkpoint_destroy(&bad)
    testing.expect(t, !exists && invalid == .Schema && !bad.ready)
    stored, found, loaded := db.checkpoint_load(&x.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&stored)
    testing.expect(t, found && loaded == .None && stored.publication == publication && slice.equal(stored.bytes, next))
}

@(test)
checkpoint_publication_reopens_with_owned_bytes_and_does_not_grant_authority :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/publication-reopen.sqlite3", DIRECTORY)
    defer delete(path)
    x: f.Fixture
    f.open(&x, path)
    defer f.close(&x)
    point, bytes := f.checkpoint(&x, 1)
    defer delete(bytes)
    before := x.room.bundle.record
    publication, error := db.checkpoint_publish(&x.store, before, 0, point, bytes, f.model())
    testing.expect(
        t,
        error == .None &&
        publication.revision == 1 &&
        publication.source_revision == before.revision &&
        publication.point == point,
    )
    testing.expect_value(t, x.room.bundle.record, before)
    retry, replayed := db.checkpoint_publish(&x.store, before, 0, point, bytes, f.model())
    testing.expect(t, replayed == .None && retry == publication && !x.store.connection.transaction)
    stored, found, loaded := db.checkpoint_load(&x.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&stored)
    testing.expect(t, loaded == .None && found && stored.ready && slice.equal(stored.bytes, bytes))
    p.close(&x.room)
    db.close(&x.store)
    testing.expect_value(t, db.open(&x.store, path), db.Error.None)
    copy, exists, result := db.checkpoint_load(&x.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&copy)
    testing.expect(t, result == .None && exists && copy.publication == publication && slice.equal(copy.bytes, bytes))
    cp: net.Checkpoint(f.World, u8, u8, 1)
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_decode(&cp, copy.bytes, f.model(), 55), net.Error.None)
    testing.expect(t, cp.frame.state.value == 8 && cp.settings.require_permit)
}

@(test)
publication_compare_exchange_and_coordinator_revision_fence_stale_writers :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/publication-cas.sqlite3", DIRECTORY)
    defer delete(path)
    x: f.Fixture
    f.open(&x, path)
    defer f.close(&x)
    first, bytes := f.checkpoint(&x, 1)
    defer delete(bytes)
    expected := x.room.bundle.record
    _, error := db.checkpoint_publish(&x.store, expected, 0, first, bytes, f.model())
    testing.expect_value(t, error, db.Error.None)
    second, next := f.checkpoint(&x, 2)
    defer delete(next)
    _, conflict := db.checkpoint_publish(&x.store, expected, 0, second, next, f.model())
    testing.expect_value(t, conflict, db.Error.Conflict)
    other: db.Store
    defer db.close(&other)
    testing.expect_value(t, db.open(&other, path), db.Error.None)
    b, found, loaded := db.load(&other, 44, 55)
    testing.expect(t, found && loaded == .None)
    restarted: p.Room
    defer p.close(&restarted)
    testing.expect_value(t, p.open(&restarted, b, db.commit, &other, {read = f.clock}), p.Error.None)
    _, stale := db.checkpoint_publish(&x.store, expected, 1, second, next, f.model())
    testing.expect_value(t, stale, db.Error.Conflict)
    old_retry, replayed := db.checkpoint_publish(&x.store, expected, 0, first, bytes, f.model())
    testing.expect(t, replayed == .None && old_retry.revision == 1)
    stored, exists, result := db.checkpoint_load(&other, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&stored)
    testing.expect(t, exists && result == .None && stored.publication.point == first)
}

@(test)
invalid_owner_scope_hash_and_readonly_storage_preserve_publication :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/publication-invalid.sqlite3", DIRECTORY)
    defer delete(path)
    x: f.Fixture
    f.open(&x, path)
    defer f.close(&x)
    point, bytes := f.checkpoint(&x, 1)
    defer delete(bytes)
    _, error := db.checkpoint_publish(&x.store, x.room.bundle.record, 0, point, bytes, f.model())
    testing.expect_value(t, error, db.Error.None)

    for kind in 0 ..< 3 {
        bad := point

        switch kind {
        case 0:
            bad.scope.room += 1
        case 1:
            bad.archive.hash[0] ~= 1
        case 2:
            bad.scope.epoch += 1
        }

        _, invalid := db.checkpoint_publish(&x.store, x.room.bundle.record, 1, bad, bytes, f.model())
        testing.expect_value(t, invalid, db.Error.Invalid)
    }

    wrong_owner, bad_bytes := f.checkpoint(&x, 2, true)
    defer delete(bad_bytes)
    _, identity := db.checkpoint_publish(&x.store, x.room.bundle.record, 1, wrong_owner, bad_bytes, f.model())
    testing.expect_value(t, identity, db.Error.Invalid)
    second, next := f.checkpoint(&x, 2)
    defer delete(next)
    testing.expect_value(t, sql.sqlite3_exec(x.store.connection.db, "PRAGMA query_only=ON;", nil, nil, nil), i32(0))
    _, readonly := db.checkpoint_publish(&x.store, x.room.bundle.record, 1, second, next, f.model())
    testing.expect_value(t, readonly, db.Error.Write)
    stored, found, loaded := db.checkpoint_load(&x.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&stored)
    testing.expect(t, found && loaded == .None && stored.publication.point == point)
}

@(test)
stored_corruption_is_not_published_to_the_caller_and_prior_owned_copy_survives :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/publication-corrupt.sqlite3", DIRECTORY)
    defer delete(path)
    x: f.Fixture
    f.open(&x, path)
    defer f.close(&x)
    point, bytes := f.checkpoint(&x, 1)
    defer delete(bytes)
    _, error := db.checkpoint_publish(&x.store, x.room.bundle.record, 0, point, bytes, f.model())
    testing.expect_value(t, error, db.Error.None)
    owned, found, loaded := db.checkpoint_load(&x.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&owned)
    testing.expect(t, found && loaded == .None)
    testing.expect_value(
        t,
        sql.sqlite3_exec(
            x.store.connection.db,
            "UPDATE replay_room_checkpoint SET bytes=zeroblob(52);",
            nil,
            nil,
            nil,
        ),
        i32(0),
    )
    bad, exists, corrupt := db.publication_load(&x.store, 44, 55)
    defer db.stored_checkpoint_destroy(&bad)
    testing.expect(t, !exists && corrupt == .Read && !bad.ready && len(bad.bytes) == 0)
    testing.expect_value(t, rec.hash(owned.bytes), point.archive.hash)
    _, _, wrong := db.publication_load(&x.store, 44, 56)
    testing.expect_value(t, wrong, db.Error.Read)
}
