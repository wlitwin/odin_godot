# Replay audio acceptance

Run `nix develop --command bash tests/replay_audio/run.sh`.

The fixture drives Replay's actual Godot voice pool with a copied original bolter
clip. It checks invalid-cue rejection before consumption, duplicate Begin,
Confirm/Update, Cancel/reappearance, voice stealing, delayed cancellation,
per-pool volume, stream ownership and nonzero mixed PCM. It then waits for engine
playback references to retire and checks clean process exit. The same script is
checked for WASM. The headless gate uses Godot's Dummy audio driver and captures
its mixer output; this is not a hardware listening test.

`vanilla_capture.gd` independently repeats the mixer check using only Godot's
AudioStreamPlayer and AudioEffectCapture. It can distinguish a driver/environment
failure from the Replay adapter. In this environment CoreAudio reported no mixed
frames in both probes and retained playback objects; the Dummy driver passed.
Do not report hardware playback as accepted from the Dummy result.
