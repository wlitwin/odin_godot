"""Reject generated regressions using a disposable source overlay."""
from pathlib import Path
import os,re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[2];script=Path(__file__).with_name('audit.py')
for case in ['valid','short_slot','missing_slot','wrong_slot','missing_method','enum_return','enum_argument']:
 with tempfile.TemporaryDirectory() as tmp:
  out=Path(tmp);(out/'godot').mkdir();(out/'gdext').symlink_to(root/'gdext',target_is_directory=True);(out/'extension_api.json').symlink_to(root/'extension_api.json')
  for p in (root/'godot').glob('*.gen.odin'):
   if p.name not in ['web_rtc_data_channel.gen.odin','node.gen.odin']:(out/'godot'/p.name).symlink_to(p)
  node=(root/'godot/node.gen.odin').read_text()
  if case=='enum_return':node=node.replace('ret = Node_Process_Mode(__return_storage)','ret = Node_Process_Mode(0)',1)
  if case=='enum_argument':node=node.replace('mode_ := Int(mode_)','mode_ := mode_',1)
  (out/'godot/node.gen.odin').write_text(node)
  data=(root/'godot/web_rtc_data_channel.gen.odin').read_text()
  if case=='short_slot':data=data.replace('&__return_storage)','&ret)',1)
  if case=='missing_slot':data=data.replace('    __return_storage: Int\n','',1)
  if case=='wrong_slot':data=data.replace('__return_storage: Int','__return_storage: Float',1)
  if case=='missing_method':data=re.sub(r'web_rtc_data_channel_get_buffered_amount :: proc[\s\S]*?\n\}', '',data,count=1)
  (out/'godot/web_rtc_data_channel.gen.odin').write_text(data)
  p=subprocess.run([sys.executable,str(script)],env={**os.environ,'REPLAY_ABI_SOURCE_ROOT':str(out)},capture_output=True,text=True)
  assert (p.returncode==0)==(case=='valid'),(case,p.stdout,p.stderr)
print('REPLAY_PTRCALL_ABI_AUDIT_TESTS_OK 7')
