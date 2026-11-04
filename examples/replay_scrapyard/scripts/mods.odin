package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import rgd "godot:replay/godot"
import content "../shared/content"
import mods "../shared/mods"
import storagegd "godot:replay/godot/storage"

// Only a fresh authority loads local overlays. Followers and resumed worlds use
// the catalog already carried by the authoritative frame/checkpoint.
mods_enabled :: proc(self: ^ReplayScrapyard, role: rgd.Session_Role) -> bool {
    if self.resume_requested || scrap_int("RSY_RESUME", 0) != 0 {
        return false
    }

    if role != .Solo && role != .Host && role != .Server {
        return false
    }

    if self.online.launch {
        return self.online.party.grant.identity.member == 1
    }

    return(
        (scrap_int("RSY_COORD_PORT", 0) == 0 && scrap_param("RSY_COORD_URL", "") == "") ||
        scrap_int("RSY_MEMBER", 0) == 1 \
    )
}

mods_load :: proc(catalog: ^content.Catalog) {
    directory := scrap_param("RSY_MODS_DIR", "")

    if len(directory) == 0 {
        if len(scrap_param("RSY_TOKEN", "")) > 0 && scrap_int("RSY_PERSIST", 0) == 0 {
            return
        }

        directory = "user://mods"
    }

    path := gd.new_string_odin(directory)
    defer gd.free_string(path)

    if !gd.dir_access_dir_exists_absolute(path) {
        return
    }

    dir := gd.dir_access_open(path)

    if dir == nil {
        gd.print_str("RSY_MODS_SKIP directory")
        return
    }

    defer if gd.ref_counted_unreference(dir) {
        gdext.object_destroy(dir)
    }

    files := gd.dir_access_get_files(dir)
    defer gd.free_packed_string_array(files)
    gd.packed_string_array_sort(&files)
    count := 0

    for i in 0 ..< gd.packed_string_array_size(&files) {
        filename := gd.packed_string_array_get(&files, i)
        defer gd.free_string(filename)
        name := gd.gd_string_to_odin(filename)

        if !strings.has_suffix(name, ".json") {
            continue
        }

        count += 1

        if count > 32 {
            gd.print_str("RSY_MODS_SKIP file limit")
            break
        }

        bytes, err := storagegd.storage_read(fmt.tprintf("%s/%s", directory, name), mods.MAX_FILE_BYTES)
        defer delete(bytes)

        if err != .None {
            gd.print_str(fmt.tprintf("RSY_MODS_SKIP file=%s read=%v", name, err))
            continue
        }

        applied := mods.apply(catalog, bytes)

        if applied.error != .None {
            gd.print_str(fmt.tprintf("RSY_MODS_SKIP file=%s reason=%v", name, applied.error))
            continue
        }

        n := applied.counts
        gd.print_str(
            fmt.tprintf(
                "RSY_MODS file=%s guns=%d mobs=%d st=%d co=%d ab=%d",
                name,
                n.guns,
                n.mobs,
                n.status,
                n.combos,
                n.abilities,
            ),
        )
    }
}

@(gd_method)
replay_scrapyard_catalog_hash :: proc(self: ^ReplayScrapyard) -> gd.Int {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return -1
    }

    return gd.Int(content.fingerprint(frame.state.catalog) & 0x7fff_ffff_ffff_ffff)
}

@(gd_method = "owned_return")
replay_scrapyard_gun_name :: proc(self: ^ReplayScrapyard, wanted: gd.Int) -> gd.String {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok || wanted < 0 || wanted >= content.MAX_GUNS {
        return gd.new_string_odin("")
    }

    return gd.new_string_odin(content.name_string(&frame.state.catalog.guns[wanted].name))
}
