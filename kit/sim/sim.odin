package kit_sim

// kit/sim — the server-authority resim companion (engine-free core).
//
// The friendslop toolkit (kit/net + kit/session) is deliberately NOT rollback
// netcode: owner streams never mispredict, host deltas apply on arrival, and
// the price is the two-timelines presentation discipline. This package is the
// OTHER model, for the games that need it — contested, cheat-resistant,
// inputs-only-up — built as a third lane BESIDE the existing two rather than
// a replacement:
//
//   field tag                authority      wire                      applied by
//   replicate                host           reliable deltas           on arrival
//   replicate,owner          owning peer    unreliable stream         interpolated in the past
//   replicate,predict        server sim     tick-stamped snapshots    rollback + resim
//
// .Predicted fields are excluded from the host delta walk at the mask level
// (kit/net diff_mask), exactly like .Owner_Stream — the lanes can never fight
// over a field. Slow discrete state (chests, inventory, roster, blobs, stats)
// keeps riding the session's delta walk and command loop unchanged; only the
// contested fast state (movement, projectiles) opts into this lane. A hybrid
// game composes per-field.
//
// The model: ONE authority (the server), a fixed simulation tick, and clients
// that run AHEAD of the server by an adaptive lead so their input for tick T
// arrives just before the server simulates T. Gameplay for this lane lives in
// tick procs — pure functions of (predicted fields, input, sim queries) that
// both sides run: the server authoritatively, the client speculatively. When
// authoritative state for tick T arrives, the client compares its own
// prediction AT T (memcmp — the house idiom); a match costs nothing and skips
// resim (the common case), a mismatch restores the predict set to truth and
// replays T+1..head from the stored input ring. Mispredictions self-heal at
// the next snapshot, which is why NO cross-machine float determinism is
// required — approximate re-execution suffices; the server's word is final.
//
// The pieces, all engine-free and headless-testable like kit/net:
//
//   history.odin    predict-subset capture/restore + the tick-indexed History
//                   ring (client predicted states, server truth for lag comp —
//                   play.Trail's contract, descriptor-driven)
//   input.odin      the input pipeline: client ring + redundant unreliable
//                   packets (loss story is redundancy, not retransmit) +
//                   server per-player de-jitter buffer with hold-last
//   tick.odin       the fixed sim ticker with a timescale nudge, and the
//                   adaptive lead controller fed by knet.Clock_Sync
//   reconcile.odin  the compare → restore → resim driver
//
// What this package deliberately does NOT do (yet): wire formats for snapshot
// batches, session integration, scriptgen surfaces (gd:"input", @(gd_tick),
// the predict tag), lag-comp query scoping, render-error smoothing. Those are
// the later phases; this file set is the substrate they all stand on.
//
// The design is recorded in the project knowledge doc
// server-authority-resim-companion (p: odin_godot).

import knet "godot:kit/net"

// The sim tick rate this lane defaults to. Distinct from knet.DEFAULT_TICK_HZ
// (20 — the WIRE pacing of the coop model): a resim lane ticks at gameplay
// rate because the tick IS the simulation.
DEFAULT_SIM_HZ :: 60

// Convenience re-exports so games touching only the sim lane read one prefix.
Net_Id :: knet.Net_Id
Entity_Desc :: knet.Entity_Desc
