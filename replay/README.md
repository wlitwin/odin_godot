# Replay: an experimental simulation-first library

Replay runs gameplay rules against a complete Odin world that can be saved and
replayed. Use it when local simulation, prediction or recovery needs to reproduce
a game's state from recorded inputs. It lives beside Kit and uses its own
replication, simulation and session runtimes. Keep both implementations and both
versions of each ported game available.

Replay implements local simulation, server-authoritative prediction/reconciliation,
cooperative owner streams, and deterministic P2P rollback. Its shared foundations
include bounded typed history, entity pools and random-number generators,
canonical codecs, presentation
journals, recipient views, checkpoints, durable enrollment and host migration.
Godot owns scenes/input/output; the simulation packages run without Godot.

Start with [getting started](getting-started.md), the
[Session starter project](../build/template/replay/README.md), and the
[checked lifecycle recipes](../examples/replay_recipes/README.md). Most games
need one Timeline, Session or Room runtime owner. The package reference below
also includes optional advanced mechanisms and tools. Kit (v1)
and Replay (v2) share [Odin/API conventions](../docs/authoring-guide.md#api-conventions-shared-by-kit-and-replay)
while retaining their different gameplay models.

The library remains experimental. Use the [framework completion audit](../docs/replay/framework-audit.md)
to distinguish implemented contracts, tested combinations and remaining framework
work. Full parity across every ported game is not its completion gate.

- [Roadmap and implementation plan](../docs/replay/roadmap.md)
- [Getting started and choosing a runner](getting-started.md)
- [Compatibility and upgrade policy](compatibility.md)
- [Experimental support and release assessment](support.md)
- [Architecture and current API](../docs/replay/architecture.md)
- [Game ports and comparison protocol](../docs/replay/comparison.md)
- [Runnable loot example](../examples/replay_loot/README.md)
- [Godot Hello and Loot scenes](../examples/replay_hello/README.md)
- [Presentation contract](view/README.md)
- [Explicit event folding](event_folding.md)
- [Implementation progress](../docs/replay/progress.md)
- [Editor authoring workflow and tools](editor/README.md)
- [Typed scene adapters and view declarations](godot/scene/adapter-bindings.md)
- [Authored archetypes and scene ownership](godot/scene/archetypes.md)
- [Revision freezing and explicit conversion](evolution/README.md)
- [Reusable feature scenarios](testing/README.md)
- [Canonical schema/codecs](schema/README.md)
- [Typed action/event/state unions](schema/unions.md)
- [Owned audit captures and field diagnostics](diagnostics.md)
- [Portable local gameplay recordings](diagnostic/recording.md)
- [Network simulation recordings](net/recording.md)
- [Session round-trip telemetry](telemetry/README.md)
- [Transports and ENet gate](transport/README.md)
- [Server/client runner](net/README.md)
- [Canonical delta codec](delta/README.md)
- [Replay Cavecrawl port](../examples/replay_cavecrawl/README.md)
- [Replay Quickdraw competitive slice](../examples/replay_quickdraw/README.md)
- [Replay Speedball contested-pitch slice](../examples/replay_speedball/README.md)
- [Replay Claimball scoped-prediction slice](../examples/replay_claimball/README.md)
- [Prediction groups and boundary values](net/groups.md)
- [Initial deterministic P2P runner](p2p/README.md)
- [Durable fixed-roster P2P provisioning](p2p/provision/README.md)
- [P2P party client and signaling integration](godot/p2p_party.md)
- [Authenticated native two-player P2P](godot/p2p_direct.md)
- [Deterministic arithmetic and duel](deterministic/README.md)
- [Gameplay motion/query helpers](play/README.md)
- [Aim context and historical collision queries](net/view_time.md)
- [Godot session facade](godot/README.md)
- [Durable checkpoints and recovery contract](../docs/replay/recovery.md)
- [Explicit checkpoint conversion](net/checkpoint_upgrade.md)
- [Trusted checkpoint replication](recovery/README.md)
- [Authority decisions and lease enforcement](authority/README.md)

From the repository root:

```sh
nix develop --command bash tests/replay/run.sh
nix develop --command bash tests/replay_view/run.sh
nix develop --command bash examples/replay_hello/run.sh
nix develop --command bash examples/replay_loot/run.sh
```

The test gate runs native tests, type-checks the instantiated example for WASM,
and executes the example. It is also registered in `tests/run_all.sh`.

<a id="the-contract"></a>

## World state and step requirements

```odin
import replay "godot:replay"

World :: struct {position: i32, rng: replay.Rng}
Input :: struct {move: i8}
Event :: struct {position: i32}

step :: proc(world: ^World, input: Input, ctx: ^replay.Step(Event)) {
    world.position += i32(input.move)
}

// Application initialization:
timeline: replay.Timeline(World, Input, Event)
err := replay.init(&timeline, replay.Frame(World){}, step)
// Check err, advance with typed inputs, copy frames for presentation, and destroy.
```

Store all mutable gameplay state in `World`, including RNG, cooldowns,
scheduled work, entity lifetime, and entity allocation. A step can modify several
entities directly. Read device input before calling `advance`. Draw from copies
returned by `current` or `read`; presentation never writes into simulation.

The value-storage implementation supports scalars, enums, bit sets, fixed
arrays, ordinary structs, and supported tagged unions containing those values.
Initialization recursively rejects pointers, slices, strings, maps, procedures,
and other unsupported types.
Struct padding is allowed: frames copy typed values within one process; they
are not wire packets. Canonical wire codecs live in `replay/schema`; dynamic
collections remain future storage work.

Treat a live `Timeline` as a single owner of allocations: keep it in one place,
pass it by pointer, and call `destroy` once. Frame and event reads return/copy
owned values. Pool pointers and step contexts are borrowed for the current step.

<a id="present-limits"></a>

## Current capabilities and limits

- Room has native/browser planned/crash migration, returned-host, repeated-handoff,
  control-partition and successor-loss evidence. Owner-driven co-op and native/
  browser P2P have separate contracts. These tests establish bounded scenarios,
  not arbitrary public reachability or platform coverage. Steam has contract tests;
  live-account acceptance remains separate.
- Server snapshots use acknowledged deltas, negotiated compression and full-state
  recovery. Prediction groups and recipient views are authored policies: the
  framework validates their declared invariants, not arbitrary gameplay dependencies.
- `revise_input` supplies an explicitly corrected input batch; it is not a network
  protocol and does not decide whose input or state is authoritative.
- Initializing another timeline from a saved `Frame` proves in-process resume.
  Its epoch only scopes event IDs; it does not elect a host or reject packets.
- Events have speculative/confirmed/watched presentation and cancellation/update
  delivery. Committed external effects/outboxes remain future work. Do not play
  effects directly from a step.
- `audit` reports the first differing tick. `audit_capture` retains the exact
  mismatch; canonical schema diagnostics identify differing fields. Local audit
  does not prove arbitrary game code deterministic across platforms. P2P has
  separate recorded-corpus cross-target checks.
- Whole frames and replay scratch are copied. This deliberately prioritizes
  correctness while the API is explored; scale claims require measurements.

The API is experimental. Use the framework audit and each package's tested
configurations to assess support. Historical game-parity records compare
individual ports; they are not a checklist of missing framework features.

## Optional exact correction reuse

`correct_reusing(timeline, truth, events[, rewrite])` returns the ordinary Result
and a separate reused-record count. It validates the same checkpoint/event/history
conditions as `correct`, calls the rewriter for every visited suffix input, and
publishes atomically. When the complete predecessor state and rewritten input are
byte-identical to their recorded counterparts, the existing record is retained;
its state/events need no simulation or copying. Changed inputs and state continue
through normal simulation, and reuse may resume after exact convergence.

This requires a deterministic step with all mutable dependencies in State/Input
and unchanged external configuration/callbacks. It is explicit and opt-in. Padding
may conservatively prevent reuse; byte comparison also distinguishes signed zero.
The ordinary `correct` and audit paths still execute the whole suffix. Audit never
trusts reused records as proof of determinism. Result.steps remains the processed
suffix span; subtract the separately returned count for simulated correction steps.
A failed call returns zero reuse and leaves published state/input/events unchanged.
