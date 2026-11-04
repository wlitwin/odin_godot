"""Pure disk/reader controls. Fake subprocess stdout only; no Game or Native."""
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

import stream
from stream import Actor, StreamBounds, _DiskEvents
from evidence import EvidenceError


def line(number=0, event='NOTE', padding=''):
    return (json.dumps(dict(event=event, number=number, padding=padding),
                       separators=(',', ':'))+'\n').encode()


class FakeProcess:
    def __init__(self, raw):
        self.stdout=io.BytesIO(raw); self.pid=123456; self.returncode=0
    def poll(self):return self.returncode
    def wait(self, timeout=None):return self.returncode


class Clock:
    def __init__(self):self.value=-1
    def __call__(self):self.value+=1;return float(self.value)


class ShortWriter:
    def __init__(self, base, fail=False):self.base=base;self.fail=fail;self.calls=0
    def write(self, value):
        self.calls+=1
        if self.fail and self.calls>1:raise OSError('deliberate partial write failure')
        return self.base.write(value[:3])
    def __getattr__(self, name):return getattr(self.base,name)


class SpoolTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.serial=0

    def actor(self, raw, bounds=None, identity=None, fsync_failure=False):
        self.serial+=1;process=FakeProcess(raw)
        bounds=bounds or StreamBounds(line_bytes=512,log_bytes=2*1024*1024,
                                     index_bytes=1024*1024,consume_bytes=65536)
        real_sync=os.fsync;calls=[0]
        def sync(fd):
            calls[0]+=1
            if fsync_failure and calls[0]==2:raise OSError('deliberate EOF fsync failure')
            real_sync(fd)
        with patch.object(stream.subprocess,'Popen',return_value=process), \
             patch.object(stream.time,'monotonic',new=Clock()), \
             patch.object(stream.os,'fsync',side_effect=sync):
            actor=Actor(role='host',godot='FAKE_ONLY',project=self.root,environment={},
                        output=self.root/str(self.serial),bounds=bounds,identity=identity)
            actor.thread.join(10);self.assertFalse(actor.thread.is_alive())
            facts=actor.finish()
        self.addCleanup(actor.close)
        return actor,facts

    def drain(self, actor, callback, max_records=64):
        total=0
        while actor.pending_event_count:
            before=actor.records_consumed
            try:actor.consume(callback,max_records=max_records)
            except (EvidenceError,RuntimeError):pass
            delta=actor.records_consumed-before
            self.assertGreater(delta,0,'valid tail must make progress')
            self.assertLessEqual(delta,max_records);total+=delta
        return total

    def test_backlog_5000_is_disk_bounded_ordered_and_original_time(self):
        raw=b'Godot banner\n'+b''.join(line(i) for i in range(5000))
        actor,before=self.actor(raw,identity=dict(source='synthetic-source',build='synthetic-build'))
        self.assertTrue(actor.reader_eof);self.assertEqual(actor.pending_event_count,5000)
        self.assertEqual(actor.events.qsize(),5000);self.assertEqual(before['pending_events'],5000)
        self.assertEqual(actor.records_consumed,0);self.assertFalse(hasattr(actor.events,'queue'))
        self.assertEqual(before['intake']['index_bytes'],96+5000*96)
        self.assertEqual(before['intake']['peak_pending_events'],5000)
        self.assertEqual(actor.log_path.read_bytes(),raw)
        received=[];self.assertEqual(self.drain(actor,lambda k,r,t:received.append((k,r,t))),5000)
        self.assertEqual([r['number'] for _,r,_ in received],list(range(5000)))
        self.assertEqual([t for _,_,t in received],[float(i+1) for i in range(5000)])
        final=actor.facts();self.assertEqual(final['records_consumed'],5000)
        self.assertEqual(final['pending_events'],0);self.assertEqual(final['intake']['pending_events'],0)
        self.assertTrue(final['intake']['final_flush_fsync_ok']);self.assertIsNone(actor.error)
        actor.close();actor.close()
        self.assertTrue(actor._spool.raw_reader.closed and actor._spool.index_reader.closed)

    def test_consume_is_bounded_by_bytes_and_records(self):
        # Identity is about70B; this allows one large row, not64, per turn.
        bounds=StreamBounds(line_bytes=256,log_bytes=8192,index_bytes=8192,consume_bytes=600)
        actor,_=self.actor(b''.join(line(i,padding='x'*180) for i in range(8)),bounds)
        rows=[];self.assertEqual(actor.consume(lambda k,r,t:rows.append(r),max_records=64),1)
        self.assertEqual(actor.pending_event_count,7)
        self.assertEqual(self.drain(actor,lambda k,r,t:rows.append(r)),7)
        self.assertEqual([r['number'] for r in rows],list(range(8)))
        with self.assertRaises(EvidenceError):actor.consume(lambda *x:None,max_records=0)

    def test_exact_raw_and_index_bounds_and_overflow_are_explicit(self):
        row=line();payload=row*3
        exact=StreamBounds(line_bytes=len(row),log_bytes=len(payload),index_bytes=96+3*96,consume_bytes=2048)
        actor,_=self.actor(payload,exact);self.assertIsNone(actor.error)
        self.drain(actor,lambda *x:None);self.assertEqual(actor.bytes_seen,actor.bytes_retained)
        overflow,_=self.actor(payload+row,exact)
        self.assertIsNotNone(overflow.error);self.assertEqual(overflow.bytes_seen,len(payload)+len(row))
        self.assertEqual(overflow.bytes_retained,len(payload));self.assertEqual(overflow.log_path.read_bytes(),payload)
        self.assertEqual(self.drain(overflow,lambda *x:None),3)
        indexed=StreamBounds(line_bytes=len(row),log_bytes=4096,index_bytes=96+2*96,consume_bytes=2048)
        overflow,_=self.actor(payload,indexed)
        self.assertIsNotNone(overflow.error);self.assertEqual(overflow.bytes_retained,len(payload))
        self.assertEqual(overflow.records_seen,3);self.assertEqual(overflow.pending_event_count,2)
        self.assertEqual(overflow.intake_facts()['index_bytes'],96+2*96)
        self.assertEqual(self.drain(overflow,lambda *x:None),2)

    def test_partial_writes_preserve_counters_and_publish_only_complete_index(self):
        output=self.root/'direct';output.mkdir();bounds=StreamBounds(line_bytes=512,log_bytes=4096,index_bytes=4096)
        spool=_DiskEvents(output,'host',bounds,None)
        spool.log=ShortWriter(spool.log);spool.index=ShortWriter(spool.index)
        raw=line();self.assertEqual(spool.write_raw(raw),len(raw));spool.publish(0,raw,1.25)
        spool.finish_writer();self.assertEqual(spool.get_nowait(),('NOTE',json.loads(raw),1.25))
        self.assertIsNone(spool.facts()['integrity_error']);spool.close()
        output=self.root/'fault';output.mkdir();spool=_DiskEvents(output,'host',bounds,None)
        spool.write_raw(raw);spool.index=ShortWriter(spool.index,fail=True)
        with self.assertRaisesRegex(OSError,'partial write'):spool.publish(0,raw,1.0)
        self.assertEqual(spool.published,0);self.assertEqual(spool.index_bytes,99)
        spool.finish_writer();self.assertIsNotNone(spool.facts()['integrity_error']);spool.close()

    def test_raw_index_identity_and_truncation_tampering_never_consumes_entry(self):
        for fault in ('raw','header','sequence','chain','index_truncate','raw_truncate','identity','path_swap'):
            with self.subTest(fault=fault):
                actor,_=self.actor(line())
                spool=actor._spool
                if fault=='identity':spool.identity_path.write_bytes(b'{}')
                elif fault=='path_swap':
                    replacement=actor.output/'replacement';replacement.write_bytes(actor.log_path.read_bytes())
                    replacement.replace(actor.log_path)
                else:
                    path=spool.index_path if fault in ('header','sequence','chain','index_truncate') else actor.log_path
                    data=bytearray(path.read_bytes())
                    if fault.endswith('truncate'):data=data[:-1]
                    else:data[{'raw':0,'header':0,'sequence':96,'chain':191}[fault]]^=1
                    path.write_bytes(data)
                with self.assertRaises(EvidenceError):actor.consume(lambda *x:self.fail('corrupt callback'))
                self.assertEqual(actor.records_consumed,0);self.assertEqual(actor.pending_event_count,1)
                actor.close();self.assertEqual(actor.pending_event_count,1)
                self.assertTrue(spool.consumer_closed);self.assertIsNotNone(actor.error)

    def test_recomputed_chain_cannot_forge_original_observed_time(self):
        actor,_=self.actor(line());p=actor._spool.index_path;data=bytearray(p.read_bytes())
        values=list(stream._RECORD_PREFIX.unpack(data[96:160]));values[3]=12345.0
        prefix=stream._RECORD_PREFIX.pack(*values);data[96:160]=prefix
        data[160:192]=hashlib.sha256(bytes(data[64:96])+prefix).digest();p.write_bytes(data)
        with self.assertRaisesRegex(EvidenceError,'anchor'):actor.consume(lambda *x:None)
        self.assertEqual(actor.records_consumed,0)

    def test_fatal_callback_drains_real_disk_tail_across_batches(self):
        raw=line(0,'FATAL')+b''.join(line(i) for i in range(1,131))+line(131,'RESULT')
        actor,_=self.actor(raw);received=[]
        def callback(kind,row,when):
            received.append(kind)
            if kind=='FATAL':raise RuntimeError('deliberate callback failure')
        with self.assertRaisesRegex(RuntimeError,'callback failure'):actor.consume(callback,max_records=64)
        self.assertEqual(actor.records_consumed,64);self.assertEqual(actor.pending_event_count,68)
        self.assertEqual(self.drain(actor,callback),68)
        self.assertEqual(received[-1],'RESULT');self.assertEqual(len(received),132)
        self.assertIsNone(actor.error)

    def test_parser_and_overlong_lines_keep_raw_and_valid_cleanup_tail(self):
        for bad in (b'ERROR: deliberate source failure\n',b'\xff\n',b'x'*513+b'\n'):
            with self.subTest(bad=bad[:10]):
                raw=bad+line(1,'RESULT');actor,_=self.actor(raw)
                self.assertEqual(actor.log_path.read_bytes(),raw);self.assertIsNotNone(actor.error)
                received=[];self.drain(actor,lambda k,r,t:received.append(k))
                self.assertEqual(received,['RESULT']);self.assertTrue(actor.reader_eof)

    def test_eof_fsync_failure_is_explicit_and_all_handles_can_close(self):
        actor,facts=self.actor(line(0,'RESULT'),fsync_failure=True)
        self.assertFalse(facts['intake']['final_flush_fsync_ok']);self.assertIn('fsync',actor.error)
        self.assertTrue(actor.reader_eof);self.drain(actor,lambda *x:None)
        actor.close();self.assertTrue(actor._spool.log.closed and actor._spool.index.closed)
        self.assertTrue(actor._spool.consumer_closed)

    def test_eof_extra_index_bytes_fail_final_proof(self):
        actor,_=self.actor(line());p=actor._spool.index_path
        with p.open('ab') as out:out.write(b'x')
        actor.consume(lambda *x:None)
        facts=actor.intake_facts();self.assertIsNotNone(facts['integrity_error'])
        self.assertIsNotNone(actor.error);self.assertEqual(actor.records_consumed,1)

    def test_active_close_preserves_handles_then_forced_finish_drains_and_closes(self):
        ready,release=threading.Event(),threading.Event()
        class Stdout:
            def readline(self,size):ready.set();release.wait(5);return b''
            def close(self):pass
        class Process(FakeProcess):
            def __init__(self):self.stdout=Stdout();self.pid=123456;self.returncode=None
            def wait(self,timeout=None):
                if self.returncode is None:raise subprocess.TimeoutExpired('fake',timeout)
                return self.returncode
            def terminate(self):self.returncode=-15;release.set()
            def kill(self):self.returncode=-9;release.set()
        process=Process()
        with patch.object(stream.subprocess,'Popen',return_value=process):
            actor=Actor(role='client',godot='FAKE_ONLY',project=self.root,environment={},output=self.root/'forced')
        self.addCleanup(actor.close);self.assertTrue(ready.wait(2))
        with self.assertRaises(EvidenceError):actor.close()
        self.assertFalse(actor._spool.consumer_closed)
        facts=actor.finish(abort=True);self.assertEqual(facts['exit_code'],-15)
        self.assertFalse(facts['natural']);self.assertTrue(actor.reader_eof)
        self.assertEqual(actor.consume(lambda *x:None),0);actor.close();actor.close()

    def test_default_unknown_identity_and_invalid_bounds_are_explicit(self):
        actor,_=self.actor(line())
        self.assertEqual(actor.intake_facts()['identity']['identity'],{'status':'unknown'})
        self.drain(actor,lambda *x:None)
        for bounds in (StreamBounds(index_bytes=95),StreamBounds(consume_bytes=1),
                       StreamBounds(pending_events=0),StreamBounds(index_bytes=2**64)):
            with self.subTest(bounds=bounds),patch.object(stream.subprocess,'Popen') as launch:
                self.serial+=1
                with self.assertRaises(EvidenceError):
                    Actor(role='host',godot='FAKE_ONLY',project=self.root,environment={},output=self.root/str(self.serial),bounds=bounds)
                launch.assert_not_called()

    def test_launch_failure_closes_all_created_writer_and_consumer_handles(self):
        created=[];original=stream._DiskEvents
        def spool(*args,**kwargs):
            result=original(*args,**kwargs);created.append(result);return result
        with patch.object(stream,'_DiskEvents',side_effect=spool), \
             patch.object(stream.subprocess,'Popen',side_effect=OSError('deliberate launch failure')):
            with self.assertRaisesRegex(OSError,'launch failure'):
                Actor(role='host',godot='FAKE_ONLY',project=self.root,environment={},output=self.root/'launch-fail')
        self.assertEqual(len(created),1)
        self.assertTrue(all(handle.closed for handle in created[0]._handles))

    def test_reader_start_failure_stops_owned_child_and_closes_handles(self):
        created=[];original=stream._DiskEvents
        def spool(*args,**kwargs):
            result=original(*args,**kwargs);created.append(result);return result
        class Process(FakeProcess):
            def __init__(self):super().__init__(b'');self.returncode=None;self.terminated=False
            def terminate(self):self.terminated=True;self.returncode=-15
        process=Process()
        with patch.object(stream,'_DiskEvents',side_effect=spool), \
             patch.object(stream.subprocess,'Popen',return_value=process), \
             patch.object(stream.threading.Thread,'start',side_effect=RuntimeError('deliberate reader start failure')):
            with self.assertRaisesRegex(RuntimeError,'reader start failure'):
                Actor(role='host',godot='FAKE_ONLY',project=self.root,environment={},output=self.root/'start-fail')
        self.assertTrue(process.terminated and process.stdout.closed)
        self.assertTrue(all(handle.closed for handle in created[0]._handles))


if __name__=='__main__':unittest.main()
