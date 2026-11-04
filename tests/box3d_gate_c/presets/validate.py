#!/usr/bin/env python3
"""Read-only source preset contract check; never builds, exports or runs Godot."""
from pathlib import Path
import argparse,configparser,hashlib,json
ROOT=Path(__file__).resolve().parents[3]
def value(config,section,key):
 raw=config.get(section,key)
 return json.loads(raw) if raw.startswith('"') else raw

def inspect(root):
 contract=json.loads(Path(__file__).with_name('presets.json').read_text());rows=[]
 for framework,details in contract['frameworks'].items():
  path=root/details['project']/'export_presets.cfg'
  cfg=configparser.ConfigParser(interpolation=None,strict=True);cfg.read(path)
  for index,(target,spec) in enumerate(contract['presets'].items()):
   section='preset.'+str(index);options=section+'.options'
   assert value(cfg,section,'name')==spec['name'] and value(cfg,section,'platform')==spec['platform']
   assert value(cfg,options,'binary_format/architecture')==spec['architecture']
   assert value(cfg,section,'export_filter')=='all_resources'
   assert all(x in value(cfg,section,'include_filter').split(',') for x in ['*.odin','*.gd','*.tres','*.tscn','*.gdextension'])
   assert cfg.get(section,'encrypt_pck')=='false' and cfg.get(section,'encrypt_directory')=='false'
   if target=='macos-arm64':
    assert spec['architecture']==spec['launcher_architecture']=='universal' and spec['required_launcher_slice']=='arm64'
    assert spec['required_sdk_architecture']==spec['required_runtime_architecture']=='arm64'
    assert cfg.get(options,'codesign/codesign')=='1' and cfg.get(options,'notarization/notarization')=='0'
    assert value(cfg,options,'application/bundle_identifier')==details['bundle_identifier']
    assert value(cfg,options,'application/min_macos_version_arm64')==spec['minimum_macos']
   row=dict(framework=framework,target=target,name=spec['name'],preset_path=str(path),preset_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
   if target=='macos-arm64':
    row.update(launcher_selector=spec['launcher_architecture'],required_launcher_slice=spec['required_launcher_slice'],required_sdk_architecture=spec['required_sdk_architecture'],required_runtime_architecture=spec['required_runtime_architecture'],scope_qualification=spec['scope_qualification'])
   rows.append(row)
 # Preparation copies the entire project; these files require no special packer.
 content=root/'examples/box3d_authoring_shared/content'
 shared={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in content.iterdir() if p.is_file()}
 for details in contract['frameworks'].values():
  actual=root/details['project']/'content'
  assert {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in actual.iterdir() if p.is_file()}==shared
 return dict(result='PRESET_SOURCE_VALID',scope='configuration/normal source inclusion only; no export/runtime/GateC claim',presets=rows,identical_authored_content=True,builds_started=0,Godot_jobs_started=0)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=ROOT);p.add_argument('--out',type=Path);a=p.parse_args()
 report=inspect(a.root.resolve());text=json.dumps(report,indent=2)+'\n'
 if a.out:
  with a.out.open('x') as f:f.write(text)
 print(text,end='')
if __name__=='__main__':main()
