"""Generic authoring requests reject invalid contracts before game work starts."""
from pathlib import Path
from types import SimpleNamespace
import copy
import json
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'replay/editor'))
from manifest import ContractError, load_manifest, normalize_request
from worker import WorkerContext, run


class AuthoringContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='replay-authoring-contract-')
        self.addCleanup(self.directory.cleanup)
        self.project = Path(self.directory.name)
        for name in ['definition.tres', 'preview.tscn']:
            (self.project / name).write_text('fixture')
        (self.project / 'policy.py').write_text('''from pathlib import Path
from dataclasses import dataclass
@dataclass
class Result:
    ok: bool
def run(ctx, action, inputs):
    (ctx.project / "called").write_text(action)
    return {"ok": Result(True).ok, "issues": [], "request": ctx.request}
''')
        self.manifest = {
            'version': 1, 'worker': 'res://policy.py',
            'inputs': [
                {'id': 'item', 'label': 'Definition', 'kind': 'resource', 'default': 'res://definition.tres'},
                {'id': 'pace', 'label': 'Pace', 'kind': 'choice', 'choices': [{'label': 'Normal', 'value': 80}, {'label': 'Slow', 'value': 150}]}],
            'actions': [
                {'id': 'inspect', 'label': 'Inspect definitions', 'kind': 'worker', 'inputs': ['item', 'pace']},
                {'id': 'preview', 'label': 'Open preview', 'kind': 'open_scene', 'scene': 'res://preview.tscn'}]}
        self.save(self.manifest)

    def save(self, value):
        (self.project / 'replay_authoring.json').write_text(json.dumps(value))

    def invoke(self, request=None, describe=False):
        request_path = self.project / 'request.json'
        request_path.write_text(json.dumps(request))
        result_path = self.project / 'job/result.json'
        code = run(SimpleNamespace(project=self.project, framework=ROOT, godot='unused',
                                   result=result_path, describe=describe, request=request_path))
        return code, json.loads(result_path.read_text())

    def test_describe_has_only_declared_actions_and_does_not_import_worker(self):
        code, report = self.invoke(describe=True)
        self.assertEqual(code, 0)
        self.assertEqual([a['id'] for a in report['manifest']['actions']], ['inspect', 'preview'])
        self.assertNotIn('status_action', report['manifest'])
        self.assertFalse((self.project / 'called').exists())

    def test_worker_receives_choice_values_and_declared_defaults(self):
        code, report = self.invoke({'action': 'inspect', 'inputs': {'pace': 150}})
        self.assertEqual(code, 0)
        self.assertEqual(report['request'], {'action': 'inspect', 'inputs': {'item': 'res://definition.tres', 'pace': 150}})
        self.assertEqual((self.project / 'called').read_text(), 'inspect')

    def test_invalid_requests_never_load_project_handler(self):
        for request in [
            {'action': 'undeclared'}, {'action': 'inspect', 'inputs': {'extra': 'oops'}},
            {'action': 'inspect', 'inputs': {'pace': 1}}, {'action': 'inspect', 'inputs': {'pace': True}},
            {'action': 'inspect', 'inputs': {'item': 'res://missing.tres'}}]:
            with self.subTest(request=request):
                code, report = self.invoke(request)
                self.assertEqual(code, 1)
                self.assertFalse(report['ok'])
                self.assertTrue(report['issues'])
                self.assertFalse((self.project / 'called').exists())

    def test_manifest_errors_are_actionable(self):
        variants = []
        duplicate = copy.deepcopy(self.manifest)
        duplicate['actions'].append(duplicate['actions'][0])
        variants.append(duplicate)
        duplicate = copy.deepcopy(self.manifest)
        duplicate['inputs'].append(duplicate['inputs'][0])
        variants.append(duplicate)
        for field, value in [('kind', 'shell'), ('inputs', ['unknown'])]:
            changed = copy.deepcopy(self.manifest)
            changed['actions'][0][field] = value
            variants.append(changed)
        missing = copy.deepcopy(self.manifest)
        missing['actions'][1]['scene'] = 'res://missing.tscn'
        variants.append(missing)
        legacy = {'worker': 'res://policy.py', 'ability': 'res://definition.tres'}
        variants.append(legacy)
        for value in variants:
            with self.subTest(value=value):
                self.save(value)
                with self.assertRaises(ContractError) as error:
                    load_manifest(self.project)
                self.assertEqual(error.exception.issues[0]['source'], 'res://replay_authoring.json')

    def test_scene_requires_a_valid_report_and_successful_process(self):
        class SceneJob:
            def __init__(self, result, report, code=0, text=''):
                self.result, self.report, self.code, self.text = result, report, code, text
            def progress(self, message): pass
            def run(self, argv, **options):
                if self.report is not None:
                    Path(options['env']['REPLAY_AUTHORING_REPORT']).write_text(json.dumps(self.report))
                return self.code, self.text
        result = self.project / 'result.json'
        for report in [None, {}, {'ok': 'yes', 'issues': []}, {'ok': True, 'issues': ['unstructured']}]:
            with self.subTest(report=report):
                ctx = WorkerContext(self.project, ROOT, 'unused', SceneJob(result, report), {'action': 'inspect', 'inputs': {}})
                with self.assertRaises((RuntimeError, ValueError)):
                    ctx.run_scene('res://preview.tscn')
        for code, text in [(1, ''), (0, '\nERROR: scene initialization failed'), (0, 'resources still in use')]:
            ctx = WorkerContext(self.project, ROOT, 'unused', SceneJob(result, {'ok': True, 'issues': []}, code, text), {})
            self.assertFalse(ctx.run_scene('res://preview.tscn')['ok'])
        ctx = WorkerContext(self.project, ROOT, 'unused', SceneJob(result, {'ok': True, 'issues': []}), {})
        self.assertTrue(ctx.run_scene('res://preview.tscn')['ok'])


if __name__ == '__main__':
    unittest.main()
