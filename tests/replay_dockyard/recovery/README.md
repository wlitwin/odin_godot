# Dockyard lifecycle checks

These cases use the ordinary production Web export, real canvas inputs, the
existing Party/Room service and independent Chrome processes. They reuse the
online runner and browser verification helpers; no test autoload or private
Timeline/packet setter is installed. Every completed pair compares actual bytes
of Solver, Game, Side, Observations and Occurrences, the complete signature,
application acknowledgement and typed resource/engine teardown.

Choose a flow with `R1_FLOW=observer|transient|gap|frozen|cold|hostloss|hostfrozen`:

| Flow | Actual boundary |
| --- | --- |
| `observer` | Authority progresses before a third membership uses Watch. The public Observer Session has seat0, consumes no controls, records no prediction lead, issues no action and does not replay earlier boost cosmetics. All three final complete frames match. |
| `transient` | Real outgoing reliable messages are discarded until the original sequence1 action is observed pending. The owned browser peer connection closes; the same live Client reconnects through Room. A committed replacement Welcome settles that original attempt once, including an explicit unapplied outcome if its due tick expired. No replacement attempt is issued. |
| `gap` | Actual game-channel sends are discarded while authority advances beyond H128, followed by a real connection replacement. The received complete Welcome has an observed new scope and baseline beyond the old window. This is a declared channel-discard/reconnect fixture, not Internet UDP-loss certification. |
| `frozen` | A real background tab and Chrome lifecycle freeze suspend the Client while authority progresses. The resulting browser Back-Forward Cache socket event is recorded as the expected injected lifecycle event; application errors remain failures. Final complete state must match. |
| `cold` | An existing action is drained before checked Leave Crew. A new browser process reuses its private storage profile, chooses Recent Crew, keeps the member identity and obtains a newer challenged incarnation. It does not replay the old action or its cosmetics. This does not claim persistence of arbitrary pending actions across process destruction. |
| `hostloss` | The authority browser closes. A correlated coordinator reply ends its usable lease; the survivor shows stopped/rehost UI. Five-part state remains unchanged until the actual new-crew button closes the old Runtime and reloads the scene. A fresh crew then completes a normal pair run. |
| `hostfrozen` | The actual authority tab is hidden/frozen beyond its lease; hosting permission fencing ends that job explicitly. Checked leave and the survivor's fresh-crew flow remain separate from seamless migration. |

```sh
R1_FLOW=transient nix develop --command python3 -B \
  tests/replay_dockyard/recovery/run.py --production-ui --ticks 3600 \
  --export-record /ABS/ordinary-export/report.json \
  --service-record /ABS/prepared-service/report.json \
  --out /ABS/NEW-case --godot /ABS/Godot
```

Faults operate on owned public WebRTC objects or the browser's declared lifecycle
API. They never assign a head, confirmed frontier, recovery serial, ACK, input
receipt or Native state. A head gap alone does not prove canonical recovery:
replacement cases require actual committed Welcome generation/serial/baseline.
Same-scope healing is labelled separately. The browser lifecycle command is
documented by the [Chrome protocol](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-setWebLifecycleState);
channel operations use the [WebRTC API](https://w3c.github.io/webrtc-pc/).

Room preserves its actual phase-aware permit and exact owner during redirect.
The application's v3 readiness acknowledgement echoes only a generation for
which the host accepted a real admitted readiness message. Periodic GO cannot
implicitly acknowledge a new generation. The service cohort binds this app
version, and physics packets/solver formats remain unchanged.

Reports retain raw producer logs, original failures, selected processes and
immutable export bindings. The runner seals its selected driver, shared browser
helper and Python source before and after execution. Private profiles and invite
capabilities stay outside published evidence. Earlier functional runs remain
build-specific; final release/browser/performance qualification uses the final
frozen candidate. These local checks do not establish public Internet reachability,
hardware frame budgets or human co-op playability.
