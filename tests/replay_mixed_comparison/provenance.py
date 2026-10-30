"""Validate an optional isolated Kit owner-unwind control without relabeling it."""
from pathlib import Path
import hashlib,json

def validate(root,framework,build,plan):
    enabled=plan.get('owner_control',False)
    assert type(enabled) is bool
    collections=build.get('collections',{'kit':framework['root'],'replay':framework['root']})
    assert set(collections)=={'kit','replay'} and collections['replay']==framework['root']
    files=['owner-control.json','kit-framework-source.json']
    if not enabled:
        assert not any((root/name).exists() for name in files)
        assert collections['kit']==framework['root']
        return {'enabled':False}
    control=json.loads((root/'kit-framework-source.json').read_text())
    repair=json.loads((root/'owner-control.json').read_text())
    assert collections['kit']==control['root'] and control['root']!=framework['root']
    assert control['sha256'].keys()==framework['sha256'].keys()
    changed=[name for name,h in framework['sha256'].items() if control['sha256'][name]!=h]
    assert changed==['kit/net/registry.odin']
    assert repair['changed']==changed[0] and repair['original_root']==framework['root']
    assert repair['before_sha256']==framework['sha256'][changed[0]]
    assert repair['after_sha256']==control['sha256'][changed[0]]
    for name,h in control['sha256'].items():
        assert hashlib.sha256((Path(control['root'])/name).read_bytes()).hexdigest()==h,('control framework',name)
    return {'enabled':True,'repair':repair,'kit_collection':control['root'],'replay_collection':framework['root']}
