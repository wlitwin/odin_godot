package replay_scrapyard

import "core:strings"
import "core:strconv"
import gd "godot:godot"

scrap_param :: proc(key: cstring, fallback: string = "") -> string {
    name := string(key)
    query := strings.to_lower(name[4:], context.temp_allocator)
    return gd.launch_param(key, query, fallback)
}

scrap_int :: proc(key: cstring, fallback: int) -> int {
    text := scrap_param(key, "")

    if text == "" {
        return fallback
    }

    value, ok := strconv.parse_int(text)
    return ok ? value : -1
}
