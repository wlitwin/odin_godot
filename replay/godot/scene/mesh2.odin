package replay_godot_scene

import "core:math"
import gd "godot:godot"
import "godot:gdext"

// Installs an immutable, untextured polygon mesh on an existing 2D instance.
// The caller keeps ownership of points. The node owns the resulting mesh;
// replacing it releases its previous mesh through Godot's normal references.
// Animate the node's transform/self_modulate, not the mesh's vertex/index data.
// Simple polygons only, bounded to 4096 vertices. Failure leaves its mesh intact.
mesh2_polygon :: proc(node: gd.Mesh_Instance2d, points: gd.Packed_Vector2_Array) -> bool {
    if node == nil {
        return false
    }

    local := points
    count := int(gd.packed_vector2_array_size(&local))

    if count < 3 || count > 4096 {
        return false
    }

    for i in 0 ..< count {
        point := gd.packed_vector2_array_get(&local, gd.Int(i))

        for value in point {
            if math.is_nan(value) || math.is_inf(value) {
                return false
            }
        }
    }

    indices := gd.geometry2d_triangulate_polygon(gd.singleton_geometry2d(), points)
    defer gd.free_packed_int32_array(indices)

    if gd.packed_int32_array_size(&indices) != gd.Int((count - 2) * 3) {
        return false
    }

    vertices := gd.new_packed_vector3_array()
    defer gd.free_packed_vector3_array(vertices)

    for i in 0 ..< count {
        point := gd.packed_vector2_array_get(&local, gd.Int(i))
        gd.packed_vector3_array_append(&vertices, {point[0], point[1], 0})
    }

    arrays := gd.new_array()
    defer gd.free_array(arrays)

    if gd.array_resize(&arrays, gd.Int(gd.Mesh_Array_Type.Array_Max)) != 0 {
        return false
    }

    vertex_value := gd.variant_from_packed_vector3_array(&vertices)
    defer gd.variant_destroy(&vertex_value)
    index_value := gd.variant_from_packed_int32_array(&indices)
    defer gd.variant_destroy(&index_value)
    gd.array_set(&arrays, gd.Int(gd.Mesh_Array_Type.Array_Vertex), vertex_value)
    gd.array_set(&arrays, gd.Int(gd.Mesh_Array_Type.Array_Index), index_value)
    blend_shapes := gd.new_array()
    defer gd.free_array(blend_shapes)
    lods := gd.new_dictionary()
    defer gd.free_dictionary(lods)
    mesh := gd.new_array_mesh()

    if mesh == nil {
        return false
    }

    gd.ref_counted_init_ref(mesh)

    defer if gd.ref_counted_unreference(mesh) {
        gdext.object_destroy(mesh)
    }

    gd.array_mesh_add_surface_from_arrays(
        mesh,
        .Primitive_Triangles,
        arrays,
        {blend_shapes},
        lods,
        gd.Mesh_Array_Format(0),
    )

    if gd.mesh_get_surface_count(mesh) != 1 {
        return false
    }

    gd.mesh_instance2d_set_mesh(node, mesh)
    return true
}
