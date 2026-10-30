# Godot telemetry adapter acceptance

Run `nix develop --command bash tests/replay_telemetry_godot/run.sh`.

The real session adapter and link router consume a schema-valid report from an
admitted peer over Memory transport. Gameplay Resyncing remains eligible; fencing
clears readback, and a closed session disables the component. The fixture supplies
session metadata without opening a gameplay world. Real gameplay, UI, ENet and
Chrome/WebRTC coverage lives in the Scrapyard tally/browser/migration gates.
