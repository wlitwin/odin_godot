"""Render standalone comparison figures; requires matplotlib."""
from pathlib import Path
import argparse,bisect,json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
s=json.loads((a.run/'summary.json').read_text());assert s['contract']['scenario']=='combat_encounter'
colors={'kit':'#286b98','replay':'#d67d26'}
fig,axes=plt.subplots(1,3,figsize=(13.5,4.8))
for ax,metric,title,scale,ylabel in zip(axes,['frame_p50_us','active_observed_frame_p50_us','application_tx_bps'],['Whole callback','Observed active combat','Application output'],[1,1,1024],['p50 elapsed time (µs)','p50 elapsed time (µs)','KiB / second']):
 for j,impl in enumerate(['kit','replay']):
  rows=[s['aggregates'][impl+'/'+role] for role in ['host','client']]
  values=[(r['combat'][metric] if metric.startswith('active_') else r[metric]) for r in rows]
  mid=np.array([v['median']/scale for v in values]);low=mid-np.array([v['min']/scale for v in values]);high=np.array([v['max']/scale for v in values])-mid
  x=np.arange(2)+(j-.5)*.36
  bars=ax.bar(x,mid,.34,label='Kit' if impl=='kit' else 'Replay',color=colors[impl],yerr=[low,high],capsize=4)
  ax.bar_label(bars,labels=[f'{v:.0f}' if scale==1 else f'{v:.1f}' for v in mid],padding=7,fontsize=9)
 ax.set_xticks([0,1],['Host','Client']);ax.set_title(title);ax.set_ylabel(ylabel);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True);ax.margins(y=.24)
axes[0].legend(frameon=False)
fig.suptitle('Scrapyard four-enemy encounter · three alternating pairs',fontsize=15)
fig.text(.5,.025,'Bars: median of per-run values; whiskers: range. 60 Hz / 60 FPS, 120 ms receive delay per process.\nWhole-game callbacks include different presentation and authority work; these are not framework-only CPU ratios.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.12,1,.94])
for ext in ['png','svg','pdf']:fig.savefig(a.output/('costs.'+ext),dpi=180)
plt.close(fig)
grid=np.linspace(0,8,481)
fig,axes=plt.subplots(2,2,figsize=(11,7),sharex=True)
for impl in ['kit','replay']:
 traces=[json.loads(p.read_text())['workload']['observations'] for p in sorted(a.run.glob('pair-*/'+impl+'/host.json'))]
 for ax,key,label,top in zip(axes.flat,['living','hp','kills','scrap'],['Living enemies','Team health','Team kills','Collected scrap'],[4,20,4,12]):
  curves=[]
  for trace in traces:
   times=[r['us']/1e6 for r in trace];vals=[sum(r['combat'][key]) if isinstance(r['combat'][key],list) else r['combat'][key] for r in trace]
   curves.append([vals[max(0,bisect.bisect_right(times,t)-1)] for t in grid])
  v=np.array(curves);ax.fill_between(grid,v.min(axis=0),v.max(axis=0),color=colors[impl],alpha=.15,step='post')
  ax.step(grid,np.median(v,axis=0),where='post',color=colors[impl],label='Kit' if impl=='kit' else 'Replay')
  ax.set_ylim(-.1,top+.5);ax.set_ylabel(label);ax.grid(alpha=.2)
for ax in axes[-1]:ax.set_xlabel('Seconds since local measurement start')
axes[0,0].legend(frameon=False)
fig.suptitle('Authoritative host observations · median and range across pairs',fontsize=14)
fig.text(.5,.02,'Sampled traces, without aligning away spawn/response differences. Matching final totals do not prove identical gameplay.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.045,1,.95])
for ext in ['png','svg','pdf']:fig.savefig(a.output/('encounter.'+ext),dpi=180)
plt.close(fig)
print('REPLAY_COMPARISON_FIGURES_OK')
