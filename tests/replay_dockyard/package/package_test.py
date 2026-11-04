"""Synthetic byte/transaction checks, not game/runtime qualification."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('dockyard_package',ROOT/'examples/replay_dockyard/package.py')
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name);self.export=self.base/'input/export';self.export.mkdir(parents=True)
        (self.export/'index.html').write_bytes(b'opaque synthetic export bytes')
        self.record=self.base/'input/report.json';self.record.write_text(json.dumps({'result':'EXPORTED_BROWSER_PENDING','export_files':tool.files(self.export)}))
        self.qa=self.base/'qa.json';self.qa.write_text(json.dumps({'result':'SYNTHETIC_NOT_QUALIFIED'}))
        self.runtime=self.base/'runtime/report.json';self.runtime.parent.mkdir()
        self.runtime.write_text(json.dumps({'result':'SYNTHETIC_NOT_GAMEPLAY','all_five_byte_equal':True,'host':{'cohort':'1234567890abcdef'},'client':{'cohort':'1234567890abcdef'}}))
        (self.runtime.parent/'export-binding.json').write_text(json.dumps({'actual_exit':0,'export_record_sha256':tool.sha(self.record),'export_unchanged':True}))
        self.out=self.base/'candidate'
    def tearDown(self):self.temp.cleanup()
    def collect(self):return tool.package(self.record,self.out,self.qa,runtime_report=self.runtime)
    def test_exact_bytes_cohort_and_not_released(self):
        self.collect();r=tool.verify(self.out)
        self.assertFalse(r['release_admitted']);self.assertEqual(r['web_cohort'],'1234567890abcdef')
        self.assertEqual((self.out/'web/index.html').read_bytes(),(self.export/'index.html').read_bytes())
        self.assertIn('REPLAY_ROOM_CONTENT=0x1234567890abcdef',(self.out/'operator/service.env.example').read_text())
    def test_changed_export_is_rejected_before_publication(self):
        (self.export/'index.html').write_bytes(b'changed')
        with self.assertRaises(ValueError):self.collect()
        self.assertFalse(self.out.exists())
    def test_symlink_input_is_rejected(self):
        (self.export/'index.html').unlink();(self.export/'index.html').symlink_to(self.qa)
        with self.assertRaises(ValueError):self.collect()
        self.assertFalse(self.out.exists())
    def test_existing_output_is_preserved_and_corruption_detected(self):
        self.collect();before=tool.sha(self.out/'manifest.json')
        with self.assertRaises(ValueError):self.collect()
        self.assertEqual(before,tool.sha(self.out/'manifest.json'))
        (self.out/'web/index.html').write_bytes(b'corrupt')
        with self.assertRaises(ValueError):tool.verify(self.out)
    def test_wrong_runtime_binding_does_not_rebind_export(self):
        (self.runtime.parent/'export-binding.json').write_text(json.dumps({'actual_exit':0,'export_record_sha256':'0'*64,'export_unchanged':True}))
        with self.assertRaises(ValueError):self.collect()
        self.assertFalse(self.out.exists())
    def test_manifest_pin_rejects_rewritten_manifest(self):
        self.collect();pin=tool.sha(self.out/'manifest.json')
        value=json.loads((self.out/'manifest.json').read_text());value['qualification_result']='changed'
        (self.out/'manifest.json').write_text(json.dumps(value))
        with self.assertRaises(ValueError):tool.verify(self.out,pin)
    def test_custom_template_record_pin_is_required(self):
        template=self.base/'template-record.json';template.write_text('{}')
        record=json.loads(self.record.read_text())
        record['custom_web_template']={'record':str(template),'record_sha256':'0'*64}
        self.record.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError,'template record pin'):self.collect()
        self.assertFalse(self.out.exists())
    def test_compiled_notices_are_preserved_and_incomplete_input_refused(self):
        notices=self.base/'notices';notices.mkdir()
        license_file=notices/'godot-license.txt';license_file.write_text('Synthetic license notice')
        record={'version':{'string':'synthetic'},'copyright_info':[{'name':'synthetic'}],'license_info':{'synthetic':'license'}}
        (notices/'godot-compiled-notices.json').write_text(json.dumps(record))
        tool.package(self.record,self.out,self.qa,runtime_report=self.runtime,godot_notices=notices)
        tool.verify(self.out)
        self.assertEqual((self.out/'licenses/godot-license.txt').read_bytes(),license_file.read_bytes())
        self.assertEqual(json.loads((self.out/'licenses/godot-compiled-notices.json').read_text()),record)
        license_file.write_text('')
        rejected=self.base/'incomplete'
        with self.assertRaisesRegex(ValueError,'complete compiled Godot notices'):
            tool.package(self.record,rejected,self.qa,runtime_report=self.runtime,godot_notices=notices)
        self.assertFalse(rejected.exists())

if __name__=='__main__':unittest.main()
