Shared authoring API: legacy schema 1, motion schema 2.

Package `godot:box3d/authoring`, input types are in `types.odin`.
`bake(Scene_Input, allocator=context.allocator) -> (Baked_Scene, Diagnostic)`;
`parse_and_bake(json_bytes:[]u8, allocator=context.allocator) -> (Baked_Scene, Diagnostic)`;
`destroy(^Baked_Scene)`; `build(^Baked_Scene, profile:u64) -> (Built_Scene, Diagnostic)`;
`built_destroy(^Built_Scene) -> b.Status`.

JSON uses the EXACT field names/types of Scene_Input, Body_Input and Shape_Input.
Vectors are arrays, poses are `{position:[x,y,z],rotation:[x,y,z,w]}`. Types/kinds
are lowercase strings. Body.shapes is the resource list, copied inline; no engine
values, paths, instance IDs or runtime handles. Extractors emit all fields using
the defaults in types.odin, not omitted implicit defaults. Sphere `center` and
Capsule `centers_a`/`centers_b` are exact local endpoints, not height surrogates.
Heightfield rows are Z and columns X, positive spacing.
Positive scale only; sphere/capsule require uniform scale. Body/world transforms
are rigid; all resource scale/local_pose is baked into exact native geometry.

Body identity hashes namespace+body key. Shape identity hashes
namespace+body key+resource key. Authored resource identity hashes namespace+key.
Native catalog identity hashes canonical baked geometry and namespace: identical
geometry has ONE catalog ID even for distinct resources. Scene_Data.resources
preserves each authored resource key/logical ID/catalog mapping.
The same resource key may be reused on different bodies ONLY with identical
baked geometry; it is one immutable catalog asset. Duplicate body keys or duplicate
shape keys on a body, conflicting reused resources, u64/u32 collisions and zero
IDs fail before publication. Authored logical IDs do not depend on insertion
order or geometry content; native catalog IDs bind geometry content. SHA256
scene identity binds the baked semantic data. Arrays are sorted by
stable keys before native construction. No native allocation identities are IDs.

Limits preserve current 35 bodies/35 shapes/32 dynamic/8 catalog assets and
64MiB envelope; Hull 4..256 points, Mesh 4096 vertices/24576 indices,
64x64 heightfield and 2MiB input.
Non-origin/rotated boxes become exact eight-vertex hulls. Mesh/heightfield require
Static, non-sensor and enable_sensor_events=false (the mesh/heightfield default).
Explicit unsupported flags fail validation; the builder never drops them.
Builder owns a native world, immutable trusted catalog and
local logical-ID-to-native-key maps; geometry temporaries are released after
shape retention. Every failure destroys the partial unpublished candidate.

Native advanced-catalog ABI is in `box3d/native/authoring_catalog.h`: V2 descriptor
size72/align8 on supported64-bit targets, verified through actual C layout queries.
Legacy primitive catalogs remain recovery1; authored catalogs are recovery2.
Pure5, Native-facing Odin3 and both framework cases pass on the declared macOS
reference; Native Debug/Release/ASanUBSan11each and actual Godot SDK resource/scene
roundtrip/source-free construction pass. Export GateC remains separate.

P5.2 motion additions (validated on the recorded P5.2 graph):

`scene_input_default(namespace, schema_version=1)` preserves the P5.1 default;
pass `2` for motion. Schema1 accepts no joints/characters and retains its exact
old content-hash projection and authored recovery2 catalog. Schema2 binds appended
motion arrays and uses `recovery_catalog_create_v3`/recovery3. Both schemas retain
the original body/shape/resource IDs. Logical joint/character IDs use distinct
`joint`/`character` domains, namespace+stable_key, never native keys.

`Scene_Input.joints:[]Joint_Input` (maximum ONE) contains stable_key, lowercase
kind (`pin`, `hinge`, `slider`, `spherical`, `distance`, `motor`, `weld`, `wheel`),
body_a/body_b authored stable-key strings, local_frame_a/b Pose_Input, common
force_threshold/torque_threshold/constraint_hertz/constraint_damping_ratio f32,
collide_connected bool, and named `axis`, `distance`, `spherical`, `motor`, `weld`,
`wheel` settings. These named settings exactly mirror the public fixed-width types
in box3d/joints.odin / native/motion.h. Their Vec3/Quat values are JSON objects
`{x,y,z}` / `{x,y,z,w}`; frame poses remain arrays as above. Unused setting blocks
must be zero. `joint_input_default` is a pure explicit authoring default, while
`b.motion_joint_default` exposes the pinned engine's actual defaults. Angles are
radians, linear lengths metres. Axis flags spring1/limit2/motor4; spherical flags
spring1/cone2/twist4/motor8; wheel flags suspensionSpring1/suspensionLimit2/
spinMotor4/steering8/steeringLimit16. Pin maps Spherical with angular flags OFF;
Hinge maps Revolute Z; Slider maps Prismatic X. Reject missing/self/two-static
bodies, invalid poses/settings/flags/limits and unsupported unused blocks before
publishing a bake. Build resolves Body_Key only after all bodies, then creates
actual constraints transactionally and publishes local Joint_Key maps.

`Scene_Input.characters:[]Character_Input` contains stable_key, optional
exclude_body authored body key (empty means none), config and initial.
Config fields are max_slides (1..8), capsule `{center1:[3],center2:[3],radius}`,
up[3] (normalized by bake), floor_cosine[0..1], category_bits/mask_bits:u64 and
include_sensors:bool. Initial is `{position:[3],velocity:[3]}`. Initial grounding
is explicitly unavailable/zero until actual movement; no authored native ground
key. `character_input_default` gives the exact source defaults. All storage is
copied; config/state are not live Godot references. Built character maps contain
the copied config with resolved optional self Body_Key and initial POD.

Public runtime wrappers are `b.motion_joint_default/create`, `b.query_aabb`,
`b.query_ray_sorted` (old query_ray unchanged), `b.query_capsule/capsule_cast`,
and `b.character_step(world,config,state,dt)->(Character_Result,Status)`.
All 13 C record layouts/fields are independently queried by motion_abi_check.
New queries return COMPLETE sorted Motion_Hit sets keyed by Shape_Key/Body_Key;
Capacity returns exact required count with no truncated prefix. Character uses
the actual engine capsule/plane mover; dt0 is no-op, otherwise fixed1/60 only.
It returns explicit caller-owned POD, never changes a body or owns a tick. The
framework is responsible for storing/reverting that state with its transaction.

P5.3 detached artifact/editor surface (first source checkpoint, uncompiled):

`artifact_create(definition_json, Import_Metadata, allocator)->(Owned_Artifact, Artifact_Diagnostic)`;
`artifact_load(encoded, allocator)->(Owned_Artifact, Artifact_Diagnostic)`;
`artifact_destroy(^Owned_Artifact)`; `import_metadata(source_uri,source_revision)`.
One owning artifact contains its owning shared Baked_Scene, copied source/import
metadata and encoded bytes; definition_json is a read-only view into encoded and
must not be deleted separately. Assignment aliases ownership. Failure publishes
empty output and cleans the local candidate. Loading makes an independent owner.

Version1 binary header is exactly200 bytes, little-endian: magic OGB3ART1[8],
artifact_version:u32,header_bytes:u32,scene_schema:u32,import_version:u32,
source_length:u32,metadata_length:u32,payload_length:u64; then source_sha256,
bake_sha256,metadata_sha256,payload_sha256,shared_bake_sha256 (each32 bytes).
Payload is canonical Import_Metadata JSON followed by EXACT source JSON bytes.
Lengths must match the whole file with no trailing bytes. Source<=2MiB,
metadata<=16KiB, bounded parser scratch and all existing bake limits apply.
Importer ogb3.authoring/version1 and nonempty source_uri are explicit; an empty
source_revision is unavailable. Shared-bake identity fingerprints actual
types/bake/motion source. Load checks all versions/hashes, rebakes once, compares
semantic identity and canonical envelope. No Native memory/ABI/handles are stored.
Semantic bake identity survives equivalent scene order while exact source and
artifact identity correctly change. This is corruption checking, not authentication.

`artifact_inspect_json` returns one owning JSON buffer. Durable u64 IDs are exact
16hex strings, catalog IDs8hex; metadata includes source/import/schema/bake
identities/counts. Optional authored SHAPE preview delegates debug_preview (the
shared pure outline generator), no fake frame/stamp or Native world. Optional
Godot module methods and installation are in addons/box3d_authoring/tool_module.
