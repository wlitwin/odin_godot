"""Verify engine ptrcall scalar and enum storage against the current API."""
import collections,json,os,re,sys
from pathlib import Path
root=Path(os.environ.get('REPLAY_ABI_SOURCE_ROOT',Path(__file__).resolve().parents[2]));api=json.loads((root/'extension_api.json').read_text());mapping={'int8':'i8','uint8':'u8','int16':'i16','uint16':'u16','int32':'i32','uint32':'u32','char16':'u16','char32':'u32'}
methods=[m for c in api['classes'] for m in c.get('methods',[])]
expected=collections.Counter(mapping[m['return_value']['meta']] for m in methods if not m.get('is_vararg') and m.get('return_value',{}).get('meta') in mapping)
expected_enum_returns=sum(not m.get('is_vararg') and m.get('return_value',{}).get('type','').startswith(('enum::','bitfield::')) for m in methods)
expected_enum_args=sum(a['type'].startswith(('enum::','bitfield::')) for m in methods for a in m.get('arguments',[]))
texts={p:p.read_text() for p in (root/'godot').glob('*.gen.odin')};enums=set()
for text in texts.values():enums.update(re.findall(r'(?m)^(\w+) :: enum(?:\s+[\w.]+)?\s*\{',text))
for path in (root/'gdext').glob('*.odin'):
 enums.update('__bindgen_gde.'+name for name in re.findall(r'(?m)^(\w+) :: enum(?:\s+[\w.]+)?\s*\{',path.read_text()))
actual=collections.Counter();enum_returns=0;enum_args=0;files=set()
for path,text in texts.items():
 for m in re.finditer(r'(?m)^(\w+) :: proc "contextless" \([\s\S]*?\n\}',text):
  body=m.group(0)
  if 'object_method_bind_' not in body:continue
  header=body[:body.index('{')];ret=re.search(r'-> \(ret: ([\w.]+)\)',header)
  if ret and 'object_method_bind_ptrcall' in body:
   typ=ret.group(1)
   if typ in mapping.values() or typ=='f32' or typ in enums:
    storage='Float' if typ=='f32' else 'Int'
    assert f'__return_storage: {storage}' in body and 'raw_data(args), &__return_storage)' in body and f'ret = {typ}(__return_storage)' in body,(path,m[1])
    assert 'raw_data(args), &ret)' not in body,(path,m[1]);files.add(str(path))
    if typ in enums:enum_returns+=1
    else:actual[typ]+=1
  for arg,typ in re.findall(r'(?m)^\s+(\w+): ([\w.]+),',header):
   if typ not in enums:continue
   assert f'{arg} := Int({arg})' in body,(path,m[1],arg);enum_args+=1;files.add(str(path))
assert actual==expected,(actual,expected)
assert enum_returns==expected_enum_returns,(enum_returns,expected_enum_returns)
assert enum_args==expected_enum_args,(enum_args,expected_enum_args)
result={'pass':True,'narrow_returns':sum(actual.values()),'enum_returns':enum_returns,'enum_arguments':enum_args,'files':len(files),'types':dict(actual)}
if len(sys.argv)>1:Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n')
print('REPLAY_PTRCALL_ABI_AUDIT_OK',json.dumps(result))
