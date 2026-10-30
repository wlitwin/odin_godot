"""Scrapyard's explicit authoring commands, shared by editor UI and CI."""
from pathlib import Path
import argparse,importlib.util,json,os,re,shutil,sys,zlib
import stock


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['project','framework','godot','result']:parser.add_argument('--'+name,required=True)
    parser.add_argument('action',choices=['status','validate','bake','scaffold','correction','takeover','network','verify'])
    parser.add_argument('--selection',default='res://data/abilities/salvefield.tres')
    parser.add_argument('--name',default='');parser.add_argument('--kind',choices=['actor','ability'],default='ability')
    parser.add_argument('--latency',type=int,default=0)
    args=parser.parse_args()
    project=Path(args.project).resolve();framework=Path(args.framework).resolve()
    sys.path.insert(0,str(framework/'replay/editor'))
    from jobs import Job
    job=Job(args.result)
    stock.ROOT=project
    def stale():
        try:return json.loads((project/stock.RECEIPT).read_text())!=stock.describe((project/stock.ARTIFACT).read_bytes(),stock.sources(project))
        except (OSError,ValueError):return True
    def command(argv):
        if shutil.which('odin'):return argv
        nix=shutil.which('nix') or '/nix/var/nix/profiles/default/bin/nix'
        return [nix,'develop',str(framework),'--command',*map(str,argv)]
    ext='dylib' if sys.platform=='darwin' else 'dll' if sys.platform=='win32' else 'so'
    env=os.environ|{'ODIN_GODOT_ROOT':str(framework),'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'GODOT':args.godot,'RSY_ROLE':'','RSY_PERSIST':'0','RSY_RESUME':'0','RSY_ROOM_SERVICE':'','RSY_COORD_PORT':'0','RSY_COORD_URL':''}
    try:
        if args.action=='status':
            outdated=stale();job.publish(ok=True,running=False,stale=outdated,message='Content is stale' if outdated else 'Content is current',issues=[]);return
        job.progress('Building current Odin scripts…')
        job.run(command(['bash',framework/'build/build_scripts.sh',project]),cwd=framework,env=env,timeout=180,label='build')
        if args.action in ['validate','bake','scaffold']:
            job.progress('Validating typed definitions and scene bindings…')
            source_snapshot=stock.sources(project)
            report_path=job.result.parent/'validation.json'
            code,text=job.run([args.godot,'--headless','--path',project,'res://dev/validate_content.tscn'],env=env|{'RSY_AUTHORING_REPORT':str(report_path)},timeout=45,check=False,label='validation')
            validation=json.loads(report_path.read_text()) if report_path.exists() else {'ok':False,'issues':[{'source':'res://dev/validate_content.tscn','path':'$validation','message':text[-6000:]}]}
            if stock.sources(project)!=source_snapshot:raise RuntimeError('Authoring sources changed during validation; rerun the action.')
            if code or not validation['ok']:
                job.publish(ok=False,running=False,stale=stale(),message='Validation failed; content was not published.',issues=validation['issues']);return 1
            if args.action=='validate' and args.selection.startswith('res://scripts/drafts/'):
                draft=(project/args.selection[6:]).resolve()
                if not draft.is_relative_to(project/'scripts/drafts') or draft.name!='definition.tres':raise ValueError('Select a draft definition.')
                preview='res://'+(draft.parent/'preview.tscn').relative_to(project).as_posix()
                job.run([args.godot,'--headless','--path',project,'--script','dev/validate_draft.gd'],env=env|{'RSY_DRAFT_PREVIEW':preview},timeout=30,label='draft-validation')
            if args.action=='validate':
                job.publish(**validation,running=False,stale=stale(),message='Definitions and scene bindings are valid.');return
            if args.action=='bake':
                job.progress('Baking the canonical catalog…')
                job.run([sys.executable,project/'tools/stock.py','--project',project],env=env,timeout=75,label='bake')
                job.publish(ok=True,running=False,stale=stale(),message='Canonical content baked successfully.',issues=[]);return
            from authoring_scaffold import create
            created=create(project,args.kind,args.name,args.selection,validation['definitions'],job,env,args.godot)
            job.progress('Building and validating the new draft…')
            job.run(command(['bash',framework/'build/build_scripts.sh',project]),cwd=framework,env=env,timeout=180,label='draft-build')
            job.run([args.godot,'--headless','--path',project,'--script','dev/validate_draft.gd'],env=env|{'RSY_DRAFT_PREVIEW':created+'/preview.tscn'},timeout=30,label='draft-preview')
            job.publish(ok=True,running=False,stale=stale(),message='Draft created. Review gameplay and validation TODOs before adoption.',issues=[],created=created);return
        from authoring_scenarios import run
        result=run(args,job,project,framework,env,command)
        job.publish(**result,running=False,stale=stale())
    except Exception as error:
        message=str(error);issues=[]
        for path,line in re.findall(r'([^\n]+?\.odin)\((\d+):\d+\) Error:',message):
            p=Path(path.strip())
            if p.is_relative_to(project):issues.append({'source':'res://'+p.relative_to(project).as_posix(),'path':'$compile','line':int(line),'message':'Odin compilation failed; see job log.'})
        if not issues:issues=[{'source':'res://tools/authoring.py','path':'$job','message':message[-10000:]}]
        job.publish(ok=False,running=False,stale=stale(),message=message.splitlines()[0] if message else 'Authoring job failed.',issues=issues)
        return 1

if __name__=='__main__':raise SystemExit(main())
