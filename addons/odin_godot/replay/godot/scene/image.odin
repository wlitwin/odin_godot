package replay_godot_scene

import a "godot:replay/assets"
import gd "godot:godot"
import "godot:gdext"

// Returns an owned reference. The caller releases it with unreference/destroy.
// Pixel bounds are verified before decoding; Godot validates the complete PNG.
asset_png_image :: proc(
    bytes: []u8,
    max_bytes: int = 128 * 1024,
    max_dimension: u32 = 2048,
    max_pixels: u64 = 1024 * 1024,
) -> (
    gd.Image,
    bool,
) {
    info, ok := a.png_info(bytes, max_bytes, max_dimension, max_pixels)

    if !ok {
        return nil, false
    }

    image := gd.new_image()

    if image == nil {
        return nil, false
    }

    gd.ref_counted_init_ref(image)
    packet := gd.new_packed_byte_array()
    defer gd.free_packed_byte_array(packet)

    if gd.packed_byte_array_resize(&packet, gd.Int(len(bytes))) != 0 {
        if gd.ref_counted_unreference(image) {
            gdext.object_destroy(image)
        }

        return nil, false
    }

    copy(gd.packed_byte_array_view(&packet), bytes)

    if gd.image_load_png_from_buffer(image, packet) != .Ok ||
       gd.image_get_width(image) != i32(info.width) ||
       gd.image_get_height(image) != i32(info.height) {
        if gd.ref_counted_unreference(image) {
            gdext.object_destroy(image)
        }

        return nil, false
    }

    return image, true
}

asset_png_valid :: proc(user: rawptr, ref: a.Ref, bytes: []u8) -> bool {
    image, ok := asset_png_image(bytes)

    if image != nil && gd.ref_counted_unreference(image) {
        gdext.object_destroy(image)
    }

    return ok
}
