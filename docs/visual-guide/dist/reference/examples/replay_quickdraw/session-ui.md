# Quickdraw sessions and social UI

Replay Quickdraw starts at a scene-authored menu. Enter a name and
choose Solo, Host, Join or Watch. Address and port are editable before connection.
Host opens a waiting duel; the first connected player is the match leader and can
Start. Gameplay remains stationary until that command is accepted. Solo starts
immediately. Scripted `RQ_ROLE` launches retain automatic play, and the existing
credential-based Room launches still open automatically unless `RQ_AUTO=0`.

Enter focuses chat; Escape releases focus and preserves the draft. Typing captures
movement, drone steering, firing, dash, lob and purchase input while networking and
simulation keep running. Submitted text is displayed literally. Observer chat waits
for negotiated display-name support before enabling submission, so the selected
label is included without changing the observer's admitted identity or seat zero.

Tab shows the authoritative scoreboard: player name, kills, deaths, gold and measured
round-trip time. Departed rows remain until their seat is reused. Leave closes the
session and returns to the menu. Rejoining with the retained identity restores the
same seat and existing scores; chat history is supplied by the active authority.

Player names, waiting/started state and the manual-start policy are values inside
`World`. Names are declared through validated seat-owned actions. Start is rejected
for anyone other than the current first connected player, or after play has begun.
Existing movement, damage, hit-query, respawn, projectile, shop and score rules are
unchanged once the duel starts.

Normal native play retains a local identity and display name using the shared
profile helpers. Explicit `RQ_TOKEN`, a bot, or `RQ_PERSIST=0` bypasses these local
preferences for tests. `RQ_PROFILE` selects an alternate identity path; the name
uses that path plus `.name`. Corrupt data is preserved and joining reports the
failure. These preferences are distinct from game checkpoints and Room credentials.
Browser identity/name persistence and service-backed party invitations use the
shared [Party integration](online.md). Public deployment remains separate work.

Names, start policy, and their actions use experimental content ID
`0x52515549434b4432` (D2) because they change the complete state/action schema. D1 peers and
archives are intentionally incompatible; there is no implicit old-save conversion.
Original Kit Quickdraw remains separately runnable with its original content and
protocol. Host migration still requires a compatible prepared checkpoint; changing
this UI does not waive lease, rollback-window or admission rules.

The native UI fixture is `tests/replay_quickdraw_ui/run.sh`. It drives real menu
buttons and three processes, tests start authorization and input capture, verifies
literal and named observer chat, produces a real kill for nonzero scoreboard rows,
and leaves/rejoins without resetting scores. Separate regression runners retain
the existing historical/live A/B, predicted lob and combat migration checks.

This is a session/UI parity increment, not full Quickdraw completion. Broader combat
feedback review, public/browser/Steam paths, measurements and human
visual/play-feel review remain in the full roadmap.

[Native file saves](saves.md) provide Save/F5 and Resume solo/host. They preserve a
complete authority checkpoint and require its host identity; coordinated Room
recovery remains a separate path.
