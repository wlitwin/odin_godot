# Own an authored complete-physics Session

Use `Authored_Session(State, Control, Action, Event, Seats)` for the standard
Godot/Replay path. It owns the metered storage, exact callback leases, source
bake/build, complete codec, startup checkpoint and Session. Gameplay still uses
the existing Session API.

```odin
import physics "godot:replay/godot/physics"
import rgd "godot:replay/godot"

options := physics.authored_options(.Host)
options.port = 49742
report := physics.authored_open(
    &self.physics, authored_world, model(), initial_game, rules(), options,
)
if report.error != .None { /* report and close/retry as needed */ }

session := physics.authored_session(&self.physics) // guarded, borrowed
// Existing session_frame, changes, issue, checkpoint and presentation APIs.

error := physics.authored_close(&self.physics)
```

The game's model leaves `complete_codec` empty. `initial_game` synchronously maps
the borrowed bake/build to pointer-free game values; do not retain either input
pointer. The catalog profile defaults to the baked content ID, with an explicit
`profile` override when the game's persistence policy needs one. Rules, role,
transport and network choices stay explicit. Managed complete physics currently
requires Enet/Rtc and a network role; Solo/Steam are rejected before allocation.

Raw model users, permits, RTC authorization and other application callback
contexts still require their existing explicit ownership. The wrapper supplies
only its allocator/container capabilities; it does not infer ownership of a raw
application pointer.

`authored_checkpoint` provides one managed temporary checkpoint. Its pointer is
borrowed until `authored_checkpoint_release`, the next capture, or close. A refused
release stays in the owner for retry. Clone explicitly through Replay's existing
API for an independently owned checkpoint, using `authored_allocator` for the
matching allocator. Such a clone can outlive the source Session and scene.

`authored_data` exposes guarded borrowed Session/codec access for advanced
presentation and diagnostics. These borrows expire on successful close; do not
mutate the owner's private bake, checkpoint, or ownership bookkeeping.

Opening publishes readiness last. Setup reports copy paths and messages before
rollback, including cleanup failure. Close stops the Session before releasing
checkpoints, codec, catalog and storage. A failed close preserves the owner;
retry after the active callback or dependent operation finishes. A close request
during initialization cancels it once the synchronous callback returns.

Keep this owner through temporary tree exit/re-entry. Use checked explicit close
for pending work and `finalize` for terminal cleanup; queue node destruction
outside active callbacks. Do not discard a failed-close owner. No empty reload
hook is needed for state containing allocator/catalog callbacks.

The [authored example](../../../examples/replay_box3d_authoring/README.md) keeps
its qualification telemetry separate from this runtime ownership layer.
