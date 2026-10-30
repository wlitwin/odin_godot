"""Plot scan ratios from a validated report; requires matplotlib."""
from pathlib import Path
import json,sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
root,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
s=json.loads((root/'summary.json').read_text())['cases']
cases=['zero','canonical_world','equal_random','dense_random','alternating_changes','periodic_changes']
fig,ax=plt.subplots(figsize=(10,5))
for j,(kind,label,color) in enumerate([('SCAN_HASH','Hash','#286b98'),('SCAN_DELTA','Delta','#d67d26')]):
 values=[s[kind+'/'+c]['ratio_reference_over_current'] for c in cases]
 bars=ax.barh(np.arange(len(cases))+(j-.5)*.35,values,.33,label=label,color=color)
 ax.bar_label(bars,labels=[f'{v:.2f}×' for v in values],padding=4,fontsize=9)
ax.axvline(1,color='black',lw=1,ls='--');ax.set_yticks(np.arange(len(cases)),['Zero bytes','Canonical world','Equal random','Dense random changes','Alternating changes','Every eighth byte changes']);ax.invert_yaxis()
ax.set_xlabel('Reference time / current time (higher is faster)');ax.set_xlim(0,12);ax.grid(axis='x',alpha=.2);ax.set_axisbelow(True);ax.legend(frameon=False)
fig.suptitle('Canonical scan microbenchmark · seven alternating trials',fontsize=14)
fig.text(.5,.015,'Ratios use median per-call time. Delta varies one counter byte per iteration.\nThe fragmented-input tradeoff is retained; this is not a full-game speedup claim.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.09,1,.95])
for ext in ['png','svg','pdf']:fig.savefig(out/('scans.'+ext),dpi=180)
