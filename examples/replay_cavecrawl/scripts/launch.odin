package replay_cavecrawl

import "core:strings"
import "core:strconv"
import gd "godot:godot"

cave_param :: proc(key: cstring, fallback: string = "") -> string {
    name := string(key)
    query := strings.to_lower(name[len("REPLAY_CAVE_"):], context.temp_allocator)
    return gd.launch_param(key, query, fallback)
}

cave_int :: proc(key: cstring, fallback: int) -> int {
    text := cave_param(key, "")

    if text == "" {
        return fallback
    }

    value, ok := strconv.parse_int(text)
    return ok ? value : -1
}
