"""Install the same paid-revive feature; no scenario setup or test probes here."""
from pathlib import Path
import difflib,hashlib,json

CONTRACT = 0x5041494452455631

def install(project: Path, implementation: str, evidence: Path):
    before={}
    def edit(name,old,new):
        p=project/name; text=p.read_text(); before.setdefault(name,text)
        assert text.count(old)==1,(implementation,name,old[:100],text.count(old))
        p.write_text(text.replace(old,new))
    if implementation=='kit':
        edit('scripts/run.odin','host_honor_revive :: proc(','''PAID_REVIVE_COST :: i64(3)
paid_revive_can :: proc(self: ^Scrapyard, by: knet.Player_Id, target: ^Runner) -> bool {
    to := ksess.session_owner_of(&self.ses, target.net_id)
    member, known := ksess.session_player(&self.ses, to)
    if !known || !member.connected || to == by {return false}
    column, registered := ksess.session_stat_find(&self.ses, "scrap")
    if !registered {return false}
    funds := ksess.session_stat(&self.ses, by, column)
    receiving := ksess.session_stat(&self.ses, to, column)
    return funds >= PAID_REVIVE_COST && receiving >= 0 && receiving <= i64(max(u32)) - PAID_REVIVE_COST
}

host_honor_revive :: proc(''')
        edit('scripts/run.odin','\ttarget.health.hp = i32(REVIVE_HP)', '''    if !paid_revive_can(self, reviver, target) {return}
    recipient := ksess.session_owner_of(&self.ses, target.net_id)
    ksess.session_stat_add(&self.ses, reviver, self.scrap_col, -PAID_REVIVE_COST)
    ksess.session_stat_add(&self.ses, recipient, self.scrap_col, PAID_REVIVE_COST)
\ttarget.health.hp = i32(REVIVE_HP)''')
        edit('scripts/input.odin','\t\t// Advance on this friend; full =', '''        if !paid_revive_can(self, self.ses.me, other) {continue}
\t\t// Advance on this friend; full =''')
        edit('scripts/hud.odin','\ttheme.ui_show(self.hud.prompt, near_downed(self))', '''    gd.set_text(self.hud.prompt, my_stat(self, "scrap") >= PAID_REVIVE_COST ? "Hold E — revive and give 3 scrap" : "Revive needs 3 scrap")
\ttheme.ui_show(self.hud.prompt, near_downed(self))''')
        edit('scripts/scrapyard.odin','{tick_hz = tick_hz(), interp_delay =','{fingerprint = ksess.session_mix_fingerprint(0, "paid-revive-v1: cost=3 credit=3 cap=u32"), tick_hz = tick_hz(), interp_delay =')
        roles={'scripts/run.odin':'gameplay','scripts/input.odin':'input','scripts/hud.odin':'presentation','scripts/scrapyard.odin':'compatibility'}
    else:
        edit('shared/game/run.odin','revive_step :: proc(','''PAID_REVIVE_COST :: u32(3)
paid_revive_can :: proc(funds, receiving: u32) -> bool {
    return funds >= PAID_REVIVE_COST && receiving <= max(u32) - PAID_REVIVE_COST
}

revive_step :: proc(''')
        edit('shared/game/run.odin','&& p.in_reach(player.position, other.position, 56) {target = i; break}', '&& p.in_reach(player.position, other.position, 56) && paid_revive_can(player.scrap, other.scrap) {target = i; break}')
        edit('shared/game/run.odin','\t\t\tw.players[target].hp = 4;', '''            player.scrap -= PAID_REVIVE_COST
            w.players[target].scrap += PAID_REVIVE_COST
\t\t\tw.players[target].hp = 4;''')
        edit('scripts/hud.odin','Reviving %d%% — hold F','Reviving %d%% — hold F, give 3 scrap')
        edit('scripts/hud.odin','cstring("Hold F — revive your friend")', 'cstring("Hold F — revive and give 3 scrap")')
        edit('scripts/hud.odin','\t\t\t\t\tgd.set_string(self.prompt, "text", text);','                    if !game.paid_revive_can(player.scrap, other.scrap) {text = "Revive needs 3 scrap or wallet space"}\n\t\t\t\t\tgd.set_string(self.prompt, "text", text);')
        edit('shared/game/game.odin','0x5253435241503046',hex(CONTRACT))
        roles={'shared/game/run.odin':'gameplay','scripts/hud.odin':'presentation','shared/game/game.odin':'compatibility'}
    rows=[];patch=[]
    for name,old in sorted(before.items()):
        new=(project/name).read_text();a,b=old.splitlines(),new.splitlines()
        delta=list(difflib.unified_diff(a,b,fromfile='a/'+name,tofile='b/'+name,lineterm=''))
        patch+=delta
        added=[line[1:] for line in delta if line.startswith('+') and not line.startswith('+++')]
        removed=[line[1:] for line in delta if line.startswith('-') and not line.startswith('---')]
        row={'path':name,'category':roles[name],'added_physical':len(added),'removed_physical':len(removed),
             'added_nonblank':sum(bool(x.strip()) for x in added),'removed_nonblank':sum(bool(x.strip()) for x in removed),
             'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(new.encode()).hexdigest()}
        rows.append(row)
        for kind,text in [('before',old),('after',new)]:
            p=evidence/kind/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    (evidence/'feature.patch').write_text('\n'.join(patch)+'\n')
    (evidence/'changes.json').write_text(json.dumps({'implementation':implementation,'files':rows,'method':'Unified diff with three context lines; physical and nonblank changed lines. No time/productivity inference.'},indent=2)+'\n')
