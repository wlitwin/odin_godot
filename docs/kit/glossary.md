# Glossary

The kit's terms of art, one paragraph each — every doc links here the first
time it leans on one.

**friendslop** — the co-op game shape the toolkit is tuned for: 2–8 people
who know each other, one of whom hosts. Trust your friends, keep the host
authoritative, make joining trivial. The word names the *shape*, not the
quality bar; "the co-op kit" and "the friendslop kit" are the same thing.

**lane** — which machinery carries a replicated field, chosen per field by
its tag. The **delta lane** (`replicate`) is host-authoritative reliable
state; the **owner stream** (`owner`) is a peer's own
unreliable-but-fresh pose; the **predict lane** (`predict`) is
server-simulated state the owner predicts locally (the sim lane,
[sim.md](sim.md)). The tags are the whole declaration — the lanes never
fight over a field.

**half** — a plain proc the framework calls because its *name pairs* with a
declaration, holding the game-shaped half of a mechanism whose plumbing is
generated. `<verb>_then` (authority consequence), `<tick>_fx` (presentation),
`<class>_<field>_edge` (react to a change), `<entity>_spawned`/`_freed`
(census bookkeeping), `<game>_<event>` (session events). Generated dispatch
holds every role gate, so halves contain no `is_host` checks.

**verb** — a player-issued action that can be *rejected*: a `@(gd_command)`
proc whose body is the predicate-and-mutation, issued through its generated
`<verb>_cmd` wrapper. Predicted where legal, validated on the authority,
reverted on rejection; consequences ride the `_then` half.

**fact** — a sim-lane event that *presents* on every screen at that screen's
right time: the causer's live pass instantly (`mine=true`), the authority
live, watchers when their watch clock reaches the fact's tick, a resim never.
An entity tick's facts are its return values (the mine-form `_fx` half);
a cross-entity event discovered in a world pass or an authority half is a
*declared* fact — `@(gd_fact)` on the `<event>_fx` half, announced through
the generated bare-name door ([sim.md](sim.md)).

**census** — the framework's own ledger of live entities, queried back
instead of hand-mirrored: generated `<entity>_of(id)` / `my_<entity>()` /
`<entity>_owned_by(player)` / `<entity>_ids()` per `entity=` tag. The
`_spawned`/`_freed` **census hooks** fire at bookkeeping time — *before*
spawn fields apply — which is why presentation belongs elsewhere (see
*dress*).

**dress** — presentation applied to an entity when it first appears on a
screen: tint by team, position the node, build the nameplate. Dress belongs
on the `Ev_Spawned` event (fields are set there), never in the census hook
(fields are not), and edge halves deliberately *don't* fire for first sight
— a late joiner's 3–2 scoreboard is a baseline to dress, not three goals to
celebrate.

**mine / watched** — whose simulation a thing rides on this screen. *Mine*:
my input drives it here, now (my avatar, my predicted projectile). *Watched*:
someone else's truth, rendered a breath in the past so interpolation always
has two samples to stand between. The mine-form `_fx` halves and
`session_present` exist to put each consequence on the right one of those
two clocks.

**edge** — a change in replicated state, observed as a transition. The
`<class>_<field>_edge(game, self, old, new)` half fires once per *net*
change on every peer — the machinery that replaced hand-rolled `seen_*`
mirrors and per-frame compares.

**door** — a proc that starts or joins a session: `boot_host`, `boot_join`,
`boot_serve`, and the game's `on_host`/`on_join` methods the stock lobby's
buttons press. "Enforced at the door" means at join time, before any state
flows (bans, capacity, the version fingerprint).

**boot** — `kboot.Boot`, the game's one handle to the stock stack: lobby UI,
chat, transport wire, entity factory, and (promoted games) the sim lane.
`boot_attach` builds it; `boot_pump` drives it once per frame.

**block** — a `play`-layer primitive a game composes by embedding: a struct
carrying its own replicated fields and name-paired generated hooks, with
defaults that encode a stance (`play.Gun`, `play.Health`, `psim.Roller`).
A block delegates its work down to kit *mechanisms* — play → kit is the only
arrow, never the reverse — so the layers cannot drift on what "ready" or "a
death" means ([play.md](play.md)).

**mechanism** — a `kit`-layer proc, wire format, or descriptor table that a
block or game calls (`kcombat.cast_gate`, `kcombat.hurt`): contextless, no
opinions about game feel, no replicated state of its own. The litmus for the
split: a block *holds* replicated state and generates hooks; a mechanism is
what it calls — [combat.md](combat.md#health-and-abilities) holds the
two-layer rule.

**acid** — an acceptance test that runs the *real* game, multi-process,
headless, under an injected bad link, and asserts over printed receipts
([testing.md](testing.md)). Named for burning through pleasant illusions:
if the acid is green at 240ms RTT, the feature works where your players
actually live.
