//gd:extends Node
//gd:class ReplayRoomService
package replay_room_service

import "core:fmt"
import "core:crypto"
import "core:os"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import rel "godot:replay/relay"
import sc "godot:replay/schema"
import ck "godot:replay/provision/checkpoint"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import pitch "godot:examples/replay_speedball/shared/pitch"
import slopball "godot:examples/replay_slopball/shared/pitch"
import slopball3d "godot:examples/replay_slopball3d/shared/pitch"
import claimball "godot:examples/replay_claimball/shared/pitch"
import duel "godot:examples/replay_quickdraw/shared/duel"
import scrapyard "godot:examples/replay_scrapyard/shared/game"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

MAX_GAMES :: 16
MAX_SLUG :: 32

// One hosted game build (content ID): its own room set, database, signaling,
// relay credentials and checkpoint endpoints. Games share only the listener.
Game :: struct {
    service:            ^ReplayRoomService,
    slug:               string, // URL path segment that reaches it; "" = any path
    content:            u64,
    loaded:             int,
    checkpoint_name:    string,
    store:              db.Store,
    hub:                p.Hub,
    signal:             rgd.Rendezvous_Hub,
    relay:              rel.Server,
    checkpoints:        ck.Hub,
    cave_backend:       db.Checkpoint_Backend(cave.World, cave.Control, cave.Action, cave.Event, cave.SEATS),
    cave_owned_backend: db.Checkpoint_Backend(
        cave_owned.World,
        cave_owned.Control,
        cave_owned.Action,
        cave_owned.Event,
        cave_owned.SEATS,
    ),
    duel_backend:       db.Checkpoint_Backend(duel.World, duel.Controls, duel.Action, duel.Event, duel.SEATS),
    slopball3d_backend: db.Checkpoint_Backend(
        slopball3d.World,
        slopball3d.Control,
        slopball3d.Action,
        slopball3d.Event,
        slopball3d.SEATS,
    ),
    slopball_backend:   db.Checkpoint_Backend(
        slopball.World,
        slopball.Control,
        slopball.Action,
        slopball.Event,
        slopball.SEATS,
    ),
    claimball_backend:  db.Checkpoint_Backend(
        claimball.World,
        claimball.Controls,
        claimball.Action,
        claimball.Event,
        claimball.SEATS,
    ),
    pitch_backend:      db.Checkpoint_Backend(pitch.World, pitch.Controls, pitch.Action, pitch.Event, pitch.SEATS),
    scrapyard_backend:  db.Checkpoint_Backend(
        scrapyard.World,
        scrapyard.Control,
        scrapyard.Action,
        scrapyard.Event,
        scrapyard.SEATS,
    ),
}

ReplayRoomService :: struct {
    owner:           gd.Node,
    ready:           bool,
    // REPLAY_ROOM_GAMES mode: every connection must arrive on a configured
    // slug's path and may only reach that slug's games.
    routed:          bool,
    reclaim_idle_ms: u64,
    games:           [dynamic]^Game,
    socket:          transportgd.Websocket,
    wire:            tr.Transport,
    tls:             gd.Tls_Options,
}

parse_content :: proc(text: string) -> (u64, bool) {
    text := text
    base := u64(10)

    if len(text) > 2 && text[:2] == "0x" {
        base = 16
        text = text[2:]
    }

    if len(text) == 0 || len(text) > 20 {
        return 0, false
    }

    value := u64(0)

    for b in text {
        digit := u64(99)

        if b >= '0' && b <= '9' {
            digit = u64(b - '0')
        } else if b >= 'a' && b <= 'f' {
            digit = u64(b - 'a' + 10)
        } else if b >= 'A' && b <= 'F' {
            digit = u64(b - 'A' + 10)
        }

        if digit >= base || value > (max(u64) - digit) / base {
            return 0, false
        }

        value = value * base + digit
    }

    return value, value != 0
}

slug_valid :: proc(slug: string) -> bool {
    if len(slug) < 1 || len(slug) > MAX_SLUG {
        return false
    }

    for c in slug {
        if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_') {
            return false
        }
    }

    return true
}

unref :: proc(object: gd.Ref_Counted) {
    if object != nil && gd.ref_counted_unreference(object) {
        gdext.object_destroy(object)
    }
}

// REPLAY_ROOM_GAMES="dockyard=0xd290...,0x58a4...;golf=0x5530..." hosts several
// games: each slug is the last segment of the WebSocket path a gateway forwards
// (/replay-room/golf), and lists the content IDs (game builds) it admits.
// Listing several IDs keeps an older build's rooms reachable after an update.
parse_games :: proc(self: ^ReplayRoomService, text: string) -> bool {
    for entry in strings.split(text, ";", context.temp_allocator) {
        entry := strings.trim_space(entry)

        if entry == "" {
            continue
        }

        parts := strings.split_n(entry, "=", 2, context.temp_allocator)

        if len(parts) != 2 || !slug_valid(strings.trim_space(parts[0])) {
            return false
        }

        slug := strings.trim_space(parts[0])

        for game in self.games {
            if game.slug == slug {
                return false // one entry per slug
            }
        }

        ids := 0

        for id in strings.split(parts[1], ",", context.temp_allocator) {
            content, valid := parse_content(strings.trim_space(id))

            if !valid || len(self.games) >= MAX_GAMES {
                return false
            }

            for game in self.games {
                if game.content == content {
                    return false // a build belongs to one slug
                }
            }

            game := new(Game)
            game.service = self
            game.slug = strings.clone(slug)
            game.content = content
            append(&self.games, game)
            ids += 1
        }

        if ids == 0 {
            return false
        }
    }

    return len(self.games) > 0
}

replay_room_service_ready :: proc(self: ^ReplayRoomService) {
    games_text := gd.env_string("REPLAY_ROOM_GAMES", "")
    content_text := gd.env_string("REPLAY_ROOM_CONTENT", "")
    port, rooms := gd.env_int("REPLAY_ROOM_PORT", 49740), gd.env_int("REPLAY_ROOM_CAPACITY", 16)
    mode := gd.env_string("REPLAY_ROOM_MODE", "cooperative")
    required_model := gd.env_string("REPLAY_ROOM_CHECKPOINT_MODEL", "")
    reclaim_idle := gd.env_int("REPLAY_ROOM_RECLAIM_IDLE_MS", 0)

    if reclaim_idle < 0 ||
       reclaim_idle > 86400000 ||
       (reclaim_idle != 0 && reclaim_idle < 1000) ||
       (reclaim_idle != 0 && (mode != "cooperative" || required_model != "disabled")) {
        fail(self, "reclamation requires cooperative checkpoint-disabled mode and an idle interval of1000..86400000ms")
        return
    }

    self.reclaim_idle_ms = u64(reclaim_idle)
    bind := gd.env_string("REPLAY_ROOM_BIND", "127.0.0.1")
    database := gd.env_string("REPLAY_ROOM_DB", "")

    if games_text != "" {
        // A named checkpoint model selects one game's validation code, so it
        // only makes sense with a single content ID.
        if content_text != "" ||
           !parse_games(self, games_text) ||
           (required_model != "" && required_model != "disabled") {
            fail(
                self,
                "invalid REPLAY_ROOM_GAMES (slug=id[,id...];...), or combined with REPLAY_ROOM_CONTENT or a checkpoint model",
            )
            return
        }

        self.routed = true
    } else {
        content, valid := parse_content(content_text)

        if !valid {
            fail(self, "invalid content/port/capacity/mode")
            return
        }

        game := new(Game)
        game.service = self
        game.content = content
        append(&self.games, game)
    }

    if port < 1 || port > 65535 || rooms < 1 || rooms > p.MAX_ROOMS || (mode != "cooperative" && mode != "dedicated") {
        fail(self, "invalid content/port/capacity/mode")
        return
    }

    for game in self.games {
        if _, ok := checkpoint_model(game.content, required_model); !ok {
            fail(self, "checkpoint model does not match deployment content")
            return
        }
    }

    cert_path, key_path := gd.env_string("REPLAY_ROOM_CERT", ""), gd.env_string("REPLAY_ROOM_KEY", "")
    local := gd.env_int("REPLAY_ROOM_LOCAL_DEVELOPMENT", 0) == 1

    if cert_path == "" && key_path == "" && local && (bind == "127.0.0.1" || bind == "::1") {
        // Explicit loopback-only development transport.
    } else {
        if cert_path == "" || key_path == "" {
            fail(self, "TLS certificate and key required")
            return
        }

        cert := gd.new_x509_certificate()
        gd.ref_counted_init_ref(cert)
        defer unref(cert)
        key := gd.new_crypto_key()
        gd.ref_counted_init_ref(key)
        defer unref(key)
        cp, kp := gd.new_string_odin(cert_path), gd.new_string_odin(key_path)
        defer gd.free_string(cp)
        defer gd.free_string(kp)

        if gd.x509_certificate_load(cert, cp) != .Ok || gd.crypto_key_load(key, kp, false) != .Ok {
            fail(self, "TLS material could not be loaded")
            return
        }

        self.tls = gd.tls_options_server(key, cert)
    }

    if !transportgd.websocket_host(&self.socket, u16(port), bind, cfg = {128, 64, 256 * 1024, 10000}, tls = self.tls) {
        fail(self, "listen failed")
        return
    }

    self.wire = transportgd.websocket_transport(&self.socket)

    for game in self.games {
        if !open_store(self, game, database) {
            return
        }

        existing: [p.MAX_ROOMS]p.Bundle
        defer crypto.zero_explicit(&existing, size_of(existing))
        count, err := db.load_all(&game.store, game.content, existing[:int(rooms)])

        if err != .None {
            fail(self, "room inventory invalid or exceeds capacity")
            return
        }

        game.loaded = count
        cfg := p.HUB_CONFIG
        cfg.content, cfg.rooms = game.content, int(rooms)

        if mode == "dedicated" {
            cfg.policy.mode = .Dedicated
        }

        reclaim: p.Reclaim

        if self.reclaim_idle_ms != 0 {
            reclaim = reclaim_room
        }

        if p.hub_open(
               &game.hub,
               cfg,
               existing[:count],
               db.commit,
               &game.store,
               auth.native_clock(),
               self.wire,
               creation_guard = room_creation_guard,
               reclaim = reclaim,
               lifecycle_user = game,
           ) !=
               .None ||
           !rgd.rendezvous_hub_init(&game.signal, &game.hub, &self.socket) {
            fail(self, "coordinator startup failed")
            return
        }

        checkpoint_name, checkpoint_ok := checkpoint_open(game, game.content)

        if !checkpoint_ok {
            fail(self, "checkpoint model or endpoint startup failed")
            return
        }

        game.checkpoint_name = checkpoint_name
    }

    if !open_relays(self) {
        return
    }

    self.ready = true

    if !self.routed {
        game := self.games[0]
        gd.print_str(
            fmt.tprintf(
                "REPLAY_ROOM_SERVICE_READY rooms=%d content=%x tls=%t port=%d checkpoints=%s",
                game.loaded,
                game.content,
                self.tls != nil,
                port,
                game.checkpoint_name,
            ),
        )
        return
    }

    for game in self.games {
        gd.print_str(
            fmt.tprintf(
                "REPLAY_ROOM_GAME slug=%s content=%x rooms=%d checkpoints=%s",
                game.slug,
                game.content,
                game.loaded,
                game.checkpoint_name,
            ),
        )
    }

    gd.print_str(
        fmt.tprintf("REPLAY_ROOM_SERVICE_READY games=%d tls=%t port=%d", len(self.games), self.tls != nil, port),
    )
}

// Single-game mode keeps REPLAY_ROOM_DB as the database file and its explicit
// REPLAY_ROOM_CREATE_DB=1. With REPLAY_ROOM_GAMES, REPLAY_ROOM_DB is a directory
// holding one database per content ID (<id>.sqlite3). A new ID's database is
// created once, recorded by <id>.created; if that database later disappears the
// service refuses to start rather than silently replace it.
open_store :: proc(self: ^ReplayRoomService, game: ^Game, database: string) -> bool {
    if !self.routed {
        if db.open(&game.store, database, gd.env_int("REPLAY_ROOM_CREATE_DB", 0) == 1) != .None {
            fail(self, "private database could not be opened")
            return false
        }

        return true
    }

    if database == "" {
        fail(self, "REPLAY_ROOM_DB must name a directory with REPLAY_ROOM_GAMES")
        return false
    }

    if !os.exists(database) && os.make_directory(database, {.Read_User, .Write_User, .Execute_User}) != nil {
        fail(self, "database directory could not be created")
        return false
    }

    path := fmt.tprintf("%s/%016x.sqlite3", database, game.content)
    marker := fmt.tprintf("%s/%016x.created", database, game.content)
    create := !os.exists(path)

    if create && os.exists(marker) {
        fail(
            self,
            fmt.tprintf("database for %016x is missing after creation; operator recovery required", game.content),
        )
        return false
    }

    if db.open(&game.store, path, create) != .None {
        fail(self, "private database could not be opened")
        return false
    }

    if create && os.write_entire_file(marker, fmt.tprintf("%016x\n", game.content)) != nil {
        fail(self, "database creation marker could not be written")
        return false
    }

    return true
}

// TURN credentials (optional): one secret and URL set for every game; each
// game's relay server stamps its own content ID.
open_relays :: proc(self: ^ReplayRoomService) -> bool {
    secret_path, turn_urls :=
        gd.env_string("REPLAY_ROOM_TURN_SECRET_FILE", ""), gd.env_string("REPLAY_ROOM_TURN_URLS", "")

    if secret_path == "" && turn_urls == "" {
        return true
    }

    ttl := gd.env_int("REPLAY_ROOM_TURN_TTL", 600)

    if secret_path == "" || turn_urls == "" || ttl < 5 || ttl > 3600 {
        fail(self, "TURN provider configuration invalid")
        return false
    }

    bytes, error := storagegd.storage_read(secret_path, 256)

    defer {
        if len(bytes) > 0 {
            crypto.zero_explicit(raw_data(bytes), len(bytes))
        }

        delete(bytes)
    }

    if error != .None {
        fail(self, "TURN provider secret could not be read")
        return false
    }

    urls := strings.split(turn_urls, ",", context.temp_allocator)

    if len(urls) < 1 || len(urls) > rel.MAX_URLS {
        fail(self, "TURN URL count invalid")
        return false
    }

    config := rel.Config {
        secret     = strings.trim_space(string(bytes)),
        ttl        = u32(ttl),
        relay_only = gd.env_int("REPLAY_ROOM_TURN_RELAY_ONLY", 0) == 1,
    }

    for text, i in urls {
        valid: bool
        config.urls[i], valid = rel.url(strings.trim_space(text))

        if !valid {
            fail(self, "TURN URL invalid")
            return false
        }
    }

    for game in self.games {
        config.content = game.content

        if !rel.server_open(&game.relay, config, rel.hub_authorize, &game.hub, {read = relay_clock}, self.wire) {
            fail(self, "TURN provider startup failed")
            return false
        }
    }

    return true
}

replay_room_service_process :: proc(self: ^ReplayRoomService, dt: f64) {
    if !self.ready {
        return
    }

    tr.poll(&self.wire)

    for game in self.games {
        rgd.rendezvous_hub_pump(&game.signal)
    }

    buffer: [tr.MAX_PACKET_BYTES]u8

    for _ in 0 ..< 32 {
        message := transportgd.websocket_receive(&self.socket, buffer[:])

        if message.state == .Empty || message.state == .Disconnected {
            break
        }

        if message.state != .Received {
            continue
        }

        bytes := buffer[:message.count]

        if message.text {
            // The first signaling message names a room; later ones follow the
            // room it bound to. Single-game mode keeps the hub's own handling of
            // unknown rooms (it disconnects them).
            game := self.routed ? signaling_game(self, message.from, bytes) : self.games[0]

            if game == nil {
                transportgd.websocket_disconnect(&self.socket, message.from)
                continue
            }

            rgd.rendezvous_hub_receive(&game.signal, message.from, bytes)
            continue
        }

        // Every binary packet is a schema envelope naming its game's content ID.
        // With several games, a packet for a build this connection's path does
        // not list closes the connection, so the client fails fast instead of
        // waiting out its request timeout.
        game := packet_game(self, message.from, bytes)

        if game == nil {
            if self.routed {
                transportgd.websocket_disconnect(&self.socket, message.from)
            }

            continue
        }

        if !ck.hub_receive(&game.checkpoints, message.from, bytes) &&
           !rel.server_receive(&game.relay, message.from, bytes) &&
           !p.hub_receive(&game.hub, message.from, bytes) {
            p.hub_control_receive(&game.hub, message.from, bytes)
        }
    }

    for game in self.games {
        if game.checkpoints.ready && ck.hub_update(&game.checkpoints) != .None {
            fail(self, "checkpoint room inventory changed or storage fenced")
            return
        }
    }
}

// The slug a peer connected on: the last segment of its requested path.
peer_slug :: proc(self: ^ReplayRoomService, peer: tr.Peer_Id, dst: []u8) -> string {
    path, ok := transportgd.websocket_requested_path(&self.socket, peer, dst)

    if !ok {
        return ""
    }

    path = strings.trim_right(path, "/")

    if slash := strings.last_index_byte(path, '/'); slash >= 0 {
        path = path[slash + 1:]
    }

    return path
}

reachable :: proc(self: ^ReplayRoomService, game: ^Game, slug: string) -> bool {
    return !self.routed || game.slug == slug
}

packet_game :: proc(self: ^ReplayRoomService, peer: tr.Peer_Id, bytes: []u8) -> ^Game {
    content, ok := envelope_content(bytes)

    if !ok {
        return nil
    }

    scratch: [256]u8
    slug := self.routed ? peer_slug(self, peer, scratch[:]) : ""

    for game in self.games {
        if game.content == content {
            return reachable(self, game, slug) ? game : nil
        }
    }

    return nil
}

signaling_game :: proc(self: ^ReplayRoomService, peer: tr.Peer_Id, bytes: []u8) -> ^Game {
    scratch: [256]u8
    slug := peer_slug(self, peer, scratch[:])

    for game in self.games {
        if reachable(self, game, slug) && rgd.rendezvous_hub_claims(&game.signal, peer, bytes) {
            return game
        }
    }

    return nil
}

// The content ID in a schema envelope's header. Signed packets carry a 32-byte
// MAC after the envelope, so try the whole packet, then without the MAC.
envelope_content :: proc(bytes: []u8) -> (u64, bool) {
    meta, _, report := sc.inspect(bytes)

    if report.error != .None && len(bytes) >= sc.HEADER_BYTES + 32 {
        meta, _, report = sc.inspect(bytes[:len(bytes) - 32])
    }

    return meta.content, report.error == .None && meta.content != 0
}

fail :: proc(self: ^ReplayRoomService, reason: string) {
    gd.print_str(fmt.tprintf("REPLAY_ROOM_SERVICE_FAIL %s", reason))
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_room_service_exit_tree :: proc(self: ^ReplayRoomService) {
    for game in self.games {
        ck.hub_close(&game.checkpoints)
        rgd.rendezvous_hub_destroy(&game.signal)
        p.hub_close(&game.hub)
    }

    transportgd.websocket_close(&self.socket)

    for game in self.games {
        rel.server_close(&game.relay)
        db.close(&game.store)
        delete(game.slug)
        free(game)
    }

    delete(self.games)
    unref(self.tls)
}

relay_clock :: proc(user: rawptr) -> (u64, u64, bool) {
    wall := gd.time_get_unix_time_from_system(gd.singleton_time())
    clock := auth.native_clock()
    mono, valid := clock.read(clock.user)

    if !valid || !(wall >= 1 && wall < 9007199254740991) {
        return 0, 0, false
    }

    return u64(wall), mono, true
}
