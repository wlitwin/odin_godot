# Replay starter

This starter uses a value-only World and needs no Box3D backend. The installed
addon and Odin compiler are sufficient. See the
[Session setup](https://wlitwin.github.io/odin_godot/replay/godot.html) for the
checkout workflow; native physics has its own optional backend setup.

This is a separate optional starter for the experimental `godot:replay` library.
It does not replace the addon's ordinary Hello template or the Kit framework.
Copy this directory's contents into a **new** project root containing the installed
`addons/odin_godot` folder. The project includes its scene and pure gameplay model.

You can open the copied installed starter before its first build. Its authoring
dock is included, and reports that the first build is needed. Build through
**Project → Tools → Build Odin Scripts**, or with the packaged helpers:

```sh
SKIP_CORE=1 bash addons/odin_godot/build/build_scripts.sh .
```

Open the project in Godot and run `main.tscn`. Arrows move; Space takes the center
coin when close enough. The coin and both bags belong to one World, the value
that holds mutable simulation state. A step transfers the coin atomically.
The same model runs offline or with a server:

```sh
# Separate terminals, native ENet on the same machine:
REPLAY_STARTER_ROLE=host godot --path .
REPLAY_STARTER_ROLE=client godot --path .
REPLAY_STARTER_ROLE=observer godot --path .
```

`godot` above is your Godot executable. Default role is `solo`, port 49480 and
address `127.0.0.1`; override `REPLAY_STARTER_PORT` / `REPLAY_STARTER_ADDRESS` for
other native setups. These commands are a local networking example, not a public
matchmaking/NAT solution. Browser exports run the default offline model; networked
browser deployment requires an RTC/Party configuration supplied by your game.

Edit `data/pickup.tres` in the Inspector to change pickup reach. The **Replay**
dock offers **Save & Validate Pickup** and **Open Pickup Preview**. Run the
preview scene with F6; its reach guide updates when you refresh the saved
definition, and invalid edits leave the last valid preview visible. The first
build supplies local tool paths to the included dock; it becomes usable without
toggling the plugin or restarting the editor. No project-specific Python worker
is needed. Checkout-based projects install the dock through the normal build.
The authoring process tools currently target macOS/Linux with Python; the
gameplay model and its exports remain platform-independent.

`entities/pickup.tscn` is the authored coin. Its `PickupDef` Resource is checked
by one extractor in `scripts/pickup_def.odin`, shared by preview, validation and
game startup. Startup copies the checked reach into World before opening Session.
Resource edits do not change a running match; a new run admits the new value.
The content fingerprint includes those rules so incompatible peers are refused.

Edit `shared/game/game.odin` for simulation rules. It has no Godot objects or I/O.
`scripts/starter.odin` owns Session, samples input, and displays frames: retained
copies of the World at individual ticks. Keep scene effects outside the simulation.
`scripts/effects.odin` turns the pickup occurrence into a short colored flash and
a sound. The visual follows the journal and can be canceled; the sound waits for
confirmation. Both routes keep the original occurrence identity, so correction
does not play the same event twice. Replace `effects/pickup.tscn` or `pickup.wav`
to customize the presentation. Routes and the audio stream are released by the
script's `finalize` hook.
If startup fails, the status label and Output include the configuration field,
missing model callback, or schema path to fix. Read `session_setup_message` in
your own startup error handler; the underlying error enum is still returned.
See the [pickup recipe](https://wlitwin.github.io/odin_godot/replay/presentation.html)
for projection, animation, cancellation, and safe retirement of consumed IDs.

Build artifacts and generated scripts remain in your project, not in the addon.
The installed `addons/odin_godot/docs/replay.md` guide describes the model,
supported configurations and more advanced components. The project is intentionally
small; it does not claim host migration, persistence or competitive rollback merely
because those library packages are present.
