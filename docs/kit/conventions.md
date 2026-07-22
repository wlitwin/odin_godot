# kit design notes and conventions

This page is for contributors and the curious. It records the house grammar every package shares (so a new package feels familiar before you read its page) and the capabilities the kit leaves out, with where to reach instead.

## The house grammar

Three conventions run through every package.

### Events out; callbacks only for answers

Seven delivery mechanisms exist, and the choice among them is mechanical, not
taste:

- A module with *many* event shapes drains a named `Event` union: `session_poll`,
  `comms_poll`, `xfer_poll` loop until `ok = false`.
- A module with *one* event shape polls a **bare tuple**: `album_poll` (which
  `(player, kind)` landed), `fire_poll` (the next projectile to spawn). There is
  no union for a queue of one thing.
- A *value you read* rather than a queue you drain is a **state poll**:
  `code_poll` (the rendezvous phase), `boot_phase` (where the game is).
- A **synchronous callback** exists only where the kit needs an answer
  mid-operation and cannot proceed without it: the factory's `make`/`free` (the
  registry needs the pointer before a snapshot can apply), the interest
  `Locator_Proc` (the session can't read your positions), sim's
  `Sample_Proc`/`Step_Proc`, `Later_Proc`, the command hooks, fx's `On_Hit_Proc`.
- The **`_then` suffix** is the authority-only half of a generated event pair:
  the consequence, gated by the generated dispatch so the half never checks a role.
- **`boot_pump`** forwards slices of the session and comms queues in one call:
  the composed convenience over the two polls.
- Engine-side wiring rides Godot signals through **`@(gd_connect)`**.

The rule the seven collapse to: poll unions for multi-event, tuple-poll for
single-event, synchronous callbacks only for the answer the kit cannot proceed
without, and **everything else is an event.** Handlers file bytes; game code runs
on the game's own stack in the pump, never in a callback into half-initialized
script state.

One refinement the list compresses is spelled out in
[session.md's three tiers](session.md#three-tiers-of-entry-into-your-code), because
kit/session has the most entry points of any package: the synchronous half is
really *two* kinds. A **pull callback** is the kit asking a question it cannot
answer: the factory's `make`, the interest locator, the backup blob writer, sim's
`Sample_Proc`/`Step_Proc`; you answer and return. An **atomic authority hook** runs
inside an operation whose state does not survive it: the command hooks and
`_then`, an app handler holding a live `^knet.Reader` into the receive buffer; you
act, on the authority, and you do not re-enter. Everything remaining is tier three,
and the derivation is mechanical: *if the same meaning survives being queued and
drained next frame, it must be queued.* That is why `ksess.App_Queue` exists as a
type. Every `SES_APP` rider follows the same file-and-drain discipline.

### Four verbs name a lifetime

A type's constructor tells you who owns its memory, so nobody has to guess whether
to free it:

- `_make` returns the value: the caller owns it (`chat_make`, `registry_make`,
  `writer_make`).
- `_init` initializes memory the caller already holds, in place (`session_init`,
  `comms_init`, `lane_init`).
- `_attach` binds to a Godot node whose lifetime the *scene* owns (`wire_attach`,
  `boot_attach`).
- **A zero value is ready to use**: every `*_Config` means the defaults at zero,
  so a zero config is the out-of-the-box session.

Teardown matches the constructor: `_destroy` frees exactly what the module
allocated and **never a scene node** (the node tree belongs to the scene);
`_clear` / `_reset` empty a container without freeing it (`chat_clear_input`,
`tracers_clear`, `writer_reset`, `later_clear`); `_close` ends a connection
(`code_close`, `web_close`). Match the teardown verb to the constructor and both
leaks and double-frees become errors of habit rather than runtime surprises.

### A type's whole API is one grep

The proc prefix is the type's snake-cased name (`registry_*` for `Registry`,
`lane_*` for `Lane`, `chat_*` for `Chat`), with no exceptions, so `grep registry_`
is the complete surface of `Registry` and nothing hides under a cleverer name.
When following the rule would force an awkward call site, the type name gives way,
not the prefix: kit/ui's widgets are `Hp_Bar` (`hp_*`) and `Abilities_Bar`
(`abilities_*`), named for the nouns games already say (`hp`, beside `Inv` and
`Score`) rather than a longer `health_bar_refresh` call.

## What the kit leaves out

A few capabilities are out of scope. Here is what the kit does not do, and where
to reach instead.

### Voice

Voice is not in the toolkit. Friendslop groups already sit in a Discord call, so
voice is a solved problem for the target audience. If you ship on Steam,
GodotSteam exposes Steam voice as a near-free add-on ([steamgd](steamgd.md) gives
you the singleton access pattern). The exception is PROXIMITY voice (the
horror-co-op signature mechanic), which needs positional mixing that the
toolkit's replicated positions make easy to drive; reach for it when a game needs
it.

### Recipes, not code

Character-portable saves, private per-player state, and player-to-player trade
(the mediating-entity transaction) are documented as recipes in
[session](session.md), not as code. See the design notes in the repository's
knowledge base.

### Mobile

Nothing here is mobile-hostile (Godot exports to iOS/Android, the wire is bytes,
ENet and WebRTC both run), but two mobile realities are unaddressed. A phone's
link flaps (cell↔wifi handoff, backgrounding) far more than the "friends rejoin
an evening session" model assumes, and touch input has no home in the examples'
keyboard/mouse verbs. The reconnect machinery (tokens, host takeover) is exactly
what a flappy link wants and carries over unchanged; the gap is a touch-control
layer and a UI that reflows to a phone, both game-side. Reach for a worked mobile
example when a game ships mobile, not as kit surface.

### Async correspondence (turn-a-day, play-by-mail)

This is out of scope, and honestly a different toolkit. Everything here assumes
a LIVE session: a shared clock, interpolation timelines, presence, a host holding
authority in RAM. An async game (chess-by-notification, a 4X you touch once a
day) has no live clock and no host: its "wire" is a database row and a push
notification, its "reconnect" is a fresh load of persisted state. The
state-not-messages discipline still shapes a turn, but the transport, authority,
and persistence models are wholly different. Build it on a backend plus Godot's
HTTP client; the netcode kit has nothing to lend it but its taste in
serialization.

### Database persistence (accounts, ranked ladders, a world that outlives the session)

This is not in the kit, and the seam is clean. The kit persists a RUN
([ksave](save.md) writes POD blobs to a local file, backups ride the wire,
host-takeover resumes from them), but it does not persist a PLAYER across runs
against a server store.
That is a backend concern (Postgres/SQLite behind an auth'd API), and the kit
stays agnostic: a game reads a profile from its backend at boot and hands the
bytes to the session as ordinary replicated/blob state, then writes results back
after the run through its own client. The dividing line is authority LIFETIME:
the kit owns state for the length of a session; anything that must outlive every
participant leaving lives in your database, not here.
