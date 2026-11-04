import unittest
import trigger_summary as summary

class MarkerFormatTests(unittest.TestCase):
    def thread(self,rows):
        return dict(stringTable=['work'],markers=dict(schema=dict(name=0,startTime=1,endTime=2,phase=3,data=4),data=rows))
    def test_unused_phase_times_do_not_create_false_long_intervals(self):
        rows=[[0,10,0,0],[0,12,0,2],[0,0,17,3]]
        intervals=summary.marker_intervals(self.thread(rows))
        self.assertEqual([(r['start'],r['end'],r['boundary']) for r in intervals],[(10,10,'instant'),(12,17,'paired_interval')])
    def test_missing_ring_boundaries_stay_explicit(self):
        rows=[[0,0,8,3],[0,15,0,2]]
        intervals=summary.marker_intervals(self.thread(rows))
        self.assertEqual([(r['start'],r['end'],r['boundary']) for r in intervals],[(8,8,'unmatched_end'),(15,15,'unmatched_start')])
    def test_nested_same_name_intervals_pair_in_order(self):
        rows=[[0,0,0,2],[0,2,0,2],[0,0,5,3],[0,0,9,3]]
        intervals=summary.marker_intervals(self.thread(rows))
        self.assertEqual([(r['start'],r['end']) for r in intervals],[(2,5),(0,9)])
    def test_sparse_trailing_columns_are_optional(self):
        self.assertIsNone(summary.value([1,2],dict(cpu=4),'cpu'))
        self.assertEqual(summary.value([1,2],dict(cpu=4),'cpu',0),0)
        self.assertEqual(summary.marker_intervals(self.thread([[0,0,7,1]]))[0]['start'],0)

if __name__=='__main__':unittest.main()
