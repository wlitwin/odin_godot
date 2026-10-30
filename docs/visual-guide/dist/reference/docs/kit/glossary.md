# Kit glossary

This page defines terms used by Kit's generated APIs and reference
documentation.

## Authority

The process whose value is final for a piece of state. In session replication,
the host is authoritative for `replicate` fields and commands, while an entity
owner is authoritative for its `owner` stream. In `kit/sim`, the server is
authoritative for `predict` fields.

A listen server is both an authority and a player. A dedicated server is an
authority without a player avatar.

## Boot

`kboot.Boot` connects the common Godot-facing parts of a Kit game: lobby and HUD
widgets, `netgd` transport, session, comms, generated entity factory, frame pump,
and an optional simulation lane. For the conventional direct-field shell,
scriptgen emits `<game>_net_attach`, the normal `<game>_net_frame`, and
`<game>_net_detach`. `<game>_net_pump` and component-level `boot_*` procedures
are the custom-order primitives underneath.

`boot_phase` reports `.Menu`, `.Connecting`, `.Lobby`, or `.Playing` from the
current session state.

## Census

The generated index of live entities of each declared type. An
`entity=Player:1` field generates typed queries such as `player_of`,
`player_owned_by`, `player_ref`, and `player_all`. `Net_Ref(Player)` is the
pointer-free value to retain;
`Net_Entity(Player)` is a temporary iteration row carrying its live typed
pointer, owner, and ID. The census avoids maintaining a second game map that can
drift from the session registry.

The generated `<entity>_spawned` and `<entity>_freed` hooks run when census
bookkeeping changes. Spawn fields are not yet the presentation baseline in the
`_spawned` hook; use the later typed `<entity>_born` hook or the session's
`<game>_entity_spawned` event when initialization depends on received fields.

## Command

A player-requested action declared with `@(gd_command)`. A generated
`<verb>_cmd` proc uses the same call site on a client and on the authority.
Its typed `Action_Policy` decides who may ask, whether the issuing client may
predict, and the encoded argument limit. The command body validates current
game state and applies a single-entity mutation.

An optimistic command runs locally before the authority replies. Confirmation
keeps the predicted result; rejection replaces it with authoritative state.
Commands on simulation-lane entities are scheduled on ticks and replay with the
simulation.

The generated call returns `Action_Outcome`: its state is
`Applied`/`Predicted`/`Rejected`, its optional rejection reason is typed, and
its sequence correlates the later callback. Immediate and scheduled actions
share `Action_Reject_Reason` (`Access`, `Rate`, `Malformed`, `Stale`,
`Predicate`, `Timeout`) and the session's command-confirmed/rejected/executed
halves.

## Consequence (`_then`)

The authority-only half paired with a command, tick, or generated event. A
command body should mutate its target entity. Its `<verb>_then` consequence
performs game-level work such as spawning another entity, crediting a player, or
transferring ownership after the command succeeds.

## Delta lane

The reliable, host-authoritative replication path selected by
`gd:"replicate"`. At each network tick, the registry compares fields with a
shadow copy and encodes only changed values. A full entity record provides the
baseline for spawning, late join, and resynchronization.

## Edge

A transition in a replicated field. A generated
`<class>_<field>_edge(game, entity, old, new)` half runs when an applied network
change crosses that field. Initial state and full resynchronization establish a
baseline without replaying historical edge effects.

## Entity

A network-tracked struct with a `knet.Net_Id`, a stable wire type, an owner, and
a generated descriptor. The session controls its network lifetime; the entity
factory creates or frees the corresponding Odin script and Godot node on each
peer.

`Net_Id` identifies an entity within a session. It is not a Godot instance ID or
a persistent save identity.

## Presentation event

A one-shot presentation occurrence declared with `@(gd_event)`. Scriptgen
generates a suffix-free `^Boot` announce proc from its `_fx` declaration. Its
entity anchor selects the existing session or simulation presentation timeline,
supplies `mine`, and supports `everyone`, `owner`, or `observers` audiences.
With one entity parameter the anchor is inferred; several require
`anchor=PARAM`.

Events do not mutate authoritative state and are not replayed to joiners. Kit
suppresses sim events during resimulation, presents live/owning screens without
another interpolation delay, and schedules observers on the anchor's clock.

## Tick payload event

A one-shot simulation-lane presentation occurrence associated with a tick. A
tick proc can return payload values to a name-paired `_fx` half. Cross-entity
or world occurrences use `@(gd_event)` instead.

Tick payloads do not mutate authoritative state. Kit suppresses them during
resimulation, presents local payloads immediately, and schedules remote payloads on
the watched timeline.

## Factory

The mapping from a stable entity type number to the scene, descriptor, command
set, simulation set, and create/free functions needed on every peer. A field tag
such as ``gd:"entity=Player:1"`` lets script generation build this table and its
typed spawn/query helpers.

## Half

A user-written proc whose name and signature pair with a generated mechanism.
Script generation supplies routing and calls the game-specific half. Common
examples are:

- `<verb>_then` for an authority consequence;
- `<tick>_fx` for simulation presentation;
- `<class>_<field>_edge` for a replicated change;
- `<entity>_spawned`, `_born`, and `_freed` for entity lifetime; and
- `<game>_<event>` for session events.

The term describes one side of generated code plus game code; it does not imply
that the proc runs on every role.

## Owner stream

The unreliable, freshness-oriented replication path selected by `gd:"owner"`.
The entity's current owner writes the fields. The host verifies the sender's
ownership, relays accepted samples, and other peers interpolate them.

An owner stream is suitable when occasional loss can be replaced by the next
sample. It trusts the owner to supply the value and is therefore not a
cheat-resistant position channel.

## Network profile

A named, fully materialized `Session_Config` and `Lane_Config` pair selected
with `kboot.network_profile`: `.Friends_Coop`, `.Listen_Server_Action`, or
`.Dedicated_Competitive`. The generated `<game>_net_attach` validates the pair
and installs both halves before the stack starts. A profile records timing and
trust assumptions; only the actual authority deployment creates the trust
boundary.

## Player, peer, and seat

`knet.Player_Id` is the stable identity used by gameplay. A reconnect token can
reclaim the same player ID, stats, and owned entities after the transport
connection changes.

`ksess.Peer_Id` identifies the current transport connection and can change on
reconnect. A *seat* is a player's current place in the session roster. Spectator
and dedicated-server seats have restricted behavior.

Keep player IDs in game state; use peer IDs only at transport/session boundaries.

## Prediction, reconciliation, and resimulation

Prediction runs an action locally before authoritative state arrives.

Reconciliation compares an authoritative result with the corresponding local
prediction and adopts authority when they differ.

Resimulation restores authoritative state at an earlier tick and replays later
ticks from stored inputs. A resimulated proc may run more than once, so it must
not directly perform audio, particles, logging, node mutation, or other
one-shot effects.

## Session

`ksess.Session` owns player identity, roster, entity lifetime, replication
scheduling, commands, stats, moderation, application messages, and backup
snapshots. It is transport-independent and does not import Godot.

## Simulation lane

The `kit/sim` fixed-tick path selected by `gd:"predict"`. Clients send input
windows to one authority. The authority simulates and sends tick-stamped
snapshots; owning clients predict and reconcile, while watching clients
interpolate remote truth.

## Tick

A fixed simulation or network step. Session replication normally mutates
gameplay at frame rate while the network tick schedules replication. Simulation
lane gameplay mutates predicted fields inside fixed-rate `@(gd_tick)` procs.

Use tick counts for replayable gameplay timers. Use frame `delta` only for
presentation.

## Transport

The mechanism that carries Kit's byte messages between peers. `kit/netgd`
adapts Godot `MultiplayerPeer` transports such as ENet and WebRTC;
`kit/steamgd` adapts Steam. Session and replication code do not depend on which
transport is installed.

Transport choice affects encryption, NAT traversal, peer addressing, and host
succession support. It does not change the replicated entity schema.

## Watched entity

A remote simulation-lane entity rendered from authoritative snapshots on a
delayed clock. The delay normally provides two samples to interpolate between.
The local predicted entity is often called *mine*; a remote interpolated entity
is *watched*.

Presentation events from watched entities should run when that entity reaches
the event tick, not immediately when the packet arrives.

## Net schema

The generated package-level `NET_SCHEMA` value: structured, allocation-free
metadata for the same canonical wire contract hashed into the session
fingerprint. It lists entity kinds and fields, recursive types, input classes
and constraints, actions and policies, presentation events, profiles, and messages. Runtime
callbacks remain in their execution descriptors; the net schema is the stable
read-only view for diagnostics and tooling.

## Wire fingerprint

A generated identifier for the game's network schema. Peers with incompatible
fingerprints are refused during the session handshake instead of interpreting
the same bytes as different entity fields, commands, inputs, or messages. The
fingerprint is a compatibility check, not authentication.
