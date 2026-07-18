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
// WHAT LIVES WHERE:
//   wire.odin    — bounds-checked little-endian Writer/Reader (the byte format).
//   delta.odin   — descriptor-driven dirty tracking: per-entity shadow copies,
//                  memcmp field masks, delta write/apply, full snapshot/restore.
//                  Replicated fields are POD-ONLY by design (ints/floats/bools/
//                  enums/fixed arrays) — strings & dynamic data travel as explicit
//                  reliable messages, never as replicated fields.
//   intent.odin  — intent ids, per-peer dedup windows, the pending-prediction
//                  table with timeout → automatic revert.
//   tick.odin    — the fixed net tick (decoupled from frame rate) + clock sync.
//   interp.odin  — a typed convenience ring (Interp_Buffer($T)) for hand-driven
//                  interpolation. The REAL remote-entity path is stream.odin's
//                  Stream_Ring (warp serials, handoff seeding, per-kind blends);
//                  this one is the small generic sibling for game-side values.
//
// The generated side (scriptgen's gd:"replicate" / @(gd_command)) produces
// Entity_Desc tables and calls into this core; nothing here depends on
// codegen, so everything is testable with hand-built descriptors first.

// Stable identity of a replicated entity across the session. Allocated by the host
// (authority) — never reused within a session. 0 is the invalid id.
Net_Id :: distinct u32

NET_ID_INVALID :: Net_Id(0)

// Transport-INDEPENDENT player identity: survives reconnects and (post-v1) host
// migration. Assigned at first join, reclaimed on reconnect; never derived from a
// connection/peer handle.
Player_Id :: distinct u64

PLAYER_ID_INVALID :: Player_Id(0)

// Who owns (is authoritative for) a replicated entity's streamed state.
Ownership :: struct {
	owner: Player_Id, // PLAYER_ID_INVALID + host_owned=true => the world/host
	host_owned: bool,
}
