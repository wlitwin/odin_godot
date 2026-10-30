# Social presentation

Tab opens the scoreboard with names, kills, deaths, damage, slain dwellers, gems,
HP and **Ping (ms)**. Ping is application round-trip time measured by the authority,
including both processes' queues and pump cadence. The local authority reads zero;
unmeasured/stale rows show `--`. Observers receive measurements without acquiring
a player row. Departed player rows are hidden.

The game initializes the optional shared `telemetry.Diagnostics` owner and adds
its application lane when opening Solo/Session/Room. It updates diagnostics after
the outer session pump and reads the result only for presentation. Measurements
are not world state, saved progress or host-migration data. Fencing and authority/
connection changes invalidate them; the new authority measures again. Leaving a
session clears readback before a new connection can use the same UI.

F sends a positional ping from the local player. The marker uses the name stamped
by the Comms authority when it accepted the marker, falling back to `Seat N` for
an unnamed sender. A later rename does not relabel an already-visible ping. Plain
Label text preserves literal brackets/markup characters. Markers last 2.5 seconds
and are removed when the room/content/authority epoch, run or floor changes.
They do not reappear as historical chat or after a late join.

Enter in the name field submits the chosen name through the existing name-profile
and lobby Profile action path. This works while the lobby/menu is open during
play. Invalid names preserve the previous choice and keep the field editing. Typing
inside the name field captures social/gameplay shortcuts, including F. A valid
submission releases field focus
and consumes the Enter edge so it does not also trigger chat/gameplay. It introduces
no new simulation command, content revision or archive conversion.

The [native and Chrome gate](../../tests/replay_cave_social/README.md) covers measured
values, literal rename attribution, marker expiry, observer/departed rows, rejoin,
and a real authority handoff with fresh measurements and early retirement of an
old-epoch marker. This closes those social-presentation rows; broader private
channels, director timing, visual review and full-game parity remain open.
