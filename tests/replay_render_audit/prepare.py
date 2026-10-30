from pathlib import Path
import hashlib,json,shutil,subprocess,sys
repo=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();project=out/'project';out.mkdir(parents=True,exist_ok=True)
assert not project.exists(),'Use a fresh output directory'
shutil.copytree(repo/'examples/replay_scrapyard',project,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
p=project/'project.godot';p.write_text(p.read_text().replace('config/custom_user_dir_name="replay_scrapyard"','config/custom_user_dir_name="replay_render_audit"'))
shutil.copy2(repo/'tests/replay_render_audit/probes/mesh_probe.odin',project/'scripts/mesh_probe.odin')
shutil.copy2(repo/'tests/replay_render_audit/probes/mesh_probe_test.gd',project/'mesh_probe_test.gd')
p=project/'web_ui_test.gd';s=p.read_text();key='\tgame = get_parent()';assert key in s;s=s.replace(key,key+'\n\tif not game.mesh_probe():push_error("MESH2 ownership probe failed");return\n\tprint("REPLAY_MESH2_WEB_OWNERSHIP_OK")',1);p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'source-sha256.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','build','scriptgen'],cwd=repo,text=True).splitlines()
(out/'framework-source.json').write_text(json.dumps({name:sha(repo/name) for name in paths if Path(name).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
print('RENDER_AUDIT_PREPARED')
