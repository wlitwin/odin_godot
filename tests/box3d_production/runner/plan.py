"""Pure production plan. Creating a plan never launches a process."""
from pathlib import Path
import math,re
CASES=('functional','long','pause300','pause3000')
TARGETS=('macos-arm64','linux-x86_64')
def build_plan(config,root,python):
 root=Path(root);case=config['case'];target=config['target'];framework=config['framework']
 if case not in CASES or target not in TARGETS or framework not in ('kit','replay'):raise ValueError('unsupported case/target/framework')
 for name in ['out','godot','odin','native_library']:
  if not Path(config[name]).is_absolute():raise ValueError(name+' must be an explicit absolute path')
 out=Path(config['out'])
 if out==root or root in out.parents:raise ValueError('output must be NEW outside repository')
 if not re.fullmatch('[0-9a-f]{64}',config['native_sha256']):raise ValueError('exact Native SHA required')
 if type(config['port']) is not int or not 1024<=config['port']<=65535:raise ValueError('invalid port')
 if case=='long':
  terminal,required,minimum,timeout=108600,108000,1800,2400
  if config.get('ticks') not in (None,terminal):raise ValueError('long terminal is108600; required workload108000 remains')
  if config.get('timeout') not in (None,timeout):raise ValueError('long supervisor is2400 seconds')
 else:
  terminal=config.get('ticks') if config.get('ticks') is not None else (120 if case=='functional' else 1200)
  required=terminal;minimum=0;timeout=config.get('timeout') if config.get('timeout') is not None else (180 if case=='functional' else 240)
  if type(terminal) is not int or not 120<=terminal<=3600:raise ValueError('invalid functional-first target')
  if type(timeout) not in (int,float) or not math.isfinite(timeout) or not 0<timeout<=2400:raise ValueError('bounded supervisor timeout required')
 pause=300 if case=='pause300' else 3000 if case=='pause3000' else 0
 pause_at=config.get('pause_at',240)
 if type(pause_at) is not int or (pause and not (120<=pause_at and terminal>=pause_at+512+120)):raise ValueError('pause needs a bounded observed Host window and future suffix')
 mode=config.get('execution_mode') or ('native' if target=='macos-arm64' else None)
 if mode not in ('native','translated-linux-x86_64') or (target=='macos-arm64' and mode!='native'):raise ValueError('explicit actual execution mode required')
 export=out/'export';record=export/'export-record.json'
 if target=='macos-arm64':
  argv=[python,str(root/'tests/box3d_gate_c/macos/export.py'),'--framework',framework,'--out',str(export),'--godot',config['godot'],'--odin',config['odin'],'--native-library',config['native_library'],'--native-sha256',config['native_sha256'],'--execute']
 else:
  toolchain=config.get('toolchain_report')
  if not toolchain or not Path(toolchain).is_absolute():raise ValueError('Linux requires actual absolute toolchain report')
  argv=[python,str(root/'tests/box3d_gate_c/linux/pipeline.py'),'export','--repo-input',str(root),'--work',str(out/'linux-work'),'--out',str(export),'--framework',framework,'--native-library',config['native_library'],'--toolchain-report',toolchain,'--execution-mode',mode]
 digest=config.get('overlay_sha256')
 if not digest or not re.fullmatch('[0-9a-f]{64}',digest):raise ValueError('bound test overlay SHA required for every production case')
 overlay={'directory':str(root/'tests/box3d_production/runner/pause_overlay'),'sha256':digest,'project_settings':{'application/run/flush_stdout_on_print':True}}
 argv+=['--project-overlay',overlay['directory'],'--project-overlay-sha256',digest]
 runtime=[python,str(root/'tests/box3d_production/runner/controller.py'),'--record',str(record),'--out',str(out/'runtime'),'--case',case,'--ticks',str(terminal),'--required-ticks',str(required),'--minimum-seconds',str(minimum),'--timeout',str(timeout),'--port',str(config['port']),'--pause-at',str(pause_at),'--pause-ms',str(pause)]
 return {'schema':1,'result':'STAGED_ONLY','target':target,'framework':framework,'case':case,'execution_mode':mode,'inputs':{n:config[n] for n in ['godot','odin','native_library','native_sha256']},'terminal_tick':terminal,'required_ticks':required,'minimum_observed_seconds_after_both_GO':minimum,'timeout_seconds':timeout,'pause_ms':pause,'pause_at_confirmed':pause_at,'overlay':overlay,'steps':[{'name':'ordinary_export','argv':argv,'record':str(record)},{'name':'actual_exported_production_pair','argv':runtime,'record':str(out/'runtime/report.json')}],'jobs_started':0,'scope':'fixed functional production evidence; pauses are delivery/service gaps, not loss/jitter/CPU certification'}
