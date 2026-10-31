# kit/comms — chat, pings, system lines

`kit/comms` sends text chat, positional pings/markers, and host-authored system
lines such as "alice joined the cave". It uses the [session](session.md)'s
SES_APP messages on the reliable channel. The package supplies the packet
format and routing; the game supplies the UI and system-line wording.

Chat operates at the session level and works with the cooperative lane, the
simulation lane, or both. It does not participate in simulation ticks or prediction.

```odin
import kcomms "godot:kit/comms"
```

<a id="mental-model"></a>

## Host routing and event delivery

All messages route through the host, which attaches the speaker identity and
rebroadcasts them in host order. A client's own chat line is displayed when
that broadcast returns, preserving the same ordering as other peers.

[`ksess.Host_Relay`](session.md#host-relay) handles sender identity, source
checks, echo policy, and replay to individual recipients. Comms sets
`echo = true`, which delivers the host's broadcast back to its author.
`kit/comms` adds encoding for two message kinds, a bounded log, and a shared
event queue. `comms_say` writes the same payload on hosts and clients; the
relay selects broadcast or upload without a caller-side `is_host` check.

The receiver delivers two kinds of events:

- **Lines** land in a bounded log (`LOG_MAX :: 64` lines, oldest evicted) that a UI repaints
  from; [kit/ui's chat box](ui.md) does exactly this.
- **Markers** (pings) are transient poll-once events, not log lines. The game turns them
  into world visuals.

The session admits only seated senders to the handler. Clients drop chat
broadcasts received from any peer other than the host, preventing another
client from submitting a broadcast with an invented speaker identity.

## API by task

**Initialize:** call once with the session, on the host or client, before or
after session start:

```odin
comms_init :: proc(c: ^Comms, ses: ^ksess.Session, tag := COMMS_TAG)
comms_destroy :: proc(c: ^Comms)
```

`COMMS_TAG` is `u8(0)`; pass another tag if the game claims 0 for itself (cavecrawl keeps
comms on 0 and puts fire announcements on `TAG_FIRE :: u8(1)`). Destroy Comms
before destroying the session, since teardown removes its route from the
session.

**Send player messages:** hosts and clients use these procedures:

```odin
comms_say :: proc(c: ^Comms, text: string)                  // clipped to MAX_SAY (240 bytes)
comms_ping :: proc(c: ^Comms, kind: u8, pos: [3]f32)        // kind is game-defined; 2D leaves z zero
```

**Send a system line:** only the host may call this. The game supplies text
such as "bob joined the cave":

```odin
comms_system :: proc(c: ^Comms, text: string)
```

System lines carry `SYSTEM_LINE :: knet.Player_Id(0)` as the speaker (real ids start at 1).

**Replay history to a joiner:** the host calls this on `Ev_Player_Joined` to
send the log to that player:

```odin
comms_catchup :: proc(c: ^Comms, player: knet.Player_Id)
```

**Consume:** call this every frame:

```odin
comms_poll :: proc(c: ^Comms) -> (ev: Event, ok: bool)      // Event :: union { Ev_Line, Ev_Marker }
comms_lines :: proc(c: ^Comms) -> []Line                    // the log, oldest first
comms_line_name :: proc(c: ^Comms, line: Line) -> string    // "" for system lines
```

`Ev_Line.text` points into the log. Copy it if you keep it past a frame.

## Worked example (cavecrawl)

The frame loop polls events, repaints the chat box when a line arrives, and
creates visuals for markers.

```odin
refresh_chat := false
for {
    cev, cok := kcomms.comms_poll(&self.comms)
    if !cok {break}
    switch e in cev {
    case kcomms.Ev_Line:
        refresh_chat = true
    case kcomms.Ev_Marker:
        gd.print_str(fmt.tprintf("CAVE_MARK player=%d kind=%d x=%.1f", u64(e.player), e.kind, e.pos.x))
    }
}
if refresh_chat {
    kui.chat_refresh(&self.chat, &self.comms)
}
```

On the host, `comms_welcome` sends history to a new joiner before broadcasting
the join line. It skips history replay on rejoin:

```odin
case ksess.Ev_Player_Joined:
    if self.ses.is_host {
        if p, ok := ksess.session_player(&self.ses, e.id); ok {
            verb := e.rejoin ? "returned to" : "joined"
            kcomms.comms_welcome(&self.comms, e.id, e.rejoin, fmt.tprintf("%s %s the cave", p.name, verb))
        }
    }
```

<a id="gotchas"></a>

## Message ordering and limits

- **Reserve a unique app tag.** Comms messages use one tag inside the session's
  SES_APP framing. The game does not need a separate transport packet kind
  for chat. Other SES_APP users must choose different tags (see
  [session.md](session.md)).
- **Catchup before the join line.** `comms_welcome` handles this ordering for you. The join
  line is broadcast to everyone, including the joiner. Replay the log first
  or the joiner sees their own arrival twice. Rejoins skip catchup (a same-session
  reconnect may still hold this run's log). Use `comms_catchup`/`comms_system` directly only
  when your join lifecycle differs.
- **Your own line does not echo locally** (on a client). It lands when the host's broadcast
  comes back. Don't paint an optimistic local copy or you'll double it.
- **`comms_system` asserts `is_host`.** System lines come from the authority; clients that
  want a system line must ask the host; ordinary player text uses `comms_say`.
- **Bytes, not runes:** `MAX_SAY` is a 240-*byte* budget, clipped at a rune boundary (never
  mid-UTF-8). The host enforces the same limit again on receipt.

Siblings: [session.md](session.md) (SES_APP routing, roster, events) ·
[ui.md](ui.md) (the chat box that repaints from this log) · [net.md](net.md) (Writer/Reader).
