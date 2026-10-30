"""Require three normal pairs plus a deterministic obstruction pair."""
from pathlib import Path
import json,sys
from report import report
root=Path(sys.argv[1]);results={};obstruction=sys.argv[2] if len(sys.argv)>2 else 'obstructed'
for label in ['normal-1','normal-2','normal-3',obstruction]:
 plan=json.loads((root/(label+'-run-plan.json')).read_text())
 assert plan['finale_mode']=='navigate' and plan['forced_obstruction']==(label==obstruction)
 if label.startswith('normal-'):
  number=int(label[-1]);assert plan['order']==(['replay','kit'] if number==2 else ['kit','replay'])
 result=report(root,label);assert result['pass'],label;results[label]=result
value={'pass':True,'normal_pairs':3,'obstruction_pairs':1,'games':8,'obstruction_label':obstruction,'results':results,'scope':'Same wave controller and ordinary-input cover navigation; obstruction control is separately identified. No difficulty-equivalence or performance claim.'}
(root/'cohort.json').write_text(json.dumps(value,indent=2)+'\n');print('REPLAY_SOLO_COHORT_OK games=8')
