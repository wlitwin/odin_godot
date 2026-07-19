package kit_net

// kit/net — the friendslop toolkit's replication core (PURE Odin: no Godot imports,
// fully unit-testable headless — the engine-facing transport lives in kit/netgd).
//
// THE MODEL (see p:odin_godot/friendslop-toolkit-design for the full rationale):
// a command + owned-streams hybrid, NOT tick-rollback netcode.
//
//   * Peer-authoritative streams — state with a personal owner (your movement, your
//     aim) is authoritative on its owner and INTERPOLATED by everyone else. Nothing
//     to mispredict, nothing to resimulate. Sent as unreliable-sequenced snapshots
//     with LAST-VALUE semantics: a dropped packet is superseded by the next one.
//   * Host-authoritative commands — shared discrete state (chests, inventory, AI,
//     damage) mutates only through the intent→command→result pipeline. The SAME
//     command proc runs authoritatively on the host and (when declared predictable)
//     optimistically on the initiating client; prediction needs no hand-written
//     undo because the declared-field snapshot taken before the optimistic run is
//     the automatic revert.
//   * Transitions/effects ride the RELIABLE channel and are delivered exactly once
//     per peer; a predicted transition and its authoritative echo share an intent
//     id so confirmation MATCHES the already-played effect instead of replaying it.
//
// ONE PACKAGE, TWO LAYERS. What lives here is really two things fused under one
// name, and the fusion is DELIBERATE:
//
//   1. a shared REPLICATION SUBSTRATE — the wire, the field descriptors, the
//      codecs and blend math, the tick and clock. BOTH lanes consume it: the
//      coop lane below AND kit/sim (the server-authority resim lane, which is
//      its own package). The substrate has no name of its own.
//   2. the COOP LANE proper — the command + owned-streams model described above.
//      The substrate serves it but does not depend on it.
//
// A package split (substrate → its own package) was weighed and DEFERRED: the
// substrate stays nameless until a THIRD consumer earns the split. Two consumers
// is a shared header, not a library. This is why Field_Desc carries sim-only
// tuning fields (slack/glide/cut, whose comments open "kit/sim …") and why a
// couple of substrate symbols still sit in coop-lane files (below): the seam is
// named, not drawn. sim.md calls this the substrate LAYER of kit/net; net.md
// calls kit/net the coop replication core — both are this same package, this
// same fusion, seen from the two lanes that share it.
//
// SUBSTRATE — consumed by BOTH lanes (coop and kit/sim):
//   wire.odin    — bounds-checked little-endian Writer/Reader (the byte format).
//   delta.odin   — descriptor-driven dirty tracking: per-entity shadow copies,
//                  memcmp field masks, delta write/apply, full snapshot/restore.
//                  Also the field codecs (Wire_Kind) and interp blend math
//                  (Lerp_Kind, angle_arc/angle_lerp) both lanes encode/blend by.
//                  Replicated fields are POD-ONLY by design (ints/floats/bools/
//                  enums/fixed arrays) — strings & dynamic data travel as explicit
//                  reliable messages, never as replicated fields.
//   tick.odin    — the fixed net tick (decoupled from frame rate) + clock sync
//                  (Clock_Sync feeds both lanes' interpolation timelines).
//   net.odin     — the shared identity types (Net_Id, Player_Id) and the id-space
//                  contract (PROVISIONAL_BIT), owned beside the values they carve.
//
// COOP LANE — this model's own machinery (kit/sim does NOT consume these):
//   registry.odin — Net_Id → entity bookkeeping + the per-tick delta walk.
//   stream.odin   — owner-authoritative field streaming with delayed interp sampling.
//   intent.odin   — intent ids, per-peer dedup windows, the pending-prediction
//                   table with timeout → automatic revert.
//   command.odin  — the intent→command→result runtime loop.
//   edge.odin     — delta-lane change presentation (the <class>_<field>_edge halves).
//   later.odin    — the render-timeline delay queue (present on the eye's clock).
//
// The line isn't perfectly clean: kit/sim borrows quat_nlerp and the INTERP_CAP
// ring depth out of stream.odin (sharing the one nlerp/interp math rather than
// twinning it) and registry_bless out of registry.odin — small shared surfaces
// that are exactly the untidiness a future split would tidy. Named, not fixed.
//
// The generated side (scriptgen's gd:"replicate" / @(gd_command)) produces
// Entity_Desc tables and calls into this core; nothing here depends on
// codegen, so everything is testable with hand-built descriptors first.

// This package's wire revision — the substrate + coop-lane formats ONLY
// (field codecs, delta masks, stream batches, the command loop). Folded into
// the session's fingerprint salt beside every other package's rev, so a wire
// change here bumps a constant HERE, in the same commit. The coop delta
// mask's move to subset-ordinal bits (the phase-2 codec unification) will be
// rev 2.
WIRE_REV :: u64(2) // 1: the fingerprint-era wire as committed · 2: delta masks are subset-ordinal (delta-lane members only — one mask law with the sim codec; masks narrowed, bits renumbered on mixed-lane entities)

// Stable identity of a replicated entity across the session. Allocated by the host
// (authority) — never reused within a session. 0 is the invalid id.
Net_Id :: distinct u32

NET_ID_INVALID :: Net_Id(0)

// The high bit of the id space is RESERVED for kit/sim's client-local
// provisional spawns. Authority ids increment from 1 and never reach it;
// registry_insert refuses ids carrying the bit, so a leaked provisional can
// neither enter replication nor drag next_id past 2^31 via the insert chase.
// The constant lives HERE, beside the type whose value space it carves, so
// the contract has one owner; kit/sim aliases it.
PROVISIONAL_BIT :: u32(0x8000_0000)

// Transport-INDEPENDENT player identity: survives reconnects and (post-v1) host
// migration. Assigned at first join, reclaimed on reconnect; never derived from a
// connection/peer handle.
Player_Id :: distinct u64

PLAYER_ID_INVALID :: Player_Id(0)

// House rule, kit-wide: a composite map key is a STRUCT, never a packed
// integer. `u64(player) << 32 | id` silently truncated a u64 Player_Id twice
// (the session's interest pairs, xfer's assembly inbox) before the rule was
// written down — struct keys make the mistake unrepresentable.

