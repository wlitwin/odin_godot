package main

import "core:crypto/sha2"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import a "godot:replay/assets"
import net "godot:replay/net"
import sc "godot:replay/schema"
import game "../../shared/game"
import upgrade "../../shared/upgrade"

// An explicit offline converter. Keep game/content conversions separate: this
// bridge is valid only because protocol 6 and 7 share checkpoint layout 4.
main :: proc() {
    if !run() {
        os.exit(1)
    }
}

run :: proc() -> bool {
    if len(os.args) != 5 || (os.args[3] != "--token" && os.args[3] != "--identity-file") || os.args[4] == "" {
        fmt.eprintln("Usage: upgrade_run SOURCE DESTINATION (--identity-file identity.bin | --token TEST_LABEL)")
        return false
    }

    token: net.Token

    if os.args[3] == "--identity-file" {
        bytes, ok := read_bounded(os.args[4], 16)
        defer delete(bytes)

        if !ok || len(bytes) != 16 {
            fmt.eprintln("UPGRADE_ERROR identity file must contain exactly 16 bytes")
            return false
        }

        copy(token[:], bytes)
    } else {
        ctx: sha2.Context_256
        sha2.init_256(&ctx)
        sha2.update(&ctx, transmute([]u8)os.args[4])
        digest: [32]u8
        sha2.final(&ctx, digest[:])
        copy(token[:], digest[:16])
    }

    if token == (net.Token{}) {
        fmt.eprintln("UPGRADE_ERROR invalid identity")
        return false
    }

    bytes, read_ok := read_bounded(os.args[1], a.BUNDLE_LIMIT)
    defer delete(bytes)

    if !read_ok {
        return false
    }

    view: a.Bundle_View
    bundled := true
    source_content := u64(0)
    meta, _, inspected := sc.inspect(bytes)

    if inspected.error == .None && meta.kind == net.CHECKPOINT_KIND {
        view.meta, view.root = meta, bytes
        bundled = false
    } else {
        decoded, err := a.bundle_decode(bytes, upgrade.CONTENT_42)

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_43)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_44)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_45)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_46)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_47)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_48)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_49)
        }

        if err == .Content {
            decoded, err = a.bundle_decode(bytes, upgrade.CONTENT_50)
        }

        if err != .None {
            fmt.eprintf("UPGRADE_ERROR bundle=%v\n", err)
            return false
        }

        view = decoded
    }

    source_content = view.meta.content
    root: []u8
    upgraded: net.Error

    if source_content == upgrade.CONTENT_42 {
        root, upgraded = upgrade.root_42(view.root)
    } else if source_content == upgrade.CONTENT_43 {
        root, upgraded = upgrade.root_43(view.root)
    } else if source_content == upgrade.CONTENT_44 {
        root, upgraded = upgrade.root_44(view.root)
    } else if source_content == upgrade.CONTENT_45 {
        root, upgraded = upgrade.root_45(view.root)
    } else if source_content == upgrade.CONTENT_46 {
        root, upgraded = upgrade.root_46(view.root)
    } else if source_content == upgrade.CONTENT_47 {
        root, upgraded = upgrade.root_47(view.root)
    } else if source_content == upgrade.CONTENT_48 {
        root, upgraded = upgrade.root_48(view.root)
    } else if source_content == upgrade.CONTENT_49 {
        root, upgraded = upgrade.root_49(view.root)
    } else if source_content == upgrade.CONTENT_50 {
        root, upgraded = upgrade.root_50(view.root)
    } else {
        upgraded = .Checkpoint_Contract
    }

    defer delete(root)

    if upgraded != .None {
        fmt.eprintf("UPGRADE_ERROR checkpoint=%v\n", upgraded)
        return false
    }

    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)

    if err := net.checkpoint_decode(&cp, root, game.model(), game.CONTENT); err != .None {
        fmt.eprintf("UPGRADE_ERROR converted checkpoint=%v\n", err)
        return false
    }

    if cp.header.epoch != view.meta.epoch ||
       cp.header.tick != view.meta.tick ||
       (source_content != upgrade.CONTENT_42 &&
               source_content != upgrade.CONTENT_43 &&
               source_content != upgrade.CONTENT_44 &&
               source_content != upgrade.CONTENT_45 &&
               source_content != upgrade.CONTENT_46 &&
               source_content != upgrade.CONTENT_47 &&
               source_content != upgrade.CONTENT_48 &&
               source_content != upgrade.CONTENT_49 &&
               source_content != upgrade.CONTENT_50) {
        fmt.eprintln("UPGRADE_ERROR container metadata mismatch")
        return false
    }

    // An offline file cannot grant a coordinator lease or reconstruct a custom
    // admission callback. Such archives need an application-owned recovery path.
    if cp.settings.require_permit || cp.header.policy_id != 0 || cp.header.epoch == max(u64) {
        fmt.eprintln("UPGRADE_ERROR archive requires coordinated or custom-policy recovery")
        return false
    }

    seat, found := net.checkpoint_seat(&cp, token)

    if !found || seat == 0 {
        fmt.eprintln("UPGRADE_ERROR identity is not a saved playable member")
        return false
    }

    for player in cp.frame.state.players {
        if !a.bundle_has(&view, player.spray.image) {
            fmt.eprintln("UPGRADE_ERROR missing spray asset")
            return false
        }
    }

    for asset in view.assets[:view.count] {
        // This is bounded PNG preflight. Godot still performs the full image decode
        // when loading the converted run, just as for any current-format save.
        if _, ok := a.png_info(asset.bytes, game.SPRAY_MAX); !ok {
            fmt.eprintln("UPGRADE_ERROR invalid spray PNG structure")
            return false
        }
    }

    output := root
    bundle_bytes: []u8
    defer delete(bundle_bytes)

    if bundled {
        result, err := a.bundle_replace_root(bytes, root, source_content, target_content = game.CONTENT)

        if err != .None {
            fmt.eprintf("UPGRADE_ERROR reframe=%v\n", err)
            return false
        }

        bundle_bytes = result
        output = bundle_bytes
    }

    full_codec, public_codec, legacy_codec: sc.Schema
    defer sc.destroy(&full_codec)
    defer sc.destroy(&public_codec)
    defer sc.destroy(&legacy_codec)
    public_options := sc.DEFAULT_OPTIONS
    public_options.projection = .Public

    if sc.init(&full_codec, game.World).error != .None ||
       sc.init(&public_codec, game.World, public_options).error != .None {
        return false
    }

    full_bytes := make([]u8, full_codec.wire_size)
    defer delete(full_bytes)
    public_bytes := make([]u8, public_codec.wire_size)
    defer delete(public_bytes)

    if sc.encode(&full_codec, cp.frame.state, full_bytes).error != .None ||
       sc.encode(&public_codec, cp.frame.state, public_bytes).error != .None {
        return false
    }

    if sc.init(&legacy_codec, upgrade.World_48).error != .None {
        return false
    }

    legacy_bytes := make([]u8, legacy_codec.wire_size)
    defer delete(legacy_bytes)

    if sc.encode(&legacy_codec, upgrade.world_48(cp.frame.state), legacy_bytes).error != .None {
        return false
    }

    codec: net.Checkpoint_Codec
    defer net.checkpoint_codec_destroy(&codec)

    if net.checkpoint_codec_init(&codec, game.World, game.Control, game.Action, game.Event, game.SEATS, false) !=
       .None {
        return false
    }

    _, frame_offset, layout_ok := net.checkpoint_frame_layout(&codec)

    if !layout_ok {
        return false
    }

    if !publish_new(os.args[2], output) {
        return false
    }

    epoch_field, epoch_found := sc.field_index(&full_codec, "$.authority_epoch")

    if !epoch_found {
        return false
    }

    fmt.printf(
        "UPGRADE_EPOCH_FIELD offset=%d bytes=8\n",
        frame_offset + 8 + full_codec.fields[epoch_field].wire_offset,
    )

    for field in full_codec.fields {
        if strings.contains(field.path, ".pulse.") ||
           strings.contains(field.path, ".turret.") ||
           strings.has_prefix(field.path, "$.turrets.") {
            fmt.printf("UPGRADE_ZERO_FIELD offset=%d bytes=%d\n", frame_offset + 8 + field.wire_offset, field.width)
        }
    }

    held_schema, peer_schema, action_schema, old_action_schema: sc.Schema
    defer sc.destroy(&held_schema)
    defer sc.destroy(&peer_schema)
    defer sc.destroy(&action_schema)
    defer sc.destroy(&old_action_schema)

    if sc.init(&held_schema, net.Checkpoint_Held(game.Control, game.SEATS)).error != .None ||
       sc.init(&peer_schema, net.Checkpoint_Peer).error != .None ||
       sc.init(&action_schema, net.Checkpoint_Action(game.Action)).error != .None {
        return false
    }

    old_type: typeid = upgrade.Action_50

    if source_content == upgrade.CONTENT_42 {
        old_type = upgrade.Action_42
    } else if source_content <= upgrade.CONTENT_46 {
        old_type = upgrade.Action_46
    }

    if sc.init(&old_action_schema, old_type).error != .None {
        return false
    }

    action_base :=
        frame_offset + 8 + full_codec.wire_size + held_schema.wire_size + len(cp.peers) * peer_schema.wire_size

    for _, i in cp.actions {
        for field in action_schema.fields {
            if !strings.has_prefix(field.path, "$.value.") {
                continue
            }

            source_path := fmt.tprintf("$.%s", strings.trim_prefix(field.path, "$.value."))

            if _, found := sc.field_index(&old_action_schema, source_path); !found {
                fmt.printf(
                    "UPGRADE_ZERO_ACTION offset=%d bytes=%d\n",
                    action_base + i * action_schema.wire_size + field.wire_offset,
                    field.width,
                )
            }
        }
    }

    fmt.printf(
        "UPGRADE_LEGACY_STATE authority=%d bytes=%d epoch=%d\n",
        sc.digest(legacy_bytes) & 0x7fff_ffff_ffff_ffff,
        len(legacy_bytes),
        cp.frame.state.authority_epoch,
    )
    fmt.printf(
        "UPGRADE_STATE_DIGESTS authority=%d public=%d\n",
        sc.digest(full_bytes) & 0x7fff_ffff_ffff_ffff,
        sc.digest(public_bytes) & 0x7fff_ffff_ffff_ffff,
    )
    fmt.printf(
        "REPLAY_SCRAPYARD_UPGRADE_OK content=older->51 protocol=6/7->7 tick=%d epoch=%d seat=%d assets=%d bytes=%d\n",
        cp.header.tick,
        cp.header.epoch,
        seat,
        view.count,
        len(output),
    )
    return true
}

read_bounded :: proc(path: string, limit: int) -> ([]u8, bool) {
    file, opened := os.open(path)

    if opened != nil {
        fmt.eprintf("UPGRADE_ERROR read=%v\n", opened)
        return nil, false
    }

    defer os.close(file)
    size, sized := os.file_size(file)

    if sized != nil || size < 1 || size > i64(limit) {
        fmt.eprintln("UPGRADE_ERROR file size outside bounds")
        return nil, false
    }

    bytes := make([]u8, int(size))
    success := false

    defer if !success {
        delete(bytes)
    }

    at := 0

    for at < len(bytes) {
        n, err := os.read(file, bytes[at:])
        at += n

        if (err != nil && err != .EOF) || n == 0 {
            fmt.eprintln("UPGRADE_ERROR short or failed read")
            return nil, false
        }
    }

    extra: [1]u8
    n, err := os.read(file, extra[:])

    if n != 0 || (err != nil && err != .EOF) {
        fmt.eprintln("UPGRADE_ERROR file changed during read")
        return nil, false
    }

    success = true
    return bytes, true
}

publish_new :: proc(destination: string, bytes: []u8) -> bool {
    dir := filepath.dir(destination)
    defer delete(dir)
    file, created := os.create_temp_file(dir, ".replay-upgrade-*")

    if created != nil {
        fmt.eprintf("UPGRADE_ERROR stage=%v\n", created)
        return false
    }

    name := strings.clone(os.name(file))
    defer delete(name)
    defer os.remove(name)
    closed := false

    defer if !closed {
        os.close(file)
    }

    at := 0

    for at < len(bytes) {
        n, err := os.write(file, bytes[at:])
        at += n

        if err != nil || n == 0 {
            fmt.eprintf("UPGRADE_ERROR write=%v\n", err)
            return false
        }
    }

    if err := os.sync(file); err != nil {
        fmt.eprintf("UPGRADE_ERROR sync=%v\n", err)
        return false
    }

    err := os.close(file)
    closed = true

    if err != nil {
        fmt.eprintf("UPGRADE_ERROR close=%v\n", err)
        return false
    }

    // Linking a complete file publishes without replacing an existing file or
    // symlink. The stage is in the same directory; unsupported filesystems fail.
    if err := os.link(name, destination); err != nil {
        fmt.eprintf("UPGRADE_ERROR publish=%v (destination must be new; filesystem must support hard links)\n", err)
        return false
    }

    return true
}
