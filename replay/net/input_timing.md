# Scheduled-input timing feedback

Scheduled clients use timing feedback to keep inputs ahead of the authority
without retaining an unnecessarily large prediction lead. The welcome exchange
supplies a conservative initial prediction lead: the number of ticks the client
simulates ahead of accepted authority state. It includes
initial connection, application and checkpoint work, so it is not a permanent
estimate of steady traffic. After admission, clients calibrate using the existing
`input_newest` value in accepted snapshots. No protocol or checkpoint change is
needed.

For each scheduled input tick, the client records the first successful transport
submission time in a history-sized ring. A newer acknowledged input must match a
retained entry from the current welcome/connection. Its elapsed time includes
outbound queueing, server processing/snapshot cadence and return delivery: the
metric is **input turnaround**, not pure transport RTT. Backpressured submissions
are not timed, repeated windows retain the first successful time, and stale or
missing entries do not produce estimates.

After three valid samples, the bootstrap lead becomes the recent turnaround peak
converted to ticks plus four reserve ticks, clamped by configured `lead`,
`max_future - 2` and `max_prediction - 2`. A current one-second peak bucket and the
preceding bucket retain short bursts while aging old peaks. `lead_ticks` remains
the bound used to rebuild prediction after a complete ahead snapshot; it does not
rewrite existing history or queued action/input ticks.

Clock discipline separately uses the server-observed arrival margin:
`input_newest - snapshot_tick`. The target is three future input ticks. Around that
target the existing ±2% correction is retained. Above seven ticks the clock runs
at 0.9× until the excess drains; a negative margin uses 1.1× to recover. This changes
future local stepping through the existing `clock_scale` API. It does not rewind
or skip the authority, retime accepted requests, or bypass admission/fencing.
Applications driving `Client` directly must apply `clock_scale`; the Godot Session
adapter already does so. Spectators and latest-observation models keep scale 1.

Long local pump gaps invalidate outstanding samples, avoiding calibration from
local suspension. The gap threshold is the larger of 250 ms and
`(snapshot_every + 2) / hz` seconds. Reconnect, a new authority and every accepted
Welcome reset timing history. Configured minimum lead still applies; it remains
an application envelope choice rather than a universal latency recommendation.

Inspect `input_timing.turnaround_ms`, `input_timing.arrival_lead`, `lead_ticks`,
`clock_scale`, and the cumulative `Stats.timing_samples`, `timing_rejected` and
`lead_updates`. None is simulation state. The send-time ring adds one bounded
`Input_Sent` record per history slot (24 bytes per slot on the tested arm64 build).

Tests include a delayed welcome that initially selects 62 ticks, changing latency
and jitter, unchanged queued action due ticks, convergence, backpressure, local
stalls, reconnect and non-scheduled clients. This policy does not promise zero
corrections or hide link failure; ordinary history/capacity/recovery bounds remain.
