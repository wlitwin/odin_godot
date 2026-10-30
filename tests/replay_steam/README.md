# Steam adapter acceptance

The normal gate is a **contract fixture over ENet**, not a Steam network test:

```sh
nix develop --command bash tests/replay_steam_core/run.sh
nix develop --command bash tests/replay_steam/run.sh
```

It exercises the dynamic API calls, raw packet modes/limits, retained receive
buffers, peer-ID mapping, reference/callback ownership, Replay Session admission,
validated actions and checkpoint capture. Failures in constructors and initialization
must leave no usable peer/runtime. Native and WASM checks require no Steam install.

Inspect an actual installed GodotSteam extension without initializing Steam:

```sh
GODOTSTEAM_ADDON=/path/to/addons/godotsteam \
  nix develop --command bash tests/replay_steam/capability_run.sh
```

For live acceptance, each participant needs its own logged-in Steam account and
device with an entitled app ID. The runner creates an isolated project. Supply a
GodotSteam addon directory or a Godot executable with the native Steam classes.
Initializing this mode is a real Steam app session, not the local fixture.

```sh
# Device/account 1: keep it running and share its printed Steam ID.
GODOTSTEAM_ADDON=/path/to/addons/godotsteam STEAM_APP_ID=480 \
  STEAM_TEST_ROLE=host nix develop --command bash tests/replay_steam/live_run.sh

# Device/account 2: use the host's printed ID and the same virtual port/app ID.
GODOTSTEAM_ADDON=/path/to/addons/godotsteam STEAM_APP_ID=480 \
  STEAM_TEST_ROLE=client STEAM_HOST_ID=HOST_ID \
  nix develop --command bash tests/replay_steam/live_run.sh
```

480 is Valve's test app choice; use it only intentionally for testing, or supply
your own app ID. `STEAM_TEST_PORT` is the virtual port, default 49499 in this fixture.
`REPLAY_STEAM_LIVE_OUT` chooses the result directory. Both live processes must print
`REPLAY_STEAM_LIVE_OK`; retain both logs and actual game/extension versions. The
host is an automatic small acceptance game and exits after the shared loot result.

The currently collected evidence has no live-network success claim. The user has
been asked about availability of two-account testing; meanwhile other roadmap work
can continue. See [the adapter contract](../../replay/godot/transport/steam.md).
