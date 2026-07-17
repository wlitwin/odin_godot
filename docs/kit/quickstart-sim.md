# Hello, server authority — your first predicted entity

The [co-op quickstart](quickstart.md)'s game trusts its players: each peer
writes its own square's position. For a competitive game that's the wrong
trust model — the server must own positions, and this page promotes the
hello game to exactly that in **four small diffs**, following the
[promotion checklist](sim.md#promoting-a-coop-game). The result is
`examples/hello_sim/`, byte-identical to `examples/hello_net/` outside these
diffs. You get: clients that can't lie about where they are, your own square
still moving the *instant* a key goes down (client prediction), and remote
squares rendering smoothly a breath in the past (the watched clock).

Prerequisite: the co-op quickstart — the session half (lobby, doors, spawns,
drop-in) carries over *unchanged*, and this page only explains what moves.

## Diff 1 — the retag (the whole wire migration)

```odin
x, y: f32 `gd:"replicate,interp,owner,wire=f16"`   // coop: my stream, my truth
x, y: f32 `gd:"replicate,predict,interp"`          // sim:  server truth, predicted here
```

One word. The field's writer changes from "its owner's stream" to "the
server's simulation, predicted locally and reconciled".

## Diff 2 — movement becomes a tick

The coop hello moved `me` in the frame loop. Promoted, movement is a pure
fixed-rate step the authority runs for truth, the owner runs as prediction,
and every reconcile re-runs:

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

The one place that still touches hardware, filling my input for tick T:

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

## Diff 4 — two wiring lines

```odin
hello_sim_lane_init(self, &self.lane, &self.ses) // generated: carries the tick/sample declarations
kboot.boot_lane(&self.boot, &self.lane)          // the boot drives the lane from here on
```

(`lane: ksim.Lane` joins the game struct; the frame-loop drive block is
deleted — that's the whole promotion. Issue sites and spawn sites keep
their exact shape on both models.)

## Run it, and feel the difference

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &                        # window 1: Host
HELLO_LATENCY=120 $GODOT --path examples/hello_sim        # window 2: Join
```

**Checkpoint:** in the joined window — under 120ms injected each way — your
square still snaps to your keys with zero lag (prediction), while the host's
square glides smoothly behind (watched). Kill the latency env and nothing
about the code changes; the lane just has less to hide.
`examples/hello_sim/run.sh` pins both receipts headless: the guest's own
square moves within half a second of the press (an un-predicted square would
still be waiting on the server's echo at 240ms RTT), and the host's walk
arrives on the watched clock.

## Running the authority

A competitive game's trusted machine has three shapes, all the same code:

- **Listen server** — the host window above: a player who is also the
  authority. Free, and fine among friends; the host has the zero-latency
  seat.
- **Dedicated, headless** — `HELLO_ROLE=serve $GODOT --headless --path
  examples/hello_sim` runs `kboot.boot_serve`: an avatarless referee seat
  that simulates, fields no square, never migrates (a dead server restarts;
  the succession torch is the friends-host model's). This is what you run
  on a VPS for a match that must be fair.
- **Single** — the host with nobody joined; the same build is your practice
  range.

What the kit deliberately does not do: matchmaking services, server fleets,
or NAT traversal for raw ENet — you hand players an address (or ship the
browser build / Steam, where rooms and invites exist). See
[timelines](timelines.md) for choosing models and [sim.md](sim.md) for
everything the lane can do — lag-compensated hitscan, contested objects,
predicted spawns, verbs on the tick timeline.
