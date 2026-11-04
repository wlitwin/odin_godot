#!/usr/bin/env python3
"""Derive the bidirectional scalar field list from the audited dump-v3 visitor.
This emits explicit scalar calls, never raw native POD bytes. Manual ownership,
union, collection and semantic-reference rules live in recovery_codec.c.
"""
from pathlib import Path
import re,hashlib,sys
root=Path(__file__).resolve().parents[2];source=(root/'box3d/native/state_dump.c').read_text()
a=source.index('/* BEGIN GENERATED FIELD EMITTERS');b=source.index('/* END GENERATED FIELD EMITTERS */',a);body=source[a:b]
funcs={}
for m in re.finditer(r'static void (n_\w+)\(Dump\* d, const (\w+)\* v\) \{',body):
 i=m.end();depth=1
 while depth:
  if body[i]=='{':depth+=1
  if body[i]=='}':depth-=1
  i+=1
 funcs[m[1]]=body[m.start():i]
roots=['n_b3Body','n_b3BodySim','n_b3BodyState','n_b3Joint','n_b3JointSim_base','n_b3RevoluteJoint','n_b3DistanceJoint','n_b3MotorJoint','n_b3PrismaticJoint','n_b3SphericalJoint','n_b3WeldJoint','n_b3WheelJoint','n_b3Shape_base','n_b3Contact_base','n_b3Visitor','n_b3IslandSim','n_b3ContactSpec','n_b3SetItem','n_b3SurfaceMaterial','n_b3SATCache','n_b3Capacity','n_b3ContactLink','n_b3JointLink','n_b3ManifoldPoint']
seen=set();order=[]
def visit(n):
 if n in seen:return
 seen.add(n)
 for child in re.findall(r'\b(n_\w+)\(d,',funcs[n]):visit(child)
 order.append(n)
for n in roots:visit(n)
out='/* BEGIN CODEC SCALAR FIELDS */\n'
for n in order:
 f=funcs[n]
 if n in ['n_b3Body','n_b3Joint','n_b3Shape_base','n_b3Contact_base']:
  f=re.sub(r'    VAL\(d, v->(?:id|jointId|contactId|generation)\);\n','',f)
 if n=='n_b3Contact_base':
  # These are derived from the validated body/set graph, not untrusted wire indices.
  f=re.sub(r'    VAL\(d, v->encodedBodySim[AB]\);\n','',f)
 f=f.replace('Dump* d, const ','Codec* d, ').replace('VAL(d,','F(d,').replace('n_b3','f_b3')
 if n=='n_b3BodySim':f=f.replace('F(d, v->minExtent);','scalar(d,&v->minExtent,4,3);')
 if n=='n_b3SATCache':f=f.replace('F(d, v->separation);','scalar(d,&v->separation,4,3);')
 if n=='n_b3JointSim_base':
  f=f.replace('F(d, v->forceThreshold);','scalar(d,&v->forceThreshold,4,4);').replace('F(d, v->torqueThreshold);','scalar(d,&v->torqueThreshold,4,4);')
 if n=='n_b3DistanceJoint':
  for field in ['lowerSpringForce','upperSpringForce']:
   f=f.replace('F(d, v->'+field+');','scalar(d,&v->'+field+',4,3);')
 if n in ['n_b3DistanceJoint','n_b3MotorJoint','n_b3PrismaticJoint','n_b3SphericalJoint','n_b3WheelJoint']:
  f=re.sub(r'F\(d, v->(max\w*(?:Force|Torque))\);',r'scalar(d,&v->\1,4,4);',f)
 if n=='n_b3RevoluteJoint':
  f=f.replace('F(d, v->maxMotorTorque);','scalar(d,&v->maxMotorTorque,4,d->catalog->identity.recovery_format>=3?4:1);')
 out+=f+'\n'
out+='/* END CODEC SCALAR FIELDS */'
p=root/'box3d/native/recovery_codec.c';text=p.read_text();a=text.index('/* BEGIN CODEC SCALAR FIELDS */');b=text.index('/* END CODEC SCALAR FIELDS */',a)+len('/* END CODEC SCALAR FIELDS */')
sha=hashlib.sha256(out.encode()).hexdigest()
if '--check' in sys.argv:
 assert re.sub(r'\s+','',text[a:b]) == re.sub(r'\s+','',out), 'generated field visitor is stale'
 assert 'scalars'+sha+'/' in text, 'schema field hash is stale'
else:
 p.write_text(text[:a]+out+text[b:])
print('scalar_schema_sha256='+sha)
