# kit/comms — chat, pings, system lines

How friends talk while they play: text chat, positional pings/markers, and host-authored
system lines ("alice joined the cave"). It rides the [session](session.md)'s SES_APP
extension point on the reliable channel, so a game wires **zero** extra networking for chat —
no packet type, no kind byte, no route of its own.

**Lane compatibility: lane-agnostic.** Chat is session-level — it works identically
beside the coop lane, the sim lane, or both (quickdraw and speedball could wire it
tomorrow; nothing here touches ticks or prediction).

```odin
import kcomms "godot:kit/comms"
```

## Mental model

Everything routes through the host, which stamps the speaker and rebroadcasts — so every peer
sees the same lines in the same order (**the host's order**), on any transport. Your own chat
line comes back with the broadcast rather than echoing locally: authoritative order beats a
few milliseconds, and what you see IS what everyone sees.

That shape is not written here. It is
[`ksess.Host_Relay`](session.md#the-host-relay-host_relay--the-send-half-written-once) —
stamp, spoof-drop, echo policy, addressed replay — which kit/comms and [kit/xfer](xfer.md)
had hand-rolled twice before it existed; comms runs it with `echo = true`, which is that
"comes back with the broadcast" sentence, as a flag. What is left in this package is a
payload codec (two message kinds) over a bounded log and the shared rider queue. It shows in
the calls: `comms_say` writes the same bytes on the host and on a client, and the relay picks
the arm — there is no `is_host` at a send door anywhere in the package.

Two shapes come out the other end:

- **Lines** land in a bounded log (`LOG_MAX :: 64` lines, older evict) that a UI repaints
  from — [kit/ui's chat box](ui.md) does exactly this.
- **Markers** (pings) are transient poll-once events, not log lines — the game turns them
  into world visuals.

The session already vouches for senders (only seated players reach the handler), and clients
drop chat frames that don't come from the host's peer — a peer broadcasting lines directly is
spoofing.

## API by task

**Bind it** — once, next to the session (host or client, before or after it starts):

```odin
comms_init :: proc(c: ^Comms, ses: ^ksess.Session, tag := COMMS_TAG)
comms_destroy :: proc(c: ^Comms)
```

`COMMS_TAG` is `u8(0)`; pass another tag if the game claims 0 for itself (cavecrawl keeps
comms on 0 and puts fire announcements on `TAG_FIRE :: u8(1)`). Destroy the comms before the
session — it must outlive the session's traffic.

**Speak** — anyone:

```odin
comms_say :: proc(c: ^Comms, text: string)                  // clipped to MAX_SAY (240 bytes)
comms_ping :: proc(c: ^Comms, kind: u8, pos: [3]f32)        // kind is game-defined; 2D leaves z zero
```

**Narrate** — host only. The GAME words these ("bob joined the cave"); comms just ships them:

```odin
comms_system :: proc(c: ^Comms, text: string)
```

System lines carry `SYSTEM_LINE :: knet.Player_Id(0)` as the speaker (real ids start at 1).

**Catch a drop-in joiner up** — host, on `Ev_Player_Joined`; replays the whole log to that one
player:

```odin
comms_catchup :: proc(c: ^Comms, player: knet.Player_Id)
```

**Consume** — every frame:

```odin
comms_poll :: proc(c: ^Comms) -> (ev: Event, ok: bool)      // Event :: union { Ev_Line, Ev_Marker }
comms_lines :: proc(c: ^Comms) -> []Line                    // the log, oldest first
comms_line_name :: proc(c: ^Comms, line: Line) -> string    // "" for system lines
```

`Ev_Line.text` points into the log — copy it if you keep it past a frame.

## Worked excerpt (cavecrawl)

The pump: poll events, repaint the chat box only when a line landed, visualize markers.

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

The host's join handling is one call — `comms_welcome` owns the ordering (catchup first,
skipped on rejoin, THEN the join line) so you don't have to:

```odin
case ksess.Ev_Player_Joined:
    if self.ses.is_host {
        if p, ok := ksess.session_player(&self.ses, e.id); ok {
            verb := e.rejoin ? "returned to" : "joined"
            kcomms.comms_welcome(&self.comms, e.id, e.rejoin, fmt.tprintf("%s %s the cave", p.name, verb))
        }
    }
```

## Gotchas

- **No kind byte for chat.** Comms frames live *inside* the session's SES_APP framing under
  one tag — the game never multiplexes chat into its own packets. If your game also uses
  SES_APP, claim a different tag (see [session.md](session.md)).
- **Catchup BEFORE the join line** — the reason `comms_welcome` exists. The join line is
  about to be minted and broadcast to everyone *including* the joiner; replay first or the
  joiner sees their own arrival twice. Rejoins skip catchup (a same-session reconnect may
  still hold this run's log). Use `comms_catchup`/`comms_system` directly only when your
  ritual differs.
- **Your own line does not echo locally** (on a client). It lands when the host's broadcast
  comes back. That's the point — shared order — but don't paint an optimistic local copy or
  you'll double it.
- **`comms_system` asserts `is_host`.** System lines come from the authority; clients that
  want flavor text ask the host (or just say it).
- **Bytes, not runes:** `MAX_SAY` is a 240-*byte* budget, clipped at a rune boundary (never
  mid-UTF-8). The host clips again on receipt — the trust boundary doesn't take the client's
  word for it.

Siblings: [session.md](session.md) (SES_APP routing, roster, events) ·
[ui.md](ui.md) (the chat box that repaints from this log) · [net.md](net.md) (Writer/Reader).
