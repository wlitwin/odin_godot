package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import f "../publication_fixture"
import a "godot:replay/assets"
import ck "godot:replay/provision/checkpoint"

foreign import sqlite "system:sqlite3"

foreign sqlite {
    sqlite3_commit_hook :: proc "c" (connection: sql.DB, callback: proc "c" (_: rawptr) -> i32, user: rawptr) -> rawptr ---
}

stall :: proc "c" (_: rawptr) -> i32 {
    context = runtime.default_context()
    // The real publication UPDATE has run. SQLite has not completed COMMIT.
    // Do not reenter or query this connection from a commit callback.
    fmt.println("REPLAY_PUBLICATION_UNCOMMITTED")

    for {
        time.sleep(100 * time.Millisecond)
    }
}

main :: proc() {
    assert(len(os.args) == 3)
    mode, path := os.args[1], os.args[2]
    cache: a.Cache
    assert(a.cache_init(&cache) == .None)
    defer a.cache_destroy(&cache)
    first, _ := a.cache_put(&cache, transmute([]u8)string("Asset first"))
    second, _ := a.cache_put(&cache, transmute([]u8)string("Asset second"))
    replacement, _ := a.cache_put(&cache, transmute([]u8)string("Asset replacement"))

    if mode == "create" {
        x := new(f.Fixture)
        defer free(x)
        f.open(x, path, {first, second})
        defer f.close(x)
        point, bytes := f.checkpoint(x, 1)
        defer delete(bytes)
        payload, encoded := ck.package_encode(bytes, point, &cache, f.asset_policy())
        assert(encoded == .None)
        defer delete(payload)
        publication, error := db.checkpoint_publish(
            &x.store,
            x.room.bundle.record,
            0,
            point,
            bytes,
            f.model(),
            payload = payload,
            assets = f.asset_policy(),
        )
        assert(error == .None && publication.revision == 1)
        fmt.println("REPLAY_PUBLICATION_CREATED")
        return
    }

    s: db.Store
    assert(db.open(&s, path) == .None)
    defer db.close(&s)
    b, found, loaded := db.load(&s, 44, 55)
    assert(found && loaded == .None)
    stored, exists, error := db.checkpoint_load(&s, 44, 55, f.model(), assets = f.asset_policy())
    assert(exists && error == .None)
    defer db.stored_checkpoint_destroy(&stored)
    cp: net.Checkpoint(f.World, u8, u8, 1)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, stored.bytes, f.model(), 55) == .None)

    if mode == "verify-uncommitted" || mode == "verify-committed" {
        expected := mode == "verify-uncommitted" ? u64(1) : u64(2)
        assert(stored.publication.revision == expected && stored.publication.point.archive.sequence == expected)
        assert(cp.frame.tick == expected && cp.frame.state.value == 7 + u32(expected))
        assert(cp.frame.state.images == ([2]a.Ref{expected == 1 ? first : replacement, second}))
        a.cache_destroy(&cache)
        assert(a.cache_init(&cache) == .None)
        assert(
            ck.package_install(stored.payload, stored.bytes, stored.publication.point, &cache, f.asset_policy()) ==
                .None &&
            cache.count == 2,
        )
        assert(stored.publication.point.archive.hash == rec.hash(stored.bytes))
        assert(stored.publication.source_revision == b.record.revision && b.record.epoch == 1)
        // Restarting the coordinator remains a separate fenced decision. Loading
        // either publication does not activate a lease or advance its epoch.
        room: p.Room
        defer p.close(&room)
        assert(p.open(&room, b, db.commit, &s, {read = f.clock}) == .None)
        assert(room.service.coordinator.restarted && !room.service.coordinator.active && room.bundle.record.epoch == 1)
        fmt.printf(
            "REPLAY_PUBLICATION_CRASH_OK mode=%s publication=%d tick=%d value=%d epoch=%d generation=%d\n",
            mode,
            expected,
            cp.frame.tick,
            cp.frame.state.value,
            room.bundle.record.epoch,
            room.bundle.record.coordinator_generation,
        )
        fmt.printf("REPLAY_ASSET_PUBLICATION_CRASH_OK mode=%s assets=2 replacement=%t\n", mode, expected == 2)
        return
    }

    assert(mode == "uncommitted" || mode == "committed")
    cp.frame.tick += 1
    cp.header.tick = cp.frame.tick
    cp.frame.state.value += 1
    cp.frame.state.images[0] = replacement
    bytes, encoded := net.checkpoint_encode(&cp, f.model())
    assert(encoded == .None)
    defer delete(bytes)
    point := stored.publication.point
    point.archive = {
        sequence = 2,
        tick     = cp.frame.tick,
        bytes    = u32(len(bytes)),
        hash     = rec.hash(bytes),
    }
    payload, packaged := ck.package_encode(bytes, point, &cache, f.asset_policy())
    assert(packaged == .None)
    defer delete(payload)

    if mode == "uncommitted" {
        sqlite3_commit_hook(s.connection.db, stall, nil)
    }

    next, published := db.checkpoint_publish(
        &s,
        b.record,
        1,
        point,
        bytes,
        f.model(),
        payload = payload,
        assets = f.asset_policy(),
    )
    assert(published == .None && next.revision == 2)
    fmt.println("REPLAY_PUBLICATION_COMMITTED")

    for {
        time.sleep(100 * time.Millisecond)
    }
}
