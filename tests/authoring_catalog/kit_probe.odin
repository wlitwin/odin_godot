package scrapyard_scripts

import "core:hash"
import gd "godot:godot"

@(gd_method)
scrapyard_catalog_reload :: proc(self: ^Scrapyard) -> bool {return defs_load()}

@(gd_method)
scrapyard_catalog_digest :: proc(self: ^Scrapyard) -> gd.Int {
    return gd.Int(hash.fnv64a(defs_bytes()) & u64(max(i64)))
}

@(gd_method)
scrapyard_catalog_width :: proc(self: ^Scrapyard) -> gd.Int {return gd.Int(len(g_guns))}

@(gd_method)
scrapyard_catalog_clear :: proc(self: ^Scrapyard) {defs_unload()}
