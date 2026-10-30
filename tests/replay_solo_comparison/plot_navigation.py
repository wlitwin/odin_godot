from pathlib import Path
import argparse,json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('label');p.add_argument('out',type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
fig,axes=plt.subplots(1,2,figsize=(12,5.5))
for ax,impl in zip(axes,['kit','replay']):
 d=json.loads((a.run/impl/a.label/'result.json').read_text());proof=d['blocked_proof'];start=proof['position'];props=d['barrel_receipt']['props'];plan=next(p for p in d['navigation'] if p['phase']=='barrels')
 for x,y,w,h in d['covers']:
  ax.add_patch(Rectangle((x,y),w,h,facecolor='#70634b',edgecolor='#302c23'))
  ax.add_patch(Rectangle((x-20,y-20),w+40,h+40,fill=False,linestyle=':',edgecolor='#999999'))
 for x,y,_ in props:ax.plot([start[0],x],[start[1],y],color='#bf4545',linestyle='--');ax.scatter([x],[y],s=100,color='#de9a28',zorder=4)
 points=[start]+plan['path'];ax.plot([p[0] for p in points],[p[1] for p in points],color='#316da1',label='Planned walking route',linewidth=2)
 trace=[r['position'] for r in d['trace'] if r['ms']>=proof['ms']];ax.plot([p[0] for p in trace],[p[1] for p in trace],color='#338561',label='Observed movement',linewidth=2)
 ax.scatter([start[0]],[start[1]],marker='x',s=75,color='#bf4545',label='Blocked firing position',zorder=5)
 ax.set_xlim(720,1020);ax.set_ylim(700,530);ax.set_aspect('equal');ax.set_title(impl.title()+' · same fixed barrels and cover');ax.set_xlabel('World x');ax.set_ylabel('World y');ax.grid(alpha=.15)
axes[0].legend(loc='lower right',fontsize=8)
fig.suptitle('Stationary shots remain blocked; ordinary movement opens the firing lane')
fig.text(.5,.035,'Dashed red: blocked shot segments · Brown: actual cover · Dotted: planner clearance · Gold: unchanged barrel positions',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.075,1,.94])
for ext in ['png','svg','pdf']:fig.savefig(a.out/('navigation.'+ext),dpi=180)
print('SOLO_NAVIGATION_FIGURE_OK')
