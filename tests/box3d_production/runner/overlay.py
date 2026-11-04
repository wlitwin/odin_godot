"""Minimal optional derived-project overlay; no default export behavior change."""
from pathlib import Path
import hashlib,json,re,shutil
VERSION=2
FILES={'overlay.json','production_pause.gd'}
PROJECT_SETTINGS={'application/run/flush_stdout_on_print':True}
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def describe(folder,expected=None):
 folder=Path(folder).resolve(strict=True)
 paths=list(folder.iterdir())
 if {p.name for p in paths}!=FILES or any(not p.is_file() or p.is_symlink() for p in paths):raise ValueError('overlay must contain exactly two ordinary files')
 if sum(p.stat().st_size for p in paths)>1024*1024:raise ValueError('overlay source exceeds1MiB')
 descriptor=json.loads((folder/'overlay.json').read_text())
 if descriptor.get('version')!=VERSION or descriptor.get('autoload_name')!='Box3DProductionPause' or descriptor.get('script')!='production_pause.gd' or descriptor.get('project_settings')!=PROJECT_SETTINGS:raise ValueError('unsupported test overlay contract')
 hashes={p.name:sha(p) for p in sorted(paths)}
 digest=hashlib.sha256(json.dumps(hashes,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 if expected is not None and (not re.fullmatch('[0-9a-f]{64}',expected) or digest!=expected):raise ValueError('overlay source SHA differs')
 return dict(version=VERSION,directory=str(folder),sha256=digest,files=hashes,helper_sha256=sha(__file__),project_settings=PROJECT_SETTINGS.copy(),scope=descriptor['scope'])
def flush_setting(text):
 matches=list(re.finditer(r'(?m)^\[application\][ \t]*$',text))
 if len(matches)>1:raise ValueError('duplicate application section')
 before=None
 if matches:
  start=matches[0].end();following=re.search(r'(?m)^\[[^\]\r\n]+\][ \t]*$',text[start:]);end=start+following.start() if following else len(text)
  body=text[start:end];settings=list(re.finditer(r'(?m)^[ \t]*run/flush_stdout_on_print[ \t]*=[^\r\n]*$',body))
  if len(settings)>1:raise ValueError('duplicate flush setting')
  if settings:
   setting=settings[0];value=re.fullmatch(r'([ \t]*run/flush_stdout_on_print[ \t]*=[ \t]*)(true|false)([ \t]*(?:;[^\r\n]*)?)',setting.group())
   if value is None:raise ValueError('existing flush setting is not a literal bool')
   before=value[2]=='true';at=start+setting.start()+value.start(2);text=text[:at]+'true'+text[at+len(value[2]):]
  else:text=text[:start]+'\nrun/flush_stdout_on_print=true'+text[start:]
 else:text+='\n[application]\nrun/flush_stdout_on_print=true\n'
 return text,dict(key='application/run/flush_stdout_on_print',before_present=before is not None,before_value=before,after_value=True)
def apply(project,folder,expected):
 project=Path(project).resolve(strict=True);record=describe(folder,expected);settings=project/'project.godot';text=settings.read_text()
 target=project/'production_pause.gd'
 if target.exists() or 'Box3DProductionPause=' in text:raise ValueError('overlay would overwrite existing project data')
 text,setting_change=flush_setting(text);record['settings_changes']=[setting_change]
 entry='Box3DProductionPause="*res://production_pause.gd"\n'
 matches=list(re.finditer(r'(?m)^\[autoload\][ \t]*$',text))
 if len(matches)>1:raise ValueError('duplicate autoload section')
 if matches:
  at=matches[0].end();derived=text[:at]+'\n'+entry+text[at:]
 else:derived=text+'\n[autoload]\n'+entry
 record['project_settings_before_sha256']=sha(settings)
 shutil.copyfile(Path(record['directory'])/'production_pause.gd',target);settings.write_text(derived)
 record.update(project=str(project),derived_script_sha256=sha(target),project_settings_after_sha256=sha(settings))
 return record
def verify(record):
 if describe(record['directory'],record['sha256'])['helper_sha256']!=record['helper_sha256']:return False
 project=Path(record['project'])
 return sha(project/'production_pause.gd')==record['derived_script_sha256'] and sha(project/'project.godot')==record['project_settings_after_sha256']
