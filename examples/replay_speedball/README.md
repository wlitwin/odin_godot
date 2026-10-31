# Replay Speedball

A separate [Speedball](../speedball/README.md) port using a complete, replayable
pitch. Every playable peer predicts all players and the shared ball before the
authority settles their state. Replay's runner schedules the simulation steps and
manages input and history. Contacts, kicks, spikes, score, and kickoff state live in ordinary Odin values in
[`shared/pitch`](shared/pitch/types.odin); the Godot script handles input and views.
Original Speedball, Claimball and Slopball remain independently runnable.

From the repository root:

```sh
nix develop --command bash examples/replay_speedball/play.sh
nix develop --command bash tests/replay_speedball/run.sh
nix develop --command bash examples/replay_speedball/run.sh
nix develop --command bash examples/replay_speedball/network_run.sh
```

The interactive default is a menu with Solo, Host, Join and Watch. Set the name,
address and port there; the host starts a manually opened pitch. For scripted
automatic launches in two windows:

```sh
RSB_ROLE=host nix develop --command bash examples/replay_speedball/play.sh
RSB_ROLE=client nix develop --command bash examples/replay_speedball/play.sh
```

WASD moves, Space holds kick, E spikes, Tab holds scores and Enter focuses chat.
Escape returns the keyboard from chat. Typing captures gameplay controls. The
scoreboard shows names, teams and round-trip telemetry, retaining departed rows.
Leave returns to the menu and clears the local session; rejoining an existing
match uses the current authoritative state. Roles are `solo`, `host`, `server` (no
avatar) and `client`/`observer`. Default port is 49480; `RSB_PORT` overrides it.
`RSB_PLAYERS` sets the start threshold; `RSB_GOALS` sets the winning score.
`RSB_TOKEN` labels deterministic test credentials and bypasses local profiles.
Without it, native/browser play persists a random reconnect identity and the chosen name;
see the profile section below. The menu supports a direct address; `RSB_ADDRESS` supplies its default. Configure `RSB_ROOM_SERVICE` for the [party create/invite/rejoin menu](online.md).
The default direct mode does not provide automatic matchmaking or a public service.
`RSB_BOT=striker` chases/kicks, `spiker` performs a two-command burst, and other
nonempty bot labels idle. `RSB_LATENCY`/`RSB_JITTER` are milliseconds;
`RSB_LOSS`/`RSB_DUPLICATE` are ten-thousandths. Set `REPLAY_KEEP_LOGS=1` to retain
network gate logs. Native macOS gameplay is tested; the WASM gate type-checks the
pure simulation. The separate browser gate below establishes browser party
multiplayer; deterministic P2P remains a separate runner/gate.

## Authored rules and deliberate differences

The port preserves the 640×360 pitch, wall/goal geometry, 9/8-pixel player/ball
radii, player speed 2.2 and momentum response 0.35, kick reach/power/cooldown,
spike reach/power, soft dribble contact, ball friction/speed cap/restitution,
72-tick kickoff hold, and goal detection from the previous clamped ball position.
Dedicated seat numbering has a one-seat offset to retain original spawn/team
assignment: the first client scores into the left goal. Scene provenance is in
[assets.md](assets.md).

Unlike the original mixed simulation/discrete fields, the complete score and
winner participate in replay with the ball. The HUD reads authoritative score;
goal reset/hold predict immediately. A changed reset counter cuts smoothing.
The Replay runner processes contacts in explicit ascending seat order.

Spike commands carry intent, and both authority and prediction derive the origin
from the issuing seat's world position. The original command accepts issuer-supplied
coordinates. This is a deliberate trust-model change, not equivalent command
validation. Replay currently services one reliable action per seat per tick, so
the two commands execute on successive ticks. The spiker bot requests its burst
within 30 pixels, leaving room inside the 44-pixel predicate for both to be valid.
The original bot requests within 44 pixels and supplies its captured coordinates.
These differences must be accounted for in a paired benchmark.

The HUD/team colors remain a separate implementation. Direct session menus,
chat, and held scores are supplied and tested. Public deployment, Steam paths and broader
visual/human play-feel review remain pending. The [port ledger](parity.md) records
what is preserved and what remains. The native Room path below exercises migration in this pitch.
This remains an incomplete M6 port, not full game parity.

## Prediction and presentation

Presentation selects the state and effects to display. Its smoothing changes the
drawn pose while the simulation retains the values used for gameplay.

The runner refreshes remote held-input guesses from each authoritative
snapshot before replaying the speculative suffix. Local input samples, aiming
stamps and action IDs stay unchanged. The replacement inputs and resulting
state/events commit atomically; a failed replay preserves the old timeline.

`client.correction` contains detached before/after frames at the same prediction
tick, an authority tick and replay depth. The view feeds their position difference
to `view.smooth_correct`, then advances ordinary presentation normally. This avoids
smoothing away legitimate movement. Corrections beyond 60 pixels and goal resets
cut the glide. Smoothing never changes gameplay or checksums.

Playable peers use speculative kick flashes on the complete predicted pitch;
incorrect flashes can be canceled/replaced. `RSB_RESULT` counts starts and cancels
separately. A true observer draws sparse authoritative frames and presents each
authoritative kick once on its watch clock. Speculative flashes are reversible
cosmetics; this policy does not promise that audio already played can be undone.

The network gate starts a dedicated authority, striker, spiker and true observer
at 240 ms injected gameplay RTT. It requires two accepted spikes, local spike
Godot-node displacement over 12 game pixels within four ticks and before acknowledgement, predicted
kicks, matching 0–1 score/winner, the ball reset to center everywhere, and reconciled
kick-event counts. `RSB_METRICS` reports application bytes, replayed ticks and ball
correction magnitudes (including disagreements around predicted resets). These
values are initial diagnostics, not CPU percentiles or a Kit/Replay comparison.

## Session/UI acceptance

```sh
nix develop --command bash examples/replay_speedball/ui_run.sh
```

The host, player and observer use real ENet sessions with 120 ms receive delay
per process. The gate checks validated names, host-only start, literal chat,
input capture, held scores/ping, departure and rejoin. It drives the actual
scene signals and keyboard action map; separate native captures also exercise
Space activation of the menu and rendered score overlays.

The content ID is `0x5253504545444234`. Name/start state and commands changed
its initial schema in revision 2; revision 3 also changes the manual-start rule:
the first connected seat leads the match. A planned network handoff preserves that
leader, while a disconnected leader yields to the first surviving seat. Revision 4
adds a match round counter and round-scoped restart command. No implicit old-archive
conversion is claimed.

## Native host migration

```sh
nix develop --command bash examples/replay_speedball/migration_run.sh
```

This three-member local fixture exercises planned handoff and abrupt host loss
through the existing Replay Room driver and SQLite coordinator. A successor
prepares the complete pitch, including player identity, score and moving ball.
Recovery advances the authority epoch, restores that checkpoint, reconnects the
survivors and resumes commands, chat and presentation. The authority's Handoff
button requests a freeze/release; the recovery label shows progress and the known
rollback distance. Reconnecting clients reinstall their cosmetic event policy and
clear correction smoothing associated with the old epoch.

The fixture enables Room with `RSB_COORD_PORT`, `RSB_MEMBER` (1–3),
`RSB_INCARNATION` and a 64-character hexadecimal `RSB_COORD_KEY`. Its coordinator
uses room 49, localhost endpoints and fixed development credentials. Members 1
and 2 can host; member 3 exercises a peer without checkpoint capability. Without
these Room settings, the normal Solo/Host/Join/Watch flows use direct sessions.
This remains a fixed migration fixture. The separate [party menu](online.md) uses durable enrollment and invites through a configured room service.

Use a fresh `RSB_MIGRATION_OUT` directory to retain evidence. Set
`RSB_MIGRATION_MODES=planned` to select one scenario, or
`RSB_MIGRATION_RENDER=1` for native windows and recovery screenshots. Each scenario
requires an exactly restored moving checkpoint with a nonzero score, two new
accepted spikes, new-epoch chat and matching canonical worlds among survivors.
The gate applies 120 ms receive delay per game process; it does not simulate raw
packet loss. Manual match-leader succession additionally has a pure-model test;
lobby migration and consecutive failures need separate end-to-end coverage.


## Play again and local profiles

After a match ends, the first connected seat can press **Play again**. The command
requires the current round number and enough connected players, and rejects stale
requests, guests and observers. It resets ball/kickoff, player motion/cooldowns,
score and per-match counters while retaining names, seats, connections and match
settings. Authority epochs and the session's action sequence continue. Presentation
cuts to the new pitch, the button hides, and chat announces the new match.

Native play stores reconnect identity at `user://replay_speedball_identity` and the
name at the same path plus `.name`, independently of the original game's profile.
Set `RSB_PROFILE` to another path for each local player/process. Its parent directory
must exist. `RSB_NAME` overrides the initially displayed name; a successful connection
persists the chosen value. `RSB_PERSIST=0` opts into temporary identity/name handling.
An explicit `RSB_TOKEN` uses test credentials and bypasses profile reads and writes.
Malformed or unwritable profiles produce a visible error before joining; existing
identity is never silently replaced. Browser play uses IndexedDB through the
existing identity/name adapters; connection controls wait for the initial profile
read. A fresh browser process is tested below. Native files and browser storage
remain separate backends.

```sh
nix develop --command bash examples/replay_speedball/round_run.sh
nix develop --command bash examples/replay_speedball/profile_run.sh
```

The round gate uses a host, player and observer at 120 ms receive delay each. It
plays two complete matches, rejects guest restart, checks cleared totals and retained
seats/names, and exchanges chat after the second match. `RSB_ROUND_RENDER=1` runs
native windows and captures the winner's Play again button. The profile gate kills
a client and starts another process with its files, requiring the same seat and name;
it also checks malformed-file preservation and explicit-token precedence. Both
launchers accept fresh output directories (`RSB_ROUND_OUT`, `RSB_PROFILE_OUT`).

Original Speedball's boot helper already persisted reconnect identity. Its game
scripts do not expose Play again or a match save/load menu. Restart and saved display
names are Replay additions. The native save/resume menu is described below.


## Save and resume a pitch

Direct native hosts and solo players can click **Save · F5** or press F5 outside
chat. The menu's **Save file** field chooses the destination (`RSB_SAVE` supplies its
default, `user://speedball.replay`). Its parent directory must exist. A successful
save records the complete authority checkpoint, including the scored/moving pitch,
round, roster and command frontiers. The latest completed save replaces the selected
slot through the existing staging-file/rename helper. A failed write preserves the
previous archive and reports an error.

From the menu, **Resume solo** restores offline play; **Resume host** opens the
restored pitch for friends. Use the same local profile that saved the game. Another
participant's profile, a damaged/missing file or incompatible content cannot open
that archive as a player host. Scripted authority launches can use `RSB_RESUME=1`.
A dedicated archive must be resumed with the `server` role; the visible buttons are
for player-hosted saves.

Resume advances the saved authority epoch, restores the exact frame, retires
accepted-but-unexecuted commands, and disconnects remote seats until they rejoin.
Fresh clients use normal Join/Watch; an opt-in, credential-free query of the chosen
direct host learns its current epoch before the regular handshake. Friends retain
their own profiles and reclaim their seats. Local chat scrollback is not part of a
match file. Manual file resume assumes the old runtime has stopped; it is separate
from automatic host migration and does not elect/fence competing hosts.

Room-managed games keep their coordinator recovery path; manual file saving and
resume are disabled for them. Browser solo saves use named IndexedDB slots, described below. No old
schema conversion or power-loss durability guarantee is added by this UI.

```sh
nix develop --command bash examples/replay_speedball/save_run.sh
```

The gate saves a scored, moving pitch, kills both peers, tests solo restore and
wrong-owner/damaged/missing-file rejection, then starts fresh host/client processes.
It requires exact frame equality, the same seats/names, new spikes, a completed
match, restart into round 2 and chat. It also blocks a second staging write and
verifies that the previous archive survives. Set a fresh `RSB_SAVE_OUT` to keep
artifacts, and `RSB_SAVE_RENDER=1` for native menu/resume captures.


## Browser parties

```sh
nix develop --command bash examples/replay_speedball/online_web_run.sh
```

The Web export uses the same scene, pitch and Party/Room flow. Browser launch
settings use lowercase query keys without the `RSB_` prefix: `room_service`,
`room_local`, `players`, `goals`, `latency`, `name` and `persist`, for example.
Browser multiplayer uses a configured party service and WebRTC; raw direct ENet
joins remain native. Personal identity and display name use the `replay-speedball`
IndexedDB namespace, while room credentials use `replay-speedball-rooms`. Profile
reads finish before connection controls become active; corrupted/unavailable
storage reports an error rather than silently switching identity.

The browser gate runs a host, player and true observer in separate Chrome profiles.
It verifies actual RTC traffic, planned handoff and host loss, an exact scored/moving
checkpoint, observer leave/rejoin and a fresh browser process returning with the
same personal identity, display name, invite and seat. New spikes/chat must precede
matching canonical worlds. `RSB_WEB_OUT` selects a fresh artifact directory;
`RSB_WEB_MODES=planned` narrows the scenarios. The default runner builds and exports;
verified prebuilt runs require an existing matching Web export.

The test uses local HTTP/WS with explicit development mode and 120 ms application
receive delay. Host loss closes the host browser without handoff. It does not
establish public HTTPS/WSS deployment, TURN-only routing, raw packet-loss behavior,
OS process-kill durability, other browser engines or human play-feel parity.
Browser solo saves are described below. [Party evidence and screenshots](../../docs/replay/results/speedball-browser-2026-09-08/README.md).


## Browser solo save slots

In the browser's local menu, **Save slot** chooses a name and **Resume solo** opens
its checkpoint. Names contain 1–48 letters, numbers, dots, dashes or underscores;
`save_slot` selects the initial name (default `pitch`). Slots are scoped to the
persistent personal identity and stored in the `replay-speedball` IndexedDB
namespace. Local files and browser slots are separate backends.

During solo play, Save/F5 captures once while the game continues. **Saving…** means
the write was submitted; **Saved match…** appears only after the completed IndexedDB
receipt. Reload resumes the exact checkpoint at a newer epoch with the normal
pending-command retirement policy. Saving again replaces the slot only if its
observed revision is still current. A stale tab reports a conflict and keeps the
newer archive; it does not refresh merely to force an overwrite.

A damaged slot cannot be resumed or overwritten. New solo play remains available,
and after Leave you can choose another slot. An unreadable/corrupt personal identity
blocks connection without replacement. Browser Solo can save even when a party
service is configured, but slot selection/resume uses the local menu configuration.
Leased Room matches continue to use coordinator recovery and cannot be saved through
this solo flow.

```sh
nix develop --command bash examples/replay_speedball/browser_save_run.sh
```

The gate kills the owned Chrome process with SIGKILL after a completed save, resumes
with the same identity/name and exact scored/moving frame, executes new spikes,
finishes/restarts the match and saves round 2. It then exercises competing tabs,
corrupt archives, alternate slots and corrupt identity records, checking that the
previous data remains unchanged. `RSB_BROWSER_SAVE_OUT` selects a fresh artifact
directory. This is local Chrome process-crash evidence; power-loss durability,
browser eviction/private modes and other browser engines remain separate
requirements. Room save publication and abandoned-party restoration use the
distinct [party recovery flow](online.md#saved-party-recovery).
[Solo-slot evidence](../../docs/replay/results/speedball-browser-save-2026-09-08/README.md).
