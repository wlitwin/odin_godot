# Configure physics timing and history

Choose history, prediction/repair ceilings, tick rate, and substeps in the shared
Box3D build profile. Then initialize Kit or Replay with matching timing. The
defaults remain 128 retained frames, 60 Hz, and four native substeps per tick.

This guide extends [Configure world capacities](capacities.md). The profile is
selected before building the backend and modules; changing it during a running
match would change the meaning of that match's history and is unsupported.

## Select the profile

Add timing fields to your game's `BOX3D_CAPACITY_PROFILE` JSON file. Omitted
fields keep their defaults. For example:

```json
{
  "history_frames": 256,
  "kit_repair_ticks": 16,
  "replay_prediction_ticks": 60,
  "replay_window_ticks": 64,
  "tick_hz": 120,
  "substeps": 3,
  "memory_bytes": 2147483648
}
```

Build and select this backend through the [ordinary profile workflow](capacities.md).
The SDK propagates matching compiler settings to Odin and the authoring addon.
The resolved profile uses schema version 2; capacity-only version-1 project
profiles are accepted and gain the default timing settings.

| Field | Default | Admitted settings |
| --- | --- | --- |
| `history_frames` | 128 | 32 through 1024; a power of two is not required |
| `kit_repair_ticks` | 8 | 1 through the smaller of 255 and `history_frames - 3` |
| `replay_prediction_ticks` | 30 | 4 through `replay_window_ticks` |
| `replay_window_ticks` | 32 | 4 through `history_frames - 3` |
| `tick_hz` | 60 | 1 through 240 for the managed frameworks |
| `substeps` | 4 | 1 through 128 |

These ranges follow the combined managed integration's storage, packet, and
runner constraints. They are not general limits on every upstream Box3D use.
Kit also checks the actual encoded input size against its per-message budget;
a larger resend/repair window can be refused for large driver controls.

## Initialize the selected framework

Generic Kit and Replay defaults remain useful for games that do not use a
complete physics participant. Select the physics helpers explicitly:

| Owner | Matching setup |
| --- | --- |
| Kit complete-world Lane | Pass `sim.world_lane_config_default()` as `cfg` to `sim.lane_init`, with `sim` importing `godot:kit/sim` |
| Local Replay complete Timeline | Pass `physics.timeline_config_default()` to `replay.init_complete`, with `physics` importing `godot:replay/physics` |
| Replay complete server/client | Use `net.physics_config_default()`, with `net` importing `godot:replay/net` |
| Replay Godot Session | Supply that network configuration through `Session_Options.network` |

The helpers select the build's history and tick rate. A complete participant
rejects a runner using different values. For a local Replay Timeline, change
the helper result's `events_per_tick` if the game's event capacity needs it.

Replay network runners can choose smaller active `max_prediction`,
`max_future`, and `max_rewind` values within the build ceiling and the ordinary
runner constraints. For example, this configuration procedure keeps prediction
at no more than twelve ticks:

```odin
import net "godot:replay/net"

physics_network_config :: proc() -> net.Config {
    cfg := net.physics_config_default()
    cfg.max_prediction = min(cfg.max_prediction, 12)
    cfg.max_future = cfg.max_prediction
    return cfg
}
```

Pass the returned configuration when opening the Session or runner. Kit's
selected build bound covers both prediction and ordinary repair; Lane lead and
snapshot settings must also fit that bound. Start with its helper before
adjusting those lower runtime settings.

## Keep the clock and movement rules consistent

The native `world_step_fixed` operation uses the selected `tick_hz` and
`substeps`. `box3d.FIXED_HZ`, `FIXED_SECONDS`, and `FIXED_SUBSTEPS` report those
same values. Character movement through either framework uses the same duration.

Kit and Replay schedule their own ticks when pumped from the application frame.
Keep one outer pump and let the selected owner perform its physics steps. An
offline loop that calls `world_step_fixed` once per Godot physics callback must
run that callback at the selected rate, or use an explicit fixed-step accumulator.
A 60 Hz callback calling a 120 Hz physics step once advances half a second of
simulation per real second.

Changing the rate can also change gameplay. Express speed per unit of simulated
time and advance it using the selected step, rather than assuming a fixed
distance per tick. A three-substep tick still consumes one gameplay input and
produces one simulation tick; the substeps are internal solver work.

## Size time windows and storage together

Ticks represent a different amount of time at different rates. Thirty predicted
ticks cover half a second at 60 Hz and a quarter second at 120 Hz. The example
profile uses sixty ticks at 120 Hz to preserve that half-second window.

Retaining H frames provides at most H-1 transitions without an earlier
checkpoint. The example's 256 frames at 120 Hz span 2.125 seconds between oldest
and newest frames. Longer history costs memory; a larger correction ceiling
permits more repeated simulation work in one operation. Measure both with the
game's contact density, geometry, and event workload.

The example also raises the memory allowance to 2 GiB. Kit preflights the
primitive reservations needed across a staged correction, in addition to
retained state. A larger repair window can therefore require more headroom even
in a small scene. Keep its stock reservation until the actual operation sizes
justify a workload-specific `Config.reservation_bytes` value in `kit/physics`.
Lowering it arbitrarily can make a candidate exceed its admitted reservation.

Counts, byte quotas, and timing remain separate settings. Raising history does
not raise `memory_bytes`, and a larger repair window does not authorize changes
to already settled history. Missing predecessors still require the framework's
explicit recovery path.

## Keep execution and compatibility contracts

One main-thread caller remains required. Configurable substeps do not enable
concurrent calls or extra simulation workers. Preserve the adapter's staged
state and lifetime rules when choosing a clock owner.

Timing fields participate in the shared native/Odin profile fingerprint and
framework compatibility contracts. Rebuild and distribute matching backends
and modules to all peers. Stop Godot before replacing its backend; see
[building](building.md). Older incompatible checkpoints and peers are rejected
through those contracts rather than being interpreted at a different rate.
