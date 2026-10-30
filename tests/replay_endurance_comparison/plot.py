"""Export descriptive workload/cost figures from a verified full cohort."""
from pathlib import Path
import argparse,json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('output',type=Path);p.add_argument('--condition',choices=['delay','lossy']);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
s=json.loads((a.run/(('summary-'+a.condition+'.json') if a.condition else 'summary.json')).read_text());conditions=[a.condition] if a.condition else ['delay','lossy']
assert s['contract']['scenario']=='moving_injury_dash_reload_swarm'
assert s['full_plan'] or a.condition and s['acceptance_scope']==a.condition and json.loads((a.run/'assessment.json').read_text())['conditions'][a.condition]['accepted']
colors={'kit':'#286b98','replay':'#d67d26'}
fig,axes=plt.subplots(len(conditions),3,figsize=(13,4.7*len(conditions)),squeeze=False)
for row,condition in enumerate(conditions):
 for ax,metric,title,scale,unit in zip(axes[row],['p50_us','p95_us','application_bytes_per_second'],['Callback p50','Callback p95','Application output'],[1,1,1024],['Elapsed µs','Elapsed µs','KiB/s']):
  for j,impl in enumerate(('kit','replay')):
   values=[s['aggregates'][condition+'/'+impl+'/'+role][metric] for role in ('host','client')]
   y=[v['median']/scale for v in values];lo=[(v['median']-v['min'])/scale for v in values];hi=[(v['max']-v['median'])/scale for v in values]
   bars=ax.bar([i+(j-.5)*.36 for i in range(2)],y,.34,color=colors[impl],label='Kit owner control' if impl=='kit' else 'Replay',yerr=[lo,hi],capsize=4)
   ax.bar_label(bars,labels=[f'{v:.0f}' if scale==1 else f'{v:.1f}' for v in y],padding=6,fontsize=8)
  ax.set_xticks([0,1],['Host','Client']);ax.set_title(condition+' · '+title);ax.set_ylabel(unit);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True);ax.margins(y=.3)
axes[0,0].legend(frameon=False,fontsize=8)
fig.suptitle('Scrapyard · moving swarm, injury/regen, dash and reload',fontsize=14)
matrix_note='Full matrix rejected' if a.condition and not json.loads((a.run/'assessment.json').read_text())['full_matrix_accepted'] else 'Full matrix accepted'
fig.text(.5,.025,matrix_note+' · accepted condition shown · three alternating pairs · 20 seconds · 60 Hz / 60 FPS\nBars: median of per-run metrics; whiskers: range. Inclusive callback elapsed time and application bytes, not framework-only costs.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.09,1,.96])
for ext in ('png','svg','pdf'):fig.savefig(a.output/('costs.'+ext),dpi=180)
plt.close(fig)
for condition in conditions:
 fig,axes=plt.subplots(3,2,figsize=(12,9))
 for impl in ('kit','replay'):
  for pair in (1,2,3):
   trace=json.loads((a.run/condition/f'pair-{pair}'/impl/'success-host.json').read_text())['trace'];t=[v['us']/1e6 for v in trace];label=('Kit owner control' if impl=='kit' else 'Replay') if pair==1 else None
   data=[[v['living'] for v in trace],[v['people'][1]['hp'] for v in trace],[sum(p['burn'] for p in v['people']) for v in trace],[sum(p['surge'] for p in v['people']) for v in trace],[v['people'][1]['dashes'] for v in trace],[sum(p['mode']==1 for p in v['people']) for v in trace]]
   for ax,values in zip(axes.flat,data):ax.plot(t,values,color=colors[impl],alpha=.5,linewidth=1,label=label)
 for ax,title in zip(axes.flat,['Living enemies','Player 2 health','Burning players','Players wearing surge','Player 2 dash count','Reloading players']):ax.set_title(title);ax.set_xlabel('Local window seconds');ax.grid(alpha=.2)
 axes[0,0].legend(frameon=False);axes[0,1].set_ylim(0,11);axes[1,0].set_yticks([0,1,2]);axes[1,1].set_yticks([0,1,2]);axes[2,1].set_yticks([0,1,2])
 fig.suptitle(condition+' · authoritative traces · all runs without timing alignment',fontsize=13);fig.tight_layout(rect=[0,0,1,.96])
 for ext in ('png','svg','pdf'):fig.savefig(a.output/(condition+'-workload.'+ext),dpi=180)
 plt.close(fig)
print('REPLAY_ENDURANCE_FIGURES_OK')
