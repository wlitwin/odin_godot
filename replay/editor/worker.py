#!/usr/bin/env python3
"""Run a declared authoring action using the same request contract as the dock."""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import re
import shutil
import sys
import time

from jobs import Job
from manifest import ContractError, load_manifest, normalize_request, project_file


def module_at(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def report_value(value):
    if not isinstance(value, dict) or type(value.get('ok')) is not bool or not isinstance(value.get('issues'), list):
        raise ValueError('Authoring reports require an ok boolean and an issues array.')
    for issue in value['issues']:
        if not isinstance(issue, dict) or not all(isinstance(issue.get(k), str) for k in ('source', 'path', 'message')):
            raise ValueError('Each issue needs source, path and message strings.')
    for key in ('message', 'details', 'navigate_to'):
        if key in value and not isinstance(value[key], str):
            raise ValueError(f'Report {key} must be text.')
    if 'outputs' in value and (not isinstance(value['outputs'], list) or not all(
            isinstance(o, dict) and isinstance(o.get('path'), str) and isinstance(o.get('label'), str) for o in value['outputs'])):
        raise ValueError('Report outputs require label and path strings.')
    return dict(value)


class WorkerContext:
    def __init__(self, project, framework, godot, job, request):
        self.project, self.framework = Path(project).resolve(), Path(framework).resolve()
        self.godot, self.job, self.request = str(godot), job, request
        extension = 'dylib' if sys.platform == 'darwin' else 'dll' if sys.platform == 'win32' else 'so'
        self.env = {**os.environ, 'ODIN_GODOT_ROOT': str(self.framework), 'GODOT': self.godot,
                    'ODIN_SCRIPTS_DLL': str(self.project / f'bin/libodinscripts.{extension}')}
        self._tools = None

    def tools(self):
        if self._tools is None:
            helper = module_at('_authoring_toolchain', self.framework / 'build/toolchain.py')
            target = 'macos' if sys.platform == 'darwin' else 'windows' if sys.platform == 'win32' else 'linux'
            self._tools = helper.resolved(self.project, target, self.env)
            self.env['ODIN'] = self._tools['odin']
            self.env['PATH'] = str(Path(self.env['ODIN']).parent) + os.pathsep + self.env.get('PATH', '')
        return self._tools

    def command(self, argv):
        result = list(map(str, argv))
        if result and result[0] == 'odin':
            result[0] = self.tools()['odin']
        return result

    def build(self, label='build'):
        self.tools()
        self.job.progress('Building current Odin scripts…')
        self.job.run(['bash', self.framework / 'build/build_scripts.sh', self.project], cwd=self.framework,
                     env=self.env, timeout=180, label=label)

    def run_scene(self, scene, *, timeout=60, label='validation'):
        if not self.godot:
            raise ValueError('Set GODOT or pass --godot with the Godot executable.')
        project_file(self.project, scene, '$action.scene', suffixes=('.tscn', '.scn'))
        report_path = self.job.result.parent / (label + '.json')
        report_path.unlink(missing_ok=True)
        request_path = self.job.result.parent / 'scene-request.json'
        request_path.write_text(json.dumps(self.request, indent=2) + '\n')
        self.job.progress('Running ' + scene + '…')
        code, text = self.job.run([self.godot, '--headless', '--path', self.project, scene],
                                 env={**self.env, 'REPLAY_AUTHORING_REPORT': str(report_path),
                                      'REPLAY_AUTHORING_REQUEST': str(request_path)},
                                 timeout=timeout, check=False, label=label)
        if not report_path.is_file():
            raise RuntimeError(f'{scene} stopped without a structured report; see the {label} log.\n{text[-4000:]}')
        report = report_value(json.loads(report_path.read_text()))
        if code or re.search(r'SCRIPT ERROR|\nERROR:|ODIN_SCRIPT_PANIC|leaked at exit|resources still in use', text):
            report['ok'] = False
            report.setdefault('message', 'Validation process failed; see the job log.')
            if not report['issues']:
                report['issues'] = [{'source': scene, 'path': '$process', 'message': text[-4000:]}]
        return report


def run(args):
    job = Job(args.result)
    project, framework = Path(args.project).resolve(), Path(args.framework).resolve()
    try:
        manifest = load_manifest(project)
        if args.describe:
            job.publish(ok=True, running=False, message='Authoring actions loaded.', issues=[], manifest=manifest)
            return 0
        raw = {'action': args.action} if getattr(args, 'action', None) else json.loads(Path(args.request).read_text())
        action, request = normalize_request(project, manifest, raw)
        ctx = WorkerContext(project, framework, args.godot, job, request)
        if action['kind'] == 'run_scene':
            ctx.build()
            report = ctx.run_scene(action['scene'], timeout=action['timeout'])
        elif action['kind'] == 'worker':
            worker_path = project_file(project, manifest['worker'], 'worker', suffixes=('.py',))
            sys.path.insert(0, str(worker_path.parent))
            handler = module_at('_project_authoring', worker_path)
            report = handler.run(ctx, action['id'], request['inputs'])
        else:
            raise ContractError('$request.action', 'Open-scene actions run in the editor.')
        report = report_value(report)
        report['running'] = False
        report.setdefault('message', 'Completed.' if report['ok'] else 'Validation failed.')
        job.publish(**report)
        return 0 if report['ok'] else 1
    except Exception as error:
        issues = getattr(error, 'issues', [])
        message = str(error)
        for name, line in re.findall(r'([^\n]+?\.odin)\((\d+):\d+\) Error:', message):
            path = Path(name.strip())
            if path.is_relative_to(project):
                issues.append({'source': 'res://' + path.relative_to(project).as_posix(), 'path': '$compile',
                               'line': int(line), 'message': 'Odin compilation failed; see the job log.'})
        if not issues:
            issues = [{'source': 'res://replay_authoring.json', 'path': '$job', 'message': message[-10000:]}]
        job.publish(ok=False, running=False, message=message.splitlines()[0] if message else 'Authoring action failed.', issues=issues)
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=str(Path.cwd()))
    parser.add_argument('--framework', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--godot', default=os.environ.get('GODOT') or shutil.which('godot') or '')
    parser.add_argument('--result')
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--describe', action='store_true')
    mode.add_argument('--request')
    mode.add_argument('--action', help='Run a declared action with its default inputs.')
    args = parser.parse_args()
    if not args.result:
        args.result = str(Path(args.project) / '.godot/replay_authoring/jobs' / str(time.time_ns()) / 'result.json')
    code = run(args)
    report = json.loads(Path(args.result).read_text())
    print(report.get('message', 'Completed.') + ' Report: ' + str(Path(args.result).resolve()))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
