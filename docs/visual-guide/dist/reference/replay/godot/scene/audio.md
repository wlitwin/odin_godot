# Bounded event audio

Use `Audio_Pool` to play presentation cues with bounded voices and to match
replayed events by identity. It owns a fixed set of positional and screen-space
Godot players.
`audio_pool_init` accepts their parent and capacities (12 world / 3 screen by
default). The parent must outlive the pool. `audio_pool_destroy` stops playback,
releases player-held streams and queues the child players for deletion.

An `Audio_Cue` supplies a borrowed stream, position, gain, pitch and spatial flag.
Godot retains the stream while assigned to a player; the application keeps and
releases its own loaded-resource references. `audio_play` handles immediate UI or
forward-only presentation cues. A full pool steals a voice in round-robin order;
work remains bounded and the pool counts steals.

For journal events, use `audio_change(pool, consumption_log, change, cue, slot)`:

- Begin consumes its event ID/effect slot once and starts playback.
- Update adjusts the position of an active spatial voice without restarting it.
- Confirm does not start another clip.
- Cancel stops only a voice still tagged with that event ID/slot. A delayed cancel
  cannot stop a replacement voice after the pool has reused the player.

A consumed ID remains consumed after cancellation, completion or voice stealing.
The library cannot undo samples already heard. The `view.One_Shots` ledger retains
these consumed IDs in bounded tick buckets, independently of the active players.
A reappearing Begin after correction is suppressed while retained. Once retired,
old IDs remain expired rather than becoming new again.

Initialize the ledger with the presentation epoch/baseline and enough retained
history/events per tick for the journal being consumed. `one_shots_retire` takes
an explicitly safe monotonic frontier; it never silently evicts a live bucket to
accept a colliding tick. `Capacity` is observable. `one_shots_reset` requires a newer
epoch. Applications clear active voices and establish an appropriate new baseline
when a session or playback epoch changes.

The pool rejects invalid cues before consuming a Begin. Volume is local to this
pool and updates active voices; it does not modify the application's global master
bus. Streams, players and consumption ledgers belong to presentation, never to a
simulation frame or checkpoint.

`tests/replay_audio/run.sh` exercises actual Godot players, correction/confirmation,
cancel/reappearance, voice reuse, resource release and nonzero mixer PCM captured
through an AudioEffectCapture. Pure journal/ledger tests cover retention, capacity,
retirement and epoch boundaries. WASM checks cover the same adapter.


Godot retires audio playback references asynchronously. Stop/detach the players and
allow the engine loop to process retirement before a test expects zero resources
at process exit. Hardware backend acceptance is separate from a headless Dummy
mixer test. The included Godot-only capture probe also reproduced a silent/stalled
CoreAudio mixer in this environment; no hardware-playback success is claimed.
