"""Bounds comparisons and the explicit ~ adaptation in the APL expression engine."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'reader'))
from apl import Expression, Interval, Unknown  # noqa: E402

TTD = Interval(12., 40., 'TTD')
OPEN = Interval(12., math.inf, 'fight')


def run(text, **values):
    names = dict({'ttd': TTD, 'fight': OPEN, 'missing': Unknown(frozenset(['x']))}, **values)
    return Expression(text).evaluate(lambda name: names[name])


class IntervalTest(unittest.TestCase):
    def test_decided_comparisons(self):
        self.assertIs(run('ttd>10'), True)
        self.assertIs(run('ttd<10'), False)
        self.assertIs(run('ttd<=40'), True)
        self.assertIs(run('10<ttd'), True, 'bounds on the right side are mirrored')
        self.assertIs(run('fight>8'), True)

    def test_undecided_is_unknown(self):
        self.assertIsInstance(run('ttd>20'), Unknown)
        self.assertIsInstance(run('fight<30'), Unknown, 'no upper bound: the end of the fight is unseen')
        self.assertIsInstance(run('ttd*2>10'), Unknown, 'no arithmetic on bounds')

    def test_tilde_adaptation(self):
        self.assertIs(run('~(ttd>20)'), False, 'undecided -> false')
        self.assertIs(run('~(ttd>10)'), True)
        self.assertIs(run('~(missing)'), False)
        self.assertIs(run('!~(!(fight>30))'), True, 'undecided fight_remains>30 -> the fight continues')
        self.assertIs(run('!~(!(fight>8))'), True)
        self.assertIs(run('!~(!(ttd>50))'), False, 'decided false stays false')


if __name__ == '__main__':
    unittest.main()
