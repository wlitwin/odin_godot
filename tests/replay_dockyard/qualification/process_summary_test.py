import unittest
import process_summary as summary


class ConservativeEnvelopeTests(unittest.TestCase):
    columns=['wall_ms','query_ns','monotonic_since_start_ns']

    def test_before_query_must_finish_before_the_call_envelope(self):
        rows=[[-10,1000000,0],[0,5000000,10000000],[9,1000000,19000000]]
        before,after=summary.brackets(rows,self.columns,2,8)
        self.assertIs(before,rows[0]);self.assertIs(after,rows[2])

    def test_after_query_must_start_after_the_call_envelope(self):
        rows=[[0,1000000,0],[7,5000000,7000000],[13,1000000,13000000]]
        before,after=summary.brackets(rows,self.columns,2,10)
        self.assertIs(before,rows[0]);self.assertIs(after,rows[2])

    def test_missing_coverage_is_not_an_imputed_zero_cpu_call(self):
        self.assertEqual(summary.brackets([[5,1000000,0]],self.columns,2,10),(None,None))

    def test_wall_step_is_reported_without_normalizing_it_away(self):
        rows=[[0,0,0],[21,0,1000000]]
        self.assertEqual(summary.clock_discrepancy_ms(rows,self.columns),20)


if __name__=='__main__':unittest.main()
