"""Record the actual typed bake after import and before gameplay execution."""
from pathlib import Path
import json,shutil,sys
from fixture import CATALOG_FILES,snapshot,verify_catalog

base=Path(sys.argv[1]);impl=sys.argv[2];project=base/'project'
inputs=json.loads((base/'inputs.json').read_text());source=snapshot(project)
changes={name:{'before':inputs.get(name),'after':source.get(name)} for name in sorted(set(inputs)|set(source)) if inputs.get(name)!=source.get(name)}
assert set(changes)==(set(CATALOG_FILES) if impl=='replay' else set()),changes
if impl=='replay':
 verify_catalog(project)
 for name in CATALOG_FILES:shutil.copy2(project/name,base/'catalog'/('after-'+Path(name).name))
(base/'catalog/changes.json').write_text(json.dumps(changes,indent=2)+'\n')
(base/'source.json').write_text(json.dumps(source,indent=2)+'\n')
print('REPLAY_WEAPON_CATALOG_RECORDED '+impl)
