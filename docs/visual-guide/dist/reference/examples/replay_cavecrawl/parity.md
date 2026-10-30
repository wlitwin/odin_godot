# Cavecrawl parity tracking

This matrix separates implementation from validation. The original project stays
at `examples/cavecrawl`; this project is `examples/replay_cavecrawl`.

| Feature | Implementation | Evidence / remaining validation |
| --- | --- | --- |
| Two authored floor scenes | Copied independently | Asset hashes in assets.md |
| Movement and range checks | Replayable model | Solo/co-op Godot walk-to-chest/door |
| Chest/bag transfers | Atomic multi-entity action | Pure conservation/capacity tests; contested network test; Godot co-op |
| Drop/grab pickups | Frame-owned pool | Pure tests and real three-process drop/grab/death-spill campaign; manual view/play review pending |
| Doors | Predicted action | Pure range tests and both Godot gates |
| Relic carry/set-down | Server-simulated state/version | Pure ownership/range tests and real carry/move/set-down story; owner-stream policy comparison pending |
| Combat bursts and body hit flashes | Detached journal-driven cues; C9/O3 generation-bound dweller impacts | Native/rendered/Chrome lifecycle, real normal/faulted campaigns and old-save/recording compatibility pass |
| Rock motion and centering | Bounded per-frame visual preview with current-body clipping | Server/owner host/client/observer sampling at 30/60/144 FPS passes; pre-tick cast/contact overlays and broader feel remain open |
| Rock combat/stamina/cooldowns | Replayable model | Pure tests and full real-process campaign with friendly fire, stamina/cooldown-limited waves and revive |
| Death spills/respawn/heal | Implemented | Real revive, heal and deadline-checked automatic respawn pass; broader original scenario coverage pending |
| Dweller AI/rift navigation | Pure visibility graph | Rift detour test; exact original path equivalence intentionally unclaimed |
| Waves/floors/victory | Implemented | 262-case original director oracle on native/WASM; corrected pacing/den reset, rollback and capacity checks; normal/faulted full campaign |
| Avatar vitals/cooldowns on descent | Preserved after ordinary tick decay/regeneration | C5 unit/rollback and actual Godot transition gates; initial/restart policies distinct, ledger/effects retained as specified |
| Relic lifetime/carry across floors | C6 retains ownership/version on descent and releases in place on restart; original initial position and carry offset | Unit/rollback and native transition gates; C7 retains ownership across death/disconnect; owner-stream policy remains different |
| Carrier death/disconnect/rejoin | C7 retains ownership/version, parks absent carriers’ props and releases on identity replacement | Unit, retained-frame and carrier migration gates; C8 adopts old-host props through a recorded policy |
| Old-host relic adoption | C8 records authority seat and adopts the departed host’s prop without reassigning avatars | First-committed-tick planned/crash native gates; owner-stream motion remains separate |
| Host removal and ban continuity | Direct token ban or coordinator-durable enrolled-member removal | Native UI/rename, fresh-process denial, SQLite commit-kill, old-service timeout and native/Chrome successor replacement pass |
| Session admission/reconnect | Shared Replay runner and Room driver | Live guest redirects to the approved successor, retaining loot and issuing fresh actions |
| Chat, positional pings | Bounded host-ordered scrollback and transient floor markers | Real peer typing/late-join/ping-expiry gates; native planned/crash chat continuity; stamped chat/ping names survive renames; ping scope/expiry checked across handoff; private channels remain open |
| Lobby, score UI | Connection/online party menus, durable create/join/rejoin, replayable names/readiness/leader, named scoreboard, Leave/Escape and another-run flow | Native TLS and browser RTC menus/migration/rejoin tested; repeatable invite and isolated rooms; authority-measured latency columns now pass native observer/rejoin and browser handoff checks; public deployment and wider UX review pending |
| Resource definitions | Captured floor values in World; 1–8 waves | Inspector resources/markers, mutation isolation, save/resume and remote default-resource peers tested; arbitrary navmesh conversion remains outside this model |
| Seeded decoration | Pure original splitmix32 recipe; view rebuild on seed/depth | Original/native/WASM integer coordinates and checksum agreement; visual review pending |
| Save/resume | Complete authority archive + persistent profiles | Native and Chrome kill/save/resume exact frame hashes, persistent identity, stale-tab/corruption refusal; host/guest recovery at 120 ms receive delay; broader campaign saves pending |
| Live checkpoint replication | Shared game connection and periodic validated backups | Loot/door checkpoint agrees while playing under latency/jitter/loss/duplication; explicit trusted recipient |
| Host migration | Coordinator-driven recovery and fresh process registration | Live planned/crash/repeated/return/partition/successor-loss gates; fuller combat and topology coverage pending |
| Steam/web | Browser Room path implemented | Real browser migration matrix; Steam and public deployment still pending |
| Old/new comparison report | Matched quiet Kit/server-motion/owner-motion cohort and encoding follow-ups | Recorded response, traffic and callback costs; full combat/stress, human authoring and play-feel comparison remain open |

The [owner-motion companion](../replay_cavecrawl_owned/README.md) now supplies a
separate latest-observation profile using the same gameplay reducer. Native
movement, relic handoff, carrier recovery and service checkpoints have acceptance
cases. O2 adds scoped command origins, Chrome migration/saves, and a matched quiet
comparison. C8 introduced authority adoption to the server-simulated profile
above; [the impact contract](impacts.md) records its current content identity. Broader original rules,
remote presentation, combat/stress and human ergonomic comparison remain open.

The original Act 3 removal/ban path now has a [host moderation control](moderation.md).
Direct sessions retain checkpointed token bans; Room disables the enrolled member
and successor rights durably. Native/Chrome prepared-successor removal and
planned/crash continuation pass. Wider moderation UX and deployment remain open.
