# Kit API conventions

This page documents naming, event delivery, and ownership conventions used by
Kit packages. It is primarily a contributor reference. Game authors do not need
to memorize it before using the quickstarts.

## Event delivery

Kit chooses an event shape according to the lifetime of the data and whether the
caller can wait until the next frame.

### Queued events

Packages with several event types expose a tagged `Event` union and a poll proc:

```odin
for {
	event, ok := ksess.session_poll(&session)
	if !ok {break}
	// handle event
}
```

`session_poll`, `comms_poll`, and `xfer_poll` use this pattern. Events are queued
so normal game reactions run from the game's frame loop, after Kit has completed
the operation that produced them.

When a package has one queue shape, the poll proc returns a tuple instead of a
one-variant union. `album_poll` and `fire_poll` follow this rule.

### Current state

A proc such as `boot_phase` or `code_poll` reports current state rather than
draining a history. Callers may read it whenever they need the latest value.

### Synchronous callbacks

A callback is synchronous only when Kit cannot finish an operation without an
answer. Examples include:

- entity factory create/free procedures;
- the interest-management locator;
- backup blob serialization;
- simulation sample and step procedures;
- command hooks and application-message decoders; and
- effect collision callbacks.

There are two useful categories:

- A **pull callback** supplies a value Kit cannot derive, such as an entity
  position or serialized game blob.
- An **atomic hook** runs while temporary operation state is valid, such as a
  `^knet.Reader` over a received app message or an authority consequence that
  must remain in the same transaction.

Do not retain pointers into temporary readers or re-enter the owning subsystem
from an atomic hook unless that API explicitly permits it. If a game reaction
can wait until the next frame, queue it instead. `ksess.App_Queue` provides this
file-and-drain pattern for application messages.

The full session-specific classification is in
[Three tiers of entry into your code](session.md#three-tiers-of-entry-into-your-code).

### Generated halves

A generated half is a name-paired proc containing game-specific behavior. The
generator supplies routing and calls it from the appropriate role or timeline.
For example, `<verb>_then` is the authority consequence of a command and
`<tick>_fx` is presentation associated with a simulation tick.

Generated routing removes many repeated `is_host` checks, but it does not make
authority-specific work disappear. Keep work in an explicit authority half or
`@(gd_step = "authority")` when only the authority can perform it.

### Godot signals

Engine-side node signals use `@(gd_connect)` or explicit typed signal helpers.
Transport signals terminate in the forwarding methods configured by
`boot_attach`; standard names are generated when `Options.methods` is left at
its zero value.

## Lifetime and ownership suffixes

Constructor names indicate who supplies and owns storage:

- `_make` returns a new value whose Kit-owned allocations must later be released
  with the matching `_destroy` proc. Examples: `registry_make`, `chat_make`.
- `_init` initializes caller-owned storage in place. Examples: `session_init`,
  `comms_init`, `lane_init`.
- `_attach` binds state to a Godot node or engine object whose lifetime remains
  owned by the scene. Examples: `wire_attach`, `boot_attach`.

Teardown names distinguish operations:

- `_destroy` releases allocations owned by the value. It does not free scene
  nodes unless the API explicitly says otherwise.
- `_clear` and `_reset` remove current contents while preserving reusable
  storage.
- `_close` ends a connection or external session.
- `_detach` removes an attachment and disconnects its engine-facing state.

Configuration structs use zero as the documented default for optional fields.
Check the package reference before assuming that an arbitrary runtime value is
valid as an uninitialized zero value; initialization procedures may still be
required.

## Procedure prefixes

Public procedures normally use the snake-case type name as a prefix:

- `Registry` → `registry_*`
- `Lane` → `lane_*`
- `Chat` → `chat_*`

This makes `rg 'registry_' kit/net` a practical API index. Short UI types use the
noun shown at call sites, such as `Hp_Bar` with `hp_*` and `Abilities_Bar` with
`abilities_*`.

Generated procedures instead use the declared game, entity, command, or event
name. Their naming rules are documented in [kit/net](net.md),
[kit/session](session.md), and [kit/sim](sim.md).

## Package boundaries

The dependency direction is intentional:

- `kit/net`, `kit/session`, and `kit/sim` are engine-independent mechanisms.
- `kit/netgd`, `kit/steamgd`, `kit/ui`, and `kit/fx` adapt those mechanisms to
  Godot and external transports.
- `godot:play` composes Kit mechanisms into optional gameplay blocks.
- Game code owns genre rules, authored scenes, and backend integration.

Avoid adding game policy to a mechanism package merely because one example
needs it. Prefer a `play` block, a documented recipe, or game code when the rule
does not apply across genres.

## Out-of-scope systems

Kit intentionally does not provide:

- voice or proximity-voice capture and mixing;
- mobile touch controls or responsive mobile UI;
- asynchronous, turn-a-day session storage;
- user accounts, authentication, ranked ladders, or a persistent database;
- matchmaking and dedicated-server orchestration; or
- a native ENet relay for symmetric NAT.

Steam voice or a separate voice SDK can run beside Kit. Mobile controls and UI
belong in the game layer. Asynchronous games and account-backed persistence need
a backend whose authority outlives any one live session.

Kit's save package persists a run and reconnect identity; it is not an account
database. Recipes for character-portable data, private per-player messages, and
player-to-player transactions are documented in [kit/session](session.md#recipes-over-existing-pieces).
