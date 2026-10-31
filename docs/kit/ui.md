# kit/ui — stock-theme widgets

`kit/ui` builds a lobby, chat box, scoreboard, interaction prompt, inventory
and hotbar, hp bar, and abilities bar from Godot controls. It uses the stock
Godot theme and requires no scene assets. Theme the returned nodes or supply
custom scenes through [scene adoption](#adopting-your-own-scenes).

Widgets read session state such as roster, stats, and chat, plus values the
game supplies. They work with either replication lane; the netgraph displays
both coop and simulation statistics. HUD examples use coop fields such as
kit/combat cooldowns. A simulation game passes its corresponding fields to the
same widgets.

```odin
import kui "godot:kit/ui"
```

<a id="mental-model"></a>

## Widget creation, refresh, and ownership

Call `*_make` with a parent node to build controls and receive their handles.
The game connects buttons and input, then calls `*_refresh` when displayed
state changes. Lobby, chat, and scoreboard refresh on events; the local HUD
refreshes during frames to show live values. `*_destroy` releases tracking
arrays only. The scene owns the nodes and frees them with their parent.

Refresh procedures reuse row Labels and hide unused rows rather than rebuilding
them on each update.

The public API accepts `string`, so callers can pass `fmt.tprintf` results
without converting to `cstring`. Widget implementations perform the engine
string conversion.

## API by task

**Lobby** provides a title, status line, live roster, and three buttons:

```odin
lobby_make :: proc(parent: gd.Node, title: string) -> Lobby
lobby_destroy :: proc(l: ^Lobby)
lobby_set_status :: proc(l: ^Lobby, text: string)
lobby_show_menu :: proc(l: ^Lobby, menu: bool, start: bool)
lobby_show_code :: proc(l: ^Lobby, show: bool)   // reveal the join-code field
lobby_code :: proc(l: ^Lobby) -> string          // entered code, trimmed and uppercased; temporary allocation
lobby_refresh :: proc(l: ^Lobby, s: ^ksess.Session)
```

Connect handlers to `Lobby`'s `host_btn`, `join_btn`, and `start_btn`, each a
`gd.Button`. `start_btn` is initially hidden; the game shows it through
`lobby_show_menu` when its start conditions are met.

`lobby_refresh` reads the [session](session.md) roster in stable `Player_Id`
join order. It marks the host with a crown, the local player with `(you)`,
and departed players with dimmed `(away)` text. Measured ping comes from the
session stat registry. Relay games call `lobby_show_code` in `ready()` to
reveal the code field above Join. The Join handler reads `lobby_code`;
`""` selects address-based joining.

**Chat box** provides a bounded scrollback of [kit/comms](comms.md) lines plus a `Line_Edit`
(`CHAT_SHOW :: 8` rows painted; the comms log keeps more):

```odin
chat_make :: proc(parent: gd.Node) -> Chat
chat_destroy :: proc(ch: ^Chat)
chat_show :: proc(ch: ^Chat, visible: bool)
chat_clear_input :: proc(ch: ^Chat)
chat_refresh :: proc(ch: ^Chat, c: ^kcomms.Comms)
chat_submit :: proc(ch: ^Chat, c: ^kcomms.Comms, text: gd.String, sent: ^bool = nil)
```

Chat displays speech as `name: text` and system lines as `* text`. Connect
`chat.input`'s `text_submitted` signal to a handler that calls `chat_submit`.
It extracts and clamps the text, sends it, clears the input, and releases focus
so movement keys such as WASD return to gameplay. The optional `sent` latch
prevents the submitting Enter key from immediately reopening chat when Enter
is also bound to "talk".

**Scoreboard** displays the session stat columns the game registered, including
measured ping, damage/kills/deaths recorded through [kit/combat](combat.md),
and game-specific counters. `kit/ui` reads those columns without declaring them:

```odin
score_make :: proc(parent: gd.Node) -> Score
score_destroy :: proc(sb: ^Score)
score_show :: proc(sb: ^Score, visible: bool)          // show while Tab is held
score_hide :: proc(sb: ^Score, name: string)           // hide a column by name
score_refresh :: proc(sb: ^Score, s: ^ksess.Session)
```

Departed players remain listed with their accumulated stats. Some registered
columns carry game state that should stay off the scoreboard, such as
Scrapyard's look/iron loadout choices or the muster's ready bit. Call
`score_hide` once after declaring those columns. Unknown names are ignored.

**HUD** provides a prompt, inventory/hotbar, hp, and abilities:

```odin
prompt_make :: proc(parent: gd.Node) -> Prompt
prompt_set :: proc(p: ^Prompt, text: string)           // "" hides the prompt

inv_make :: proc(parent: gd.Node, capacity: int) -> Inv
inv_show :: proc(inv: ^Inv, visible: bool)
inv_refresh :: proc(inv: ^Inv, slots: []kitems.Slot, table: ^kitems.Table, selected := -1)
inv_destroy :: proc(inv: ^Inv)

hp_make :: proc(parent: gd.Node) -> Hp_Bar
hp_refresh :: proc(hb: ^Hp_Bar, current, max_hp: i32)

abilities_make :: proc(parent: gd.Node, capacity: int) -> Abilities_Bar
abilities_refresh :: proc(bar: ^Abilities_Bar, defs: []kcombat.Ability_Def, cds: []u16, resource: i32, tick_hz: int)
abilities_destroy :: proc(bar: ^Abilities_Bar)
```

HUD widgets render text using the stock theme. The hp bar displays
`hp ▓▓▓▓▓▓▓░░░ 70/100`, which a test can read from the node tree. Abilities
display `[rock]` when ready, `[rock 1.2s]` while cooling down, or `[rock $]`
when ready but unaffordable.

Cooldown values count ticks, so pass the rate of the loop that decrements them
as `tick_hz`. Use `session_tick_hz(&ses)` for coop cooldowns or the simulation
lane's rate for simulated cooldowns. This converts the displayed duration to
seconds at the configured rate.

Both ability storage models use `kcombat.Ability_Def` rows. A slot-array game
passes its `Cooldowns` array as `c.cds[:]`; a play-block game gathers its
countdowns beside the same definitions, such as `[]u16{r.slime.cd, r.ignite.cd}`.
Pass `selected` to display the inventory row as a hotbar.

## Adopting your own scenes

To use an authored lobby, chat, or scoreboard, build its scene in the editor
and pass it through Boot's `Options.lobby_scene` / `chat_scene` / `score_scene`;
see [boot.md](boot.md). Kit instantiates the scene and finds its required
controls by name at any depth. Those controls receive the standard behavior,
while the game controls additional nodes and appearance. A missing required
node produces a log message once during boot and leaves the widget inactive
without crashing.

```odin
lobby_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene, title: string) -> Lobby
chat_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene) -> Chat
score_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene) -> Score
```

Each widget requires these node names:

- **Lobby**: `Title` (Label), `Status` (Label), `Players` (a container for
  roster rows), `Host` (Button), `Join` (Button), and `Start` (Button,
  initially hidden). Join-code games can add an optional `Code` (LineEdit)
  revealed by `lobby_show_code`; omitting it is supported.
- **Chat**: `Lines` (a container for scrollback rows) and `Input` (LineEdit).
- **Scoreboard**: `Grid` (GridContainer). Kit sets its column count and adds
  the cells.

Authored scenes control their layout. Anchors under Boot's layer bind to the
viewport; stock sizing and scoreboard centering are skipped. Kit creates row
and cell Labels, which inherit themes from the scene root. After `boot_attach`,
use the widget's `root` to connect extra controls such as a Single Player
button or address field.

## Worked example (cavecrawl)

```odin
self.ui = kui.lobby_make(self.owner, "C A V E C R A W L")
kui.lobby_set_status(&self.ui, "Host a cave, or join one at localhost")
gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
gd.connect_to(cast(gd.Object)self.ui.join_btn, "pressed", self.owner, "on_join")
gd.connect_to(cast(gd.Object)self.ui.start_btn, "pressed", self.owner, "on_start")

self.chat = kui.chat_make(self.owner)
kui.chat_show(&self.chat, false)   // hide chat before connecting its input handler
gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")

// Position the status controls at the top-left.
// Widget creation places them at the anchor origin by default.
gd.control_set_position(cast(gd.Control)self.hud_hp.label, {8, 4}, false)
gd.control_set_position(self.hud_ab.root, {8, 22}, false)
gd.control_set_position(self.inv.root, {8, 40}, false)
```

Refresh the local player's HUD during frame processing. Host mutations do not
produce received-state events, so an event-only refresh would miss them:

```odin
kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
defs := [?]kcombat.Ability_Def{ROCK_ABILITY, HEAL_ABILITY}
kui.abilities_refresh(&self.hud_ab, defs[:], self.me_spel.cds[:], self.me_spel.stamina, ksess.session_tick_hz(&self.ses))
```

<a id="gotchas"></a>

## Layout and lifecycle constraints

- **Set grow directions alongside anchors.** An auto-sizing label at the
  bottom edge can grow downward off-screen. Pair `control_set_anchors_preset`
  with grow directions and anchor-relative offsets, as the prompt does:

  ```odin
  gd.control_set_anchors_preset(cast(gd.Control)p.label, .Preset_Center_Bottom, false)
  gd.control_set_v_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Begin)  // grow upward
  gd.control_set_h_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Both)   // keep centered
  gd.control_set_offset(cast(gd.Control)p.label, .Top, -34)                        // lifted baseline,
  gd.control_set_offset(cast(gd.Control)p.label, .Bottom, -34)                     // tracks resizes
  ```

- **Look up the host id.** `lobby_refresh` crowns `session_host(s)`. A resumed
  host keeps its old id (see [save.md](save.md)), so do not hardcode player
  id 1 as the host.
- **Refresh lists on events.** Call `lobby_refresh` on session events,
  `chat_refresh` on `Ev_Line`, and `score_refresh` on `Ev_Stats_Updated`.
  Refresh the local HUD each frame for live cooldowns and host-written state.
- **Release tracking arrays separately from nodes.** `*_destroy` frees the
  Odin arrays used by `lobby`/`chat`/`score`/`inv`/`abilities` to reuse rows
  stored in a `[dynamic]`. The scene owns their nodes.
  [`kboot.boot_detach`](boot.md) destroys those arrays before queuing their
  container subtree for deletion. Freeing only the game node releases the
  nodes but leaks tracking arrays until process exit. Call `boot_detach` while
  the game process remains alive.
- **`prompt`/`hp` need no `*_destroy`.** Each holds only a Label node freed
  with its parent. A `netgraph` holds a Label and a fixed sparkline array;
  `netgraph_destroy` zeroes it for consistent teardown calls. The game owns
  its custom netgraph, while Boot supplies its data through `boot_net_stats`.
- Position widgets after creation; their initial position is the anchor origin.

## Netgraph

Create a network overlay with `netgraph_make`, control its visibility with
`netgraph_show`, and update it with `netgraph_refresh(ng, Net_Stats{...})`:

```
net  42ms  jit 6ms  loss 1.2%  ok
rate rx 120p/s 3.2k/s · tx 48p/s 0.4k/s
rx 3.2k state 2.1 stream 0.8 app16 0.2 · tx 0.4k cmd 0.3
sim  lead 4t  resim ▁▁▂▁▇▁▁…  rec 128  gap 2  ack 3t  rw 12t  cpu 0.42ms  cq 0
snap full 2% delta 98% rows 428 quiet 2100 defer 3 aoi 900 18.2k
warn  rclamp 3▲
```

The first row shows RTT from the replicated ping stat (`net_ping_ms`) plus
jitter and loss from [ENet's per-peer statistics](netgd.md#traffic-and-link-stats).
Clients obtain the host connection's values through `netgd.wire_link_quality`.
The quality label prioritizes loss, then jitter, then RTT. The rate row reports
the last completed one-second packet and byte window.

The traffic row groups bytes by message kind. Supply
`Net_Stats.traffic = netgd.wire_traffic(&boot.wire)` as an opaque value so
`kit/ui` remains independent of the transport package. The simulation row
shows input lead and gaps, age of the last fully applied snapshot acknowledgement,
the authority's rewind envelope, replay cost since refresh, and command queue
pressure. The snapshot row shows full/delta proportions, unchanged-row
suppression, budget deferrals, AOI culling, and bytes.

The resimulation sparkline shows bursts of client replay work. A flat baseline
means no recent replay; lost inputs and contested prediction errors can produce
spikes even when correction smoothing hides their visible effect. Every field
is optional; coop games leave `sim` false. Use
[`kboot.boot_net_stats(&boot)`](boot.md) for Boot's coop statistics and the
simulation projection when `boot_lane` is installed.

The `warn` row appears when diagnostic counters are nonzero. It includes
`guard_hits` for client writes to authority-owned fields, `input_drops` for
dropped simulation inputs, `cmd_capped` for commands refused by the per-player
cap, and `rewind_clamped` for queries limited by measured-link bounds,
render-hint limits, or the absolute rewind configuration.

`boot_net_stats` fills malformed-message, access/predicate, traffic-budget,
and write-guard counters for every game. An installed lane adds simulation
counters. The overlay prints each nonzero count and marks increases since the
previous refresh with ▲. A single clamp before timing settles can be normal;
a count still rising a minute into play needs investigation. The change marker
distinguishes current failures from accumulated startup counts.

Siblings: [session.md](session.md) (roster, stats, `session_tick_hz`) ·
[comms.md](comms.md) (the chat log) · [combat.md](combat.md) (`Ability_Def`, cooldowns) ·
[items.md](items.md) (`Slot`, `Table`) · [netgd.md](netgd.md) (the shim + gauge the
netgraph draws).
