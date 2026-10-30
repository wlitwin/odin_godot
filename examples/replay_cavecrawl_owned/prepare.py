"""Create an isolated owner-motion app from the common Cavecrawl authoring source."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2]

def apply_profile(project):
    for p in (project/'scripts').glob('*.odin'):
        s=p.read_text().replace('"../shared/cave"','"godot:examples/replay_cavecrawl/shared/owner_cave"')
        s=s.replace('replay-cavecrawl-rooms','replay-cavecrawl-owned-rooms').replace('"replay-cavecrawl"','"replay-cavecrawl-owned"').replace('"REPLAY_CAVE_PORT", 49422','"REPLAY_CAVE_PORT", 49585').replace('"REPLAY_CAVE_PORT",49422','"REPLAY_CAVE_PORT",49585')
        p.write_text(s)
    p=project/'project.godot';s=p.read_text().replace('config/name="Replay Cavecrawl"','config/name="Replay Cavecrawl Owned"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ReplayCavecrawlOwned"');p.write_text(s)
    p=project/'cave.tscn';p.write_text(p.read_text().replace('value = 49422.0','value = 49585.0'))


def prepare(out):
    out=Path(out).resolve();out.mkdir(parents=True,exist_ok=True)
    project=out/'project'
    if project.exists():raise SystemExit('Use a fresh output directory; existing projects are preserved.')
    shutil.copytree(root/'examples/replay_cavecrawl',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','shared','*.uid','*.gen.odin','__pycache__'))
    apply_profile(project)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    (out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
    paths=subprocess.check_output(['rg','--files','replay','godot','gdext','runtime','core','build','scriptgen','examples/replay_cavecrawl/shared'],cwd=root,text=True).splitlines()
    (out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in paths if Path(n).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
    print(project)

if __name__=='__main__':prepare(sys.argv[1])
