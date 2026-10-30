# Speedball port ledger

Original: `examples/speedball/`. Replay: `examples/replay_speedball/`. Both retain
separate projects, launchers and ports. Original sources are not rewritten by this
port. The original's generated Kit boot/lane code and the Replay value model are
different authoring/runtime designs; matching rules is not a framework-only timing
comparison.

| Original behavior | Replay status / evidence |
| --- | --- |
| Contested whole-pitch prediction; local kick/spike response | Separate complete-state pitch; core, solo and four-process network gates |
| Pitch, ball/player movement, contact, goal/reset/hold rules | Preserved with explicit seat-order contacts; pure model tests |
| Dedicated first client's spawn/team mapping | Preserved one-seat offset; network gate requires right-side winner |
| Host/join/name/port/start front door | Scene-authored menu; match-leader manual start, editable address/port and validated names |
| Scripted auto-start and solo launch | Existing role/bot environment paths retained |
| Enter chat / Escape release / gameplay input capture | Replay comms channel; three-process UI gate checks literal markup and captured movement/spike input |
| Tab score overlay, named roster, ping, departed rows | Authoritative names/team/score with optional telemetry; departed rows retained |
| Late join and rejoin | Authority state initializes views/score; UI gate leaves/rejoins a running pitch using the same token |
| Score/winner text and arrival/start narration | Authoritative HUD and comms messages |
| Host departure | Direct sessions show connection-ended; configured Room sessions recover through an authenticated coordinator |
| Planned handoff / crash during play | Native Room gate restores a moving scored checkpoint and verifies new actions, chat and common worlds; fixed local three-member fixture |
| Original caller-supplied spike coordinates | Deliberately replaced by seat-derived origin; trust-model difference retained |
| Original mixed sim score / discrete scoreboard state | Complete Replay score/winner participates in rollback; authoritative HUD reads remain |
| Persistent reconnect identity from Kit boot | Native profile and browser IndexedDB identity/name; fresh-process gates reclaim the seat and chosen display name |
| Play again (Replay addition) | Round-scoped leader command; two complete networked matches with guest rejection, roster retention and chat |
| Match save/resume UI (Replay addition) | Direct native authority saves; exact fresh-process solo/host restore, same-seat rejoin, continued actions/restart/chat and malformed/failed-write checks |
| Party create/invite/join/rejoin (Replay integration) | Shared Party helper; native WSS and local browser RTC, durable credentials, profile separation and fresh-process host return |
| Invited watch-only mode | True seat-0 observer across migration and leave/rejoin; no player or backup subscription |
| Browser solo checkpoints (Replay addition) | Named IndexedDB slots; exact restore after SIGKILL, continued play/restart, stale-tab and corruption preservation, alternate slots |
| Room save publication and abandoned-party recovery | Host save/F5, optional cadence, guarded fresh-process rejoin, retained scored round, new guest/round/chat and continued durable save; native/browser fixtures |
| Public deployment | Still pending; direct/native/browser solo saves stay distinct from coordinated party recovery |
| Browser party gameplay | Chrome RTC planned/host-loss migration, observer rejoin, fresh-browser identity/name/invite continuity, new spikes/chat and common worlds |
| Public/Steam deployment, other browsers and broad play-feel review | Still pending for this port |

The current experimental content ID is `0x5253504545444234`. Names, named-profile
state, manual-start policy and intent commands change the model's schema from the
initial Speedball slice. Revision 3 changes start authorization to the first
connected seat, preserving the match leader during a planned authority handoff and
selecting a surviving leader after departure. Revision 4 adds the round counter and
restart intent. The previous content ID is intentionally incompatible;
old-schema archives have no implicit conversion path. Ball/score rule
changes were not used to obtain the social/UI result.
