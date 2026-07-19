# kit/ui — stock-theme widgets

The toolkit's stock widgets, built programmatically — no scene assets to install; any script
can summon them. Lobby, chat box, scoreboard, and the HUD set (interact prompt, inventory
grid/hotbar, health bar, ability bar). Styling is deliberately stock Godot theme —
friendslop lobbies are for friends, and games that care can theme the returned nodes.

**Lane compatibility: lane-agnostic.** Widgets read session-level state (roster, stats,
chat) and whatever values the game hands them — both lanes use them as-is (the netgraph
overlay draws coop and sim rows alike). The HUD set's *feeders* in the examples are
coop-shaped (e.g. the ability bar reads kit/combat cooldowns); a sim game feeds the same
widgets from its own fields.

```odin
import kui "godot:kit/ui"
```

## Mental model

**kit/ui builds controls, it never owns flow.** Every widget follows the same contract: a
`*_make` builds nodes under a parent you supply and hands back the handles; the GAME wires
the buttons/input and decides when to repaint (`*_refresh` on events, not per frame — except
the HUD, which the owner repaints live). `*_destroy` frees only the tracking arrays — the
node tree belongs to the scene and is freed with the owner.

Refresh procs reuse their row Labels across repaints and hide extras; nothing reallocates
per frame.

The package's **public API speaks `string`, not `cstring`** — callers use `fmt.tprintf` and
never think about NUL termination or c-allocator lifetimes.

## API by task

**Lobby** — title, status line, live roster, three buttons:

```odin
lobby_make :: proc(parent: gd.Node, title: string) -> Lobby
lobby_destroy :: proc(l: ^Lobby)
lobby_set_status :: proc(l: ^Lobby, text: string)
lobby_show_menu :: proc(l: ^Lobby, menu: bool, start: bool)
lobby_show_code :: proc(l: ^Lobby, show: bool)   // reveal the join-code field
lobby_code :: proc(l: ^Lobby) -> string          // what the human typed — trimmed, UPPERCASED, temp-allocated
lobby_refresh :: proc(l: ^Lobby, s: ^ksess.Session)
```

`Lobby` exposes `host_btn`, `join_btn`, `start_btn` (`gd.Button`) for the game to connect —
`start_btn` starts hidden until the host likes the roster (`lobby_show_menu`).
`lobby_refresh` repaints the roster from the [session](session.md): sorted by `Player_Id`
(join order — stable), the host crowned, yourself marked `(you)`, departed players dimmed to
`(away)`, and the stat registry's auto-fed ping when measured. Games with a relay call
`lobby_show_code` once in `ready()` (the field sits above Join; the menu toggles honor it);
Join then reads `lobby_code` — `""` means join by address.

**Chat box** — a bounded scrollback of [kit/comms](comms.md) lines plus a `Line_Edit`
(`CHAT_SHOW :: 8` rows painted; the comms log keeps more):

```odin
chat_make :: proc(parent: gd.Node) -> Chat
chat_destroy :: proc(ch: ^Chat)
chat_show :: proc(ch: ^Chat, visible: bool)
chat_clear_input :: proc(ch: ^Chat)
chat_refresh :: proc(ch: ^Chat, c: ^kcomms.Comms)
chat_submit :: proc(ch: ^Chat, c: ^kcomms.Comms, text: gd.String, sent: ^bool = nil)
```

Paints `name: text` for speech, `* text` for system lines. The game connects
`chat.input`'s `text_submitted` and calls `chat_submit` from it — the whole handler:
extract (clamped), say, clear, and PUT THE KEYS BACK ON THE WHEEL. The focus release is
the part that gets forgotten — without it a keyboard player's WASD stays trapped in the
chat box after every message; `sent` (the game's latch) stops the submitting Enter from
immediately re-opening chat when the game binds Enter to "talk".

**Scoreboard** — players × whatever stat columns the game registered (ping auto-fed,
damage/kills/deaths from [kit/combat](combat.md), the game's own counters), straight from the
session's stat registry. kit/ui renders what the registry holds; it declares nothing:

```odin
score_make :: proc(parent: gd.Node) -> Score
score_destroy :: proc(sb: ^Score)
score_show :: proc(sb: ^Score, visible: bool)          // classically: while Tab is held
score_hide :: proc(sb: ^Score, name: string)           // hide a column by name
score_refresh :: proc(sb: ^Score, s: ^ksess.Session)
```

Departed players stay listed — their tallies survive disconnects by design. Some stat
columns are PLUMBING, not score — a loadout choice replicated through the registry
(scrapyard's look/iron, the muster's ready bit) has no business on the board;
`score_hide` keeps it off (once, after the columns are declared; unknown names are a
harmless no-op).

**HUD** — prompt, inventory/hotbar, health, abilities:

```odin
prompt_make :: proc(parent: gd.Node) -> Prompt
prompt_set :: proc(p: ^Prompt, text: string)           // "" hides the prompt

inv_make :: proc(parent: gd.Node, capacity: int) -> Inv
inv_show :: proc(inv: ^Inv, visible: bool)
inv_refresh :: proc(inv: ^Inv, slots: []kitems.Slot, table: ^kitems.Table, selected := -1)
inv_destroy :: proc(inv: ^Inv)

hp_make :: proc(parent: gd.Node) -> Health_Bar
hp_refresh :: proc(hb: ^Health_Bar, current, max_hp: i32)

abilities_make :: proc(parent: gd.Node, capacity: int) -> Ability_Bar
abilities_refresh :: proc(bar: ^Ability_Bar, defs: []kcombat.Ability_Def, cds: []u16, resource: i32, tick_hz: int)
abilities_destroy :: proc(bar: ^Ability_Bar)
```

All text blocks over stock theme: the health bar renders `hp ▓▓▓▓▓▓▓░░░ 70/100` (zero art to
install, and a test can read the exact fill back out of the tree); abilities render `[rock]`
ready, `[rock 1.2s]` cooling, `[rock $]` ready-but-unaffordable. Cooldowns count TICKS of
whichever loop decays them — `tick_hz` is required, so pass `session_tick_hz(&ses)` (or the
lane's rate on a sim game) and the seconds shown are true at any configured rate. (It used
to default to 20 Hz; a 60 Hz game that omitted it showed cooldowns 3× too long — the
footgun is deleted, not documented.) BOTH ability models feed the one widget — `kcombat.Ability_Def` is
the def vocabulary at every layer: a slot-array game passes its `Cooldowns` bundle
(`c.cds[:]`); a play-block game gathers its blocks' countdowns into a local array beside the
same def rows (`[]u16{r.slime.cd, r.ignite.cd}`). With `selected`, the inventory row doubles
as a hotbar.

## Full replacement: the adopt contract

The kit provides the implementation, never the final look. A game that wants its own
lobby/chat/scoreboard authors a scene in the editor and hands it to boot
(`Options.lobby_scene` / `chat_scene` / `score_scene` — [boot.md](boot.md)); the kit
ADOPTS it: instances the scene, resolves the nodes it drives **by NAME, at any depth**
(nest your chrome however you like), and pours the stock behavior into them. Everything
else in the scene is the game's own — the kit never touches what it didn't name. A
missing contract node is reported LOUDLY (once, at boot, greppable) and degrades to a
dead widget, not a crash.

```odin
lobby_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene, title: string) -> Lobby
chat_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene) -> Chat
score_adopt :: proc(parent: gd.Node, scene: gd.Packed_Scene) -> Score
```

The contracts, by node name:

- **Lobby** — `Title` (Label) · `Status` (Label) · `Players` (any container — rows land
  here) · `Host` (Button) · `Join` (Button) · `Start` (Button; ships hidden), plus an
  OPTIONAL `Code` (LineEdit) for join-code games — quiet when absent (`lobby_show_code`
  turns it on).
- **Chat** — `Lines` (any container — the scrollback rows land here) · `Input` (LineEdit).
- **Scoreboard** — `Grid` (GridContainer — the kit sets its column count and pours the
  cells).

The scene owns its OWN layout (anchors under the boot layer bind to the viewport) — none
of the stock builders' sizing hacks apply, and the scoreboard's hand-centering is skipped.
Row/cell Labels are kit-created — theme them from the scene root. Extra nodes — a Single
Player key, an address field, the plate — are the game's to wire after `boot_attach`,
through the widget's `root`.

## Worked excerpt (cavecrawl)

```odin
self.ui = kui.lobby_make(self.owner, "C A V E C R A W L")
kui.lobby_set_status(&self.ui, "Host a cave, or join one at localhost")
gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
gd.connect_to(cast(gd.Object)self.ui.join_btn, "pressed", self.owner, "on_join")
gd.connect_to(cast(gd.Object)self.ui.start_btn, "pressed", self.owner, "on_start")

self.chat = kui.chat_make(self.owner)
kui.chat_show(&self.chat, false)   // chat with nobody wired is just a text box
gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")

// The LAYOUT is the game's call, not the kit's: status cluster stacked
// in the top-left (kit widgets spawn at the anchor origin by default).
gd.control_set_position(cast(gd.Control)self.hud_hp.label, {8, 4}, false)
gd.control_set_position(self.hud_ab.root, {8, 22}, false)
gd.control_set_position(self.inv.root, {8, 40}, false)
```

And the owner's live repaint (hosts get no state events, so the HUD repaints in process):

```odin
kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
defs := [?]kcombat.Ability_Def{ROCK_ABILITY, HEAL_ABILITY}
kui.abilities_refresh(&self.hud_ab, defs[:], self.me_spel.cds[:], self.me_spel.stamina, ksess.session_tick_hz(&self.ses))
```

## Gotchas

- **Anchor presets set ANCHORS only — not grow directions.** An auto-sizing label placed at
  the exact bottom edge grows DOWN, off screen. Pair `control_set_anchors_preset` with grow
  directions and anchor-relative offsets, the way the prompt does:

  ```odin
  gd.control_set_anchors_preset(cast(gd.Control)p.label, .Preset_Center_Bottom, false)
  gd.control_set_v_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Begin)  // grow UP
  gd.control_set_h_grow_direction(cast(gd.Control)p.label, .Grow_Direction_Both)   // keep centered
  gd.control_set_offset(cast(gd.Control)p.label, .Top, -34)                        // lifted baseline,
  gd.control_set_offset(cast(gd.Control)p.label, .Bottom, -34)                     // tracks resizes
  ```

- **The crown follows the transport SEAT, not player id 1.** `lobby_refresh` crowns
  `session_host(s)` — a resumed host returns under its old id (see [save.md](save.md)), so
  "host" is a seat, never an id you hardcode.
- **Refresh on events, not every frame** — `lobby_refresh` on session events,
  `chat_refresh` on `Ev_Line`, `score_refresh` on `Ev_Stats_Updated`. The exception is the
  owner's own HUD (live cooldown text, and hosts get no state events).
- **`*_destroy` does not free nodes.** The tree belongs to the scene; destroy only drops the
  Odin-side tracking arrays.
- Widgets spawn at the anchor origin — position them yourself; layout is the game's call.

## The netgraph — "is it healthy?", drawn

A drop-in text overlay (`netgraph_make` / `netgraph_show` /
`netgraph_refresh(ng, Net_Stats{...})`) that draws the numbers that move when
the link goes bad:

```
net  42ms  jit 6ms  loss 1.2%  ok
rx 3.2k state 2.1 stream 0.8 app16 0.2 · tx 0.4k cmd 0.3
sim  lead 4t  resim ▁▁▂▁▇▁▁…  rec 128
```

Row 1 is the link: rtt off the replicated ping stat (`net_ping_ms`), jitter
and loss off [ENet's own per-peer statistics](netgd.md#the-wire-gauge--bytes-by-kind-and-the-links-own-truth)
(`netgd.wire_link_quality` — clients fill it about the host), and a quality
word that rates loss first, then jitter, then raw rtt. Row 2 is the wire's
bytes-by-kind (`Net_Stats.traffic = netgd.wire_traffic(&boot.wire)` — an
opaque pre-formatted string, so this package never imports the transport).
Row 3 is the sim lane, and the RESIM SPARKLINE is the point: a steady sim
draws a flat baseline; a lost input or a contested mispredict makes the
client rewind, and that burst — invisible in a headless log — is exactly
what you can SEE here. Every field is optional (coop games leave `sim`
false); quickdraw's fill is the worked example. Booted games skip the
hand-fill entirely: [`kboot.boot_net_stats(&boot)`](boot.md) returns the coop
core (rtt, link jitter/loss, malformed drops, traffic) — a sim game lays its
lane rows on the result.

Siblings: [session.md](session.md) (roster, stats, `session_tick_hz`) ·
[comms.md](comms.md) (the chat log) · [combat.md](combat.md) (`Ability_Def`, cooldowns) ·
[items.md](items.md) (`Slot`, `Table`) · [netgd.md](netgd.md) (the shim + gauge the
netgraph draws).
