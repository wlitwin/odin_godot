# Chat and yard history

Scrapyard now uses the shared [Replay communications service](../../replay/comms/README.md)
for named player chat, observer chat, late-join scrollback and host-ordered yard
announcements. It runs on its own application lane alongside spray assets;
gameplay world/action/checkpoint schemas are unchanged.

Enter focuses the talk box. Typing blocks movement, dash, firing, casts, revival,
shop and save/spray shortcuts while simulation continues. Escape leaves chat
without opening the menu and retains the draft. Successful local queueing clears
the entry; rejected delivery is reported, and its text is restored if the user
has not started another message. The talk box moves above the counter on a clear
floor. Its scrollable display renders the service's retained history as plain
text with BBCode disabled.

The authority stamps player names from approved world state; older lines retain
their stamped names. Legacy Scrapyard profiles allow a few Unicode characters
that communications forbids. Chat trims valid names and substitutes `runner N`
for incompatible/empty names without changing the saved profile or gameplay
validation. Observers currently use the generic `Observer` label.

The authority visits each newly confirmed timeline tick and derives roster,
start, wave, horde/Titan, clear, gate, descent and wipe/reset announcements.
It does not sample client frames or issue messages from replayed simulation code.
A 64-entry application queue retains temporary broadcast backpressure and reserves
space for a complete tick's batch. If the simulation history overtakes that queue,
a gap message reports skipped updates and establishes a new baseline. A new
authority baselines the restored checkpoint and publishes one new-keeper line.

Communications retains 64 chat/system lines. This is ephemeral session history:
same-room host changes retain the lines each process actually received, but a
killed host can lose undelivered lines. Pending sends are retired with an explicit
result on scope/fencing changes. Fresh process gameplay save/resume does not save
chat. The existing service owns UTF-8 limits, ordered echo, rate/capacity rejection
and connection/epoch checks; participating builds must enable the same optional
service protocol.

```sh
nix develop --command bash examples/replay_scrapyard/chat_run.sh
RSY_HEADED_CLIENT=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_SCREENSHOT=/absolute/output/chat.png \
  nix develop --command bash examples/replay_scrapyard/chat_run.sh
RSY_CHAT_MIGRATION=1 \
  nix develop --command bash examples/replay_scrapyard/spray_migration_run.sh
```

The dedicated fixture checks focus/escape, live simulation, named/plain-text
delivery, identical histories and a late observer. Run/gauntlet fixtures verify
retained system history. The combined fixture checks before/after chat, one keeper
announcement, live combat recovery and the spray dependency barrier during planned
and crash migration. [Evidence](../../docs/replay/results/scrapyard-chat-2026-09-07/README.md)
records actual outcomes and the setup correction.

[Positional pings](pings.md) now have input, presentation, expiry and scope checks.
Named-observer metadata and broader chat layout/feel parity remain work. Browser
interaction, additional platforms, hardware audio, playtests and the full framework
comparison remain requirements.


Observers now use the name from the personal/front-door name field after capability
negotiation. Named messages show `Name (observer): message`; the role label remains
visible even when the chosen text matches a player's name. Historical messages keep
their originally stamped name, and a surviving observer negotiates again after a
host change. This does not allocate a player seat or permit pings/gameplay actions.
Legacy servers retain the generic `Observer` label. Display names are descriptive,
not unique account identities.


The observer recovery gate now includes abrupt host loss, fresh-process return of
the old host, and a fresh observer process with a new name. Existing history keeps
its stamped labels; the reconnecting observer remains seat zero and cannot ping.
The observer status line now lists chat/tally/menu controls and waiting information,
rather than advertising player-only combat controls.
