# Staging muster

The entry menu and staging roster share an authored, centered steel scene.
After admission it shows four stable player slots with names, fixed idle-frame
skin previews, gun/ability choices and waiting/ready/in-yard indicators. Existing yard
players are dimmed for a late joiner; Ready becomes Drop In. Observers can watch
the roster without player controls. The original previews use frame zero rather
than advancing animation, and this port follows that behavior.

All four pickers work in both directions, include [automatic choices](automatic.md),
and skip absent catalog rows. Local choices appear immediately; remote rows
reflect confirmed profiles. Changing a
pick clears local readiness and retires obsolete readiness retries before sending
the new profile. Rapid Ready toggles use the latest local choice instead of an
older authority snapshot. Restored epochs, new connections and replaced player
generations reset these optimistic choices from the confirmed profile, so Ready
after recovery cannot toggle an obsolete local flag. The authority still validates
every profile and action.

Only the staging leader can Start, and every other connected player must already
be ready. Start can ready the leader first, then waits for confirmed all-ready
state before submitting Start. It cancels that intent if eligibility changes.
The simulation's existing all-ready requirement is unchanged. Pick controls cannot
change an already-entered player, and no world/action/event/checkpoint schema or
additional gameplay-content compatibility change is needed.

The scene scrolls at smaller window heights. Existing party invite/enrollment,
profile persistence and spray controls remain on the same paths beneath the new
`UI/Lobby/Scroll/Layout` container.

```sh
nix develop --command bash examples/replay_scrapyard/muster_run.sh
RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_MUSTER_CAPTURE=/absolute/output/muster.png \
  nix develop --command bash examples/replay_scrapyard/muster_run.sh
nix develop --command bash examples/replay_scrapyard/muster_peers_run.sh
```

The [browser UI gate](browser_ui.md) uses real staging buttons to test remote
picks/unready, both cycle directions, host Start and late Drop In before running
its existing gameplay/UI checks. [Evidence](../../docs/replay/results/scrapyard-muster-2026-09-07/README.md)
records the actual acceptance results. Broader
actor/ability presentation, original transport/death scoreboard columns, wider
platform coverage and full comparison remain requirements.
