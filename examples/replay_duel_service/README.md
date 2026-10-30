# Replay Duel provisioning and signaling service

This separate native service hosts fixed two-player enrollment rooms and their
authenticated WebRTC mesh signaling, plus pair keys for native encrypted ENet.
Gameplay stays on the participants. Private
SQLite bundles contain invitation/enrollment secrets and current incarnations;
they are never sent as gameplay checkpoints.

Build/import this Godot project with the repository's usual native pipeline:

```sh
nix develop
bash build/build_scripts.sh examples/replay_duel_service
export ODIN_SCRIPTS_DLL="$PWD/examples/replay_duel_service/bin/libodinscripts.dylib"
"$GODOT" --headless --path examples/replay_duel_service --editor --quit-after 120
python3 tests/replay_comparison/wait_builds.py examples/replay_duel_service /tmp/duel-service-builds.json
bash build/build_scripts.sh examples/replay_duel_service
DUEL_SERVICE_LOCAL=1 DUEL_SERVICE_CREATE=1 \
DUEL_SERVICE_DB=/absolute/private/directory/duel.sqlite3 \
"$GODOT" --headless --path examples/replay_duel_service
```

Use `.so` instead of `.dylib` on Linux. The database parent directory must already
exist. On subsequent starts omit `DUEL_SERVICE_CREATE`; existing room keys and
player counts are restored. Missing/corrupt files fail instead of resetting rooms.

Default port is 9081. In browser Duel's lobby, enter `ws://127.0.0.1:9081`, enable
Local development service, and create a match. Use Invite player to share its
invitation with a **different browser profile/device**, which uses Join match.
Same-origin tabs in one profile share the persisted enrollment; they are not
independent players. The browser game export includes `web_archive.js`.

Outside explicit loopback development, provide `DUEL_SERVICE_CERT` and
`DUEL_SERVICE_KEY` for TLS. `DUEL_SERVICE_BIND` defaults to `127.0.0.1`;
`DUEL_SERVICE_LOCAL=1` refuses a non-loopback bind. Clients require a trusted WSS
certificate. `DUEL_SERVICE_PORT` changes the listen port, and the optional
`DUEL_SERVICE_STOP_FILE` provides a graceful local shutdown marker.

The implementation bounds rooms at 32 and connections at 128. It does not provide
human accounts, service discovery, TURN credential issuance, public room listings
or automatic room retirement. This local example does not establish public
reachability. Configure ICE/TURN independently where required.

Run `tests/replay_p2p_party/run.sh` for browser enrollment/gameplay/rejoin and
`tests/replay_p2p_native/run.sh` for native TLS provisioning, encrypted ENet and
returned-creator endpoint replacement. No original Kit project is modified.
