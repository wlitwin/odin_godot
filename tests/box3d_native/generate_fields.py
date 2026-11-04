#!/usr/bin/env python3
"""Regenerate scalar emitters using the exact pinned Clang C AST (no raw POD).
Usage: python3 tests/box3d_native/generate_fields.py BOX3D_SOURCE
The generated field list is an auditable coverage map, not runtime reflection.
"""
import json, pathlib, re, subprocess, sys, tempfile
src=pathlib.Path(sys.argv[1]); root=pathlib.Path(__file__).resolve().parents[2]
headers=['body.h','contact.h','joint.h','shape.h','island.h','sensor.h','physics_world.h','solver_set.h','table.h']
with tempfile.TemporaryDirectory() as td:
 p=pathlib.Path(td)/'types.c'; p.write_text(''.join('#include "'+h+'"\n' for h in headers))
 ast=json.loads(subprocess.check_output(['clang','-std=c17','-I'+str(src/'src'),'-I'+str(src/'include'),'-Xclang','-ast-dump=json','-fsyntax-only',str(p)]))
records={}; ids={}; aliases={}
def scan(n):
 if n.get('kind')=='RecordDecl' and n.get('completeDefinition'):
  ids[n['id']]=n
  if n.get('name'): records[n['name']]=n
 if n.get('kind')=='TypedefDecl':
  def ref(x):
   if 'ownedTagDecl' in x: aliases[n['name']]=x['ownedTagDecl']['id']
   for c in x.get('inner',[]): ref(c)
  ref(n)
 for c in n.get('inner',[]): scan(c)
scan(ast)
for k,v in aliases.items():
 if v in ids: records[k]=ids[v]
manual={'b3JointSim','b3ContactCache','b3Shape','b3Contact','b3TreeNode','b3Manifold','b3SimplexCache','b3MeshNode'}
skip={'padding1','padding2','userData','userShape','materials','manifolds','bodySimIndexA','bodySimIndexB','bodyMoveIndex','nameId','padding','hit','drawScale','customColor'}
roots=['b3Body','b3BodySim','b3BodyState','b3Joint','b3JointSim','b3Shape','b3Contact','b3Manifold','b3Visitor','b3IslandSim','b3ContactSpec','b3SetItem','b3TreeNode','b3SurfaceMaterial','b3Sphere','b3Capsule','b3SATCache','b3SimplexCache','b3Capacity','b3HullData','b3HullVertex','b3HullHalfEdge','b3HullFace','b3Plane','b3MeshData','b3MeshNode','b3MeshTriangle','b3HeightFieldData','b3ManifoldPoint','b3ContactLink','b3JointLink']
# Manual union dispatchers call all these types.
roots += ['b3DistanceJoint','b3MotorJoint','b3ParallelJoint','b3RevoluteJoint','b3SphericalJoint','b3PrismaticJoint','b3WeldJoint','b3WheelJoint']
# Shape and contact base fields emitted without anonymous unions. Pointer fields
# and inactive union storage are handled by typed runtime dispatch below.
seen=set(); funcs=[]; manifest={}
def emit_type(typ,expr,lines):
 typ=re.sub(r'^(const |struct )','',typ)
 ar=re.fullmatch(r'(.+)\[(\d+)\]',typ)
 if ar:
  for i in range(int(ar[2])): emit_type(ar[1],expr+f'[{i}]',lines)
 elif typ in records:
  visit(typ); lines.append(f'    n_{typ}(d, &{expr});')
 elif '*' in typ: raise ValueError('Unclassified pointer '+typ+' '+expr)
 else:
  lines.append(f'    VAL(d, {expr});')
def visit(name):
 if name in seen:return
 seen.add(name)
 if name in manual and name not in {'b3JointSim','b3Shape','b3Contact'}:return
 lines=[]; fields=[]
 for f in records[name].get('inner',[]):
  if f.get('kind')!='FieldDecl' or not f.get('name'):continue
  field=f['name']; typ=f['type']['qualType']
  if field in skip or '*' in typ:continue
  if name=='b3Shape' and field=='material':continue
  if name=='b3Contact' and field=='manifoldCount':continue
  fields.append(field)
  emit_type(typ,'v->'+field,lines)
 manifest[name]=fields
 suffix='_base' if name in manual else ''
 funcs.append(f'static void n_{name}{suffix}(Dump* d, const {name}* v) {{\n'+'\n'.join(lines)+'\n}\n')
for n in roots:visit(n)
out='/* BEGIN GENERATED FIELD EMITTERS: generate_fields.py */\n'
for n in sorted(seen):
 if n not in manual:out+=f'static void n_{n}(Dump*, const {n}*);\n'
out+='\n'+''.join(funcs)+'/* END GENERATED FIELD EMITTERS */'
p=root/'box3d/native/state_dump.c'; text=p.read_text(); start=text.index('/* BEGIN GENERATED FIELD EMITTERS'); end=text.index('/* END GENERATED FIELD EMITTERS */')+len('/* END GENERATED FIELD EMITTERS */'); p.write_text(text[:start]+out+text[end:])
(root/'tests/box3d_native/fields.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
