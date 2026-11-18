"""Scrapyard policy behind the framework authoring runner."""
import json
import sys
import stock


def run(ctx, action, inputs):
    project, framework, job, env = ctx.project, ctx.framework, ctx.job, ctx.env
    stock.ROOT = project
    env.update({'RSY_ROLE': '', 'RSY_PERSIST': '0', 'RSY_RESUME': '0',
                'RSY_ROOM_SERVICE': '', 'RSY_COORD_PORT': '0', 'RSY_COORD_URL': ''})

    def stale():
        try:
            return json.loads((project / stock.RECEIPT).read_text()) != stock.describe(
                (project / stock.ARTIFACT).read_bytes(), stock.sources(project))
        except (OSError, ValueError):
            return True

    if action == 'status':
        outdated = stale()
        return {'ok': True, 'stale': outdated, 'message': 'Content is stale' if outdated else 'Content is current', 'issues': []}
    ctx.build()
    if action in ('validate', 'bake', 'scaffold'):
        source_snapshot = stock.sources(project)
        validation = ctx.run_scene('res://dev/validate_content.tscn', timeout=45)
        if stock.sources(project) != source_snapshot:
            raise RuntimeError('Authoring sources changed during validation; rerun the action.')
        if not validation['ok']:
            return {**validation, 'stale': stale(), 'message': 'Validation failed; content was not published.'}
        selection = inputs.get('definition', '')
        if action == 'validate' and selection.startswith('res://scripts/drafts/'):
            draft = (project / selection[6:]).resolve()
            if not draft.is_relative_to(project / 'scripts/drafts') or draft.name != 'definition.tres':
                raise ValueError('Select a draft definition.')
            preview = 'res://' + (draft.parent / 'preview.tscn').relative_to(project).as_posix()
            job.run([ctx.godot, '--headless', '--path', project, '--script', 'dev/validate_draft.gd'],
                    env={**env, 'RSY_DRAFT_PREVIEW': preview}, timeout=30, label='draft-validation')
        if action == 'validate':
            return {**validation, 'stale': stale(), 'message': 'Definitions and scene bindings are valid.'}
        if action == 'bake':
            job.progress('Baking the canonical catalog…')
            job.run([sys.executable, project / 'tools/stock.py', '--project', project],
                    env=env, timeout=75, label='bake')
            return {'ok': True, 'stale': stale(), 'message': 'Canonical content baked successfully.', 'issues': []}
        from authoring_scaffold import create
        created = create(project, inputs['draft_kind'], inputs['name'], selection,
                         validation['definitions'], job, env, ctx.godot)
        ctx.build(label='draft-build')
        job.run([ctx.godot, '--headless', '--path', project, '--script', 'dev/validate_draft.gd'],
                env={**env, 'RSY_DRAFT_PREVIEW': created + '/preview.tscn'}, timeout=30, label='draft-preview')
        return {'ok': True, 'stale': stale(), 'message': 'Draft created. Review gameplay and validation TODOs before adoption.',
                'issues': [], 'created': created, 'details': 'Created ' + created,
                'outputs': [{'label': 'Open draft preview', 'path': created + '/preview.tscn'}],
                'navigate_to': created + '/preview.tscn'}
    from authoring_scenarios import run as scenario
    result = scenario(ctx, action, inputs)
    if result.get('kind') == 'correction':
        result['details'] = 'Casts {} → {}; health {} → {}'.format(
            result['before_casts'], result['after_casts'], result['before_hp'], result['after_hp'])
    elif result.get('kind') == 'takeover':
        result['details'] = 'Checkpoint {} → tick {}; casts {}'.format(
            result['checkpoint_tick'], result['final_tick'], result['after_casts'])
    return {**result, 'stale': stale()}
