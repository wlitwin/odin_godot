# Visual cues

`Cues(Value)` consumes journal changes into a bounded set of visible instances.
Use copied presentation values: positions, colors, labels with fixed storage, or
asset handles. Reference-bearing payloads are rejected at initialization. A cue
does not retain a simulation entity or Godot node.

```odin
cues: view.Cues(Impact)
view.cues_init(&cues, epoch, baseline)
defer view.cues_destroy(&cues)

view.cues_advance(&cues, frame_seconds)
for change in changes {view.cues_change(&cues, change, 0.8)}
for cue in cues.slots {
    if !cue.active {continue}
    // Present cue.value with cue.key as the renderer's instance identity.
}
```

Begin creates an instance. Update changes its value in place; Confirm marks it
confirmed. Neither restarts its lifetime. Cancel hides it immediately. Repeated
Begin, including after cancellation or expiry, cannot replay a consumed ID.
The renderer reconciles active keys each frame, so canceled/expired instances
are removed and a recycled slot cannot inherit the previous node's identity.
`cues_change` returns true only for a new instance.

The default pool holds 128 instances. Allocation happens at initialization; frame
updates allocate nothing. A full pool drops the new visual and retains its consumed
ID, so later retries cannot unexpectedly play it. `stats` exposes drops, duplicates,
begins, updates, confirmations and cancellations. Serial exhaustion also drops
new visuals explicitly. These are cosmetic limits, not simulation failure modes.

`cues_clear` stops active instances while retaining consumed IDs. `cues_epoch`
accepts only a strictly newer epoch and resets the ledger to an explicit baseline.
Call `one_shots_retire(&cues.ledger, through)` with a monotonic frontier behind which
no new Begin can arrive; retain enough history for the runner's correction/watch
window. Queued confirmed changes may predate a same-epoch checkpoint rebase: consume
them before advancing the frontier past their ticks. Recreating an effect owner is
appropriate when leaving a session, not for an ordinary correction.

This helper tracks visual lifetimes, not deterministic particle trajectories or
irreversible sound/external effects. The journal still determines prediction and
confirmation policy. A renderer may move, recolor or remove an active effect, but
already displayed frames cannot be undone.
