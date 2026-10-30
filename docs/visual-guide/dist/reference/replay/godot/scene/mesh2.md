# Immutable 2D polygon meshes

`mesh2_polygon(instance, points)` triangulates a simple polygon and installs an
untextured `ArrayMesh` on a Godot `MeshInstance2D`. It accepts 3–4096 finite vertices.
Failure leaves the previous mesh in place. The caller owns the input packed array;
the node owns the resulting mesh through Godot's normal reference counting.
Replacing the mesh releases the node's reference to its previous resource.

Create geometry when its shape changes. Animate `Node2D.transform`, visibility,
and `CanvasItem.self_modulate` for placement, scaling and tint. Reuse a canonical
unit shape when an affine transform describes the animation. Callers can also
share the resulting immutable mesh using Godot's ordinary mesh resource references.
The helper does not introduce global caches, simulation state or network identity.

```odin
node := gd.new_mesh_instance2d()
points := gd.new_packed_vector2_array()
for point in ([3]gd.Vector2{{0, 0}, {20, 0}, {0, 20}}) {
    gd.packed_vector2_array_append(&points, point)
}
ok := scenegd.mesh2_polygon(node, points)
gd.free_packed_vector2_array(points)
if ok {
    gd.add_child(parent, node)
    gd.canvas_item_set_self_modulate(node, {1, 0.8, 0.2, 0.5})
} else {
    gdext.object_destroy(node)
}
```

This is useful with Godot 4.7.1's compatibility web renderer. Its Polygon2D redraw
path can update an existing index buffer through a vertex-buffer target, including
when color, visibility or viewport changes cause redraw. Immutable mesh instances
avoid that update path. They also avoid repeated triangulation/uploads when only
pose or color changes. See the [reproduction and validation](../../../docs/replay/results/immutable-polygons-2026-09-13/README.md).

For observation tools, `Mesh.surface_get_arrays` can read back GPU buffers. Cache
immutable geometry by mesh resource identity instead of performing that readback
on every frame. Instance pose/tint remain separately observable and mutable.
