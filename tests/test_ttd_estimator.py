"""TTD bounds from synthetic frames: flag colour + OCR target health percent."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'reader'))
from ttd_estimator import TTDEstimator  # noqa: E402


def frame(t, flag, hp=None, hp_at=None):
    data = {'capturedAt': t, 'rows': {'context/targetGeneration': {'state': flag}}, 'numbers': {}}
    if hp is not None:
        at = t if hp_at is None else hp_at
        data['numbers']['resource/targetHealthPercent'] = {'value': hp, 'capturedAt': at, 'expiresAt': at + 1.5}
    return data


def run(est, start, seconds, flag, hp0, rate, step=.5, t0=None):
    """Feed frames every 0.1 s, health OCR every `step` s losing `rate` %/s."""
    t0 = start if t0 is None else t0
    out, t, next_ocr, cached = None, start, start, None
    while t <= start + seconds + 1e-9:
        if t >= next_ocr - 1e-9:
            cached = (round(max(hp0 - rate * (t - t0), 0), 1), t)
            next_ocr += step
        out = est.update(frame(t, flag, cached[0], cached[1]))
        t = round(t + .1, 3)
    return out


class TTDEstimatorTest(unittest.TestCase):
    def test_bounds_contain_truth(self):
        est = TTDEstimator()
        out = run(est, 0., 6., 'g0', 60., 1.)          # true TTD at 6 s: 54 s
        self.assertEqual(out['status'], 'estimate')
        self.assertLess(out['low'], 54)
        self.assertGreater(out['low'], 10, 'a slowly dying target must be decidable as >10 s')
        self.assertGreater(out['high'], 54)
        # The safety factor keeps a 14 s target undecided against 10 s.
        out = run(TTDEstimator(), 0., 6., 'g0', 40., 2.)
        self.assertTrue(out['low'] < 10 < out['high'])

    def test_warming_after_target_change(self):
        est = TTDEstimator()
        run(est, 0., 6., 'g0', 60., 2.)
        out = run(est, 6.1, 1., 'g1', 90., 1.)
        self.assertEqual(out['status'], 'warming')
        self.assertTrue(all(h >= 89 for _, h in est.samples), 'old target samples must be dropped')

    def test_late_ocr_of_old_target_is_rejected(self):
        est = TTDEstimator()
        run(est, 0., 4., 'g0', 60., 2.)
        # Switch at 4.1; OCR result still from the 4.0 frame (old target).
        est.update(frame(4.1, 'g1', 52., 4.0))
        self.assertEqual(est.samples, [])

    def test_unreadable_flag_frame_sample_is_rejected(self):
        est = TTDEstimator()
        run(est, 0., 3., 'g0', 60., 2.)
        count = len(est.samples)
        out = est.update(frame(3.1, 'unknown', 53.8))
        self.assertEqual(out['status'], 'flag_unknown')
        est.update(frame(3.2, 'g0', 53.6, 3.1))
        self.assertEqual(len(est.samples), count, 'health captured on an unknown-flag frame is not trusted')

    def test_no_damage_is_unbounded_above(self):
        est = TTDEstimator()
        out = run(est, 0., 5., 'g0', 100., 0.)
        self.assertEqual(out['status'], 'estimate')
        self.assertTrue(out['highUnbounded'])
        self.assertGreater(out['low'], 100)

    def test_fast_trash_is_short(self):
        est = TTDEstimator()
        out = run(est, 0., 3., 'g0', 80., 15.)          # dies at 5.3 s
        self.assertEqual(out['status'], 'estimate')
        self.assertLess(out['high'], 10)

    def test_no_target_and_missing_signal(self):
        est = TTDEstimator()
        self.assertEqual(est.update(frame(0., 'none', 50.))['status'], 'no_target')
        self.assertEqual(est.update({'capturedAt': 1., 'rows': {}, 'numbers': {}})['status'], 'no_target_signal')

    def test_stale_health_is_unknown(self):
        est = TTDEstimator()
        run(est, 0., 4., 'g0', 60., 2.)
        out = None
        for i in range(1, 30):
            out = est.update(frame(4. + i * .1, 'g0'))
        self.assertEqual(out['status'], 'no_health')

    def test_dead_target(self):
        est = TTDEstimator()
        out = run(est, 0., 4., 'g0', 6., 2.)
        self.assertEqual(out['status'], 'dead')


if __name__ == '__main__':
    unittest.main()
