# Native Quickdraw saves

The native session menu accepts a save-file path and offers Resume solo and Resume
host. During a direct authority session, Save/F5 writes the complete authority
checkpoint. A connected client or observer cannot save authority state. Explicit
scripted launches can use `RQ_SAVE=/path/duel.replay RQ_RESUME=1 RQ_ROLE=host` or
`RQ_ROLE=solo`; `RQ_PROFILE` selects the local reconnect identity separately.

The checkpoint contains the complete world: player lives/HP, scores, gold/equipment,
drone positions, cooldowns, respawn deadlines, active lobs, collision history, names
and start policy. Session identities, input/action ledgers and their accepted pending
work are part of the shared archive format. It does not save scene nodes, active
cosmetic pulses, local chat scrollback or personal profile files.

Resume validates the model/content contract and the saving host's identity before
opening a new authority session. It starts a newer epoch from the exact saved frame.
Direct file resume uses the default retirement policy for accepted but unexecuted
commands and schedules absent peers to leave; matching identities can rejoin their
retained seats. It does not resurrect old network connections or silently preserve
pending purchases. Solo resume keeps the host and lets other saved players depart.
Presentation is freshly seeded so historical shots/hurt flashes/rings do not replay.

A local file is not a host-election credential. Quickdraw refuses file resume for
configured Room sessions and for permit/custom-policy archives; those require their
recovery service. File resume deliberately creates a new direct session. Stop the
old direct game before replacing it. Configured online authorities now publish through [Room](online.md); public
deployment remains separate work. [Abandoned-party restoration](online.md) now has
its own service-backed acceptance path.

Writes use the existing bounded staged-file/rename helper. A failed write leaves the
previous committed file intact. Missing, damaged, incompatible or wrong-owner files
do not open a session and show a specific menu explanation. This is the existing
process-crash save boundary, not a new portable power-loss durability guarantee.
Native identity and display-name preferences remain separate; do not share an identity
file as a game-save export.

The game content/schema remains D2; this feature does not add gameplay fields. D1
archives still have no implicit conversion. Browser IndexedDB slots and identity persistence now have their own
[browser-local flow](browser-saves.md); they do not use native file paths.

Run `tests/replay_quickdraw_save/run.sh` from the Nix development environment for a
fresh-process combat save/resume fixture. It uses isolated paths and identities,
kills only its owned writers after a durable receipt, checks negative loads and
failed-write preservation, then continues respawn, equipment, purchases, lobs and
named chat in a fresh host/client pair.
