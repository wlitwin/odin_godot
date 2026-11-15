# Resuming a saved party

`Room_Options.restore_published` lets a fresh Room recover a durable checkpoint
when its previous authority is gone. `Party` enables this for trusted hosting
members (excluding observers). A live authority always takes precedence: Room
joins that host normally. Existing live migration and frozen-owner recovery keep
their own paths.

```odin
options.restore_published = true
// WSS by default; explicit loopback WS is available for local development.
options.checkpoint_local_development = local_development
error := replaygd.room_open(&room, initial_frame, game_model, options)
// Continue the usual frame loop. No separate download or restore pump is needed.
error = replaygd.room_frame(&room, delta_seconds, controls)
```

The initial frame is used only for a genuinely new bootstrap room. It is never
substituted for missing, corrupt, disallowed or too-old saved progress.

## Lifecycle

After fresh process registration and an authenticated view with no live authority,
Room computes the schema and configuration needed to validate the saved state
without creating a simulation timeline.
It reads publication status, downloads the selected revision, decodes the complete
typed checkpoint and verifies the stable token's playable reservation. Dedicated
authority uses local seat zero.

Room validates and installs packaged dependencies into `checkpoint_cache` before
requesting authority. Room owns the prepared checkpoint independently of transfer
buffers. The existing
`preparation_ready` callback must approve referenced assets before Room requests
authority. While waiting, ordinary authority queries continue and the completed
download's ACK can retry, releasing the service transfer slot. If another host
becomes live, Room releases its pending recovery state and joins it instead.

The explicit Restore request shares the authority Lease's request sequence; Room
does not start another RPC while it is pending. A successful correlated grant is
required, followed by a fresh successful renewal before `session_resume` starts a
runtime. This prevents validation/transfer latency from consuming most of the
lease before expensive runtime setup. The runtime uses the saved
configuration/state, correct local seat and freshly registered incarnation under
the newer epoch. There is no uncoordinated authority fallback.

A Restore reply may arrive after its conservative local deadline: that deadline
is anchored to request start, while the coordinator granted ownership later.
Room retains the exact prepared point and requests renewal when the authenticated
view still reports this actor's reservation. It does not request another Restore
or install a runtime using the expired permit. A successful correlated renewal
can make the same epoch usable. If the coordinator has also expired or replaced
the reservation, renewal is refused and normal recovery/join rules apply.

Retrying a request does not override the service's policy decision. `Busy` during
status/download means another bounded transfer is in progress; Room retries a new
status request after backoff instead of showing a terminal recovery error. `Busy`
on an authority request retains the prepared bytes for a later new attempt. Stale
publication/transport timeout returns to status lookup.
Connection/generation changes preserve owned bytes while the control context is
refreshed. An exact already-granted Point with a live authenticated lease can still
be installed after a lost reply. A stale local permit needs fresh authorization;
an expired coordinator reservation needs a new recovery grant.

`Room.restore.phase` exposes Checking, Downloading, Preparing, Requesting, Granted,
Complete or Failed. `error` and `authority_error` preserve storage/protocol and
authority-policy detail. Missing saves, unsupported contracts, denied reservations
and excessive rollback remain visible failures. `room_restore_retry` permits an
explicit retry for a fresh Room without an initialized Session. Cavecrawl displays
progress and a retry button through its existing party menu.

## Recovery semantics

The normal checkpoint resume policy retires pending accepted actions explicitly
and disconnects nonlocal saved peers until they reconnect. Stable tokens, reserved
seats and action frontiers survive. A game's normal leave/join rules apply to those
peers; Room does not invent an alternate inventory policy. The restoring local
player keeps its saved state. Personal profile persistence remains separate.

`Room.recovery.from_publication` identifies this path. `checkpoint_tick` is the
restored boundary and `service_known_tick` is the latest authenticated pre-attempt
authority tick observed by this Room. `known_lost_ticks` uses that known tick;
`previous_confirmed` stays zero because a fresh process had no local timeline.
This is a known rollback distance from that view, not proof about unreported work or every earlier
grant lost across service restarts. Installation/interruption timing remains
available through the existing recovery metrics.

## Acceptance and remaining work

Cavecrawl's **Rejoin recent party** resumes stored progress after the original
game process exits and the service is killed/restarted. Native verified-TLS and
fresh-browser/RTC tests restore the exact saved tick with three gems in epoch 2,
accept a new guest and its loot action, then publish the continued game again.
The browser test uses explicit loopback development WS. Separate database readers
validate the final saved inventories. The original live handoff/rejoin gate still
passes with publication enabled.

Competing-return fixtures retain the same published checkpoint in two fresh
registered processes before releasing their recovery attempts. One becomes the
new authority; the other observes that live host and joins it. Native release-order
tests cover both possible owner seats and verify one epoch advance plus conserved
loot in the next durable publication. A browser RTC race exercises the same
transition. Temporary Busy responses must not strand a participant before it can
reach that transition.

The tested recovery path covers Cavecrawl under these conditions. Bounded
atomic asset packages also support Scrapyard sprays and native/browser
restoration with an empty asset cache. Broader asset profiles, acceptance of
other games' UI/state, public deployment, and broader recovery/failure policies
remain outside this coverage. See the
[guarded service decision](../provision/checkpoint/restore.md).
