"""Pure SQLite/index controls; no process, Native, clock or throughput claim."""
import sqlite3
import unittest
import zlib

import test_rolling as fixture
from test_rolling import SOURCE, signature_for
from rolling import EvidenceError, EvidenceHold, ProcessScope


HOT_QUERY = 'SELECT count(*) FROM pending_required_frames WHERE role=?'
OLD_HOT_QUERY = '''SELECT count(*) FROM frames f WHERE role=? AND NOT EXISTS(
    SELECT 1 FROM matches m WHERE m.role=f.role AND m.scope=f.scope
    AND m.epoch=f.epoch AND m.tick=f.tick)'''


class IndexControls(unittest.TestCase):
    # Reuse only the existing pure storage fixture methods, not its test cases.
    setUp = fixture.Controls.setUp
    frame = fixture.Controls.frame
    pair = fixture.Controls.pair
    exits = fixture.Controls.exits

    def store(self, **kwargs):
        # This test fixture explicitly predeclares its synthetic identity so
        # follower-first HOLD/index transitions do not invent authority truth.
        identity = signature_for((b'solver', b'game', b'side', b'obs', b'events'), 1, 0)[16:232].hex()
        return fixture.Controls.store(self, expected_identity_hex=identity, **kwargs)

    def pending(self, store):
        return {tuple(x) for x in store.db.execute(
            'SELECT role,scope,epoch,tick FROM pending_required_frames')}

    def equivalent(self, store):
        expected = {tuple(x) for x in store.db.execute('''SELECT role,scope,epoch,tick
            FROM frames f WHERE role!='host' AND NOT EXISTS(SELECT 1 FROM matches m
            WHERE m.role=f.role AND m.scope=f.scope AND m.epoch=f.epoch AND m.tick=f.tick)''')}
        self.assertEqual(self.pending(store), expected)
        self.assertEqual(store._pending_required_findings(), [])

    def opcodes(self, store, query, args):
        count = 0
        def observe():
            nonlocal count
            count += 1
            return 0
        store.db.set_progress_handler(observe, 1)
        try:
            value = store.db.execute(query, args).fetchall()
        finally:
            store.db.set_progress_handler(None, 0)
        return value, count

    def history(self, store, count=6000):
        """Synthetic SQL metadata only, never a full-state/receipt acceptance.

        Bulk insertion avoids making thousands of durability calls just to
        establish a query-planner control. Public mutation/rollback/receipt
        invariants are tested separately below and in test_rolling.py.
        """
        parts = (b'solver', b'game', b'side', b'observations', b'occurrences')
        payload = zlib.compress(b''.join(parts))
        with store._transaction():
            for tick in range(1, count+1):
                ep, value = f'{1:016x}', f'{tick:016x}'
                sig = signature_for(parts, 1, tick)
                for role in ('host', 'client'):
                    retired = int(role == 'host' or tick <= count//2)
                    store.db.execute('INSERT INTO frames VALUES(?,?,?,?,?,?,?,?)',
                        (role, role+'-g1', ep, value, sig, None if retired else payload, '{}', retired))
                # Deliberately no claimed comparison receipts: this fixture is
                # used ONLY for exact derived-set and VM/query-plan controls.
                store.db.execute('INSERT INTO matches VALUES(?,?,?,?,?)',
                    ('client', 'client-g1', ep, value, -1))

    def test_exact_hot_count_bounded_over_retired_and_matched_unretired_history(self):
        s = self.store(frame_policy='all_follower_exports_required', max_hot_frames=3)
        for tick in (10001, 10002, 10003):
            s.register_frame('client', 'client-g1', self.frame(tick))
        before, before_ops = self.opcodes(s, HOT_QUERY, ('client',))
        self.history(s)
        self.equivalent(s)
        current, current_ops = self.opcodes(s, HOT_QUERY, ('client',))
        old, old_ops = self.opcodes(s, OLD_HOT_QUERY, ('client',))
        self.assertEqual(before, current)
        self.assertEqual(current, old)
        self.assertEqual(current[0][0], 3)
        self.assertEqual(before_ops, current_ops)
        self.assertLess(current_ops, 128)
        self.assertGreater(old_ops, 6000)
        self.assertGreater(old_ops, current_ops*100)
        with self.assertRaises(EvidenceHold):
            s.register_frame('client', 'client-g1', self.frame(10004))

    def test_tick_lookup_plans_search_index_and_vm_work_is_history_independent(self):
        s = self.store(frame_policy='all_follower_exports_required')
        s.register_frame('client', 'client-g1', self.frame(10001))
        query = 'SELECT * FROM frames WHERE role!=? AND epoch=? AND tick=? ORDER BY rowid'
        args = ('host', f'{1:016x}', f'{10001:016x}')
        before, before_ops = self.opcodes(s, query, args)
        self.history(s)
        after, after_ops = self.opcodes(s, query, args)
        self.assertEqual([tuple(x) for x in before], [tuple(x) for x in after])
        # SQLite may switch from a tiny-table plan to the tick index; the
        # growing retained history must not increase candidate-walk work.
        self.assertLessEqual(after_ops, before_ops)
        self.assertLess(after_ops, 128)
        plan = [str(x['detail']) for x in s.db.execute('EXPLAIN QUERY PLAN '+query, args)]
        self.assertTrue(any('SEARCH' in x and 'frames_tick_lookup' in x for x in plan), plan)
        self.assertFalse(any('SCAN frames' in x for x in plan), plan)
        authority = 'SELECT * FROM frames WHERE role=? AND epoch=? AND tick=? ORDER BY scope LIMIT 1'
        plan = [str(x['detail']) for x in s.db.execute('EXPLAIN QUERY PLAN '+authority, args)]
        self.assertTrue(any('frames_tick_lookup' in x and 'SEARCH' in x for x in plan), plan)
        plan = [str(x['detail']) for x in s.db.execute('EXPLAIN QUERY PLAN '+HOT_QUERY, ('client',))]
        self.assertTrue(any('SEARCH' in x and 'pending_required_frames' in x for x in plan), plan)
        self.assertEqual(s.db.execute('PRAGMA synchronous').fetchone()[0], 2)
        self.assertEqual(s.db.execute('PRAGMA journal_mode').fetchone()[0], 'delete')
        self.assertLessEqual(s.db.execute('PRAGMA page_count').fetchone()[0], s.normal_pages)

    def test_duplicate_hold_first_match_and_retire_never_double_remove(self):
        s = self.store(frame_policy='all_follower_exports_required', max_hot_frames=1)
        b = s.register_frame('client', 'client-g1', self.frame(1)).frames[0]
        self.equivalent(s)
        self.assertEqual(s.register_frame('client', 'client-g1', self.frame(1)).state, 'duplicate')
        self.assertEqual(s.compare_and_seal(b).state, 'hold')
        with self.assertRaises(EvidenceHold):s.retire(b)
        self.equivalent(s)
        self.assertEqual(len(self.pending(s)), 1)
        s.register_frame('host', 'host-g1', self.frame(1))
        s.compare_and_seal(b); self.equivalent(s)
        count = s.db.execute('SELECT count(*) FROM receipts').fetchone()[0]
        s.compare_and_seal(b); s.retire(b); s.retire(b)
        self.assertEqual(s.db.execute('SELECT count(*) FROM receipts').fetchone()[0], count)
        self.assertEqual(len(self.pending(s)), 0)
        s.register_frame('client', 'client-g1', self.frame(2)); self.equivalent(s)

    def test_matched_unretired_frees_only_optin_required_capacity(self):
        optional = self.store(frame_policy='all_follower_exports_required', max_hot_frames=1)
        self.pair(optional)
        optional.register_frame('client', 'client-g1', self.frame(2))
        self.equivalent(optional)
        strict = self.store(max_hot_frames=1)
        a, b = self.pair(strict)
        self.assertEqual(self.pending(strict), set())
        with self.assertRaises(EvidenceHold):strict.register_frame('client', 'client-g1', self.frame(2))
        with self.assertRaises(EvidenceHold):strict.register_frame('host', 'host-g1', self.frame(2))
        strict.retire(b); strict.register_frame('client', 'client-g1', self.frame(2))

    def test_scope_epoch_keys_and_same_tick_receipt_insertion_order(self):
        s = self.store(frame_policy='all_follower_exports_required', max_hot_frames=3)
        s.register_process(ProcessScope('client', 'client-a', 3, SOURCE, 1, 0))
        s.register_frame('client', 'client-g1', self.frame(1))
        s.register_frame('client', 'client-a', self.frame(1))
        s.register_frame('client', 'client-g1', self.frame(1, epoch=2))
        self.assertEqual(len(self.pending(s)), 3); self.equivalent(s)
        a = s.register_frame('host', 'host-g1', self.frame(1)).frames[0]
        result = s.compare_and_seal(a)
        self.assertEqual([x.scope_id for x in result.frames], ['client-g1', 'client-a'])
        self.assertEqual(len(self.pending(s)), 1); self.equivalent(s)
        a = s.register_frame('host', 'host-g1', self.frame(1, epoch=2)).frames[0]
        s.compare_and_seal(a); self.assertEqual(self.pending(s), set()); self.equivalent(s)

    def test_insert_and_first_match_rollback_preserve_raw_pending_and_receipts(self):
        s = self.store(frame_policy='all_follower_exports_required')
        s.db.execute("CREATE TEMP TRIGGER fail_pending BEFORE INSERT ON pending_required_frames BEGIN SELECT RAISE(ABORT,'injected'); END")
        with self.assertRaises(EvidenceError):s.register_frame('client', 'client-g1', self.frame(1))
        self.assertEqual(s.db.execute('SELECT count(*) FROM frames').fetchone()[0], 0)
        self.assertEqual(self.pending(s), set())
        s.db.execute('DROP TRIGGER fail_pending')
        s.register_frame('host', 'host-g1', self.frame(1))
        b = s.register_frame('client', 'client-g1', self.frame(1)).frames[0]
        receipts = s.db.execute('SELECT count(*) FROM receipts').fetchone()[0]
        payload = s.db.execute("SELECT payload FROM frames WHERE role='client'").fetchone()[0]
        s.db.execute("CREATE TEMP TRIGGER fail_pending BEFORE DELETE ON pending_required_frames BEGIN SELECT RAISE(ABORT,'injected'); END")
        with self.assertRaises(EvidenceError):s.compare_and_seal(b)
        self.assertEqual(s.db.execute('SELECT count(*) FROM matches').fetchone()[0], 0)
        self.assertEqual(s.db.execute('SELECT count(*) FROM canonical_frames').fetchone()[0], 0)
        self.assertEqual(s.db.execute('SELECT count(*) FROM receipts').fetchone()[0], receipts)
        self.assertEqual(s.db.execute("SELECT payload FROM frames WHERE role='client'").fetchone()[0], payload)
        self.equivalent(s)
        s.db.execute('DROP TRIGGER fail_pending'); s.compare_and_seal(b); self.equivalent(s)

    def test_pending_drift_and_retired_unmatched_are_finalize_failures(self):
        for change, message in (
            ("INSERT INTO pending_required_frames VALUES('client','orphan','0000000000000001','0000000000000002')", 'orphan'),
            ("INSERT INTO pending_required_frames SELECT role,scope,epoch,tick FROM frames WHERE role='client'", 'matched row'),
            ("INSERT INTO pending_required_frames SELECT role,scope,epoch,tick FROM frames WHERE role='host'", 'authority row')):
            s = self.store(frame_policy='all_follower_exports_required'); self.pair(s); self.exits(s)
            s.db.execute(change); s.db.commit()
            result = s.finalize()
            with self.subTest(change=change):
                self.assertEqual(result['result'], 'FAIL')
                self.assertTrue(any(message in x for x in result['findings']))
        for change, message in (("DELETE FROM pending_required_frames", 'missing unmatched'),
                                ("UPDATE frames SET retired=1 WHERE role='client'", 'retired unmatched')):
            s = self.store(frame_policy='all_follower_exports_required')
            s.register_frame('client', 'client-g1', self.frame(1))
            s.db.execute(change); s.db.commit()
            result = s.finalize()
            with self.subTest(change=change):
                self.assertEqual(result['result'], 'FAIL')
                self.assertTrue(any(message in x for x in result['findings']))
        s = self.store(); self.pair(s); self.exits(s)
        s.db.execute("INSERT INTO pending_required_frames VALUES('client','client-g1','0000000000000001','0000000000000001')"); s.db.commit()
        self.assertTrue(any('strict policy' in x for x in s.finalize()['findings']))

    def test_missing_pending_first_match_cannot_publish_receipt(self):
        s = self.store(frame_policy='all_follower_exports_required')
        s.register_frame('host', 'host-g1', self.frame(1))
        b = s.register_frame('client', 'client-g1', self.frame(1)).frames[0]
        s.db.execute('DELETE FROM pending_required_frames'); s.db.commit()
        receipts = s.db.execute('SELECT count(*) FROM receipts').fetchone()[0]
        with self.assertRaises(EvidenceError):s.compare_and_seal(b)
        self.assertEqual(s.db.execute('SELECT count(*) FROM matches').fetchone()[0], 0)
        self.assertEqual(s.db.execute('SELECT count(*) FROM receipts').fetchone()[0], receipts)
        self.assertTrue(any('missing unmatched' in x for x in s.finalize()['findings']))


if __name__ == '__main__':unittest.main()
