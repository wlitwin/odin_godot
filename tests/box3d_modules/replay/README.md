# P4 Replay ownership support checks

These focused checks exercise the concrete native C ABI and `box3d/godot/host`
registry with explicitly fake Core execution/procedure-membership hooks. They are
not substitutes for Root's actual Godot two-module source-free/reload tests.
No test here certifies the still-unmet whole-call4ms Gate B requirement.

- The parent test package covers native domain/layout/ledger bindings and generic
  CompleteCheckpoint/Timeline ownership. Heap source objects are actually freed;
  separately retained allocator contexts remain live through event/container
  cleanup. Wrong realm/unprotected access rejects before touching typed state;
  declined final data drop leaves a cleanup-only tombstone, without double free.
- `guard/` is compiled with strict domain plus verified expected build/target.
  Pre-install native use rejects; Snapshot/Catalog/Geometry/World ownership is
  preserved on denied release. The expected-mismatch variant rejects even when
  the actual native cookie is otherwise valid.
- `capsule/` uses the real host registry to clone/destroy an origin-owned generic
  complete checkpoint after actual source destruction, keeping event allocator
  data alive through the entire typed destructor and Core return boundary.
- `provider/` is a strict SDK composition using a retained Meter allocator and
  explicit independent owner. It exercises real fixed steps, early command
  failure/child-budget cleanup, C-shaped physics capsule body reads/dump/digests,
  native-only restore, clone/destroy, cross-producer budget rejection, and exact
  block-leased Timeline user data. It frees the source user block before calls;
  actual free waits for the separate user owner. All counts return to zero.
- `codec/` uses an explicit managed codec-context lease and a separate allocator
  owner. Releasing the actual source reference does not free the codec while
  wire/TF budget callbacks own bytes. Busy refusal preserves it; final whole
  cleanup releases the actual managed allocation.

Strict compilation requires `BOX3D_REQUIRE_DOMAIN=true`, the current library,
`BOX3D_EXPECTED_BUILD` and `BOX3D_EXPECTED_TARGET` from verified native metadata.
The ABI uses one shared native domain. Static linkage is permitted only for
standalone focused tests; deployment acceptance inspects the actual shared image.
Use `-define:ODIN_TEST_THREADS=1` for native tests.

Public composition points:

```odin
// Optional concrete provider; pure Core/Owner import never activates this.
owner, err := ph.owner_context_create(
    meter.data_lease(meter_context),
    allocator_data = meter.allocator(meter_context).data,
    require_live_instance = false,
)
cp, err := ph.checkpoint_make(frame, Event, world, config,
    allocator = meter.allocator(meter_context), ownership = owner)
cap, err := ph.checkpoint_capsule_create(&cp, service,
    allocator = meter.allocator(meter_context))
```

`Owner_Context` runtime metadata is excluded from canonical config/game identity.
A callback user distinct from allocator data requires its own explicit retained
`user_owner` plus `user_data` in `r.init_complete`. A block lease requires exact
allocation base/size and exact validated alias; membership is not ownership.
Raw scene userdata cannot be disguised as a retained heap context.

Physics capsule operation ABI (process-local C POD only):

| Operation | Number | Args |
| --- | --- | --- |
| Destroy |0|Core Capsule.destroy callback|
| Clone |1|bg.Capsule_Clone_Args, out Capsule*|
| Cached body |0x100|key:u64, out Body_State* (native80B POD)|
| Normalized dump |0x101|bytes:u8*, capacity:u64, required:u64*|
| Solver digests |0x102|out World_Digests* (two u64)|
| Native-only restore |0x103|borrowed world:u32, reserved:u32=0|

Native-only restore does **not** restore/publish Game/Side/occurrences. Canonical
framework recovery is required for those. Opaque Capsule32B may be transferred as
TEST ONLY process-local bytes through Godot if ownership transfers exactly once;
cloning produces a second independent owner. No typed Odin checkpoint, allocator,
procedure userdata layout, slice or typeid crosses a module by value. Capsule
invoke/destroy callbacks must remain the actual stable Core entrypoints.

`runner/` extends the real-host fixture through the existing complete Server,
Client, durable Checkpoint, recovery and transfer objects. Both model-containing
allocations are actually freed by their source before pumping; explicit model
subfield block leases defer physical free through whole teardown. It compares
canonical solver bytes and Game, closes both source runtimes, decodes a detached
archive and restores/steps a new Server. The transfer Sender/Receiver source
blocks are also freed before packet updates. Missing user/accept contexts,
failed replacement admission and declined final data release preserve owners;
cleanup-only tombstones retry without repeating payload release. This fixture
uses a context-free test transport shim and fake Core hooks, not Godot Session.

Runtime ownership arguments are append-only and excluded from wire schemas:

- `server_init[_complete]`, `client_init`, `server_restore`: `Runner_Ownership`
  contains exact allocator/model/wire/permit/profile/identity/admission contexts.
  The model context must explicitly lease `&server.model` / `&client.model`.
- `Model.user_context` and `action_admission_context` separately own nonnil raw
  application pointers. Allocator ownership cannot stand in for either pointer.
- `Complete_Codec.ownership` and `Container_Ownership` declare allocator and exact
  `data_context`. The concrete provider populates these from its retained owners.
  Reusable `checkpoint_codec_init` also requires an explicit codec block context.
- Detached `Checkpoint`, `Complete_Data` and `Complete_View` retain whole code,
  allocator and codec ownership. Use `checkpoint_encode_owned` for detached
  bytes. Raw `checkpoint_encode` output remains caller-allocator-owned and must
  be freed while that allocator/context is retained by the caller.
- Transfer `Ownership` declares allocator/container/wire/accept/schema/budget
  contexts. Recovery `Receiver_Ownership` additionally declares model/policy and
  reusable codec contexts. A borrowed schema needs its own explicit owner.

Strict complete mode rejects absent metadata before allocating containers or
calling the corresponding raw user callback. Standalone zero-owner behavior is
unchanged. Automatic Godot Session/Migration_Link/Prepared forwarding is P4.2;
this support does not claim those high-level SDK wrappers are integrated.

Expected native flags use `BOX3D_EXPECTED_BUILD=sha256:<64hex>` and
`BOX3D_EXPECTED_TARGET=sha256:<64hex>` to prevent Odin interpreting a digest that
starts with numeric/exponent characters as a number. Already typed raw64 strings
remain compatible. The expected hashes come from native build metadata.
