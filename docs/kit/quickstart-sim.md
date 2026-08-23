# Quickstart: server authority and client prediction

The [co-op quickstart](quickstart.md)'s game trusts its players: each peer
writes its own square's position. A competitive game needs the opposite: the
server owns positions, and clients can't lie about where they are. This page
promotes the hello game to that model in **four small diffs**, following the
[promotion checklist](sim.md#promoting-a-coop-game). The result is
`examples/hello_sim/`: `examples/hello_net/` with these four diffs applied,
plus the dedicated `serve` entry point (below) and without the optional
join-code entry points.

You get: clients that can't lie about where they are, your own square still
moving the *instant* a key goes down (client prediction), and remote squares
rendering smoothly a breath in the past (the watched clock).

The prerequisite is the co-op quickstart. The session half (lobby, doors, spawns,
drop-in) carries over *unchanged* apart from the join-code doors, so this page
only explains what moves.

## Diff 1 — retag the position field

```odin
x, y: f32 `gd:"owner,interp,wire=f16"`   // coop: my stream, my truth
x, y: f32 `gd:"predict,interp"`          // sim:  server truth, predicted here
```

In the `Player` entity struct, one word changes. The field's writer moves from
"its owner's stream" to "the server's simulation, predicted locally and
reconciled".

## Diff 2 — movement becomes a tick

Under server authority, movement is a pure fixed-rate step: the authority runs
it for truth, the owner runs it as prediction, and every reconcile re-runs it.

```odin
Player_Input :: struct {
	move: [2]i8, // -1/0/1 per axis
}

STEP :: f32(160.0 / 60.0) // px per tick at the lane's 60 Hz

@(gd_tick)
player_tick :: proc(self: ^Player, input: Player_Input) {
	self.x = clamp(self.x + f32(input.move[0]) * STEP, 8, 632)
	self.y = clamp(self.y + f32(input.move[1]) * STEP, 8, 352)
}
```

## Diff 3 — the device read becomes a sample

The one place that still touches hardware fills my input for tick T:

```odin
@(gd_sample)
hello_sample :: proc(self: ^HelloSim, tick: u64, input: ^Player_Input) {
	input^ = {}
	if gd.is_action_pressed("ui_right") {input.move[0] += 1}
	if gd.is_action_pressed("ui_left") {input.move[0] -= 1}
	if gd.is_action_pressed("ui_down") {input.move[1] += 1}
	if gd.is_action_pressed("ui_up") {input.move[1] -= 1}
}
```

## Diff 4 — add the lane, wire it in `ready()`, drop the per-frame move

Unlike the first three diffs, this one is not a free-standing declaration; it
lands in specific places. First, the lane is a field on the *game* struct
(`HelloSim`), beside the session and boot:

```odin
lane: ksim.Lane, // the sim lane: tick scheduling, prediction, reconcile
```

Two lines wire it, in `ready()` right after `boot_attach` and `<game>_entities`:

```odin
hello_sim_lane_init(self, &self.lane, &self.ses) // generated: carries the tick/sample declarations
kboot.boot_lane(&self.boot, &self.lane)          // the boot drives the lane from here on
```

Finally, delete the coop game's per-frame movement from `process()`. hello_net
wrote its own square's position there every frame; that work now belongs to
`player_tick` (Diff 2), fed by `hello_sample` (Diff 3). What remains in
`process()` is only the pump, unchanged from the coop game:

```odin
events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())
hello_sim_events(self, events)
```

That is the full set of changes. Issue sites and spawn sites keep their exact
shape on both models.

## Run it

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &                        # window 1: Host
HELLO_LATENCY=120 $GODOT --path examples/hello_sim        # window 2: Join
```

**Checkpoint:** in the joined window, with under 120ms injected each way,
your square still snaps to your keys with zero lag (prediction), while the host's
square glides smoothly behind (watched). Remove the latency env and nothing
about the code changes; the lane runs the same path with less latency to mask.
`examples/hello_sim/run.sh` pins both receipts headless: the guest's own
square moves within half a second of the press (an un-predicted square would
still be waiting on the server's echo at 240ms RTT), and the host's walk
arrives on the watched clock.

## Running the authority

A competitive game's trusted machine has three shapes, all the same code:

- **Listen server.** This is the host window above: a player who is also the
  authority. It is free and fine among friends, since the host has the
  zero-latency seat.
- **Dedicated, headless.** `HELLO_ROLE=serve $GODOT --headless --path
  examples/hello_sim` runs `kboot.boot_serve`, an avatarless referee seat
  that simulates, fields no square, and never migrates. A dead dedicated
  server restarts rather than handing off; the host-migration handoff belongs
  to the friends-host model. Run this on a VPS for a match that must be fair.
- **Single.** This is the host with nobody joined; the same build is your
  practice range.

## What the kit does not do

The kit does not provide matchmaking services or server fleets. NAT traversal
is half-solved: the
[join-code relay](netgd.md#join-codes-for-native-enet-codeodin) hands the host
each joiner's observed endpoint and the host punches a few UDP packets at it,
so a plain-ENet join crosses LAN, port-forwarded, and the common
port-preserving home NATs on a four-letter code. Symmetric NATs are an honest
failure (there is no TURN for raw ENet), so the join reports why and offers
the doors that always work: the browser build (WebRTC + TURN) and Steam.

See [timelines](timelines.md) for choosing models and [sim.md](sim.md) for
everything the lane can do: lag-compensated hitscan, contested objects,
predicted spawns, and verbs on the tick timeline.
