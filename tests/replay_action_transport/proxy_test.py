import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('action_proxy',Path(__file__).with_name('proxy.py'));p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
v=lambda *kinds:[{'kind':kind} for kind in kinds]
assert p.selected('heartbeat',v(9,11,15))
assert not p.selected('heartbeat',v(9,5))
assert p.selected('action',v(5,11,15))
assert not p.selected('action',v(25,5)) # nested Action in a copy bundle
assert not p.selected('action',v(5,16))
assert not p.selected('action',[])
print('ACTION_PROXY_SELECTION_OK')
