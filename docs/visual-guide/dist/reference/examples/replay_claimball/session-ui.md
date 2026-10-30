# Claimball session UI

Run `nix develop --command bash examples/replay_claimball/play.sh`. The native menu
opens with a name, address, port, and Solo / Host / Join / Watch buttons. Host waits
for the first connected player to Start; Solo starts automatically. `RCB_PLAYERS`
sets the minimum player count (one by default in the menu), and `RCB_GOALS` sets the
winning score. Explicit `RCB_ROLE` launches retain automatic start for existing
fixtures. The default port is 49490.

WASD moves, Space kicks, and E spikes. Enter opens chat and captures gameplay
input; Escape releases focus while keeping the draft. Chat text is literal. Named
observers negotiate support while retaining seat zero. Hold Tab for authoritative
player names, teams, scores and round-trip time. A dash means no current ping
sample. Departed players remain listed until their seat is reused.

Leave returns to the menu. Rejoining with the same identity retains the seat and
match score. Normal native play persists identity at
`user://replay_claimball_identity` and the display name in the adjacent `.name`
file. `RCB_PROFILE` selects an isolated location. Explicit tokens, bots and
`RCB_PERSIST=0` bypass profile writes. Malformed saved data is preserved and blocks
connection. These files store preferences/identity, not a saved match.

Names and the start command participate in the replayable world. Leader decisions
can read roster metadata for outside players without bringing their avatars into
the local prediction group. Physics, claim thresholds and remote presentation
remain as documented in the main README. Content C3 (`0x52434c41494d4233`) explicitly
distinguishes the new world/action/event schema from C1/C2; no automatic archive conversion
is provided.

[Party menus and browser sessions](online.md) now have local RTC acceptance. Steam
and public deployment remain work. Fixed native Room recovery is described in
[migration.md](migration.md).
See the [validation results](../../docs/replay/results/claimball-ui-2026-09-13/README.md)
for the retained intermittent observer fault failure.

## Play again

After a completed match, its first connected player can press **Play again** if
enough players remain. The command names the completed round. Guests, observers,
in-progress matches, exhausted round counters and stale requests are refused.
The new match resets scores, kick/spike/contact totals, ball kickoff, player
positions, velocity and cooldowns. Names, teams, connections, seats, match settings,
chat history and session action sequencing survive. A departed initialized player
keeps its row and is reset for a later return.

This is an addition to the original game's interface. It is a game command inside
the existing session, not a disconnect/reconnect operation. Local prediction still
contains one avatar plus the ball. Read-only outsider samples stay unchanged until
a new authority snapshot arrives. Presentation cuts across round boundaries and
ignores old-round kick/spike effects after the new round is confirmed. Gameplay
event IDs include the round, so corrections cannot reuse an old match’s effect.

Run `nix develop --command bash tests/replay_claimball_ui/round_run.sh` for two
complete native matches with a host, client and observer. Set
`REPLAY_CLAIMBALL_ROUND_OUT` to a fresh output path to retain the build and receipts.

## Native match saves

Choose a save file in the menu; the default is `user://claimball.replay`.
**Save · F5** writes the current authority checkpoint. Only the local authority can
save. A failed staging write preserves the previous completed file. A subsequent
successful save replaces that file. The button's notice reports completion or a
path/write-access problem. F5 is captured while entering chat text.

From a fresh process, **Resume solo** or **Resume host** loads that checkpoint with
the original host profile. It restores the exact saved frame and opens a newer
session epoch. Solo resumes with the host; other saved players are scheduled to
leave. In hosted play, their original profiles can rejoin their seats. Round,
score, player motion/cooldowns, ball state, roster and match settings come from the
checkpoint. The client's prediction group is rebuilt by the existing runner.
File resume retires pending commands under the shared default policy; it is not
coordinated host migration.

Missing, damaged/incompatible, protected-policy and exhausted-epoch saves are
refused before a session opens. The host identity must match the saved local seat.
Existing files and identities are kept on rejection. Native file saves do not
persist the cosmetic chat history; fresh sessions can exchange named chat again.
Browser-local checkpoints now use a separate slot adapter. Provisioned Parties publish
through their service; fixed native Rooms disable direct file save/resume.
This adds no schema change beyond the existing C3 game version.

Use `RCB_SAVE` to select a path at launch and `RCB_PROFILE` for the matching host
identity/name profile. Each process can use a separate profile path. Resume solo
and Resume host are the supported menu entry points; a dedicated-server resume
front door is not part of this increment.

## Browser-local Solo saves

Without a Party service, the browser menu offers Solo, a named save slot and Resume
solo. `save_slot=pitch` is the default query setting. Labels contain 1–48 letters,
numbers, dots, dashes or underscores. Storage keys include the personal identity
hash, so separate profiles do not share a slot accidentally.

Save waits for an IndexedDB receipt and displays completion or a failure. Leave
is blocked while the write is pending. Resume restores the complete saved frame
under the same identity in a newer epoch. `role=solo&resume=1&save_slot=pitch` waits
for both identity and slot loading before starting an automatic resume.

Competing tabs use revision checks: a stale tab cannot overwrite the newer save.
The UI asks that tab to reload. Malformed checkpoints and identities are preserved
and refused; choosing another valid slot permits a new save without changing the
bad slot. Browser profile/storage controls outside the game still determine the
lifetime of locally stored data.

Party Save/F5 continues to publish through the service and creates no local Solo
slot. Browser-local saves, native files and Party publications are separate stores.
All use the existing C3 model; this integration does not change its wire schema.
