# Inspecting and branching local history

`Debug_Scrubber` is an opt-in timeline dock for an offline developer workflow.
Pause, inspect a retained frame, and either resume the original future or start
an alternate branch. The widget reads frame copies and returns commands; the
application owns the clock, presentation and decision to replace its timeline.

```odin
// Init once at a stable address; destroy before its owner leaves the tree.
rgd.debug_scrubber_init(&scrubber, owner)

// Before advancing the local timeline:
switch rgd.debug_scrubber_frame(&scrubber, &timeline) {
case .Inspect: // Save prior pause state, pause the clock, discard device edges.
case .Resume: // Restore prior pause state, clear accumulated time/device edges.
case .Branch:
    frame, ok := rgd.debug_scrubber_read(&scrubber, &timeline)
    if ok {
        // Explicit application operation: initialize from this complete frame
        // under a new epoch, reset presentation at this tick, then leave inspection.
    }
case .Invalidated: // The source epoch/head changed; release the inspection pause.
case .None:
}

// While active, paint this value instead of the live head. Do not play its old
// one-shot events or feed its poses back into simulation.
frame, inspecting := rgd.debug_scrubber_read(&scrubber, &timeline)

rgd.debug_scrubber_end(&scrubber)     // Explicit reset/branch completion.
rgd.debug_scrubber_destroy(&scrubber) // Teardown, including signal callables.
```

F10 and the Pause/Resume button enter or leave inspection. Drag the slider or use
its ordinary keyboard controls to select a frame. Branch is a separate button.
Godot's `pressed` signal is latched, so a complete click between render frames
still reaches the application. Repeated clicks on the same button before a pump
coalesce. Keep the widget at a stable address until destroy disconnects callbacks.

The slider stores relative offsets within at most 4096 retained slots. It does
not convert absolute `u64` ticks to floating point. `replay.history_window` scans
bounded record metadata and includes the initial/corrected checkpoint. This differs
from an audit window, which requires known generating inputs and a preceding frame.
Tick zero, wrapped retention, nonzero checkpoints and the `u64` boundary are valid.

## Ownership and limits

The owner must exclusively pause its local timeline while inspecting. Epoch/head
changes invalidate the selection; the widget does not detect arbitrary same-head,
same-epoch replacement or concurrent mutation. Session, Room and P2P runners are
not paused, corrected or migrated by these controls. No network or administrative
authority is implied. Use the separate read-only diagnostic overlay on live peers.

Resume retains the original timeline and confirmation frontier. Branching is an
explicit local operation from a complete frame, including entity generations,
cooldowns and RNG. The application must start a new presentation epoch and seed
its journal at the branch tick; old effects must not be delivered again. This does
not undo already committed external effects. It is not network recovery or a save
format. The optional field editor below edits a copied local preview; the
[recording exporter](../diagnostic/recording.md) saves the original replayable suffix.

## Hello integration

Replay Hello enables the dock alongside `debug_enabled` / `REPLAY_DEBUG=1`.
F8 controls the older audit panel; the history dock remains available when that
panel is hidden. Ordinary launches allocate no debugging components.

The example preserves an existing pause on Resume, paints historical entity views,
and clears transient flashes when leaving inspection. Branching calls its existing
complete-frame reset under a fresh epoch. Gameplay input held during inspection
stays suppressed until released, preventing a slider/key gesture from leaking into
the resumed or branched simulation. Inspection creates no catch-up backlog.

Run `nix develop --command bash tests/replay_scrubber/run.sh` for the core-backed
native scene workflow, existing Hello/Loot regressions, rendered capture and WASM
check. The dedicated fixture preserves prepared inputs, binaries' hashes and driver
revisions. Broader editor workflows remain roadmap work.

The [recorded native/Chrome gate](../../docs/replay/results/history-inspection-2026-09-13/README.md)
also covers real browser keyboard, slider and button input with zero buffer-target
conflicts. Focused slider arrow keys intentionally change the selected tick; they
are not gameplay movement while inspecting. Browser acceptance checks held fire,
and native acceptance checks both held movement and fire. Hello's muzzle flash now
uses an immutable mesh to avoid the Polygon2D redraw issue exposed by this gate.

## Editing a preview

`Debug_Field_Editor(State)` adds a schema-derived field menu, value input, Apply
and Reset. Hello enables it with the history dock. Fields include array leaves,
entity IDs, counters, timers, enum names and authority-only values; the application
provides its state validator to reject broken relationships such as a pool count
that disagrees with its live slots.

```odin
editor: rgd.Debug_Field_Editor(game.World)
rgd.debug_field_editor_init(&editor, owner, game.network_state_valid)

// Before handling the scrubber action, including Branch:
action := rgd.debug_scrubber_frame(&scrubber, &timeline)
rgd.debug_field_editor_frame(&editor, &scrubber, &timeline)
frame, inspecting := rgd.debug_field_editor_read(&editor)
// Paint frame while inspecting. On Branch, accept this complete frame under a
// new epoch. On Resume/Invalidated, restore the previous pause and input guard.
// On explicit reset/branch completion:
rgd.debug_field_editor_end(&editor)
// At teardown, before freeing its owner:
rgd.debug_field_editor_destroy(&editor)
```

Apply validates a candidate, then replaces only the preview. The original frame,
retained timeline, confirmation frontier and journal stay unchanged. Reset restores
the selected original frame; selecting another tick or leaving inspection discards
edits. Branch uses the edited state with the selected original tick. Hello seeds a
new presentation epoch without playing old effects and preserves the prior pause.
The `dirty` flag means an edit was accepted since selection/reset, including an
accepted value equal to its original value.

Values accept exact booleans, decimal or `0x` integers, enum names or declared
numeric values, numeric bit masks, and finite floats. The input is limited to 128
characters. Overflow, malformed text, illegal flags, inactive union fields and
model-invalid candidates are rejected without changing the preview. Union tags
are inspectable but read-only: changing variants needs a complete valid value.
Single-field validation cannot perform a coordinated multi-field transaction.

The menu shows at most the first 2048 schema leaves and explicitly reports
truncation. Its search is supplied by Godot's ordinary dropdown. Large models can
build their own searchable editor on `schema.field_index`, `schema.scalar_text`
and `schema.edit_scalar`. These helpers do not alter schema fingerprints or wire
formats. The widget requires a complete authority schema and retains two frame
copies; Apply also allocates one canonical payload and a typed candidate. It is
intended for paused authoring, not a simulation tick or a live network peer.
