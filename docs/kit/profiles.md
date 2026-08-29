# Network profiles

Kit's named network profiles configure the session and simulation lane as one
validated unit. They are starting points, not hidden modes: a profile returns an
ordinary `kboot.Network_Config`, so the game can inspect and override every
field before attaching.

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

`rewind_max` is an absolute gameplay ceiling, not automatic credit granted to
every client. For each shooter the authority derives a tighter live envelope
from its measured RTT/jitter, input margin, snapshot cadence, and configured
watch delay (with one cadence of interpolation-phase slack). Until that clock
sample is warm, competitive rewind judges live.

Omitting the third argument is exactly `.Friends_Coop`. Prefer naming the
profile in production game code because it records the intended trust and
latency model where the stack is attached.

## Choose by authority model

| Profile | Use it for | What it assumes |
| --- | --- | --- |
| `.Friends_Coop` | Invited co-op, reliable shared state, owner-streamed movement | Players are allowed to author their own fast state. The host still validates shared commands. |
| `.Listen_Server_Action` | Player-hosted action games using server simulation and prediction | Clients send inputs; the listen host decides outcomes. The hosting player still controls the authority process. |
| `.Dedicated_Competitive` | An action game refereed by an avatarless server | Clients are adversarial and the authority runs on infrastructure they do not control. Every simulation input class must use `@(gd_input)` constraints or a semantic validator. |

A profile does not create a trust boundary. `.Dedicated_Competitive` only has
that meaning when the authority is actually started with `kboot.boot_serve` on
a trusted machine. Running the same configuration through `boot_host` is still
a listen server. Encryption, account identity, moderation, deployment policy,
and game-specific command predicates remain application responsibilities.

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

Structural decoding only proves that bytes fit `Player_Input`; the generated
sanitizer proves that their values obey the declared input language. Add the
sample validator hook as well when legality depends on multiple fields or game
state.

## Defaults at a glance

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

## Supported starting envelopes

`network_profile_envelope(profile)` publishes the scale limits verified by the
engine-free benchmark gate. These are framework envelopes, not promises about
your game logic, physics, engine nodes, transport overhead, or hosting machine:

| Profile | Players | Persistent replicated entities | Hot entities per recipient/tick | Predicted entities/client | Forced replay |
| --- | ---: | ---: | ---: | ---: | ---: |
| Friends co-op | 8 | 2,000 | 500 | 0 | 0 |
| Listen-server action | 8 | 2,000 | 500 | 128 | 8 ticks |
| Dedicated competitive | 8 | 2,000 | 500 | 512 | 8 ticks |

`tests/kitstress` measures server CPU, application egress bytes, session
resident/peak allocation, join/snapshot/resume cost, per-recipient AOI fanout,
and reconciliation cost at increasing sizes. Its optimized native reference
run exercises 2/100, 4/500, and 8/2,000 player/entity fanout shapes plus
32/128/512 predicted entities. The test uses generous complexity tripwires;
repeat it on deployment hardware and add the engine/game frame before raising
an envelope. “Hot” means dirty and inside one recipient's AOI in the same tick;
unchanged and out-of-interest entities are sparse and do not consume snapshot
rows.

## Overrides remain ordinary fields

`network_profile` materializes every timing field, including booleans. That
means an override never has to fight the lower-level "zero means default"
convention:

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

## Hand-wired stacks

The generated facade is the normal path. A game using the lower-level lifecycle
can apply the same contract directly:

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
procedures so normal scripts need only `kboot`.
