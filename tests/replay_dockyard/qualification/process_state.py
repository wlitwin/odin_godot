"""Bounded, read-only Darwin observations of one controller-verified process.

CPU totals include every process thread. They are an upper bound, not an exact
accounting of Room.frame. Layout/flavor comes from SDK sys/proc_info.h.
"""
import ctypes
import json
import os
from collections import deque
import threading
import time


class TaskInfo(ctypes.Structure):
    _fields_=[(name,ctypes.c_uint64) for name in ['virtual','resident','user','system','threads_user','threads_system']]+[
      (name,ctypes.c_int32) for name in ['policy','faults','pageins','cow_faults','messages_sent','messages_received','mach_syscalls','unix_syscalls','context_switches','thread_count','running_threads','priority']]


class Timebase(ctypes.Structure):
    _fields_=[('numer',ctypes.c_uint32),('denom',ctypes.c_uint32)]


class Accessor:
    def __init__(self):
        if ctypes.sizeof(TaskInfo)!=96:raise RuntimeError('unsupported proc_taskinfo layout')
        self.lib=ctypes.CDLL('/usr/lib/libproc.dylib',use_errno=True)
        self.lib.proc_pidinfo.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_uint64,ctypes.c_void_p,ctypes.c_int]
        self.lib.proc_pidinfo.restype=ctypes.c_int
        system=ctypes.CDLL('/usr/lib/libSystem.B.dylib');self.timebase=Timebase()
        system.mach_timebase_info.argtypes=[ctypes.POINTER(Timebase)]
        if system.mach_timebase_info(ctypes.byref(self.timebase))!=0 or not self.timebase.numer or not self.timebase.denom:
            raise RuntimeError('Mach timebase unavailable')

    def read(self,pid):
        info=TaskInfo();ctypes.set_errno(0)
        count=self.lib.proc_pidinfo(pid,4,0,ctypes.byref(info),ctypes.sizeof(info))
        if count!=ctypes.sizeof(info):raise OSError(ctypes.get_errno(),f'proc task read returned {count} bytes')
        return info

    def cpu_ns(self,raw):
        return raw*self.timebase.numer//self.timebase.denom


def calibrate():
    api=Accessor();before=api.read(os.getpid());start_cpu=time.process_time_ns();until=time.perf_counter()+.1;work=0
    while time.perf_counter()<until:work=(work*17+1)%10000019
    cpu_ns=time.process_time_ns()-start_cpu;after=api.read(os.getpid())
    raw_delta=after.user+after.system-before.user-before.system;delta=api.cpu_ns(raw_delta);ratio=delta/cpu_ns
    if not .95<=ratio<=1.05:raise RuntimeError(f'CPU counter nanosecond calibration failed: {ratio}')
    return dict(result='SELF_PROCESS_ONLY',layout_bytes=ctypes.sizeof(TaskInfo),observed_raw_cpu_units='Mach ticks; conversion validated on this host',
      mach_timebase=dict(numer=api.timebase.numer,denom=api.timebase.denom),python_process_cpu_ns=cpu_ns,proc_cpu_delta_raw=raw_delta,converted_cpu_ns=delta,ratio=ratio)


class Sampler:
    columns=['wall_ms','monotonic_since_start_ns','query_ns','user_ticks','system_ticks','faults','pageins','cow_faults','context_switches','running_threads','priority','resident_bytes']
    def __init__(self,pid,capacity=8192):
        if not 1<=capacity<=8192:raise ValueError('capacity beyond8192-row bound')
        self.pid=pid;self.api=Accessor();self.rows=deque(maxlen=capacity);self.stop_event=threading.Event()
        self.error=None;self.total=0;self.started_ns=time.monotonic_ns();self.thread=threading.Thread(target=self.run,daemon=True)

    def start(self):
        self.api.read(self.pid);self.thread.start()

    def run(self):
        previous=None
        try:
            while not self.stop_event.is_set():
                before=time.monotonic_ns();wall=time.time_ns()/1e6;info=self.api.read(self.pid);after=time.monotonic_ns()
                cpu=info.user+info.system
                if previous is not None and cpu<previous:raise RuntimeError('process CPU counter regressed')
                previous=cpu;self.rows.append([wall,before-self.started_ns,after-before,info.user,info.system,info.faults,info.pageins,info.cow_faults,info.context_switches,info.running_threads,info.priority,info.resident]);self.total+=1
                self.stop_event.wait(.001)
        except Exception as exc:self.error=repr(exc)

    def finish(self,path,metadata):
        self.stop_event.set();self.thread.join()
        result=dict(schema_version=1,result='PROCESS_OBSERVATIONS_NOT_ADMISSION',target_pid=self.pid,
          cpu_timebase=dict(numer=self.api.timebase.numer,denom=self.api.timebase.denom,conversion='raw ticks * numer / denom = nanoseconds; validated by self calibration'),
          observed_scope='All threads in one controller-verified Firefox content process',columns=self.columns,
          rows=list(self.rows),total_observations=self.total,retained_rows=len(self.rows),capacity=self.rows.maxlen,error=self.error,metadata=metadata,
          limitations=['Process CPU includes rendering, JIT, GC and other threads; it is not exact Room.frame CPU.',
            'Read-only observations may perturb scheduling and may themselves have gaps.',
            'Counters and running-thread counts do not identify a complete wait or scheduling history.',
            'No wall-time subtraction, cause or unprofiled qualification is inferred.'])
        encoded=json.dumps(result,separators=(',',':')).encode()
        if len(encoded)>8*1024*1024:raise RuntimeError('observer output exceeds8MiB')
        with path.open('xb') as stream:stream.write(encoded);stream.write(b'\n')
        return result


if __name__=='__main__':print(json.dumps(calibrate()))
