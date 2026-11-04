"""Bounded subprocess observations for the Gate B controller.

This module launches the existing authored scene. It does not generate inputs,
edit simulation state, or replace either framework's network/runtime path.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import math
import os
import queue
import struct
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'box3d_slices/harness'))
from evidence import EvidenceError, require, strict_json
from runner import BAD_LOG


@dataclass(frozen=True)
class StreamBounds:
    line_bytes: int = 1024 * 1024
    log_bytes: int = 128 * 1024 * 1024
    pending_events: int = 1024
    index_bytes: int | None = None
    consume_bytes: int = 4 * 1024 * 1024


_MAGIC = b'B3INTK01'
_HEADER_PREFIX = struct.Struct('<8sIIQQ32s')
_RECORD_PREFIX = struct.Struct('<QQQd32s')
_HEADER_BYTES = _RECORD_BYTES = 96
_IDENTITY_BYTES = 16 * 1024


class _DiskEvents:
    """One producer/one consumer. Only complete index entries are published.

    The bounded raw log is the payload store. No parsed-record backlog or
    per-record in-memory offset list is retained.
    """
    def __init__(self, output, role, bounds, identity):
        self.bounds = bounds
        self.index_limit = bounds.log_bytes if bounds.index_bytes is None else bounds.index_bytes
        require(identity is None or isinstance(identity, dict), 'intake identity must be an object')
        require(all(type(v) is int and 0 < v <= sys.maxsize for v in
                    (bounds.line_bytes, bounds.log_bytes, bounds.pending_events,
                     self.index_limit, bounds.consume_bytes)) and
                bounds.log_bytes >= bounds.line_bytes and bounds.line_bytes < sys.maxsize
                and self.index_limit >= _HEADER_BYTES,
                'invalid stream bounds')
        self.identity = dict(schema=1, role=role,
                             identity={'status':'unknown'} if identity is None else identity)
        identity_bytes = json.dumps(self.identity, sort_keys=True, separators=(',', ':'),
                                    ensure_ascii=False, allow_nan=False).encode('utf-8')
        require(len(identity_bytes) <= _IDENTITY_BYTES, 'intake identity bound exceeded')
        self.identity = strict_json(identity_bytes)
        self.identity_sha = hashlib.sha256(identity_bytes).digest()
        self.entry_overhead = _HEADER_BYTES + _RECORD_BYTES + len(identity_bytes) + 1
        require(bounds.consume_bytes >= bounds.line_bytes + self.entry_overhead,
                'consume byte budget cannot fit one maximum-size record')
        self.log_path, self.index_path = output/'godot.log', output/'intake.index'
        self.identity_path = output/'intake-identity.json'
        self._lock = threading.Lock()
        self.published = self.consumed = self.peak_pending = 0
        self.raw_bytes = self.index_bytes = 0
        self._raw_hash, self._index_hash = hashlib.sha256(), hashlib.sha256()
        self._last_offset_end = 0
        self._last_observed = -1.0
        self._raw_failed = self._index_failed = False
        self.writer_closed = self.consumer_closed = self.fsync_ok = False
        self._handles = []
        try:
            with self.identity_path.open('xb', buffering=0) as f:
                self._write_all(f, identity_bytes)
                f.flush(); os.fsync(f.fileno())
            self.log = self.log_path.open('xb', buffering=0); self._handles.append(self.log)
            self.index = self.index_path.open('xb', buffering=0); self._handles.append(self.index)
            header = _HEADER_PREFIX.pack(_MAGIC, 1, _RECORD_BYTES, bounds.log_bytes,
                                         self.index_limit, self.identity_sha)
            self.header = header + hashlib.sha256(header).digest()
            self._write_index(self.header)
            self._write_chain = self._read_chain = self.header[-32:]
            self.raw_reader = self.log_path.open('rb', buffering=0); self._handles.append(self.raw_reader)
            self.index_reader = self.index_path.open('rb', buffering=0); self._handles.append(self.index_reader)
            self._identity_size = len(identity_bytes)
        except BaseException:
            for handle in reversed(self._handles):
                handle.close()
            raise

    @staticmethod
    def _write_all(handle, data, progress=None):
        view = memoryview(data)
        while view:
            count = handle.write(view)
            if count is None or count <= 0:
                raise OSError('intake write made no progress')
            if progress is not None:
                progress(view[:count])
            view = view[count:]

    def _write_index(self, data):
        def progress(part):
            self._index_hash.update(part)
            with self._lock:
                self.index_bytes += len(part)
        self._write_all(self.index, data, progress)

    def write_raw(self, raw):
        if self._raw_failed:
            return 0
        retained = min(len(raw), self.bounds.log_bytes-self.raw_bytes)
        def progress(part):
            self._raw_hash.update(part)
            with self._lock:
                self.raw_bytes += len(part)
        try:
            self._write_all(self.log, raw[:retained], progress)
        except BaseException:
            self._raw_failed = True
            raise
        return retained

    def publish(self, offset, raw, observed_at):
        if self._index_failed:
            return False
        try:
            require(type(observed_at) is float and math.isfinite(observed_at) and observed_at >= 0,
                    'invalid original intake observation time')
            require(self.index_bytes + _RECORD_BYTES <= self.index_limit,
                    'intake index byte bound exceeded; evidence incomplete')
            require(0 < len(raw) <= self.bounds.line_bytes and offset+len(raw) <= self.raw_bytes,
                    'index refers to unretained raw bytes')
            prefix = _RECORD_PREFIX.pack(self.published+1, offset, len(raw), observed_at,
                                          hashlib.sha256(raw).digest())
            chain = hashlib.sha256(self._write_chain+prefix).digest()
            self._write_index(prefix+chain)
            # FileIO writes precede publication; final EOF fsync is mandatory.
            with self._lock:
                self._write_chain = chain
                self.published += 1
                self.peak_pending = max(self.peak_pending, self.published-self.consumed)
            return True
        except BaseException:
            self._index_failed = True
            raise

    def qsize(self):
        with self._lock:
            return self.published-self.consumed

    def empty(self):
        return self.qsize() == 0

    @staticmethod
    def _read_at(handle, offset, length):
        handle.seek(offset)
        data = handle.read(length)
        require(len(data) == length, 'truncated intake reference')
        return data

    @staticmethod
    def _same_file(handle, path):
        opened, named = os.fstat(handle.fileno()), path.stat()
        require((opened.st_dev, opened.st_ino) == (named.st_dev, named.st_ino),
                'intake file identity changed')

    def pop(self, budget):
        with self._lock:
            published, raw_bytes, write_chain = self.published, self.raw_bytes, self._write_chain
        if self.consumed == published:
            raise queue.Empty
        require(not self.consumer_closed, 'intake consumer closed with pending records')
        if budget < self.entry_overhead:
            return None, 0
        require(self.identity_path.stat().st_size == self._identity_size,
                'intake source identity changed')
        with self.identity_path.open('rb') as identity:
            require(hashlib.sha256(identity.read(self._identity_size+1)).digest() == self.identity_sha,
                    'intake source identity changed')
        self._same_file(self.raw_reader, self.log_path)
        self._same_file(self.index_reader, self.index_path)
        require(self._read_at(self.index_reader, 0, _HEADER_BYTES) == self.header,
                'intake version/header/bounds changed')
        encoded = self._read_at(self.index_reader, _HEADER_BYTES+self.consumed*_RECORD_BYTES,
                                _RECORD_BYTES)
        prefix, chain = encoded[:64], encoded[64:]
        sequence, offset, length, observed_at, raw_hash = _RECORD_PREFIX.unpack(prefix)
        require(sequence == self.consumed+1 and offset >= self._last_offset_end and
                0 < length <= self.bounds.line_bytes and offset+length <= raw_bytes,
                'invalid intake sequence/offset/length')
        require(math.isfinite(observed_at) and observed_at >= 0 and observed_at >= self._last_observed,
                'invalid intake observation order')
        require(hashlib.sha256(self._read_chain+prefix).digest() == chain,
                'intake index chain mismatch')
        if sequence == published:
            require(chain == write_chain, 'intake published-prefix anchor mismatch')
        cost = self.entry_overhead+length
        if cost > budget:
            return None, self.entry_overhead
        raw = self._read_at(self.raw_reader, offset, length)
        require(hashlib.sha256(raw).digest() == raw_hash, 'intake raw reference SHA mismatch')
        record = decode_record(raw)
        require(record is not None, 'indexed intake record became ordinary stdout')
        with self._lock:
            self.consumed += 1
        self._read_chain = chain
        self._last_offset_end, self._last_observed = offset+length, observed_at
        return (*record, observed_at), cost

    def get_nowait(self):
        record, _ = self.pop(self.bounds.consume_bytes)
        return record

    def finish_writer(self):
        if self.writer_closed:
            return
        first = None
        for handle in (self.log, self.index):
            try:
                handle.flush(); os.fsync(handle.fileno())
            except BaseException as error:
                first = first or error
            finally:
                handle.close()
        self.writer_closed = True
        self.fsync_ok = first is None
        if first is not None:
            raise first

    def close(self):
        if self.consumer_closed:
            return
        require(self.writer_closed, 'intake close before writer finished')
        self.raw_reader.close(); self.index_reader.close()
        self.consumer_closed = True

    def facts(self):
        result = dict(version=1, record_bytes=_RECORD_BYTES, header_bytes=_HEADER_BYTES,
                      identity=self.identity, identity_path=str(self.identity_path),
                      identity_sha256=self.identity_sha.hex(), log_path=str(self.log_path),
                      index_path=str(self.index_path), log_limit_bytes=self.bounds.log_bytes,
                      index_limit_bytes=self.index_limit, log_bytes=self.raw_bytes,
                      index_bytes=self.index_bytes, records_published=self.published,
                      records_consumed=self.consumed, pending_events=self.qsize(),
                      peak_pending_events=self.peak_pending, consume_bytes=self.bounds.consume_bytes,
                      writer_closed=self.writer_closed, consumer_closed=self.consumer_closed,
                      final_flush_fsync_ok=self.fsync_ok)
        result['integrity_error'] = None
        if self.writer_closed:
            try:
                for path, size, wanted, name in ((self.log_path, self.raw_bytes, self._raw_hash.hexdigest(), 'log'),
                                               (self.index_path, self.index_bytes, self._index_hash.hexdigest(), 'index')):
                    require(path.stat().st_size == size, 'sealed intake '+name+' size changed')
                    h = hashlib.sha256()
                    with path.open('rb') as stream:
                        remaining = size
                        while remaining:
                            block = stream.read(min(1024*1024, remaining))
                            require(bool(block), 'sealed intake '+name+' truncated')
                            h.update(block)
                            remaining -= len(block)
                        require(not stream.read(1), 'sealed intake '+name+' grew')
                    result[name+'_sha256'] = h.hexdigest()
                    require(path.stat().st_size == size and h.hexdigest() == wanted,
                            'sealed intake '+name+' changed')
                require(self.index_bytes == _HEADER_BYTES+self.published*_RECORD_BYTES,
                        'incomplete unpublished intake index suffix')
                require(self.identity_path.stat().st_size == self._identity_size,
                        'sealed intake identity size changed')
                with self.identity_path.open('rb') as identity:
                    require(hashlib.sha256(identity.read(self._identity_size+1)).digest() == self.identity_sha,
                            'sealed intake identity changed')
            except (EvidenceError, OSError) as failure:
                result['integrity_error'] = repr(failure)
        return result


def decode_record(raw: bytes):
    """Decode the existing scene diagnostics without inventing missing fields."""
    text = raw.decode('utf-8', errors='strict').rstrip('\r\n')
    require(not any(marker in text for marker in BAD_LOG), ('runtime error', text[:1000]))
    if text.startswith('{'):
        row = strict_json(text)
        require(isinstance(row, dict) and isinstance(row.get('event'), str),
                'plain scene record lacks event')
        return row['event'].upper(), row
    if text.startswith('BOX3D_SLICE_'):
        prefix, separator, body = text.partition(' ')
        kind = prefix.removeprefix('BOX3D_SLICE_')
        if kind in ('WAIT','ERROR') and separator and not body.startswith('{'):
            return kind, {'message':body}  # Existing authored handshake/error format.
        require(separator and body.startswith('{'), ('unstructured scene record', kind))
        row = strict_json(body)
        require(isinstance(row, dict), 'scene record is not an object')
        return kind, row
    return None  # Godot banner and other ordinary stdout remain in the raw log.


class Actor:
    def __init__(self, *, role, godot, project: Path, environment, output: Path,
                 bounds=StreamBounds(), wake=None, identity=None):
        self.role, self.bounds = role, bounds
        self.wake = wake
        self.output = output.resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self._spool = _DiskEvents(self.output, role, bounds, identity)
        self.log_path, self.log = self._spool.log_path, self._spool.log
        self.events = self._spool
        self.error = None
        self._error_lock = threading.Lock()
        self._reader_eof = False
        self._consuming = False
        self.bytes_seen = self.bytes_retained = self.records_seen = 0
        self.forced = False
        self.rss_samples = self.sampled_rss_peak_bytes = self.rss_unavailable = 0
        self.started = time.monotonic()
        self.ended = None
        self.command = [str(godot), '--headless', '--max-fps', '60', '--path', str(project)]
        try:
            self.process = subprocess.Popen(self.command, cwd=project, env=environment,
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except BaseException as original:
            try:
                self._spool.finish_writer()
            except BaseException as cleanup:
                original.add_note('intake setup cleanup: '+repr(cleanup))
            self._spool.close()
            raise
        self.thread = threading.Thread(target=self._read, daemon=True)
        try:
            self.thread.start()
        except BaseException as original:
            try:
                if self.process.poll() is None:
                    self.process.terminate()
                    try:
                        self.process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        self.process.kill(); self.process.wait()
                if self.thread.is_alive():
                    self.thread.join(timeout=5)
            except BaseException as cleanup:
                original.add_note('intake reader-start child cleanup: '+repr(cleanup))
            finally:
                self.process.stdout.close()
                try:
                    self._spool.finish_writer()
                except BaseException as cleanup:
                    original.add_note('intake reader-start file cleanup: '+repr(cleanup))
                self._spool.close()
            raise

    def _fail(self, error):
        with self._error_lock:
            if self.error is None:
                self.error = str(error)
                if self.wake is not None:
                    self.wake.set()

    @property
    def pending_event_count(self):
        return self.events.qsize()

    @property
    def records_consumed(self):
        return self._spool.consumed if hasattr(self, '_spool') else getattr(self, '_legacy_consumed', 0)

    @property
    def reader_eof(self):
        return getattr(self, '_reader_eof', False)

    def _read(self):
        saw_eof, oversized_line = False, False
        try:
            while True:
                raw = self.process.stdout.readline(self.bounds.line_bytes + 1)
                if not raw:
                    saw_eof = True
                    break
                self.bytes_seen += len(raw)
                offset = self._spool.raw_bytes
                try:
                    retained = self._spool.write_raw(raw)
                except BaseException as error:
                    self._fail(repr(error)); retained = 0
                self.bytes_retained = self._spool.raw_bytes
                if len(raw) > self.bounds.line_bytes:
                    self._fail('raw stdout line bound exceeded; evidence incomplete')
                    oversized_line = True
                skip = oversized_line
                if oversized_line and raw.endswith(b'\n'):
                    oversized_line = False
                if retained != len(raw):
                    self._fail('raw stdout byte bound/write failed; evidence incomplete')
                    continue
                if skip:
                    continue
                try:
                    record = decode_record(raw)
                    if record is not None:
                        self.records_seen += 1
                        observed_at = time.monotonic()  # Same original post-decode observation point.
                        self._spool.publish(offset, raw, observed_at)
                        if self.wake is not None:
                            self.wake.set()
                except Exception as error:
                    self._fail(repr(error))
        except BaseException as error:
            self._fail(repr(error))
        finally:
            try:
                self.process.stdout.close()
            except BaseException as error:
                self._fail(repr(error))
            try:
                self._spool.finish_writer()
            except BaseException as error:
                self._fail(repr(error))
            self._reader_eof = saw_eof
            if self.wake is not None:
                self.wake.set()

    def consume(self, callback, *, max_records=64):
        """Fair bounded work. Callback failure does not abandon valid tail records."""
        require(type(max_records) is int and max_records > 0, 'invalid consume record budget')
        require(not getattr(self, '_consuming', False), 'reentrant intake consumption')
        first_failure, count, remaining = None, 0, self.bounds.consume_bytes
        self._consuming = True
        try:
            for _ in range(min(self.bounds.pending_events, max_records)):
                try:
                    if hasattr(self, '_spool'):
                        record, used = self._spool.pop(remaining)
                        remaining -= used
                        if record is None:
                            break
                        kind, row, observed_at = record
                    else:  # Compatibility for existing metadata-only Actor.__new__ fixtures.
                        kind, row, observed_at = self.events.get_nowait()
                        self._legacy_consumed = self.records_consumed+1
                except queue.Empty:
                    break
                except (EvidenceError, OSError, UnicodeError, ValueError) as failure:
                    self._fail(repr(failure)); break
                count += 1
                try:
                    callback(kind, row, observed_at)
                except Exception as failure:
                    if first_failure is None:
                        first_failure = failure
        finally:
            self._consuming = False
        if first_failure is not None:
            raise first_failure
        require(self.error is None, (self.role, 'incomplete endpoint observations', self.error))
        return count

    def sample_rss(self):
        if self.process.poll() is not None:
            return
        try:
            result=subprocess.run(['ps','-o','rss=','-p',str(self.process.pid)],
                capture_output=True,text=True,timeout=0.5)
            value=result.stdout.strip()
            if result.returncode!=0 or not value.isdecimal():
                self.rss_unavailable+=1
                return
            self.rss_samples+=1
            self.sampled_rss_peak_bytes=max(self.sampled_rss_peak_bytes,int(value)*1024)
        except (OSError,subprocess.TimeoutExpired):
            self.rss_unavailable+=1

    def finish(self, *, abort=False):
        """Return actual exit facts. Forced exits can never count as natural cleanup."""
        if self.process.poll() is None:
            require(abort, (self.role, 'finish requested before natural exit'))
            try:
                self.process.wait(timeout=0.75)
            except subprocess.TimeoutExpired:
                self.forced = True
                self.process.terminate()
        try:
            code = self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.forced = True
            self.process.kill()
            code = self.process.wait()
        self.thread.join(timeout=5)
        require(not self.thread.is_alive(), 'stdout did not drain after actor exit')
        if self.ended is None:
            self.ended = time.monotonic()
        return self.facts(code=code)

    def facts(self, *, code=None):
        """Refresh after final drain; finish intentionally preserves consumer FDs."""
        if code is None:
            code = self.process.poll()
        intake = self.intake_facts()
        return dict(pid=self.process.pid, exit_code=code, natural=not self.forced,
                    elapsed_seconds=(time.monotonic() if self.ended is None else self.ended)-self.started,
                    reader_error=self.error, bytes_seen=self.bytes_seen,
                    bytes_retained=self.bytes_retained, records_seen=self.records_seen,
                    pending_events=self.pending_event_count,records_consumed=self.records_consumed,
                    reader_eof=self.reader_eof,intake=intake,rss_samples=self.rss_samples,
                    sampled_rss_peak_bytes=self.sampled_rss_peak_bytes,rss_unavailable=self.rss_unavailable,
                    rss_scope='sampled OS ps residentKiB*1024; whole Godot process, NOT requested-byte quota or exact highwater')

    def intake_facts(self):
        """Current read-only cursor/identity/file proofs for post-EOF finalization."""
        result = self._spool.facts()
        result.update(records_seen=self.records_seen, bytes_seen=self.bytes_seen,
                      bytes_retained=self.bytes_retained, reader_eof=self.reader_eof)
        if result['integrity_error'] is not None:
            self._fail(result['integrity_error'])
        return result

    def close(self):
        """Idempotent consumer release; pending entries remain an explicit failure."""
        require(not self.thread.is_alive(), 'intake close while reader still active')
        if self.pending_event_count:
            self._fail('intake closed with unconsumed committed records; evidence incomplete')
        self._spool.close()
