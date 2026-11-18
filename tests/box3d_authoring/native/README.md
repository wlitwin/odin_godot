The `authoring` CTest uses actual Native worlds and catalog-owned factories for
Box, Sphere, Capsule, Hull, Mesh, and an externally baked heightfield Mesh. It
checks complete solver dumps after canonical decode/restore, exact re-encoding,
continued stepping after catalog/source release, malformed Mesh caches and
manifolds, invalid geometry/aliases, and atomic controlled allocation failures.
The `recovery` and independent `recovery_reference` checks use current format 3
through the primitive convenience API. Both constructors produce identical
identities and bytes, reject ambiguous geometry aliases, and use only catalog
allocation headroom for primitives. Motion tests cover every joint family and
reject old format headers without publication or leaks.
