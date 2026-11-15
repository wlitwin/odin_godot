`generate(frame, scene, options, out)` reads the existing copied presentation
`Frame`, immutable geometry slices and allocation-key bindings. It returns a
value `Batch` and `Error`. Runtime drawing defaults off. Enabled requests require
an exact epoch/tick/revision/source stamp; stale requests leave output untouched.
There is no retained frame, view, Native world, Godot object, allocator or clock.

The input slices must remain immutable for the call and must not alias `out`.
Validation/counting precedes output. Every error preserves the entire output
buffer. `Batch.count` is nonzero only on success. On Capacity, `required` is exact
after counting, `MAX_LINES+1` denotes a lower bound beyond the preview budget,
and zero means an input cap prevented counting. Successful lines contain only
copied endpoints/colors and survive destruction of every input.

Bindings are ordered by stable logical ID and use copied body poses plus their
rigid local poses. Sphere centers and arbitrary capsule endpoints are supported.
Hull point clouds yield convex crease lines; coplanar face diagonals are omitted.
Mesh outlines use every triangle, including a heightfield already baked to Mesh.
Joint overlays display copied anchor frames and their connection. Character
capsules, up and ground vectors come from explicitly supplied copied Game/Side;
they are never inferred by querying a solver. Missing bodies/geometries and
unsupported/invalid inputs fail explicitly. Preview limits do not change physics
profile caps or define any new asset identity algorithm.

`preview_geometry(geometry, pose, color, segments, out)` reuses the same geometry
generator for authored editor previews. It has no frame stamp and makes no claim
to show a live or historical simulation. `segments=0` selects16; other values
must be even8..64. The package is contextless and imports only the value-only
presentation package and standard math. Root schedules compiler/runtime checks.
