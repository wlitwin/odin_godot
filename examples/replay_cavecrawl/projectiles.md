# Rock presentation

Rock views now move between Cavecrawl's 20 Hz simulation ticks. The renderer reads
each live rock's current position and per-tick velocity, then previews up to one
tick (12 pixels) ahead using `view.Tick_Phase`. It stops the preview at the nearest
currently visible living body, excluding the shooter and corpses. This query is
visual only: it cannot damage a body, remove a rock or create an impact event.

Host, player and observer use the same bounded rule. Observers begin a fresh
phase when a snapshot head arrives; their unrelated local fixed clock is not used
to place a newly received rock ahead in time. A stalled head holds after
one tick; fencing/pausing stops the phase clock. Epoch and view-reset changes start
fresh phases. Rock membership and generation still come from the current frame,
so removal, rollback and pool reuse retain the existing node identity rules. Leave
clears the phase and scene instances.

The dot's Label is centered using its actual font minimum size, matching the
original tracer's center convention. Its authored yellow color is retained without
a second tint. These are presentation changes; C9/O3 content, simulation, recordings
and saves remain unchanged.

The original Kit tracer starts at render-time cast submission and emits visual
contact feedback immediately. Replay still begins a rock when its predicted or
authoritative simulation creates it, and C9/O3 impact events still drive feedback.
The bounded preview can therefore wait briefly at a contact for the next simulated
tick. Instant pre-tick casts/contact overlays remain a separate parity/latency
decision; this change does not claim identical projectile feel.
