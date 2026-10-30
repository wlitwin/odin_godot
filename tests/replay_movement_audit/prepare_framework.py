"""Isolated Kit control: preserve live owner fields during pending delta unwind."""
from pathlib import Path
import hashlib,json,shutil,sys
root=Path(__file__).resolve().parents[2];target=Path(sys.argv[1]).resolve();target.mkdir(parents=True,exist_ok=True)
assert target!=root and not (target/'kit').exists()
for p in root.iterdir():
 if p.name.startswith('.') or p.name=='kit':continue
 (target/p.name).symlink_to(p,target_is_directory=p.is_dir())
shutil.copytree(root/'kit',target/'kit')
p=target/'kit/net/registry.odin';before=p.read_text()
old='''unwind_pending :: proc(ctx: ^Command_Ctx, e: ^Registry_Entry) {
\t#reverse for &p in ctx.pending.entries {
\t\tif pending_reconciles(p, e) {
\t\t\t// Client-only path: predicted fields belong to the sim lane.
\t\t\tfields_restore(e.entity, e.set.entity_desc, p.revert, {.Predicted})'''
new='''unwind_pending :: proc(ctx: ^Command_Ctx, e: ^Registry_Entry) {
\tskip := Subset_Skips{.Predicted}
\tif (ctx.me != PLAYER_ID_INVALID && e.owner == ctx.me) || e.predict_owner {skip += {.Owner}}
\t#reverse for &p in ctx.pending.entries {
\t\tif pending_reconciles(p, e) {
\t\t\t// Isolated diagnostic control: preserve the independently owned stream.
\t\t\tfields_restore(e.entity, e.set.entity_desc, p.revert, skip)'''
assert before.count(old)==1;p.write_text(before.replace(old,new))
(target/'repair.json').write_text(json.dumps({'original_root':str(root),'changed':'kit/net/registry.odin','before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':'Isolated comparison control; no original Kit/game file changed.'},indent=2)+'\n')
print('OWNER_AUDIT_FRAMEWORK_READY')
