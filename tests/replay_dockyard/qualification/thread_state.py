"""Bounded, read-only Darwin thread observations for an owned test process.

The controller must verify ownership before constructing a sampler. These
observations are diagnostic and never qualify the uninstrumented frame budget.
Layout/flavors: the installed SDK's sys/proc_info.h and libproc.h.
"""
import ctypes
import json
import os
from collections import deque
import threading
import time


class ThreadInfo(ctypes.Structure):
    _fields_=[('user',ctypes.c_uint64),('system',ctypes.c_uint64)]+[
      (name,ctypes.c_int32) for name in ['cpu','policy','state','flags','sleep','current_priority','priority','max_priority']]+[('name',ctypes.c_char*64)]


class Accessor:
    def __init__(self):
        if ctypes.sizeof(ThreadInfo)!=112:raise RuntimeError('unsupported proc_threadinfo layout')
        self.lib=ctypes.CDLL('/usr/lib/libproc.dylib',use_errno=True)
        self.lib.proc_pidinfo.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_uint64,ctypes.c_void_p,ctypes.c_int]
        self.lib.proc_pidinfo.restype=ctypes.c_int

    def read(self,pid,handle,flavor=5):
        info=ThreadInfo();ctypes.set_errno(0)
        count=self.lib.proc_pidinfo(pid,flavor,handle,ctypes.byref(info),ctypes.sizeof(info))
        if count!=ctypes.sizeof(info):raise OSError(ctypes.get_errno(),f'proc thread read returned {count} bytes')
        return info

    def named_thread(self,pid,name):
        handles=(ctypes.c_uint64*512)();count=self.lib.proc_pidinfo(pid,6,0,handles,ctypes.sizeof(handles))
        if count<=0 or count%8 or count>=ctypes.sizeof(handles):raise RuntimeError('thread list unavailable or beyond512-thread bound')
        matches=[]
        for handle in list(handles)[:count//8]:
            info=self.read(pid,handle)
            if info.name.decode(errors='replace')==name:matches.append((handle,info))
        if len(matches)!=1:raise RuntimeError(f'exactly one owned {name} thread required, found{len(matches)}')
        return matches[0]


def calibrate():
    api=Accessor();lib=ctypes.CDLL('/usr/lib/libSystem.B.dylib');identifier=ctypes.c_uint64()
    lib.pthread_threadid_np.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint64)]
    if lib.pthread_threadid_np(None,ctypes.byref(identifier))!=0:raise RuntimeError('self thread identifier unavailable')
    before=api.read(os.getpid(),identifier.value,15);start_cpu=time.thread_time_ns();until=time.perf_counter()+.1;work=0
    while time.perf_counter()<until:work=(work*17+1)%10000019
    cpu_ns=time.thread_time_ns()-start_cpu;after=api.read(os.getpid(),identifier.value,15)
    delta=after.user+after.system-before.user-before.system;ratio=delta/cpu_ns
    if not .95<=ratio<=1.05:raise RuntimeError(f'CPU counter nanosecond calibration failed: {ratio}')
    return dict(result='SELF_PROCESS_ONLY',layout_bytes=ctypes.sizeof(ThreadInfo),observed_cpu_units='ns',
      python_thread_cpu_ns=cpu_ns,proc_cpu_delta_raw=delta,ratio=ratio)


class Sampler:
    columns=['wall_ms','monotonic_since_start_ns','query_ns','user_ns','system_ns','run_state','current_priority','priority','cpu_usage_raw','flags']
    def __init__(self,pid,handle,capacity=8192):
        if not 1<=capacity<=8192:raise ValueError('capacity beyond8192-row bound')
        self.pid=pid;self.handle=handle;self.api=Accessor();self.rows=deque(maxlen=capacity)
        self.stop_event=threading.Event();self.error=None;self.total=0;self.started_ns=time.monotonic_ns();self.thread=threading.Thread(target=self.run,daemon=True)

    def start(self):
        self.api.read(self.pid,self.handle)
        self.thread.start()

    def run(self):
        previous=None
        try:
            while not self.stop_event.is_set():
                before=time.monotonic_ns();wall=time.time_ns()/1e6;info=self.api.read(self.pid,self.handle);after=time.monotonic_ns()
                cpu=info.user+info.system
                if previous is not None and cpu<previous:raise RuntimeError('thread CPU counter regressed')
                previous=cpu
                self.rows.append([wall,before-self.started_ns,after-before,info.user,info.system,info.state,info.current_priority,info.priority,info.cpu,info.flags]);self.total+=1
                # Record real observation intervals. There is no fabricated
                # sample or compensation when the observer wakes up late.
                self.stop_event.wait(.001)
        except Exception as exc:self.error=repr(exc)

    def finish(self,path,metadata):
        self.stop_event.set();self.thread.join()
        result=dict(schema_version=1,result='THREAD_OBSERVATIONS_NOT_ADMISSION',target_pid=self.pid,
          thread_handle_hex=f'{self.handle:016x}',columns=self.columns,rows=list(self.rows),total_observations=self.total,
          retained_rows=len(self.rows),capacity=self.rows.maxlen,error=self.error,metadata=metadata,
          limitations=['Read-only observations may perturb scheduling and may themselves have gaps.',
            'Observed thread states are snapshots, not a complete context-switch history.',
            'CPU totals are cumulative counters calibrated on the observer process; no wall time is subtracted.',
            'The controller must verify target ownership; no unprofiled qualification or cause is inferred.'])
        encoded=json.dumps(result,separators=(',',':')).encode()
        if len(encoded)>8*1024*1024:raise RuntimeError('observer output exceeds8MiB')
        with path.open('xb') as stream:stream.write(encoded);stream.write(b'\n')
        return result


if __name__=='__main__':print(json.dumps(calibrate()))
