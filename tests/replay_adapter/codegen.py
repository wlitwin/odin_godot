from pathlib import Path
import os,subprocess,sys
root=Path(__file__).resolve().parents[2]
sg=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
source='''//gd:extends Node2D
//gd:class DemoView
//gd:replay_view value=value,present=demo_present,validate=demo_validate,retired=demo_retire,appearance=style,configure=demo_configure
package demo_view
import gd "godot:godot"
import d "godot:replay/definitions"
DemoView :: struct {owner:gd.Node2d,value:u8,style:^Style}
demo_present :: proc(self:^DemoView,value:u8) {self.value=value}
demo_validate :: proc(self:^DemoView)->d.Report {return {}}
demo_configure :: proc(self:^DemoView,style:^Style)->d.Report {self.style=style;return {}}
demo_retire :: proc(self:^DemoView) {}
'''
style='''//gd:extends Resource
//gd:class DemoStyle
package demo_view
import gd "godot:godot"
Style :: struct {owner:gd.Resource,tint:gd.Color `gd:"export"`}
'''
def case(name,text,generation=True,compilation=True,diagnostic=''):
 project=out/name;project.mkdir();(project/'view.odin').write_text(text);(project/'style.odin').write_text(style)
 generated=subprocess.run([str(sg),str(project),f'-godot:{root}'],capture_output=True,text=True)
 (project/'generation.log').write_text(generated.stdout+generated.stderr)
 assert (generated.returncode==0)==generation,(name,generated.stderr)
 if not generation:
  assert diagnostic in generated.stderr+generated.stdout
  return
 output=(project/'odin_godot_scripts.gen.odin').read_text()
 assert 'demo_view_replay_binding' in output and 'godot:kit/' not in output
 assert 'rview.Script_Archetype(type_of(DemoView{}.value),DemoView,type_of(DemoView{}.style^))' in output
 second=subprocess.run([str(sg),str(project),f'-godot:{root}'],capture_output=True,text=True,check=True)
 assert (project/'odin_godot_scripts.gen.odin').read_text()==output
 checked=subprocess.run([os.environ.get('ODIN','odin'),'check',str(project),f'-collection:godot={root}','-no-entry-point','-target:freestanding_wasm32'],capture_output=True,text=True)
 (project/'compile.log').write_text(checked.stdout+checked.stderr)
 assert (checked.returncode==0)==compilation,(name,checked.stderr)
 if not compilation:assert diagnostic in checked.stdout+checked.stderr
case('valid',source)
case('unknown',source.replace('value=value,','values=value,'),generation=False,diagnostic='unknown replay_view option')
case('missing_field',source.replace('value=value,','value=absent,'),generation=False,diagnostic='display field "absent" does not exist')
case('unpaired',source.replace(',configure=demo_configure',''),generation=False,diagnostic='appearance and configure')
case('duplicate',source.replace('value=value,','value=value,value=value,'),generation=False,diagnostic='duplicate replay_view option')
case('bad_present',source.replace('proc(self:^DemoView,value:u8)','proc(self:^DemoView,value:u16)'),compilation=False,diagnostic='incompatible present callback signature')
case('bad_configure',source.replace('proc(self:^DemoView,style:^Style)','proc(self:^DemoView,style:gd.Resource)').replace('self.style=style;',''),compilation=False,diagnostic='incompatible configure callback signature')
print('REPLAY_VIEW_CODEGEN_OK cases=7 stable=true wasm=true no_kit_import=true')
