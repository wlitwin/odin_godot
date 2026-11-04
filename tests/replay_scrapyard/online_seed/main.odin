package main
import "core:fmt"
import "core:os"
import net "godot:replay/net"
import p "godot:replay/provision"
import game "godot:examples/replay_scrapyard/shared/game"
import profile "godot:examples/replay_scrapyard/shared/profile"

main :: proc() {
    assert(len(os.args) == 3)
    dir, role := os.args[1], os.args[2]
    secret, err := p.secret()
    assert(err == .None)
    token: net.Token
    copy(token[:], secret[:16])
    identity := net.token_hash(token)
    name := ""

    for b in identity {
        name = fmt.tprintf("%s%02x", name, b)
    }

    record := profile.Record {
        identity = identity,
        profile = {
            name = game.name(role == "host" ? "Host Forge" : "Guest Forge"),
            look = role == "host" ? 2 : 1,
            iron = role == "host" ? 1 : 2,
            abilities = role == "host" ? [2]u8{5, 1} : [2]u8{4, 6},
            meta = {cores = 7, parts = 2},
        },
    }
    bytes, error := profile.encode(record)
    defer delete(bytes)
    assert(error == .None)
    assert(
        os.write_entire_file(fmt.tprintf("%s/replay_identity", dir), token[:], perm = {.Read_User, .Write_User}) ==
        nil,
    )
    assert(
        os.write_entire_file(
            fmt.tprintf("%s/replay_profile_%s", dir, name),
            bytes,
            perm = {.Read_User, .Write_User},
        ) ==
        nil,
    )
    fmt.println("RSY_ONLINE_PROFILE_SEEDED", role)
}
