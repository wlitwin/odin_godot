# Browser-local Quickdraw saves

Without a configured party service, the browser menu offers Solo, a named save slot
and Resume solo. Slots use the existing IndexedDB checkpoint helper and are scoped
to the persistent personal identity. The default is `duel`; `save_slot` selects an
initial slot. Valid names use 1–48 letters, digits, dots, dashes or underscores.

Save/F5 captures the complete authority checkpoint once and writes asynchronously.
The notice says Saving until the storage receipt arrives. Leave is blocked during
that write. A successful receipt records the exact saved tick/state hash and slot
revision; ordinary gameplay continues while storage is pending.

Resume borrows the validated slot archive and uses the same restore path as native
files: the saving host identity must match, the new epoch must be greater, and Room
or custom-policy archives are refused. It restores complete gameplay state without
replaying historical cosmetic effects. `role=solo&resume=1` waits for both identity
and slot reads before starting; profile readiness alone is not enough.

Writes compare the revision previously read by that tab. A stale tab fails with a
conflict and cannot silently replace the newer save. It must reload or select another
slot. Corrupt/incompatible slots cannot resume or save over their data. A new unsaved
solo run remains available, and choosing another valid slot creates an independent
save. A malformed persistent identity blocks play rather than creating a substitute.

These are browser-local checkpoints. Party Save/F5 still publishes through Room;
it does not write this local slot. Local browser slots are presented by the standalone
solo menu, while configured party menus retain their service-backed flow. Native
file saves remain available in the native application. No content/model schema changed.

IndexedDB durability follows the shared browser-store contract. Eviction, private mode,
other browser engines, device transfer and public deployment require separate evidence.
See `tests/replay_quickdraw_browser_save/run.sh` for the local Chrome acceptance gate.
