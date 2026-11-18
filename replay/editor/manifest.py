"""The project-owned authoring vocabulary; actions are its capabilities."""
from pathlib import Path
import json
import math
import re

MANIFEST = 'replay_authoring.json'
IDENTIFIER = re.compile(r'[A-Za-z][A-Za-z0-9_-]{0,63}\Z')


class ContractError(ValueError):
    def __init__(self, path, message, source='res://' + MANIFEST):
        super().__init__(message)
        self.issues = [{'source': source, 'path': path, 'message': message}]


def require(condition, path, message):
    if not condition:
        raise ContractError(path, message)


def project_file(project, value, field, *, suffixes=()):
    require(isinstance(value, str) and value.startswith('res://'), field, 'Use a res:// project path.')
    relative = value[6:].split('::', 1)[0]
    require(relative and '..' not in Path(relative).parts and not Path(relative).is_absolute(), field, 'Use a path inside the project.')
    path = Path(project) / relative
    require(path.is_file(), field, f'Project file does not exist: {value}')
    require(not suffixes or path.suffix in suffixes, field, f'Expected one of: {", ".join(suffixes)}')
    return path


def object_fields(value, allowed, path):
    require(isinstance(value, dict), path, 'Expected an object.')
    unknown = value.keys() - allowed
    require(not unknown, path, 'Unknown fields: ' + ', '.join(sorted(unknown)))


def identifier(value, field):
    require(isinstance(value, str) and IDENTIFIER.fullmatch(value), field, 'Use a short identifier with letters, numbers, hyphens or underscores.')


def load_manifest(project):
    try:
        value = json.loads((Path(project) / MANIFEST).read_text())
    except (OSError, ValueError) as error:
        raise ContractError('$', f'Cannot read {MANIFEST}: {error}') from error
    object_fields(value, {'version', 'title', 'worker', 'inputs', 'actions', 'status_action'}, '$')
    require(type(value.get('version')) is int and value['version'] == 1, 'version', 'Use authoring manifest version 1.')
    result = {'version': 1, 'title': value.get('title', 'Replay'), 'inputs': [], 'actions': []}
    require(isinstance(result['title'], str) and result['title'].strip(), 'title', 'Provide a nonempty title.')
    inputs = value.get('inputs', [])
    require(isinstance(inputs, list), 'inputs', 'Expected an array of input declarations.')
    input_ids = set()
    for index, raw in enumerate(inputs):
        path = f'inputs[{index}]'
        object_fields(raw, {'id', 'label', 'kind', 'default', 'required', 'choices', 'filters'}, path)
        item = dict(raw)
        identifier(item.get('id'), path + '.id')
        require(item['id'] not in input_ids, path + '.id', 'Input IDs must be unique.')
        input_ids.add(item['id'])
        require(isinstance(item.get('label'), str) and item['label'].strip(), path + '.label', 'Provide an input label.')
        require(item.get('kind') in ('resource', 'file', 'text', 'choice'), path + '.kind', 'Input kind must be resource, file, text or choice.')
        item.setdefault('required', item['kind'] in ('resource', 'file'))
        require(type(item['required']) is bool, path + '.required', 'Expected true or false.')
        if item['kind'] == 'choice':
            choices = item.get('choices')
            require(isinstance(choices, list) and bool(choices), path + '.choices', 'Declare at least one choice.')
            values = []
            for choice in choices:
                object_fields(choice, {'label', 'value'}, path + '.choices')
                require(isinstance(choice.get('label'), str) and choice['label'].strip(), path + '.choices', 'Every choice needs a label.')
                require(type(choice.get('value')) in (str, int), path + '.choices', 'Choice values must be strings or integers.')
                require(choice['value'] not in values, path + '.choices', 'Choice values must be unique.')
                values.append(choice['value'])
            item.setdefault('default', values[0])
            require(any(type(item['default']) is type(v) and item['default'] == v for v in values), path + '.default', 'Default must be a declared choice value.')
        else:
            require('choices' not in item, path + '.choices', 'Only choice inputs declare choices.')
            item.setdefault('default', '')
            require(isinstance(item['default'], str), path + '.default', 'Expected text.')
        filters = item.get('filters', [])
        require(isinstance(filters, list) and all(isinstance(f, str) for f in filters), path + '.filters', 'Expected an array of file filters.')
        require(not filters or item['kind'] in ('resource', 'file'), path + '.filters', 'Only resource/file inputs use filters.')
        result['inputs'].append(item)
    actions = value.get('actions')
    require(isinstance(actions, list) and bool(actions), 'actions', 'Declare at least one authoring action.')
    action_ids = set()
    for index, raw in enumerate(actions):
        path = f'actions[{index}]'
        object_fields(raw, {'id', 'label', 'kind', 'inputs', 'scene', 'save', 'timeout'}, path)
        action = dict(raw)
        identifier(action.get('id'), path + '.id')
        require(action['id'] not in action_ids, path + '.id', 'Action IDs must be unique.')
        action_ids.add(action['id'])
        require(isinstance(action.get('label'), str) and action['label'].strip(), path + '.label', 'Provide an action label.')
        require(action.get('kind') in ('open_scene', 'run_scene', 'worker'), path + '.kind', 'Action kind must be open_scene, run_scene or worker.')
        action.setdefault('inputs', [])
        require(isinstance(action['inputs'], list) and all(isinstance(i, str) for i in action['inputs']), path + '.inputs', 'Expected input IDs.')
        require(len(set(action['inputs'])) == len(action['inputs']) and set(action['inputs']) <= input_ids, path + '.inputs', 'Reference each declared input at most once.')
        action.setdefault('save', action['kind'] != 'open_scene')
        require(type(action['save']) is bool, path + '.save', 'Expected true or false.')
        if action['kind'] in ('open_scene', 'run_scene'):
            project_file(project, action.get('scene'), path + '.scene', suffixes=('.tscn', '.scn'))
        else:
            require('scene' not in action, path + '.scene', 'Worker actions select their own scenes.')
        if action['kind'] == 'run_scene':
            action.setdefault('timeout', 60)
            require(type(action['timeout']) in (int, float) and math.isfinite(action['timeout']) and 1 <= action['timeout'] <= 3600, path + '.timeout', 'Scene timeout must be 1–3600 seconds.')
        else:
            require('timeout' not in action, path + '.timeout', 'Only run_scene actions declare a scene timeout.')
        result['actions'].append(action)
    if any(a['kind'] == 'worker' for a in result['actions']):
        project_file(project, value.get('worker'), 'worker', suffixes=('.py',))
        result['worker'] = value['worker']
    elif 'worker' in value:
        raise ContractError('worker', 'Remove the worker path when no action uses it.')
    if 'status_action' in value:
        status = next((a for a in result['actions'] if a['id'] == value['status_action']), None)
        require(status is not None and status['kind'] == 'worker' and not status['save'], 'status_action', 'Status must name a worker action with save:false.')
        result['status_action'] = value['status_action']
    return result


def normalize_request(project, manifest, raw):
    object_fields(raw, {'action', 'inputs'}, '$request')
    action = next((a for a in manifest['actions'] if a['id'] == raw.get('action')), None)
    require(action is not None, '$request.action', 'Choose a declared action.')
    supplied = raw.get('inputs', {})
    require(isinstance(supplied, dict) and supplied.keys() <= set(action['inputs']), '$request.inputs', 'Supply only inputs used by this action.')
    definitions = {i['id']: i for i in manifest['inputs']}
    values = {}
    for key in action['inputs']:
        item = definitions[key]
        value = supplied.get(key, item['default'])
        path = '$request.inputs.' + key
        if item['kind'] == 'choice':
            require(any(type(value) is type(c['value']) and value == c['value'] for c in item['choices']), path, 'Choose a declared value.')
        else:
            require(isinstance(value, str), path, 'Expected text.')
            require(not item['required'] or bool(value.strip()), path, 'This input is required.')
            if value and item['kind'] == 'resource':
                project_file(project, value, path)
            elif value and item['kind'] == 'file':
                if value.startswith('res://'):
                    file = project_file(project, value, path)
                else:
                    file = Path(value).expanduser()
                    if not file.is_absolute():
                        file = Path(project) / file
                    require(file.is_file(), path, f'File does not exist: {value}')
                value = str(file.resolve())
        values[key] = value
    return action, {'action': action['id'], 'inputs': values}
