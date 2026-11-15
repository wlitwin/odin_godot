# Network profiles

A named network profile returns a `kboot.Network_Config` containing session and
simulation-lane settings. Choose a profile for the authority model, inspect or
override its fields, then pass the complete value to the generated attach procedure.
Attachment validates the session and lane configuration together.

```odin
cfg := kboot.network_profile(.Listen_Server_Action)
cfg.session.max_players = 4
cfg.lane.smooth_cut = 48
cfg.lane.rewind_max = 30

my_game_net_attach(self, kboot.Options{
	title = "MY GAME",
	env = "MY_GAME",
}, cfg)
```

`rewind_max` caps historical rewind for hit judgment. For each shooter, the
authority computes a tighter window from measured RTT and jitter, input margin,
snapshot cadence, and configured watch delay, with one cadence of
interpolation-phase slack. Until clock sampling is established, competitive
rewind judges the current state.

Omitting the third argument selects `.Friends_Coop`. Name the profile in game
code so the authority and timing choice is visible at the attachment call.

## Choose by authority model

| Profile | Use it for | What it assumes |
| --- | --- | --- |
| `.Friends_Coop` | Invited co-op, reliable shared state, owner-streamed movement | Players are allowed to author their own fast state. The host still validates shared commands. |
| `.Listen_Server_Action` | Player-hosted action games using server simulation and prediction | Clients send inputs; the listen host decides outcomes. The hosting player still controls the authority process. |
| `.Dedicated_Competitive` | An action game refereed by an avatarless server | Clients are adversarial and the authority runs on infrastructure they do not control. Every simulation input class must use `@(gd_input)` constraints or a semantic validator. |

Run `.Dedicated_Competitive` with `kboot.boot_serve` on trusted infrastructure.
Using that profile with `boot_host` still gives authority to the hosting player.
The application supplies encryption, account identity, moderation, deployment
policy, and game-specific command predicates.

The generated attach knows whether the game has a simulation lane and whether
all of its input classes have generated `@(gd_input)` constraints or an
authored validator. It refuses a dedicated profile with an unvalidated input
class before the network starts:

```odin
@(gd_input)
Player_Input :: struct {
	move: [2]i8 `gd:"range=-1:1"`,
}

@(gd_sample)
player_sample :: proc(self: ^Game, tick: u64, input: ^Player_Input) {
	// Read local controls.
}
```

Decoding reconstructs `Player_Input`; the generated sanitizer applies its
declared value constraints. Add a sample validator when validity depends on
several fields or game state.

<a id="defaults-at-a-glance"></a>

## Default timing and traffic budgets

All three profiles use bounded admission and the generated wire fingerprint
gate. Their main timing choices are:

| Profile | Session rate | Session interpolation | Sim / snapshot rate | History | Rewind limit | Future-input limit | Watched delay | Snapshot budget |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: |
| Friends co-op | 20 Hz | fixed 150 ms | 60 / 20 Hz | 128 ticks | 250 ms | 64 ticks | 100 ms | 64 KiB/recipient |
| Listen-server action | 20 Hz | adaptive 150–400 ms | 60 / 20 Hz | 128 ticks | 400 ms | 64 ticks | 100 ms | 32 KiB/recipient |
| Dedicated competitive | 20 Hz | adaptive 100–250 ms | 60 / 30 Hz | 128 ticks | 250 ms | 24 ticks | 67 ms | 24 KiB/recipient |

Authority-ingress budgets are token buckets; rates below are per seated peer
(`actions` is per stable player seat). The friends profile allows a two-second
reliable burst for loading/transfer spikes; the others are tighter:

| Profile | Reliable ingress | Stream ingress | Action ingress |
| --- | ---: | ---: | ---: |
| Friends co-op | 512 pkt/s, 2 MiB/s | 240 pkt/s, 2 MiB/s | 64 act/s, 256 KiB/s |
| Listen-server action | 256 pkt/s, 1 MiB/s | 240 pkt/s, 2 MiB/s | 60 act/s, 256 KiB/s |
| Dedicated competitive | 128 pkt/s, 512 KiB/s | 120 pkt/s, 1 MiB/s | 30 act/s, 128 KiB/s |

The dedicated profile also shortens command and join timeouts, requires a
bounded player count, and refuses `Session_Config.fingerprint =
ksess.FINGERPRINT_NONE`. Its tighter future-input limit reduces how far an
untrusted client can stamp work ahead of authority time.

The profiles deliberately leave co-op outbound `stream_budget = 0`: an
owner-stream budget requires a game-authored interest function. Simulation
snapshot budgets are safe without AOI and are enabled above; they prioritize
owned/stale rows and force a full row after deferral or AOI re-entry. Public
games should still install AOI. `traffic.stream` is the distinct bounded
client-to-authority ingress shown above.

<a id="supported-starting-envelopes"></a>

## Measured framework limits

`network_profile_envelope(profile)` reports the framework limits exercised by
the engine-free benchmark gate. Measure the complete game before treating these
limits as a deployment capacity: game logic, physics, engine nodes, transport
overhead, and hardware contribute additional cost.

| Profile | Players | Persistent replicated entities | Hot entities per recipient/tick | Predicted entities/client | Forced replay |
| --- | ---: | ---: | ---: | ---: | ---: |
| Friends co-op | 8 | 2,000 | 500 | 0 | 0 |
| Listen-server action | 8 | 2,000 | 500 | 128 | 8 ticks |
| Dedicated competitive | 8 | 2,000 | 500 | 512 | 8 ticks |

`tests/kitstress` measures server CPU, application egress bytes, session
resident/peak allocation, join/snapshot/resume cost, per-recipient AOI fanout,
and reconciliation cost at increasing sizes. Its optimized native reference
run exercises 2/100, 4/500, and 8/2,000 player/entity fanout cases plus
32/128/512 predicted entities. Its thresholds detect large cost regressions.
Repeat the measurement on deployment hardware and include the engine/game frame
before increasing the supported limits. “Hot” means dirty and inside one recipient's AOI in the same tick;
unchanged and out-of-interest entities are sparse and do not consume snapshot
rows.

<a id="overrides-remain-ordinary-fields"></a>

## Override profile values

`network_profile` fills every timing field, including booleans. Assign an
override on that returned value rather than relying on a lower-level
“zero means default” convention:

```odin
cfg := kboot.network_profile(.Listen_Server_Action)
cfg.session.interp_adapt = false
cfg.session.interp_delay = 0.12
cfg.lane.echo_inputs = true
cfg.lane.tolerance = 0.5
my_game_net_attach(self, opts, cfg)
```

The complete value is validated before `boot_attach` or `lane_init`. Validation
covers positive rates and durations, adaptive interpolation floor/ceiling,
bounded history indices, redundancy wire limits, the 31-tick watched-offset
ceiling, smoothing values, and trust-profile requirements. Predict-world input
echo also requires positive float tolerance; exact held-input comparison would
otherwise trigger reconciliation on nearly every snapshot.

Build overrides by editing a value returned from `network_profile`. A partial
`Network_Config{...}` literal is rejected rather than silently combining two
different default systems.

<a id="hand-wired-stacks"></a>

## Direct component setup

The generated `<game>_net_attach` wrapper is the usual entry point. A game
managing component lifetimes directly can configure the same settings before
attachment:

```odin
cfg := kboot.network_configure(
	&self.ses,
	kboot.network_profile(.Listen_Server_Action),
	kboot.Network_Capabilities{
		has_lane = true,
		all_inputs_validated = true,
	},
)
kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, opts)
my_game_lane_init(self, &self.lane, &self.ses, cfg = cfg.lane)
kboot.boot_lane(&self.boot, &self.lane)
```

`godot:kit/netcfg` contains the engine-free implementation and can be imported
directly for tooling or tests. `kit/boot` re-exports its game-facing types and
procedures so game scripts can use the `kboot` import for that setup.
