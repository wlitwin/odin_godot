from pathlib import Path
import argparse,json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
s=json.loads((a.run/'summary.json').read_text());colors={'original':'#aa5941','owner_preserved':'#287c88'}
fig,axes=plt.subplots(1,2,figsize=(11,4.8))
for i,variant in enumerate(colors):
 rows=[r for r in s['runs'] if r['variant']==variant and r['role']=='client']
 x=[pair+(i-.5)*.3 for pair in range(1,4)]
 bars=axes[0].bar(x,[r['packet_rewinds'] for r in rows],.28,label='Original Kit' if i==0 else 'Isolated owner-preserving control',color=colors[variant]);axes[0].bar_label(bars,padding=3)
 axes[1].plot([1,2,3],[r['observed_travel'][1] for r in rows],marker='o',color=colors[variant],label=variant)
axes[0].set_title('Client packet-processing backward moves');axes[0].set_ylabel('Events inside constant-direction segments');axes[0].margins(y=.2);axes[0].legend(frameon=False,fontsize=8)
axes[1].set_title('Second player · client-observed path');axes[1].set_ylabel('Observed pixels in twenty seconds');axes[1].set_ylim(bottom=0)
for ax in axes:ax.set_xticks([1,2,3]);ax.set_xlabel('Alternating pair');ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
fig.suptitle('Owner-stream state lost during pending command unwind',fontsize=14)
fig.text(.5,.015,'Same game/adapters/content; one isolated Kit unwind change. Original sources remain untouched.\nPath observations are not a CPU comparison or proof of identical gameplay.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.08,1,.94])
for ext in ('png','svg','pdf'):fig.savefig(a.output/('owner-control.'+ext),dpi=180)
plt.close(fig);print('REPLAY_MOVEMENT_AUDIT_FIGURES_OK')
