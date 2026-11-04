#+build darwin
package replay_authoring_demo

import "core:strings"

foreign import process_images "system:c"

foreign process_images {
    _dyld_image_count :: proc "c" () -> u32 ---
    _dyld_get_image_name :: proc "c" (index: u32) -> cstring ---
}

native_image_count :: proc() -> int {
    count := 0

    for i in 0 ..< _dyld_image_count() {
        name := _dyld_get_image_name(i)

        if name == nil {
            continue
        }

        path := string(name)

        if strings.contains(path, "libogb3") && strings.has_suffix(path, ".dylib") {
            count += 1
        }
    }

    return count
}
