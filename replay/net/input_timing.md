# Scheduled-input timing feedback

Scheduled clients submit inputs before the authority reaches their assigned
ticks. Timing feedback adjusts their prediction lead, the number of ticks they
simulate ahead of accepted authority state. The welcome exchange sets a
conservative initial lead, but its duration includes connection setup,
application work, and checkpoint handling. It can therefore overestimate the
lead needed during ordinary traffic. After admission, accepted snapshots'
existing `input_newest` value lets the client calibrate without changing the
protocol or checkpoint format.

For each scheduled input tick, the client records the first successful transport
submission time in a ring sized to its history. A newly acknowledged input must
match a retained entry from the current welcome/connection. The elapsed time
includes outbound queueing, server processing and snapshot cadence, and return
delivery. This measures input turnaround rather than transport RTT alone.
Backpressured submissions have no send-time sample. Repeated windows keep the
first successful submission time; stale or missing entries produce no estimate.

After three valid samples, the bootstrap lead becomes the recent turnaround peak
converted to ticks plus four reserve ticks, clamped by configured `lead`,
`max_future - 2` and `max_prediction - 2`. The client retains peaks from the
current and previous one-second buckets, allowing short bursts to affect the
lead until their buckets age out. `lead_ticks` bounds prediction rebuilt after
a complete snapshot ahead of the client's prediction. It does not rewrite
existing history or change queued action/input ticks.

Clock discipline separately uses the server-observed arrival margin:
`input_newest - snapshot_tick`. The target is three future input ticks. Around that
target the existing ±2% correction is retained. Above seven ticks the clock runs
at 0.9× until the excess drains; a negative margin uses 1.1× to recover. This changes
future local stepping through the existing `clock_scale` API. It does not rewind
or skip authority ticks, retime accepted requests, or bypass admission or
authority fencing.
Applications driving `Client` directly must apply `clock_scale`; the Godot Session
adapter already does so. Spectators and latest-observation models keep scale 1.

Long local pump gaps invalidate outstanding samples, avoiding calibration from
local suspension. The gap threshold is the larger of 250 ms and
`(snapshot_every + 2) / hz` seconds. Reconnect, a new authority and every accepted
Welcome reset timing history. The configured minimum lead still applies.
Choose that minimum for the application's expected conditions; the calibration
policy does not establish a universal latency setting.

Inspect `input_timing.turnaround_ms`, `input_timing.arrival_lead`, `lead_ticks`,
`clock_scale`, and the cumulative `Stats.timing_samples`, `timing_rejected` and
`lead_updates`. None is simulation state. The send-time ring adds one bounded
`Input_Sent` record per history slot (24 bytes per slot on the tested arm64 build).

Tests include a delayed welcome that initially selects 62 ticks, changing latency
and jitter, unchanged queued action due ticks, convergence, backpressure, local
stalls, reconnect and non-scheduled clients. This policy does not promise zero
corrections or hide link failure; ordinary history/capacity/recovery bounds remain.
