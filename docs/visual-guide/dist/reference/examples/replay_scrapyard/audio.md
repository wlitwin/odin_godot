# Audio and local settings

Scrapyard uses the original 23 synthesized sound effects and five music tracks.
Their source hashes are recorded in `shared/audio/asset-provenance.json`; original
assets and projects remain separate. Playback uses Replay's bounded audio adapter,
with 12 positional voices, three screen voices and two music decks.

Shot events record the firing weapon's family. The audio mapper uses that value
to select a clip even after the player switches weapons or the entity is removed.
It does not need a later World value or a live entity pointer. Gameplay journal
events drive shots, dash, hit, kill, hurt, pickup and blasts. Confirmation does not replay an already heard clip,
and cancellation retains its consumed ID while stopping any still-owned voice.
Positional effects use the original gain table and ±8% pitch variation.

Other cues follow forward authoritative observations: gun jam/reload/clear states,
down/revive, purchases, ability counters, floor clear/descent/wipe and selected enemy
attack transitions. Initial observation, restore, new run and new epoch establish a
silent baseline. Repeated or older observations do not replay those transitions.
Each change in the departure countdown's seconds plays the original tick sound
and a small camera jolt. Canceling is silent, and joining/restoring mid-countdown does not replay its start.
These sampled transitions can coalesce or omit short intermediate states under a
large snapshot gap; they are not an event-complete log of every original SFX site.
The distinction remains part of the full audio/parity audit.

Music selection uses the original seed/floor/run hash for the three combat tracks.
Staging/wipe use the menu track and a cleared floor uses the intermission track.
Two looping decks crossfade and the silent outgoing deck stops. Music is selected
from current authority state, independently of effect history and replay.

The Esc menu offers sound volume (0–100% in ten steps), camera shake and
fullscreen controls, plus a preview of the selected spray when its texture is
available. Volume controls all Replay Scrapyard voices/music without changing a
global audio bus. Shake affects only the camera's presentation offset. Fullscreen
is disabled by the headless display; browser fullscreen remains subject to the
browser's user-gesture behavior and has not been accepted by the settings gate.

Native preferences use the separate bounded `user://replay_settings` record.
`RSY_SETTINGS_PATH` overrides it. Native writes stage a complete file before rename.
Browser preferences use the `settings` key in this game's IndexedDB namespace and
revision-checked writes. Rapid edits while a write is pending are coalesced into a
subsequent committed value. Conflicts/corruption preserve the existing record and
keep further changes session-local. The menu reports settings that could not be
saved. Pending browser operations have the existing browser-store commit contract.

`RSY_PERSIST=0` disables settings persistence as well as profiles, which keeps the
editor workbench and automated sessions from changing normal preferences. Normal
loadout choices remain in the existing profile record. `RSY_AUDIO=0` disables audio;
the dedicated server role skips audio initialization by default.

```sh
nix develop --command bash tests/replay_audio/run.sh
nix develop --command bash examples/replay_scrapyard/settings_run.sh
nix develop --command bash examples/replay_scrapyard/web_settings_run.sh
```

The native and browser gates verify defaults, committed edits, fresh-process
reload and corrupt-record preservation. The browser gate additionally kills Chrome
after commit and verifies revision-conflict handling. Mixer capture confirms actual
nonzero audio output; it is not a subjective listening review or an exhaustive
sound-parity test.

These historical updates introduced game content `...3044` for the extra event
data, `...3046` for [cast paths](cast_paths.md), and `...3047` for
[dash actions](controls.md). Protocol 7 and checkpoint layout 4 remained unchanged. Explicit import supports content 42, 43 and 44 archives,
including their original event contract. Event histories are not archived, so
conversion rebinds the event schema without inventing past events. World/control
state and action frontiers remain preserved. Full listening/visual parity, browser
audio gesture coverage and broader playtesting remain roadmap requirements.


AudioServer playback retirement is asynchronous. Automated scene tests close the
game and allow its processing loop to retire audio references before quitting.
The native CoreAudio backend produced no mixer frames in this environment, even
with a Godot-only playback probe, and left pending playback references at exit.
Hardware listening/driver acceptance remains open. The rendered settings/fullscreen
check uses the Dummy driver; a separate capture verifies nonzero mixed PCM there.
