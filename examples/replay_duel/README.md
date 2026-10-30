# Replay Duel

Run this two-player projectile duel to study peer-to-peer (P2P) simulation.
Both participants simulate the complete match and exchange inputs; neither sends
authoritative world corrections. Deterministic execution lets them compare state
hashes after receiving the same inputs. The original games remain separate.

```sh
nix develop --command bash examples/replay_duel/play.sh
RDP_ROLE=dial nix develop --command bash examples/replay_duel/play.sh

nix develop --command bash examples/replay_duel/run.sh
nix develop --command bash examples/replay_duel/resume_run.sh
nix develop --command bash examples/replay_duel/rejoin_run.sh
nix develop --command bash examples/replay_duel/watch_run.sh
nix develop --command bash examples/replay_duel/profile_run.sh
nix develop --command bash tests/replay_p2p/run.sh
nix develop --command bash tests/replay_deterministic/run.sh
```

Start the two interactive commands in separate terminals. A/D move, Space jumps,
and J fires. The default role listens; `RDP_ROLE=dial` connects to localhost.
Port defaults to 49520. This initial launcher admits one remote ENet peer and binds
the listening/dialing roles to fixed logical IDs 1/2. Fresh ENet connection IDs can
therefore change during coordinated restore. Production admission/rendezvous is
not implemented by that native ENet launcher. The browser invitation path below
uses durable provisioning and authenticated rendezvous.

## Browser match invitations

Run the separate [Duel service](../replay_duel_service/README.md), export/serve the
browser game, and open `lobby.html`. Under Match invitations, supply the service
address and choose Create match. The game offers Invite player before the other
participant arrives. Share that link with a different browser profile/device,
which chooses Join match. Credentials are generated and saved automatically in
each profile's IndexedDB; only the bearer invitation goes in the shared link.
The invitation dialog supports both browser-native Copy and manual selection.

Before closing a participant, use Save & pause and keep the downloaded file. To
return, open the lobby with the same service, import that file and choose Rejoin
recent. Enrollment alone cannot restore the simulation/input history. The service
registers a newer process incarnation while retaining the match's session and
ordered player IDs. Both the creator and guest can use this flow; compatible
participant history is still required.

The flow uses the reusable [P2P party owner](../../replay/godot/p2p_party.md).
The service fixes the roster at two players and grants no simulation authority.
A guest can wait for the creator's signaling room for up to 15 seconds. Initial
enrollment/registration failures remain explicit; established gameplay does not
stop solely because the enrollment control connection fails.

```sh
REPLAY_P2P_PARTY_OUT=/absolute/fresh/build nix develop --command bash tests/replay_p2p_party/run.sh
REPLAY_PREBUILT=1 REPLAY_P2P_PARTY_OUT=/absolute/fresh/build \
REPLAY_P2P_PARTY_RUN=/absolute/fresh/creator-return REPLAY_P2P_PARTY_MODE=creator \
nix develop --command bash tests/replay_p2p_party/run.sh
```

This browser path uses WebRTC. Native two-player provisioning now uses encrypted
ENet through [P2P Direct](../../replay/godot/p2p_direct.md). Public accounts/deployment
and authenticated spectator enrollment remain open.
The direct demo, manually issued credential fixtures and native ENet scenarios
remain independently runnable.

## Native provisioned matches

Use the same Duel service with native `RDP_PARTY=create`, `join`, or `rejoin` and
`RDP_SERVICE=wss://your-service`. A private CA can be supplied with `RDP_CA`.
Explicit loopback development uses `RDP_LOCAL=1` with a loopback WS service.
`RDP_ADDRESS`/`RDP_PORT` advertise the local native endpoint. The creator listens;
the guest discovers the creator's current registered endpoint through the service.
Optional `RDP_BIND_ADDRESS`/`RDP_BIND_PORT` select the local listener independently
for interface/port forwarding. Omitting both retains the advertised endpoint as
the listener. The service still receives only the advertised endpoint.

Create on one profile/device and use Copy invitation. The joining profile supplies
that code as `RDP_INVITE`. Set `RDP_ROOMS_DB` and `RDP_ARCHIVE` to separate absolute
paths when testing multiple native profiles on one machine. Defaults use the game's
user directory. The enrollment database and participant archive are different files.

To return after Save & pause, use the same database with `RDP_PARTY=rejoin`,
`RDP_STAGE=resume` and the saved `RDP_ARCHIVE`. A creator can register a new port;
the survivor follows the new endpoint after authenticating the new incarnation.
The original `RDP_ROLE`/direct ENet demonstration remains available when `RDP_PARTY`
is absent. Native provisioned mode currently supports two participants.

```sh
REPLAY_P2P_NATIVE_OUT=/absolute/fresh/build nix develop --command bash tests/replay_p2p_native/run.sh
REPLAY_P2P_NATIVE_OUT=/absolute/fresh/build REPLAY_PREBUILT=1 \
REPLAY_P2P_NATIVE_RUN=/absolute/fresh/guest REPLAY_P2P_NATIVE_MODE=guest \
nix develop --command bash tests/replay_p2p_native/run.sh
```

The model in `shared/duel` uses Q24.8 coordinates, checked updates, stable projectile
slots and frame-owned RNG. Three hits kill a fighter; respawn happens after a
deterministic randomized delay. All bullets resolve before damage is applied so
same-tick trades are symmetric. Presentation draws copied state and uses an event journal to reconcile displayed
effects after replay.

The real-process gate uses 120 ms receive delay per side, 0–20 ms jitter, 10%
unreliable loss and 10% duplication. It simulates 600 ticks, waits for both confirmed
checksums, verifies the whole final world against a reference run and checks shot
event reconciliation. The default two-tick input delay and eight-tick prediction
limit intentionally expose stalls at this latency. A stall counter counts attempted
steps that waited, not distinct simulation ticks or elapsed stall duration.

`tests/replay_deterministic` executes a 2,400-tick corpus with four seeds on native
arm64 and freestanding WASM, comparing canonical state/event hashes and gameplay
counters. The WASM module imports no host simulation functions. This is execution
evidence, not merely a type-check. P2P browser gameplay and coordinated file recovery now have separate real-browser
gates. Other native targets and polished lobby/recovery UX remain pending.

`resume_run.sh` saves each participant's full protocol archive at tick 240 while
the final ticks are still speculative. It kills both processes, creates new ENet
connections, restores their different durable frontiers and continues to tick 600.
The gate checks the full world and shot journal against uninterrupted execution.
Use `REPLAY_KEEP_LOGS=1` to retain the logs and `.rply` files. To inspect a saved
participant without Godot or a network:

```sh
nix develop --command bash examples/replay_duel/verify.sh /path/to/listen.rply
```

The verifier reexecutes the retained inputs and checks every state/event digest.
`tests/replay_p2p/run.sh` creates normal and deliberately divergent recordings,
executes the same verifier on native arm64 and WASM, and requires the changed
execution to first mismatch at tick 12. This is a bounded retained history, not a
full-length replay movie. See the [archive contract](../../replay/p2p/README.md).

`rejoin_run.sh` exercises a native live rejoin. Only the dialing participant saves
at tick 240 and is killed. The listener stays in the same process, stalls at its
prediction bound and waits through timeout. A fresh dialing process restores its
own file; the listener rebinds its logical peer to the new ENet connection and
calls `p2p.reconnect`. The gate verifies that the listener's current frame, captured
input frontier, confirmed tick and timeline allocation survive the rebind, then
checks both tick-600 worlds and shot journals against uninterrupted execution.
Set `RDP_REJOIN_OUT` to an empty directory to choose retained output.
`RDP_LIVE_REJOIN=1` (browser `?live_rejoin=1`) enables this fixture's reconnect
behavior. The browser lobby enables it; direct launch defaults remain off.

The fixed loopback role mapping is a trusted test provider, not authenticated
admission. Old ENet identities are excluded by the replacement mapping. The saved
participant stops sampling before it is killed: an arbitrary older archive can
fail if survivors have inputs it forgot or required retransmission history was
evicted. The runner refuses both cases. The same behavior now has a browser gate
described below. Authenticated browser creator recovery also has a separate gate.

`creator_rejoin_run.sh` covers the native listening participant returning. The
creator saves and pauses at tick 240, then is killed. The dialing process retains
its runner through timeout, closes its retired transport and reconnects to the
restored listener at the same address. Physical server ID 1 is reused, so an
explicit transport-reopen state triggers the logical rebind. The gate checks the
world, sampled/confirmed and receive/ACK frontiers, local slot, roster, chain and
input/hash/timeline storage, then compares both tick-600 worlds and shot journals
with uninterrupted execution. Use `RDP_CREATOR_OUT` for a fresh output directory.
This replaces a listening transport, not a missing participant's input history;
the same archive-retention limits and trusted loopback-provider scope apply.

`watch_run.sh` adds a third Godot process after confirmed tick 150. Its separate
spectator connection receives only confirmed history. A six-second blackout of
that connection allows the two players to advance beyond retained history; the
spectator reports the omitted range, rebuilds at a new baseline, and continues
through tick 900 with new shot events and the same reference world. The gate
requires at least 128 ticks of post-recovery play. It uses the same delay/jitter/
loss profile as the player fixture. Disable the blackout with
`RDP_WATCH_BLACKOUT_MS=0` to exercise continuous late-join delivery.

For interactive spectating, start the listening player with `RDP_WATCH=1`, start
the dialing player normally, then start a third `play.sh` with `RDP_ROLE=watch`.
The spectator connects to game port + 1. The current launcher admits one viewer
and trusts the listening participant as the viewing source. Spectators are
independent of the player roster; losing their connection cannot stall players.
`watch_failover_run.sh` closes only that spectator stream during active play,
then reconnects the viewer to the second participant on game port + 2. A retained
anchor proves continuity, so the viewer keeps its world and event journal and
reaches tick 900 without another presentation reset. Both players keep simulating.
The native fixture uses configured loopback peers and a private anchor file;
public authenticated spectator provisioning, browser source-switch integration,
automatic restoration of a restarted spectator and delayed disclosure remain
pending. See the [spectator contract](../../replay/p2p/spectators.md).

View geometry was copied from Replay Quickdraw's script-free gunner/bullet scenes;
see its [original asset provenance](../replay_quickdraw/assets.md). The copied
fighter scene SHA-256 is `7ccb2b812b16da493fb2157206da86b18b9d21e28b95f0d39df87055bbf7fb24`;
the bullet is `f1d1339990e8adfec1e7861831a18e17177b6e0959abb10e7812b15b022b7777`.
These are provisional views; human visual/play-feel review remains open.

The [profiling contract](../../replay/p2p/profiling.md) explains operation wall
timings and capture-to-first-simulation latency. `profile_run.sh` compares two/eight
delay ticks with the same gameplay inputs; `tests/replay_p2p/bench.sh` separately
measures optimized native process CPU over two peers and Memory transport.
`tests/replay_deterministic/run.sh` now checks default and speed optimization on
the host and WASM, plus macOS x86-64 under Rosetta when available. Rosetta validates
an alternate ISA binary on this Mac, not independent x86 hardware or other OSes.
Set `REPLAY_REQUIRE_ROSETTA=1` to make an unavailable Rosetta check fail explicitly.


## Browser play and acceptance

```sh
# Build/export, start the local signaling/HTTP fixtures and print the lobby URL.
REPLAY_WEB_PLAY=1 nix develop --command bash examples/replay_duel/web_run.sh

# Automated separate-Chrome-process scenarios; logs are retained.
nix develop --command bash examples/replay_duel/web_run.sh
```

The lobby creates a match or joins a room as a player/spectator. The hosting game
shows room codes and copy buttons for join/watch links. A/D, Space and J drive the
same inputs as native play. Browser `?role=`, `?url=`, `?room=` and other lowercase
query names correspond to native `RDP_ROLE`, `RDP_URL`, `RDP_ROOM`, etc. The default
browser backend is raw Replay WebRTC; the native backend remains ENet. Neither
path uses Godot scene RPCs. Two trusted participants bind to fixed logical IDs
1/2. Numeric transport IDs and copied links do not authenticate a player.

A viewer joins a separate watch room, corresponding to native's separate watch
port. It is outside the player confirmation roster. The full suite covers:

- `fault`: 600 ticks with 120 ms receive delay, 20 ms jitter, 10% unreliable loss
  and duplication, plus a three-second input blackout. Prediction reaches its
  bounded horizon and waits, then retransmission/rollback reaches the reference.
- `watch`: a third browser joins after tick 150. Six seconds of lost spectator
  traffic exceed retained history; an explicit reset resumes viewing, with at
  least 128 further ticks before the 1,200-tick reference/effect checks.
- `resume`: both participants export their own 240-tick protocol archives. The
  driver verifies downloaded file lengths and closes both browser processes.
  Fresh browsers import those files through the lobby, open a fresh RTC room and
  restore their different durable input frontiers before continuing to tick 600.
- `rejoin`: the dialing browser clicks **Save & pause** during play. The driver
  verifies the downloaded file and that its head and sampled frontier stop, then
  kills that Chrome process. The match creator stays open through timeout. A fresh
  browser imports the file and joins the same room with a new physical RTC ID;
  the survivor retains its frame/allocation and both reach the tick-600 reference.
- `creator` (authenticated provider): the creator clicks Save & pause and its
  browser is killed. The joining browser stays open through timeout. A fresh
  creator imports its own file and credential; peer ID 1 receives a new connection
  generation. The survivor retains its runner and both reach tick 600.
- `interactive`: actual keyboard movement/jump/fire reaches the other browser;
  the hosting page's copy button produces the expected join link.

Select scenarios with `REPLAY_WEB_MODES="fault watch"`; choose a retained log
location with `REPLAY_DUEL_WEB_LOGS=/absolute/path`. There are no automatic retries.
The delay/loss decorator runs at the application's packet boundary over real
WebRTC; this does not emulate internet NAT, packet-level SCTP congestion or TURN.

Browser recovery uses explicit participant files, with a 16 MiB import bound.
The lobby finishes an IndexedDB upload transaction before entering the game;
the game waits for the bounded buffer and performs normal archive decoding and
reexecution validation. Initiating a browser download does not prove it was saved:
the browser/user owns completion. This gate verifies actual files and restores
in new browser processes. It does not claim implicit Godot virtual-filesystem
flush durability.

To leave and return as the joining player, click **Save & pause**, keep the completed
download, and close that browser. Leave the match creator open. To return, open its
join link, import your participant file and join the room. Save & pause stops new
input capture while servicing received inputs and presentation reconciliation;
there is no continue button that could silently make the downloaded file stale.
For an authenticated fixed match, the creator can also save and return while the
joining browser stays open: import its own credential and archive, then create the
same match again. The service retains the fixed match scope. The plain local
signaling fixture still requires coordinated recovery when its creator closes.
The signaling service must remain available for either live-rejoin flow.

The local fixture is not an authenticated public relay. STUN/TURN deployment,
additional browser engines, source failover, and automatic
coordinated save/lobby flows remain open. Human play-feel review is still needed.
[Recorded browser evidence](../../docs/replay/results/p2p-browser-2026-09-06/README.md)
includes logs, archives and rendered views.
The [live browser rejoin evidence](../../docs/replay/results/p2p-browser-rejoin-2026-09-08/README.md)
records the killed process, survivor identity, archive and state checks.

## Authenticated P2P admission

```sh
nix develop --command bash tests/replay_p2p_admission/run.sh
nix develop --command bash tests/replay_p2p_admission/service_run.sh
nix develop --command bash tests/replay_p2p_admission/web_run.sh
```

The browser gate starts a native Godot signaling provider with a fixed two-member
registry. Each Chrome process imports its personal JSON credential using the lobby's
credential input; the file contains `member`, `incarnation` and a 64-character
lowercase hexadecimal `key`. The lobby stores only that participant's credential
in its tab's sessionStorage and carries `auth=1` in navigation/join links. Keys
never appear in the URL. The authenticated profile currently admits players only.

Duel opens `Rtc_P2P_Auth` using its session/content/epoch and ordered member IDs 1/2.
Before initial binding and live rejoin it requires the provider's verified member
identity for the connected physical RTC peer. The gate rejects a duplicate creator,
wrong key, wrong role, unknown member and replayed connection proof, then saves and
kills only the dialing browser. Its authenticated replacement receives a new RTC
ID, restores its archive and reaches the tick-600 reference with the live survivor.

The fixture uses published test credentials and loopback WS. A deployment must
issue personal credentials and authenticate the provider, for example through
verified WSS. This fixture does not provide a public Party account/invite flow or
authenticated spectator admission. Native listening-transport replacement
has the separate loopback gate above. The browser gate covers either participant returning, including a
creator whose numeric RTC ID remains 1 while its connection generation changes. See [the provider contract](../../replay/p2p/admission/README.md) and
[recorded evidence](../../docs/replay/results/p2p-admission-2026-09-08/README.md).
