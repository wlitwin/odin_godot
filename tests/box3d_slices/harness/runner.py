"""Build normal examples and observe two independent Godot/ENet processes."""
from __future__ import annotations
from pathlib import Path
import os
import queue
import shutil
import socket
import subprocess
import threading
import time

from evidence import EndpointEvidence, EvidenceError, bounded_read, digest, json_bytes, load_frame, preserve_mismatch, require, strict_json, verify_pair, verify_observer_cohort, verify_dedicated_cohort, verify_32_pair_envelope

SUFFIXES = ('.odin', '.c', '.h', '.sh', '.py', '.gd', '.gdextension', '.godot', '.cfg', '.tscn', '.tres', '.gdshader')
BAD_LOG = ('SCRIPT ERROR:', 'ODIN_SCRIPT_PANIC', 'Program crashed', 'ODIN_BOX3D_SHUTDOWN_LIVE',
           'ODIN_BOX3D_SHUTDOWN_NOT_EMPTY', 'ODIN_MANAGED_CALLABLE_SHUTDOWN_NOT_EMPTY', 'ODIN_GODOT_CRASH:', 'ERROR:', 'ObjectDB instances leaked at exit', 'Resources still in use at exit')
PREFIX = 'BOX3D_SLICE_'
MAX_LINE = 1024 * 1024
MAX_LOG = 64 * 1024 * 1024


def sha(path):
    return digest(Path(path).read_bytes())


def inventory(repo, project):
    result = {}
    roots = ('box3d', 'core', 'runtime', 'kit', 'replay', 'build', 'scriptgen', 'gdext', 'godot',
             'examples/box3d_common', 'tests/box3d_slices/harness')
    paths = set()
    for name in roots:
        paths.update((repo / name).rglob('*'))
    paths.add(repo / 'tests/box3d_slices/run.py')
    paths.update(project.rglob('*'))
    for path in sorted(paths):
        if path.is_file() and path.suffix in SUFFIXES and not path.name.endswith('.gen.odin') and not any(part in path.parts for part in ('bin', '.godot', '__pycache__')):
            result[str(path.relative_to(repo))] = sha(path)
    return result


def authored_ready(project):
    if not (project / 'project.godot').is_file():
        return False, 'project.godot not authored'
    if not (project / 'odin_godot.gdextension').is_file():
        return False, 'GDExtension declaration not authored'
    scripts = [p for p in (project / 'scripts').glob('*.odin') if not p.name.endswith('.gen.odin')]
    if not scripts:
        return False, 'example scripts not authored'
    return True, 'authored project present; runtime readiness must be proved by build/launch'


class Process:
    def __init__(self, godot, project, role, env, root, app_role=None):
        self.role, self.root = role, root
        self.app_role=app_role or role
        self.evidence = EndpointEvidence(env['B3_FRAMEWORK'], role, root)
        self.evidence.app_role=self.app_role
        self.evidence.require_go=env.get('B3_END_TICK') is not None
        self.command = [godot, '--headless', '--max-fps', '60', '--path', str(project)]
        self.events = queue.Queue(maxsize=4096)
        self.reader_error = None
        self.bytes = 0
        self.log = root / 'godot.log'
        self.log_stream = self.log.open('wb')
        try:
            self.process = subprocess.Popen(self.command, cwd=project, env=env, stdin=subprocess.DEVNULL,
                                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except Exception:
            self.log_stream.close()
            raise
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()

    def _read(self):
        try:
            while True:
                raw = self.process.stdout.readline(MAX_LINE + 1)
                if not raw:
                    break
                self.bytes += len(raw)
                if len(raw)>MAX_LINE or self.bytes>MAX_LOG:
                    self.reader_error = self.reader_error or 'endpoint log bound exceeded'
                    continue  # Drain without retaining or blocking the endpoint.
                self.log_stream.write(raw)
                self.log_stream.flush()
                try:
                    text = raw.decode('utf-8', errors='strict').rstrip('\r\n')
                    require(not any(marker in text for marker in BAD_LOG), ('endpoint runtime error', self.role, text))
                    if text.startswith('{'):
                        value = strict_json(text)
                        kind = value.get('event')
                        require(isinstance(kind,str), 'plain JSON diagnostic has no event')
                        self.events.put_nowait((kind.upper(),value))
                    elif text.startswith(PREFIX):
                        head, separator, tail = text.partition(' ')
                        kind = head[len(PREFIX):]
                        if kind in ('WAIT','ERROR') and separator and not tail.startswith('{'):
                            self.events.put_nowait((kind,{'message':tail}))
                        else:
                            require(separator and tail.startswith('{'), ('invalid diagnostic line', self.role, text[:200]))
                            self.events.put_nowait((kind, strict_json(tail)))
                except Exception as error:
                    self.reader_error = self.reader_error or repr(error)
                    # Preserve/drain the tail so diagnostics cannot SIGPIPE a
                    # correctly unwinding failed endpoint or hide its true exit.
        except Exception as error:
            self.reader_error = self.reader_error or repr(error)
        finally:
            self.process.stdout.close()

    def consume(self):
        count = 0
        while True:
            try:
                kind, value = self.events.get_nowait()
            except queue.Empty:
                break
            self.evidence.receive(kind, value)
            count += 1
        require(self.reader_error is None, ('endpoint evidence reader failed', self.role, self.reader_error))
        require(not self.evidence.errors, ('endpoint reported failure',self.role,self.evidence.errors[0] if self.evidence.errors else None))
        return count

    def close(self, abort=False):
        if self.process.poll() is None and abort:
            try:
                self.process.wait(timeout=0.75)  # Observe ordinary failed cleanup/exit first.
            except subprocess.TimeoutExpired:
                self.process.terminate()
        try:
            code = self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            code = self.process.wait()
        self.thread.join(3)
        self.log_stream.close()
        return code


class Run:
    def __init__(self, args, repo, framework):
        self.args, self.repo, self.framework = args, repo, framework
        self.out = args.out.resolve() / framework
        self.out.mkdir(parents=True, exist_ok=False)
        self.source = repo / 'examples' / (framework + '_box3d')
        self.project = self.out / 'project'
        self.nodes = []
        self.steps = []
        self.compared = set()
        self.compared_by_actor={}
        self.first_mismatch = None
        self.report = dict(result='INCOMPLETE', framework=framework, scope=f'initial{args.bodies} actual independent Godot/ENet '+args.cohort+' correctness',cohort=args.cohort,initial_dynamic_bodies=args.bodies,
                           required_ticks=args.ticks, steps=self.steps, whole_call_4ms='UNMET/separate GateB requirement')
        self.env = dict(os.environ, ODIN_GODOT_ROOT=str(repo), ROOT=str(repo), ODIN=args.odin,
                        BOX3D_NATIVE_LIBRARY=str(args.native.resolve()))
        for name in ('SKIP_CORE', 'BUILD_MODULES', 'SCRIPT_BUILD_FLAGS', 'B3_ROLE', 'B3_OUTPUT','B3_END_TICK','B3_EXPECT_OBSERVERS','B3_TOKEN'):
            self.env.pop(name, None)
        self.ext = '.dylib' if os.uname().sysname == 'Darwin' else '.so'

    def publish(self):
        (self.out / 'result.json').write_bytes(json_bytes(self.report) + b'\n')

    def command(self, name, command, timeout=240):
        path = self.out / (name + '.log')
        started = time.monotonic()
        try:
            with path.open('wb') as output:
                value = subprocess.run(command, cwd=self.repo, env=self.env, stdout=output,
                                       stderr=subprocess.STDOUT, timeout=timeout)
            code = value.returncode
        except subprocess.TimeoutExpired:
            code = None
        self.steps.append(dict(name=name, command=command, exit_code=code, elapsed_seconds_observation=time.monotonic()-started,
                               log=str(path), log_sha256=sha(path)))
        self.publish()
        require(code == 0, ('build/import failed or timed out', name, code, str(path)))
        text = path.read_text(errors='replace')
        require(not any(word in text for word in BAD_LOG), ('build/import runtime error', name))

    def compare_available(self):
        if len(self.nodes)<2:
            return
        authority=self.nodes[0].evidence
        for node in self.nodes[1:]:
            follower=node.evidence
            compared=self.compared_by_actor.setdefault(node.role,set())
            for key in sorted(authority.frames.keys() & follower.frames.keys()):
                if key in compared:
                    continue
                left,right=authority.frames[key],follower.frames[key]
                if left.sig!=right.sig or left.parts()!=right.parts():
                    self.first_mismatch=preserve_mismatch(self.out/'first-mismatch',left,right,authority.accepted,follower.predicted)
                    self.report['first_mismatch']=dict(self.first_mismatch,follower=node.role)
                    self.publish()
                    raise EvidenceError(('first confirmed five-part mismatch',node.role,key,self.first_mismatch))
                compared.add(key)
                self.compared.add(key)

    def run(self):
        before = None
        failure = None
        codes = []
        try:
            ready, reason = authored_ready(self.source)
            if not ready:
                self.report.update(result='NOT_READY', reason=reason, project=str(self.source))
                return self.report
            before = inventory(self.repo, self.source)
            (self.out/'sources-before.json').write_bytes(json_bytes(before)+b'\n')
            self.report['source_inventory'] = dict(path=str(self.out/'sources-before.json'), sha256=sha(self.out/'sources-before.json'), count=len(before))
            require(self.args.native.is_file(), ('missing supplied Native library', str(self.args.native)))
            self.report['native'] = dict(path=str(self.args.native.resolve()), sha256=sha(self.args.native))
            shutil.copytree(self.source, self.project, ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin','*.gen.odin.uid','__pycache__'))
            # Preserve the examples' authored relative common-package import layout.
            shutil.copytree(self.repo/'examples/box3d_common',self.out/'box3d_common',ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin','__pycache__'))
            self.env['ODIN_SCRIPTS_DLL'] = str(self.project/'bin'/('libodinscripts'+self.ext))
            if self.args.configuration == 'Release':
                self.env['SCRIPT_BUILD_FLAGS'] = '-o:speed'
            self.command('build', ['bash', str(self.repo/'build/build_scripts.sh'), str(self.project)])
            if self.args.configuration == 'Release':
                self.command('core-release', ['bash','-c','source "$1/build/common.sh"; BOX3D_RUNTIME_DIR="$2/bin"; atomic_odin_dll "$1/core" "$2/bin/$3" -o:speed -debug',
                                             'slice-core', str(self.repo), str(self.project), 'libodin_godot'+self.ext])
            self.report['binaries'] = {str(p.relative_to(self.project)):sha(p) for p in sorted((self.project/'bin').iterdir()) if p.is_file()}
            self.command('prepared-import', [self.args.godot, '--headless', '--path', str(self.project), '--import'])
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(('127.0.0.1', 0))
                port = sock.getsockname()[1]
            requested_impairment={name:self.env.get(name,'0') for name in
                                  ('B3_LATENCY','B3_JITTER','B3_LOSS','B3_DUPLICATE','B3_REORDER')}
            self.report['transport'] = dict(kind='actual Godot ENet', address='127.0.0.1', port=port,
                impairment='scene local-receive configuration requested' if any(v not in ('','0') for v in requested_impairment.values()) else 'none requested',
                requested_impairment_environment=requested_impairment,
                impairment_evidence='Requested environment only; effective settings require endpoint READY/configuration verification.',
                control_truth_injection=False)
            actors=(('host','host',101),('client','client',202))
            if self.args.cohort=='observer':actors+= (('observer','observer',303),)
            elif self.args.cohort=='dedicated':actors=(('server','server',101),('client1','client',202),('client2','client',203))
            self.report['actors']=[dict(label=label,role=role,token=token) for label,role,token in actors]
            for label,role,token in actors:
                output = self.out / label
                output.mkdir()
                env = dict(self.env, B3_FRAMEWORK=self.framework, B3_ROLE=role, B3_PORT=str(port), B3_ADDRESS='127.0.0.1',
                           B3_SEED=str(self.args.seed), B3_BODIES=str(self.args.bodies), B3_TICKS=str(self.args.ticks), B3_OUTPUT=str(output),B3_TOKEN=str(token),B3_SCRIPTED='1',B3_ACTOR=label)
                if self.args.cohort!='pair':env.update(B3_EXPECT_OBSERVERS='1' if self.args.cohort=='observer' else '0',B3_END_TICK=str(self.args.end_tick))
                self.nodes.append(Process(self.args.godot, self.project, label, env, output,app_role=role))
            deadline = time.monotonic() + self.args.timeout
            while True:
                for node in self.nodes:
                    node.consume()
                self.compare_available()
                for node in self.nodes:
                    code = node.process.poll()
                    require(code in (None,0), (node.role, 'process exited', code, str(node.log)))
                if all(node.process.poll() is not None for node in self.nodes):
                    break
                require(time.monotonic() < deadline, ('actual endpoint timeout', self.args.timeout))
                time.sleep(0.02)
        except Exception as error:
            failure = repr(error)
        finally:
            for node in self.nodes:
                codes.append(node.close(abort=failure is not None))
            # Reader tail must be consumed after both exits; a socket write or
            # process exit cannot stand in for endpoint diagnostic consumption.
            try:
                for node in self.nodes:
                    node.consume()
                if self.nodes:
                    self.compare_available()
                    clean = [node.evidence.teardown(code) for node,code in zip(self.nodes,codes)]
                    self.report['cleanup'] = clean
                if failure is None and len(self.nodes)>=2:
                    pairs={node.role:verify_pair(self.nodes[0].evidence,node.evidence,self.args.ticks,self.compared_by_actor[node.role]) for node in self.nodes[1:]}
                    if self.args.cohort!='pair':
                        require(len(self.nodes)==3,'cohort actor missing')
                        self.report['agreement_by_follower']=pairs
                        validator=verify_observer_cohort if self.args.cohort=='observer' else verify_dedicated_cohort
                        self.report['cohort_contract']=validator([n.evidence for n in self.nodes],self.args.ticks,self.args.end_tick)
                    else:self.report['agreement']=pairs['client']
                    if self.args.bodies==32:self.report['envelope32']=verify_32_pair_envelope([n.evidence for n in self.nodes])
            except Exception as error:
                if failure is None:
                    failure = repr(error)
            self.report['compared_confirmed_frames'] = sum(len(x) for x in self.compared_by_actor.values())
            self.report['compared_by_actor']={name:sorted(keys) for name,keys in self.compared_by_actor.items()}
            self.report['compared_keys'] = sorted(self.compared)
            self.report['processes'] = [dict(role=n.role,app_role=n.app_role,pid=n.process.pid,command=n.command,exit_code=code,
                                             log_sha256=sha(n.log),log_bytes=n.bytes,ready=n.evidence.ready,result=n.evidence.result,
                                             observed_frames=len(n.evidence.frames),events=n.evidence.events) for n,code in zip(self.nodes,codes)]
            if before is not None:
                after = inventory(self.repo,self.source)
                (self.out/'sources-after.json').write_bytes(json_bytes(after)+b'\n')
                self.report['source_fence_unchanged'] = before==after
                if before!=after:
                    failure = failure or 'source set changed during case; partial/not coherent'
            if failure is not None:
                self.report.update(result='FAIL' if self.nodes else 'NOT_READY',error=failure)
            elif len(self.nodes)==(3 if self.args.cohort!='pair' else 2):
                self.report['result']='PASS'
            self.publish()
        return self.report
