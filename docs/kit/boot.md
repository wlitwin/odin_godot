# kit/boot — the first thirty lines, written once

Two games proved that every friendslop project opens the same way: `ready()`
builds the same lobby/chat/scoreboard/stage/world/wire stack line-for-line,
and `process()` starts with the same pump-tick-drain preamble plus the same
five boilerplate event reactions — roughly a hundred duplicated lines before
any game code. `kit/boot` absorbs exactly that, and nothing game-shaped.

```odin
import kboot "godot:kit/boot"

// ready() — after installing your factory/hooks:
kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
	title       = "P U T T P U T T",
	status      = "Host a course, or join one at localhost",
	legend      = "click: putt · Tab scores · Enter chat", // "" = no legend
	msg_kind    = MSG_SESSION,
	latency_env = "GOLF_LATENCY", // the injected-latency shim's env knob
	methods     = {"on_host", "on_join", "on_start", "on_chat",
	               "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
})

// process():
events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
if self.ses.is_host {
	for _ in 0 ..< ticks { my_game_tick(self) }
}
for ev in events {
	#partial switch e in ev { /* ONLY game cases — see below */ }
}
```

**Everything stays yours.** Every widget is a public field on `Boot`
(`boot.ui`, `boot.chat`, `boot.score`, `boot.legend`, `boot.wire`,
`boot.stage`, `boot.world`) — reposition, restyle, or ignore them. The eight
`@(gd_method)` names are declared in *your* script (Godot signals must land on
the game's class); their bodies are one-liners — see either example game's
`net.odin`.

**`boot_pump` handles the boilerplate and re-yields everything.** It runs
`wire_pump` + `session_tick`, reacts to the five events every game reacts to
identically (Welcomed/Joined/Left → lobby+score repaints and the host's Start
gating at `min_players`; Stats → score repaint; Join_Failed/Host_Left →
status lines), then returns **every** session event plus the comms markers
(temp-allocated) so your switch sees the full stream. Your cases run *after*
boot's, so a game-specific status line simply overwrites the stock one.

**The buttons:** `boot_host(b, port, name)` and
`boot_join(b, addr, port, token, name)` do transport-up + session-start + the
menu/status/chat ritual (via `netgd.begin_host/begin_join`, which exist
separately if you want the ritual your way — e.g. cavecrawl's Steam paths).
`boot_chat(b, text, &sent)` is the whole `text_submitted` handler, focus
release included ([kui.chat_submit](ui.md)).

Identity pairs with [`ksave.token`](save.md): the env-or-file-or-per-instance
ladder in one call, with the same-machine seat-stealing footgun documented as
an option instead of discovered in production.
