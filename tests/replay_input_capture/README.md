# Control-consumption boundary

```sh
nix develop --command bash tests/replay_input_capture/run.sh
```

This native Godot fixture uses real Session/network runners over Memory transport.
A client waits while the authority advances. Its next session frame receives a
complete ahead snapshot and bootstraps prediction, advancing the timeline without
using the supplied button press. `control_consumed` must remain false. The next
real input step consumes the retained press once. A second press survives a
prediction-capacity stall and also reaches the authority once. Both predicted and
authoritative final counts must be two, with clean resource shutdown.

The fixture also induces the actual fact-overflow receiver path, confirms that
Session has no readable authority frame, and issues a Receipt action through the
facade. It verifies no immediate send, then advances on real engine frames until
the new Welcome and authority verdict arrive. Both worlds must include the action
once, and the facade must expose exactly one confirmed result. The earlier input
capture/catch-up checks remain required.

The model uses a versioned per-action schedule: amount 3 is receipt-time;
amounts 1 and 2 remain scheduled. During resync, the facade must reject a scheduled
request without adding a queue entry, then admit the receipt-time request and
expose its single settled result. `REPLAY_MIXED_ACTION_SESSION_OK` is required in
addition to the earlier control-capture and receipt-resync markers.

The action uses the reusable intent helper. The fixture filters predicted,
cancelled, foreign-seat and foreign-epoch changes and verifies duplicate results
do not settle twice. A second phase captures a real server checkpoint and client
recovery report, promotes the retained request into a Room authority, retires the
request absent from that checkpoint, and submits a fresh request with the reused
sequence in the new epoch. The old epoch's result cannot consume that new ticket.
