"""Standalone comparison charts. Requires matplotlib; no game/runtime dependency."""
from pathlib import Path
import argparse,json,statistics
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
s=json.loads((a.run/'summary.json').read_text());assert s['full_plan'] and s['contract']['scenario']=='moving_status_swarm'
colors={'kit':'#286b98','replay':'#d67d26'}
fig,axes=plt.subplots(1,3,figsize=(12.5,4.7))
for ax,metric,title,scale,unit in zip(axes,['p50_us','p95_us','application_bytes_per_second'],['Callback p50','Callback p95','Application output'],[1,1,1024],['Elapsed µs','Elapsed µs','KiB/s']):
 for j,impl in enumerate(('kit','replay')):
  rows=[s['aggregates'][impl+'/'+role][metric] for role in ('host','client')]
  y=[r['median']/scale for r in rows];lo=[(r['median']-r['min'])/scale for r in rows];hi=[(r['max']-r['median'])/scale for r in rows]
  bars=ax.bar([i+(j-.5)*.36 for i in range(2)],y,.34,color=colors[impl],label=('Kit control' if impl=='kit' and s.get('owner_control',{}).get('enabled') else impl.capitalize()),yerr=[lo,hi],capsize=4)
  ax.bar_label(bars,labels=[f'{v:.0f}' if scale==1 else f'{v:.1f}' for v in y],padding=6,fontsize=9)
 ax.set_xticks([0,1],['Host','Client']);ax.set_title(title);ax.set_ylabel(unit);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True);ax.margins(y=.25)
axes[0].legend(frameon=False,loc='upper left')
fig.suptitle('Scrapyard · moving/status swarm'+(' · Kit owner-unwind control' if s.get('owner_control',{}).get('enabled') else ''),fontsize=14)
fig.text(.5,.025,'Three alternating pairs · 20 seconds · 60 Hz / 60 FPS · 120 ms receive delay per process\nBars: median of per-run metrics; whiskers: range. Inclusive callbacks and application bytes, not framework-only CPU/transport cost.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.12,1,.94])
for ext in ('png','svg','pdf'):fig.savefig(a.output/('costs.'+ext),dpi=180)
plt.close(fig)
fig,axes=plt.subplots(2,2,figsize=(11,7))
for impl in ('kit','replay'):
 for pair in (1,2,3):
  trace=json.loads((a.run/f'pair-{pair}/{impl}/success-host.json').read_text())['trace'];t=[s['us']/1e6 for s in trace];label=('Kit control' if impl=='kit' and s.get('owner_control',{}).get('enabled') else impl.capitalize()) if pair==1 else None
  for ax,values in zip(axes.flat,[[s['living'] for s in trace],[s['chilled'] for s in trace],[sum(p['rally'] for p in s['people']) for s in trace],[sum(s['kills']) for s in trace]]):
   ax.plot(t,values,color=colors[impl],alpha=.5,linewidth=1,label=label)
for ax,title in zip(axes.flat,['Living enemies','Chilled enemies','Players wearing rally','Team kills']):ax.set_title(title);ax.set_xlabel('Seconds in local window');ax.grid(alpha=.2)
axes[0,0].legend(frameon=False);axes[1,0].set_yticks([0,1,2]);fig.suptitle('Authoritative traces · all three runs, without timing alignment'+(' · isolated Kit control' if s.get('owner_control',{}).get('enabled') else ''),fontsize=13)
fig.tight_layout(rect=[0,0,1,.95])
for ext in ('png','svg','pdf'):fig.savefig(a.output/('workload.'+ext),dpi=180)
plt.close(fig)
print('REPLAY_MIXED_FIGURES_OK')
