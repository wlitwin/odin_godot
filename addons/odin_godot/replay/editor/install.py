"""Install the optional editor UI for a project declaring replay_authoring.json."""
from pathlib import Path
import json,shutil,sys
source=Path(__file__).resolve().parent
project=Path(sys.argv[1]).resolve()
if not (project/'replay_authoring.json').exists():raise SystemExit(0)
target=project/'addons/replay_authoring';target.mkdir(parents=True,exist_ok=True)
for name in ['plugin.cfg','plugin.gd','preview_controls.gd']:shutil.copy2(source/name,target/name)
(target/'toolchain.json').write_text(json.dumps({'framework':str(source.parents[1]),'python':sys.executable},indent=2)+'\n')
print('REPLAY_EDITOR_INSTALLED',target)
