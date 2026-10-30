"""Non-overwriting, single-directory draft publication. No wire IDs from file order."""
from pathlib import Path
import json,re,tempfile,fcntl


def create(project,kind,name,selection,definitions,job,env,godot):
    parent=project/'scripts/drafts';parent.mkdir(parents=True,exist_ok=True)
    with (parent/'.allocation.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        return _create(project,kind,name,selection,definitions,job,env,godot)


def _create(project,kind,name,selection,definitions,job,env,godot):
    if len(name)>40 or not re.fullmatch(r'[a-z][a-z0-9]*(?:_[a-z0-9]+)*',name):raise ValueError('Use a lower-case name with letters, digits and underscores (maximum 40 characters).')
    category='abilities' if kind=='ability' else 'mobs'
    if kind=='actor' and not any(d['source']==selection and d['category']=='mobs' for d in definitions):selection='res://data/mobs/scrapbot.tres'
    source=next((d for d in definitions if d['source']==selection and d['category']==category),None)
    if source is None:raise ValueError('Choose an existing definition of the draft kind as its starting point.')
    parent=project/'scripts/drafts';parent.mkdir(parents=True,exist_ok=True)
    destination=parent/name
    if destination.exists():raise ValueError('That draft already exists; no files were overwritten.')
    used={int(d['id']) for d in definitions if d['category']==category}
    for path in parent.glob('*/draft.json'):
        prior=json.loads(path.read_text())
        if prior['kind']==kind:used.add(int(prior['stable_id']))
    available=[i for i in range(1 if kind=='ability' else 0,16 if kind=='ability' else 8) if i not in used]
    if not available:raise ValueError('No free stable ID within the current catalog capacity. Review schema/capacity before expanding it.')
    stable_id=available[0];uri='res://scripts/drafts/'+name
    # Stage outside scripts so import/build watchers never see half-written Odin.
    staging=project/'.godot/replay_authoring/staging';staging.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=name+'-',dir=staging) as directory:
        stage=Path(directory)
        job.run([godot,'--headless','--path',project,'--script','dev/scaffold_definition.gd'],env=env|{'RSY_DRAFT_SOURCE':selection,'RSY_DRAFT_ID':str(stable_id),'RSY_DRAFT_NAME':name,'RSY_DRAFT_OUTPUT':str(stage/'definition.tres')},timeout=30,label='draft-definition')
        metadata={'kind':kind,'name':name,'stable_id':stable_id,'source':selection,'status':'draft','requires_review':True,'definition':uri+'/definition.tres'}
        (stage/'draft.json').write_text(json.dumps(metadata,indent=2)+'\n')
        if kind=='ability':
            (stage/'preview.tscn').write_text(f'''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://dev/ability_preview.tscn" id="preview"]
[ext_resource type="Resource" path="{uri}/definition.tres" id="definition"]
[node name="{name}" instance=ExtResource("preview")]
definition = ExtResource("definition")
''')
            (stage/'workbench.tscn').write_text(f'''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://dev/ability_workbench.tscn" id="workbench"]
[ext_resource type="Resource" path="{uri}/definition.tres" id="definition"]
[node name="{name}" instance=ExtResource("workbench")]
ability = ExtResource("definition")
''')
        else:
            actor(stage,name,uri,stable_id)
        (stage/'scenario.py').write_text(f'''"""Run this draft through the common authoring worker after building the project.
Actor drafts inherit baseline behavior; write feature assertions before adoption.
"""
from pathlib import Path
import argparse,subprocess,sys
parser=argparse.ArgumentParser();parser.add_argument('--framework',required=True);parser.add_argument('--godot',required=True);parser.add_argument('--result',required=True)
args=parser.parse_args();project=Path(__file__).resolve().parents[3]
action={'"correction"' if kind=='ability' else '"validate"'}
subprocess.run([sys.executable,str(project/'tools/authoring.py'),'--project',str(project),'--framework',args.framework,'--godot',args.godot,'--result',args.result,action,'--selection','{uri}/definition.tres'],check=True)
''')
        (stage/'README.md').write_text(f'''# {name}: {kind} draft (stable ID {stable_id})

Open preview.tscn with F6. This directory is a draft, outside the live catalog.
Ability drafts have a workbench scene for explicit isolated admission and tests.
The actor scene keeps ScrapEnemyView at its root and composes its generated visual
script as a child, so it retains the existing typed enemy binding contract.

- TODO: choose and validate gameplay tuning in definition.tres. Existing behavior
  comes from the selected source; new rules/state belong in shared/game.
- TODO: add feature-specific assertions to scenario.py before adoption.
- TODO: review save/network content policy for changed rules or schema.
- For adoption, move the definition to data/{category}/ and update its references.
  Actor registrations belong in archetypes/enemies and must reference that adopted
  definition. Validate and bake; never renumber established IDs by sorting files.
- Cosmetic behavior belongs in the scene/view component. Do not mutate World.

No permissions, prediction policy or migration defaults were generated.
''')
        # Same-filesystem directory rename publishes all outputs together.
        if destination.exists():raise ValueError('Draft destination appeared during generation; refusing overwrite.')
        stage.rename(destination)
    return uri


def actor(stage,name,uri,stable_id):
    cls=''.join(piece.capitalize() for piece in name.split('_'))+'Visual'
    (stage/'view.odin').write_text(f'''//gd:extends Node2D
package draft_{name}
import gd "godot:godot"
import rt "godot:runtime"
import views "../../views"
import display "../../../shared/presentation"

// A composed visual child. The inherited root keeps the game's binding contract.
{cls} :: struct {{owner:gd.Node2d,value:display.Mob_View}}
{name}_visual_process :: proc(self:^{cls},dt:f64) {{
    parent:=rt.script_of(gd.node_get_parent(self.owner),views.ScrapEnemyView)
    if parent==nil || !parent.ready || parent.retired {{return}}
    self.value=parent.value
    // TODO: render this feature from copied display values; never borrow World.
}}
''')
    (stage/'scene.tscn').write_text(f'''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://entities/mob.tscn" id="base"]
[ext_resource type="Script" path="{uri}/view.odin" id="view"]
[node name="{name}" instance=ExtResource("base")]
[node name="FeatureVisual" type="Node2D" parent="."]
script = ExtResource("view")
''')
    (stage/'registration.tres').write_text(f'''[gd_resource type="Resource" script_class="ScrapEnemyArchetype" format=3]
[ext_resource type="Script" path="res://scripts/views/enemy_archetype.odin" id="script"]
[ext_resource type="Resource" path="{uri}/definition.tres" id="definition"]
[ext_resource type="PackedScene" path="{uri}/scene.tscn" id="scene"]
[ext_resource type="Resource" path="res://visuals/enemies/scrapbot.tres" id="appearance"]
[resource]
script = ExtResource("script")
definition = ExtResource("definition")
scene = ExtResource("scene")
appearance = ExtResource("appearance")
''')
    (stage/'preview_state.tres').write_text(f'''[gd_resource type="Resource" script_class="ScrapEnemyPreview" format=3]
[ext_resource type="Script" path="res://scripts/views/enemy_preview.odin" id="script"]
[ext_resource type="Resource" path="{uri}/definition.tres" id="definition"]
[resource]
script = ExtResource("script")
definition = ExtResource("definition")
attacking = true
warning = false
fraction = 0.7
warning_radius = 180.0
''')
    (stage/'preview.tscn').write_text(f'''[gd_scene format=3]
[ext_resource type="PackedScene" path="{uri}/scene.tscn" id="scene"]
[ext_resource type="Resource" path="{uri}/preview_state.tres" id="sample"]
[node name="{name}Preview" instance=ExtResource("scene")]
position = Vector2(640, 360)
preview = true
preview_state = ExtResource("sample")
''')
