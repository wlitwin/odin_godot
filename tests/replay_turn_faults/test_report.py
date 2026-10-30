"""Receipt mutations: run against a completed real fault recording, not synthetic play."""
import contextlib,io,json,shutil,tempfile,unittest,sys
from pathlib import Path
from report import report
SOURCE=Path(sys.argv.pop(1)).resolve() if len(sys.argv)>1 else None
class Tests(unittest.TestCase):
    def test_rejects_bad_evidence(self):
        self.assertIsNotNone(SOURCE,'supply completed real fault output directory')
        cases=[('receipt',lambda r:r.update(enabled=False)),('receipt',lambda r:r.update(refused_flows=1)),('receipt',lambda r:r.update(errors=['failure'])),('receipt',lambda r:r['flows'][0]['up'].update(forwarded=0)),('receipt',lambda r:r['flows'][0]['up'].update(peak_packets=999999)),('receipt',lambda r:r['flows'][0]['up'].update(socket_errors=1)),('relay',lambda r:r[0]['rows'][0].update(local='host')),('relay',lambda r:r[0]['rows'][0].update(relayProtocol='tcp')),('relay',lambda r:r[0]['rows'][0].update(bytesReceived=0)),('game',lambda r:r.update(exact=False)),('game',lambda r:r.update(solver_seeded=False)),('game',lambda r:r.update(continued_kicks_and_goal=False)),('ready',lambda r:r['config'].update(loss=1))]
        with tempfile.TemporaryDirectory() as work:
            root=Path(work);(root/'proxy').mkdir();(root/'game/browser').mkdir(parents=True)
            files=['faults.json','proxy/ready.json','proxy/receipt.json','proxy/packets.jsonl','turn.log','game/browser/relay.json']+[str(p.relative_to(SOURCE)) for p in (SOURCE/'game/browser').glob('*-result.json')]
            for rel in files:shutil.copyfile(SOURCE/rel,root/rel)
            paths={'receipt':root/'proxy/receipt.json','relay':root/'game/browser/relay.json','game':next((root/'game/browser').glob('*-result.json')),'ready':root/'proxy/ready.json'}
            with contextlib.redirect_stdout(io.StringIO()):report(root)
            for index,(kind,mutate) in enumerate(cases):
                path=paths[kind];original=path.read_bytes();value=json.loads(original);mutate(value);path.write_text(json.dumps(value))
                try:
                    with self.subTest(case=index,kind=kind),self.assertRaises(AssertionError),contextlib.redirect_stdout(io.StringIO()):report(root)
                finally:path.write_bytes(original)
        print('REPLAY_TURN_REPORT_MUTATIONS_OK',len(cases))
if __name__=='__main__':unittest.main()
