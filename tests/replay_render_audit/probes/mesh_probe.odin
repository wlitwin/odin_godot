package replay_scrapyard
import gd "godot:godot"
import "godot:gdext"
import scenegd "godot:replay/godot/scene"

@(gd_method)
replay_scrapyard_mesh_probe :: proc(self: ^ReplayScrapyard) -> bool {
    node := gd.new_mesh_instance2d()
    defer gdext.object_destroy(node)
    points := gd.new_packed_vector2_array()
    defer gd.free_packed_vector2_array(points)

    for p in ([3]gd.Vector2{{}, {20, 0}, {0, 20}}) {
        gd.packed_vector2_array_append(&points, p)
    }

    if !scenegd.mesh2_polygon(node, points) {
        return false
    }

    original := gd.mesh_instance2d_get_mesh(node)
    defer gd.release_ref(original)

    if gd.ref_counted_get_reference_count(original) != 2 {
        return false
    }

    invalid := gd.new_packed_vector2_array()
    defer gd.free_packed_vector2_array(invalid)

    if scenegd.mesh2_polygon(node, invalid) {
        return false
    }

    for p in ([3]gd.Vector2{{}, {transmute(f32)u32(0x7fc00000), 0}, {0, 20}}) {
        gd.packed_vector2_array_append(&invalid, p)
    }

    if scenegd.mesh2_polygon(node, invalid) {
        return false
    }

    current := gd.mesh_instance2d_get_mesh(node)
    defer gd.release_ref(current)

    if current != original || gd.ref_counted_get_reference_count(original) != 3 {
        return false
    }

    if !scenegd.mesh2_polygon(node, points) {
        return false
    }

    // Only the two explicit getter references remain on the retired mesh.
    if gd.ref_counted_get_reference_count(original) != 2 {
        return false
    }

    replacement := gd.mesh_instance2d_get_mesh(node)
    defer gd.release_ref(replacement)

    if replacement == original || gd.ref_counted_get_reference_count(replacement) != 2 {
        return false
    }

    return true
}
