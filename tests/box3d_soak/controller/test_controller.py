"""Synthetic controller failure controls. No Godot, Native or physics run."""
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock,patch
import json
import os
import queue
import subprocess
import sys
import tempfile
import unittest

import run as controller
from run import Soak, EventArchive, drain_actor
from evidence import Frame
from rolling import RollingConfig,RollingStore,ProcessScope,EvidenceDivergence

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'audit'))
from test_rolling import signature_for
from build import ODIN_WRAPPER,run_owned_command,verify_example_copy
from stream import Actor,StreamBounds


class Controls(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)

    def args(self):
        return SimpleNamespace(framework='kit',bodies=32,out=self.root/'run',
            project=self.root/'project',build_record=self.root/'build-record.json',
            ticks=240,end_tick=240,seed=1,latency=0,jitter=0,loss=0,minimum_wall_seconds=0,
            timeout=1,store_mib=64,event_mib=16,log_mib=4,godot='/not-executed')

    def test_intent_contract_is_declared_before_ready_admission(self):
        args=self.args()
        legacy=dict(intent_source='outside_sim_catalog_class1',action_timing='Scheduled')
        self.assertEqual(controller.verify_intent_contract(args,legacy),1)
        v2=dict(legacy,intent_contract_version=2)
        with self.assertRaisesRegex(RuntimeError,'prelaunch declaration'):
            controller.verify_intent_contract(args,v2)
        args.kit_intent_contract=2
        self.assertEqual(controller.verify_intent_contract(args,v2),2)
        with self.assertRaisesRegex(RuntimeError,'prelaunch declaration'):
            controller.verify_intent_contract(args,legacy)
        for invalid in (True,False,0,3,'2',2.0,None):
            with self.subTest(version=invalid),self.assertRaises(RuntimeError):
                controller.verify_intent_contract(args,dict(legacy,intent_contract_version=invalid))
        with self.assertRaisesRegex(RuntimeError,'actual Kit intent catalog'):
            controller.verify_intent_contract(args,dict(v2,intent_source='different'))
        args.framework='replay'
        with self.assertRaisesRegex(RuntimeError,'Replay cannot'):
            controller.verify_intent_contract(args,v2)
        args.kit_intent_contract=1
        self.assertEqual(controller.verify_intent_contract(args,{}),1)
        args=self.args()
        run=SimpleNamespace(args=args,archive=Mock(),store=Mock(),source_sha='1'*64,impairment={})
        actor=SimpleNamespace(role='client',process=SimpleNamespace(pid=123))
        observation=controller.Observation(run,actor)
        with self.assertRaisesRegex(RuntimeError,'prelaunch declaration'):
            observation.receive('READY',dict(v2,target=240,baseline=0))
        self.assertIsNone(observation.ready)
        run.store.register_process.assert_not_called()

    def test_compiler_recorder_writes_two_real_json_lines_and_preserves_arguments(self):
        wrapper=self.root/'record.py';wrapper.write_text(ODIN_WRAPPER)
        output=self.root/'calls.jsonl'
        env=dict(os.environ,GATE_B_COMPILER_CALLS=str(output),GATE_B_REAL_ODIN='/usr/bin/true')
        for argv in (['build','a path with spaces','literal\\n'],['build',"apostrophe's path",'-o:speed']):
            subprocess.run([sys.executable,str(wrapper),*argv],env=env,check=True)
        rows=output.read_bytes().splitlines()
        self.assertEqual(len(rows),2)
        self.assertEqual(json.loads(rows[0])['argv'],['build','a path with spaces','literal\\n'])

    def test_build_timeout_stops_owned_nested_compiler_group(self):
        pidfile=self.root/'nested.pid'
        child_code='import os,time;open('+repr(str(pidfile))+',"w").write(str(os.getpid()));time.sleep(30)'
        parent_code='import subprocess,sys,time;subprocess.Popen([sys.executable,"-c",'+repr(child_code)+']);time.sleep(30)'
        with (self.root/'timeout.log').open('wb') as output:
            result=run_owned_command([sys.executable,'-c',parent_code],cwd=self.root,
                env=os.environ.copy(),output=output,timeout=0.5)
        self.assertTrue(result['timed_out']);self.assertIsNone(result['exit_code'])
        self.assertTrue(pidfile.is_file(),'nested control process did not actually start')
        child_pid=pidfile.read_text().strip()
        status=subprocess.run(['ps','-o','stat=','-p',child_pid],capture_output=True,text=True).stdout.strip()
        self.assertTrue(not status or status.startswith('Z'),('nested compiler still running',status))

    def test_fatal_callback_still_consumes_actual_queued_result_tail(self):
        actor=Actor.__new__(Actor);actor.bounds=StreamBounds();actor.events=queue.Queue();actor.error=None
        actor.role='client'
        for kind,row in (('INTENT_UNEXERCISED',{'reason':'fresh_tick_after_end'}),
                         ('RESULT',{'ok':False,'cleanup_errors':0})):
            actor.events.put((kind,row,1.0))
        received=[]
        def callback(kind,row,when):
            received.append((kind,row))
            if kind=='INTENT_UNEXERCISED':raise RuntimeError('actual scene failure')
        with self.assertRaisesRegex(RuntimeError,'actual scene failure'):actor.consume(callback)
        self.assertEqual([kind for kind,row in received],['INTENT_UNEXERCISED','RESULT'])
        self.assertEqual(actor.events.qsize(),0)

    def test_post_eof_drain_reaches_real_tail_across_batches_after_callback_failure(self):
        rows=[('ERROR',dict(reason='controlled'))]+[('STATUS',dict(index=i)) for i in range(130)]+[
            ('RESULT',dict(ok=False,cleanup_errors=0))]
        actor=SimpleNamespace(reader_eof=True,pending_event_count=len(rows))
        received=[];batches=[]
        def consume(callback,*,max_records):
            batch=rows[:max_records];del rows[:len(batch)];first=None
            for kind,row in batch:
                actor.pending_event_count-=1
                try:callback(kind,row,1.0)
                except Exception as failure:first=first or failure
            batches.append(len(batch))
            if first is not None:raise first
            return len(batch)
        actor.consume=consume
        def callback(kind,row,when):
            received.append((kind,row))
            if kind=='ERROR':raise RuntimeError('first actual callback failure')
        failure=drain_actor(actor,callback)
        self.assertEqual(str(failure),'first actual callback failure')
        self.assertEqual(actor.pending_event_count,0)
        self.assertEqual(received[-1],('RESULT',dict(ok=False,cleanup_errors=0)))
        self.assertEqual(batches,[64,64,4])

    def test_post_eof_corrupt_prefix_cannot_spin_or_claim_drain(self):
        actor=SimpleNamespace(reader_eof=True,pending_event_count=1,consume=Mock(return_value=0))
        failure=drain_actor(actor,lambda *args:None)
        self.assertIn('cannot advance',str(failure))
        actor.consume.assert_called_once()
        self.assertEqual(actor.pending_event_count,1)

    def test_older_binary_build_cannot_claim_current_repository_source(self):
        a=self.args();a.project.mkdir()
        a.build_record.write_text(json.dumps(dict(result='PASS',exit_code=0,source_fence_unchanged=True,
            framework='kit',project=str(a.project),source_manifest_sha256='1'*64)))
        with patch.object(controller,'source_manifest',return_value={}),patch.object(controller,'Actor') as launch:
            report=Soak(a).run()
        self.assertEqual(report['result'],'FAIL')
        self.assertIn('different current production source',report['error'])
        launch.assert_not_called()

    def test_source_manifest_includes_both_example_imports_and_detects_a_change(self):
        files=('examples/replay_box3d/shared/adapter/model.odin',
               'examples/kit_box3d/scripts/runtime.odin','examples/box3d_common/rules.odin')
        for name in files:
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('synthetic source')
        ignored=self.root/'examples/replay_box3d/bin/library.odin'
        ignored.parent.mkdir(parents=True);ignored.write_text('not a source')
        with patch.object(controller,'ROOT',self.root):
            before=controller.source_manifest('replay')
            self.assertEqual(set(before),set(files))
            (self.root/files[0]).write_text('changed actual imported adapter')
            after=controller.source_manifest('replay')
        self.assertNotEqual(before[files[0]],after[files[0]])

    def test_copied_example_must_match_the_source_snapshot_before_compilation(self):
        project=self.root/'copied';source=project/'shared/adapter/model.odin'
        source.parent.mkdir(parents=True);source.write_bytes(b'actual copied adapter')
        manifest={'examples/replay_box3d/shared/adapter/model.odin':controller.sha(source),
            'examples/replay_box3d/scripts/class.gen.odin':'1'*64}
        self.assertTrue(verify_example_copy(project,'replay',manifest))
        source.write_bytes(b'older or concurrently changed copied adapter')
        with self.assertRaisesRegex(Exception,'consumed example copy differs'):
            verify_example_copy(project,'replay',manifest)

    def test_one_finish_failure_does_not_abandon_other_owned_actor(self):
        a=self.args()
        with patch.object(controller,'source_manifest',return_value={}):
            case=Soak(a)
            actors=[]
            for role,pid in (('host',101),('client',202)):
                actor=SimpleNamespace(role=role,output=self.root/role,process=SimpleNamespace(pid=pid,poll=lambda:0),
                    finish=Mock(),consume=Mock())
                case.observations[role]=SimpleNamespace(result=None,target_at=None,receive=lambda *x:None)
                actors.append(actor)
            actors[0].finish.side_effect=RuntimeError('synthetic stdout drain failure')
            actors[1].finish.return_value=dict(exit_code=0,natural=True)
            case.actors=actors
            report=case.run()  # Missing build record causes the controlled abort path.
        self.assertEqual(report['result'],'FAIL')
        actors[1].finish.assert_called_once_with(abort=True)
        self.assertIn('synthetic stdout drain failure',report['exits']['host']['finish_error'])
        self.assertTrue((a.out/'report.json').is_file())

    def long_args(self, framework='kit', sources=None, oracle=None, seed=1):
        from long_policy import make_plan,plan_digest
        a=self.args();a.ticks=36000;a.end_tick=36600;a.minimum_wall_seconds=600;a.timeout=900
        a.framework=framework;a.seed=seed
        if sources is None:sources={'synthetic.odin':'f'*64}
        source_sha=controller.hashlib.sha256(controller.json_bytes(sources)+b'\n').hexdigest()
        plan=make_plan(a.out.name,a.framework,a.end_tick,{role:source_sha for role in ('host','client')},
            a.store_mib*1024*1024,a.event_mib*1024*1024,a.log_mib*1024*1024,
            execution=controller.frozen_execution(a),replay_rule_oracle=oracle)
        a.long_policy_plan=self.root/'frozen-long-plan.json'
        a.long_policy_plan.write_bytes(controller.json_bytes(plan)+b'\n')
        a.long_policy_sha256=plan_digest(plan)
        return a,sources,plan

    def test_long_policy_marker_precedes_launch_and_cannot_override_runtime_failure(self):
        a,sources,plan=self.long_args()
        a.project.mkdir();(a.project/'.godot').mkdir()
        (a.project/'.godot/extension_list.cfg').write_text('synthetic metadata')
        frozen={'bin/libogb3.dylib':'1'*64};launches=[]
        with patch.object(controller,'source_manifest',return_value=sources),\
             patch.object(controller,'tree_manifest',return_value=frozen):
            case=Soak(a)
            a.build_record.write_text(json.dumps(dict(result='PASS',exit_code=0,source_fence_unchanged=True,
                framework=a.framework,project=str(a.project),source_manifest_sha256=case.source_sha,
                source_manifest=str(a.out/'sources-before.json'),frozen_project_files=frozen,
                consumed_example_source_copy_verified=True)))
            def fail_launch(**kwargs):
                marker=case.archive.db.execute('SELECT id,role,kind,body,observed_at FROM events').fetchall()
                self.assertEqual(len(marker),1)
                self.assertEqual(marker[0][:3],(1,'controller','LONG_POLICY'))
                self.assertEqual(json.loads(marker[0][3]),case.coverage_binding)
                self.assertIsNone(marker[0][4])
                launches.append(kwargs['role'])
                raise RuntimeError('synthetic process launch failure')
            with patch.object(controller,'Actor',side_effect=fail_launch),\
                 patch('long_policy.classify',return_value=dict(result='PROSPECTIVE_LONG_COVERAGE_PASS')):
                report=case.run()
        self.assertEqual(launches,['host'])
        self.assertEqual(report['result'],'FAIL')
        self.assertIn('synthetic process launch failure',report['error'])
        self.assertEqual(report['prospective_long_audit']['result'],'PROSPECTIVE_LONG_COVERAGE_PASS')
        self.assertTrue((a.out/'controller-before-long-audit.json').is_file())

    def test_long_policy_with_a_different_run_cannot_launch(self):
        from long_policy import plan_digest
        a,sources,plan=self.long_args();plan['run_id']='some-other-attempt'
        a.long_policy_plan.write_bytes(controller.json_bytes(plan)+b'\n')
        a.long_policy_sha256=plan_digest(plan)
        with patch.object(controller,'source_manifest',return_value=sources),\
             patch.object(controller,'Actor') as launch:
            with self.assertRaisesRegex(Exception,'differs from frozen'):
                Soak(a)
        launch.assert_not_called()

    def test_old_public_oracle_cannot_launch_a_new_native_build(self):
        # Reuse only immutable public descriptor evidence, with no Native call.
        oracle=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-bindings/replay-p44/seed-oracle-9c66-v2/oracle-values-v1.json')
        if not oracle.is_file():self.skipTest('preserved descriptor oracle unavailable')
        sources=json.loads((oracle.parent/'sources-before.json').read_text())
        a,sources,plan=self.long_args('replay',sources,dict(path=str(oracle),sha256=controller.sha(oracle)),seed=17)
        (a.project/'.godot').mkdir(parents=True);(a.project/'.godot/extension_list.cfg').write_text('synthetic metadata')
        (a.project/'bin').mkdir()
        metadata=a.project/'bin/box3d-runtime.json'
        metadata.write_text(json.dumps(dict(domain=dict(build='sha256:'+'f'*64,target='sha256:'+'e'*64))))
        frozen={'bin/libogb3.dylib':'1'*64,'bin/box3d-runtime.json':controller.sha(metadata)}
        with patch.object(controller,'source_manifest',return_value=sources),\
             patch.object(controller,'tree_manifest',return_value=frozen),\
             patch.object(controller,'Actor') as launch:
            case=Soak(a)
            a.build_record.write_text(json.dumps(dict(result='PASS',exit_code=0,source_fence_unchanged=True,
                framework=a.framework,project=str(a.project),source_manifest_sha256=case.source_sha,
                source_manifest=str(a.out/'sources-before.json'),frozen_project_files=frozen,
                consumed_example_source_copy_verified=True)))
            report=case.run()
        launch.assert_not_called()
        self.assertEqual(report['result'],'FAIL')
        self.assertIn('old oracle cannot qualify selected Native',report['error'])
        self.assertFalse((a.out/'observations.sqlite').exists())

    def test_observation_time_is_bound_without_changing_actual_row(self):
        archive=EventArchive(self.root/'timed-events.sqlite',16*1024*1024)
        self.addCleanup(archive.db.close)
        actual=dict(epoch=1,tick=5,seat=2,kind=6)
        archive.append('host','INPUT',actual,observed_at=12.5)
        archive.append('client','INPUT',actual)  # Saved evidence has no invented time.
        archive.append('host','STATUS',dict(available=True),observed_at=13)
        self.assertEqual(list(archive.rows('host','INPUT')),[actual])
        self.assertEqual(archive.db.execute('SELECT observed_at FROM events ORDER BY id').fetchall(),
            [(12.5,),(None,),(13.0,)])
        self.assertEqual(archive.verify_chain()['events'],3)
        for invalid in (True,-1,float('nan'),float('inf')):
            with self.assertRaises(Exception):archive.append('host','INPUT',actual,observed_at=invalid)
        self.assertEqual(archive.count,3)
        archive.db.execute('UPDATE events SET observed_at=13 WHERE id=1');archive.db.commit()
        with self.assertRaises(Exception):archive.verify_chain()

    def test_first_mismatch_binds_bounded_real_observations_and_unknown_prediction(self):
        case=Soak.__new__(Soak);case.out=self.root;case.source_sha='1'*64
        case.consume_export_files=False;case.pending=[]
        case.archive=EventArchive(self.root/'events.sqlite',16*1024*1024);self.addCleanup(case.archive.db.close)
        case.store=RollingStore(RollingConfig(directory=self.root/'rolling',authority_role='host',
            follower_roles=('client',),allowed_sources={r:('1'*64,) for r in ('host','client')},
            disk_budget_bytes=64*1024*1024,frame_policy='all_follower_exports_required',
            decision_coverage='after_admission_baseline'));self.addCleanup(case.store.close)
        observations={}
        for role,pid in (('host',1),('client',2)):
            case.store.register_process(ProcessScope(role,role,pid,'1'*64,1,0))
            observations[role]=SimpleNamespace(actor=SimpleNamespace(role=role,process=SimpleNamespace(pid=pid),output=self.root),
                scope=role,frames=0,last_frame=0,last_confirmed=0)
        accepted=dict(epoch=1,tick=5,seat=1,x=25,z=0,origin='Local')
        case.archive.append('host','INPUT',accepted)
        case.archive.append('client','ISSUED',dict(epoch=1,seat=2,submitted_tick=5,sequence=5))
        frames=[]
        for number,game in enumerate((b'game',b'changed')):
            parts=(b'solver',game,b'side',b'observations',b'occurrences');paths=[]
            for i,data in enumerate(parts):
                path=self.root/f'{number}.part{i}';path.write_bytes(data);paths.append(path)
            frames.append(Frame(1,5,signature_for(parts,1,5),tuple(paths),{}))
        with patch.object(controller,'load_frame',side_effect=frames):
            case.frame(observations['host'],dict(epoch=1,tick=5))
            with self.assertRaises(EvidenceDivergence):case.frame(observations['client'],dict(epoch=1,tick=5))
        saved=case.store.first_mismatch()
        self.assertEqual(saved['expected']['parts'][1],b'game')
        self.assertEqual(saved['actual']['parts'][1],b'changed')
        self.assertEqual(json.loads(saved['context']['accepted_inputs']),[accepted])
        self.assertEqual(saved['context']['predicted_inputs'],b'')
        self.assertEqual(saved['context']['provenance']['actual_issued_requests'],
            [dict(epoch=1,seat=2,submitted_tick=5,sequence=5)])
        self.assertEqual(saved['context']['depth'],0)
        prefix=saved['context']['provenance']['archive_prefix']
        self.assertEqual(prefix['through_event_id'],2)
        self.assertEqual(prefix['head_sha256'],case.archive.verify_chain()['head_sha256'])
        case.archive.db.execute("UPDATE events SET body='{}' WHERE id=1");case.archive.db.commit()
        with self.assertRaises(Exception):case.archive.verify_chain()


if __name__=='__main__':unittest.main()
