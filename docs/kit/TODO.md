# Kit multiplayer hardening and ergonomics roadmap

This roadmap turns the multiplayer-framework review into verifiable work. It
preserves Kit's central design: games declare state, inputs, and verbs while the
framework owns transport, authority, prediction, and reconciliation. The co-op
and resimulation lanes remain separate execution models; their authoring surface
and hostile-input boundary converge through generated schema and admission data.

Status: `[ ]` pending, `[~]` in progress, `[x]` complete.

## Architectural direction

- [ ] Generate one package-level `Net_Schema` containing entity fields, input
  classes, verbs, access rules, scheduling mode, argument limits, facts, and
  protocol fingerprint material.
- [~] Express co-op and simulation verbs through one generated action descriptor.
  The runtime may still execute them differently (`immediate` versus `tick`), but
  authors should use one vocabulary for access, prediction, arguments, results,
  and consequences.
- [~] Put every client-originated action through one authority-ingress policy:
  seat/spectator checks, deduplication, entity access, size and semantic
  validation, plausible tick windows, rate budgets, rejection, and metrics.
- [ ] Keep role-specific work explicit only where it is genuinely different.
  Generated authority/everywhere passes and consequence hooks should replace
  routine role branches; documentation should not claim that all authority
  branches are inherently avoidable.
- [ ] Do not collapse the framework into a universal rollback ECS. Co-op state
  replication and authoritative resimulation have different correctness and
  scaling properties; a shared declaration/gateway layer gives the ergonomic
  win without hiding those differences.

## P0 — hostile-input and authority correctness

- [~] Harden simulation input admission.
  - [x] Reject tick-window overflow and inputs implausibly far ahead of the
    authority before they can occupy the de-jitter ring.
  - [x] Clear sample scratch before every generated/user sampler so omitted
    fields are neutral instead of stale.
  - [x] Generate and install a typed per-input validator/sanitizer hook from
    `@(gd_sample="validate[=PROC]")`; run it on local samples and transactionally
    across authority-received windows before any buffer mutation.
  - [ ] Add declarative field constraints for automatic ranges, finite floats,
    normalized vectors, and enum membership; keep the hook for game predicates.
  - [ ] Bound per-seat input classes and packet bytes, not just each window.
- [~] Harden simulation command admission.
  - [x] Reject sequence zero and deduplicate/replay-protect per player.
  - [x] Bound encoded arguments and future scheduling; reject invalid requests
    explicitly instead of letting them time out.
  - [x] Re-check seat, spectator, ownership, entity, and verb access at execution
    time, because reliable traffic can outlive an ownership or roster change.
  - [x] Purge queued commands on player departure and entity untrack/despawn.
  - [ ] Add per-seat command rate/byte budgets and escalation hooks for abuse.
- [~] Validate snapshot acknowledgements before using them as delta baselines or
  lag-compensation evidence.
  - [x] Track the snapshots actually issued to each player and reject future,
    pre-join, misaligned, or regressing acknowledgements.
  - [x] Bound accepted acknowledgement age and expose rejection telemetry.
  - [ ] Derive the competitive rewind envelope from server-observed RTT/jitter
    and issued snapshots; treat the client render offset as a bounded hint, not
    proof of what was visible.
- [x] Make malformed reliable replication transactional. Decode/stage a whole
  entity update before mutating live state, or force an explicit full resync;
  never bless a partially applied delta as the sender's new shadow baseline.
- [~] Enforce co-op authority policy at ingress.
  - [x] Route client owner streams through the host gateway, verify every row's
    sender against authoritative ownership, and reject direct peer streams.
  - [x] Give co-op commands explicit generated access (`owner`, `any_seat`,
    `authority`) and enforce it independently of the command predicate.
  - [ ] Add per-peer reliable/unreliable traffic budgets and kick/report hooks.

## P1 — wire and configuration invariants

- [ ] Define a recursive canonical wire ABI and fingerprint it.
  - [ ] Reject or canonically encode platform-width `int`/`uint`, implicit-width
    enums, pointers, padding-dependent nested structs, and other target-sensitive
    fields in every networked declaration (not only direct command arguments).
  - [ ] Hash canonical field paths, wire kinds, widths, enum representations,
    bounds, access policy, and action scheduling into the protocol fingerprint.
  - [ ] Add cross-target/version fixtures proving equal fingerprints imply equal
    bytes and incompatible schemas fail the session handshake.
- [~] Validate lane configuration as one coherent set.
  - [x] Keep redundancy within the receiver and `u8` wire caps.
  - [x] Keep rewind, watch delay, command/input lead, and snapshot cadence within
    the ring horizon; reject negative values instead of silently defaulting them.
  - [x] Assert every `u8`/`u16` count and payload before conversion, including
    input classes, echo rows, snapshot full rows, and entity counts.
- [ ] Add protocol-wide packet/field/container byte ceilings before allocation,
  including profile, message, fact, command, and replication payloads.
- [ ] Add fuzz/property tests for every decoder and state machine. Invariants:
  no panic, bounded allocation/work, no partial committed mutation after error,
  monotonic acknowledgement state, and deterministic replay.

## P1 — ergonomic authoring surface

- [ ] Add first-class input constraints to `@(gd_input)` and generated typed
  sanitizers, with safe defaults and actionable compile-time errors.
- [~] Replace stringly command modes with a typed/declarative action policy while
  retaining concise annotations for the common owner-only case. Runtime and
  generated descriptors now share `Command_Access`; annotation parsing remains.
- [ ] Generate typed entity references/indexes (`Net_Ref(T)`, owner queries,
  tracked iteration) so games do not repeatedly scan or hand-cast registries.
- [ ] Generate named, validated network profiles (friends co-op, listen-server
  action, dedicated competitive) that set coherent lanes, rates, history, and
  hardening defaults; allow explicit overrides with validation.
- [ ] Simplify lifecycle setup into one generated game-network façade that owns
  session, registry, lane, event forwarding, ownership changes, and teardown.
  Keep the lower-level pieces available for advanced games.
- [ ] Make rejection observable through typed outcomes/callbacks for both co-op
  and tick-scheduled actions; distinguish access, rate, malformed, stale,
  predicate, and timeout in diagnostics without exposing protocol plumbing in
  normal gameplay code.
- [ ] Update examples and documentation to describe trust profiles precisely:
  invited-peer co-op, listen-server authority, and adversarial dedicated-server
  play are different guarantees.

## P2 — scale and operations

- [ ] Add simulation interest management/AOI and per-recipient snapshot byte
  budgets. Unchanged predicted entities currently still cost a row every batch.
- [ ] Add dirty/change suppression or chunked keyframes without weakening the
  acknowledgement-baseline recovery invariant.
- [ ] Expose a unified netgraph: packet/byte rates, malformed/policy/rate drops,
  input lead and gaps, ack age, rewind depth/clamps, resim ticks/cost, command
  queue/rejections, snapshot full/delta ratios, and AOI pressure.
- [ ] Add structured disconnect reasons and production logging hooks that do not
  allocate unbounded attacker-controlled text.
- [ ] Benchmark server CPU, bandwidth, memory, and resimulation at increasing
  player/entity counts; turn results into supported profile envelopes.

## Verification gates

- [x] Pure `kit/net`, `kit/session`, `kit/sim`, and stress suites pass.
- [x] Generated-authoring (`tests/repgen`) contracts pass on native and web
  targets where applicable.
- [x] Real ENet two-peer (`tests/kitsync`) replication and optimistic actions pass.
- [x] Quickdraw and Speedball native three-process latency/loss gates pass,
  including rewind, resimulation, predicted actions, spawns, and multiple input
  classes.
- [~] New adversarial fixtures cover duplicate/zero commands, oversized args,
  future ticks, leave/untrack races, forged snapshot acks/render offsets, input
  overflow/future windows, malformed transactional deltas, and traffic budgets.
  - [x] Simulation commands, snapshot evidence, and input tick windows.
  - [x] Transactional co-op delta/full rows, forged owner streams, co-op command
    access, and semantic input windows.
  - [ ] Traffic budgets.
- [x] Scrapyard runs as the integration consumer for the unified API migration.
  - [x] Its 16 generated script classes compile against this working tree.
  - [x] Its full 21-act multiplayer acid suite passes against this working tree
    at 120 ms injected one-way latency, including dedicated authority, host
    succession, lag compensation, streams, commands, and stress traffic.
