from pathlib import Path
import os
import subprocess
import sys
import time
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'replay/testing/tools'))
from peers import Peer,run
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=False)
def peer(name,code):return Peer(name,[sys.executable,'-u','-c',code],dict(os.environ),('READY',))
result=run([peer('a','print("READY hash=42")'),peer('b','print("READY hash=42")')],out/'equal',stagger=0,hash_pattern=r'hash=(\d+)')
assert result['hashes']=={'a':'42','b':'42'}
try:
 run([peer('a','print("READY hash=42")'),peer('b','print("READY hash=43")')],out/'mismatch',stagger=0,hash_pattern=r'hash=(\d+)')
except AssertionError as error:assert 'hashes differ' in str(error)
else:raise AssertionError('mismatch accepted')
start=time.monotonic()
try:run([peer('slow','import time; print("READY"); time.sleep(60)')],out/'timeout',timeout=.2,stagger=0)
except subprocess.TimeoutExpired:pass
else:raise AssertionError('timeout accepted')
assert time.monotonic()-start<5 and (out/'timeout/slow.log').exists()
try:run([peer('bad','print("READY ERROR: deliberate")')],out/'error',stagger=0)
except AssertionError:pass
else:raise AssertionError('error log accepted')
print('REPLAY_PEER_HARNESS_OK equality=true mismatch=true timeout=true logs=true errors=true')
