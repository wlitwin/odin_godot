<a id="look-here"></a>

# Positional pings

Middle mouse sends a positional ping through Replay communications. The
original gold diamond pulses and fades over 2.6 seconds; the sender's stamped name
floats upward for 0.9 seconds, and the existing ping sound plays on receipt.
Players can ping while downed. Menu/chat input and pointer use over those panels
block the gameplay binding. Observers receive live pings but cannot create them.

Pings remain presentation data. They do not alter the world, consume gameplay
actions or enter gameplay checkpoints. The communications service orders/deduplicates
delivery and applies its existing rate/capacity limits. Local queueing is not an
authority acceptance receipt; rejected pings are reported without replacing a
chat draft. Late joiners receive chat history without historical markers.

The view keeps at most 32 active ping rigs. Expiry, unavailable world state,
room/epoch/content replacement and floor/run changes remove them. Coordinates
outside the yard are rejected. The existing marker payload is scoped to this
2D game without a wire-format change: `tag = run | 1`, while its spare Z value is
`floor + 256 * (run & 1)`. Together these represent all u32 run and u8 floor values
exactly, including run zero and the maximum run. X/Y remain world coordinates.
Receivers require an exact scope match before presenting a marker.

```sh
nix develop --command bash examples/replay_scrapyard/pings_run.sh
RSY_HEADED_CLIENT=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_SCREENSHOT=/absolute/output/ping.png \
  nix develop --command bash examples/replay_scrapyard/pings_run.sh
```

The fixture exercises a real middle-mouse event, stamped position/name, menu/chat
blocking, observer restrictions, late-history exclusion and node expiry. The run
fixture sends a ping during the last second of departure and requires it to clear
on the next floor before its natural lifetime ends. Scope boundary tests include
run zero, odd/even runs, maximum u32 runs and a changed floor.

[Evidence](../../docs/replay/results/scrapyard-pings-2026-09-07/README.md) records
actual outcomes and an inspected capture. Native captures use Dummy audio;
hardware listening, browser/platform interaction, named-observer metadata,
broader presentation/feel and the full comparison remain requirements.
