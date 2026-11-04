The `authoring` CTest uses actual Native worlds and catalog-owned factories for
Box, Sphere, Capsule, Hull, Mesh, and an externally baked heightfield Mesh. It
checks complete solver dumps after canonical decode/restore, exact re-encoding,
continued stepping after catalog/source release, malformed Mesh caches and
manifolds, invalid geometry/aliases, and atomic controlled allocation failures.
The existing `recovery` and independent `recovery_reference` tests retain the
primitive format-1 coverage. No test has been executed at the source checkpoint;
Root schedules the exclusive Native build/test matrix.
