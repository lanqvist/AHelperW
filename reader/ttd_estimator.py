"""Target time-to-die bounds from the engine-rendered target health percent.

The addon never does arithmetic on secret health; it renders the percent and a
target-change flag (four colours cycling on PLAYER_TARGET_CHANGED). The reader
fits the health slope of the current target and publishes bounds [low, high]:
a comparison `ttd>T` is decided only by `low`, `ttd<T` only by `high`.
Anything else stays unknown. Parameters come from the offline prototype over
recorded fights (docs/PROJECT_MEMORY.md, "Прототип автоматического TTD").
"""
import math

WINDOW = 8.0        # seconds of health samples in the slope fit
MIN_SPAN = 1.5      # seconds between the oldest and newest sample used
MIN_SAMPLES = 3
WARMUP = 2.5        # seconds on a target before any bound is published
RESOLUTION = .1     # HUD percent resolution
SAFETY = 2.0        # damage rate may change by this factor either way (x3: same
                    # errors at 10 s, 87% instead of 94% of long-life frames decided)
STALE = 2.0         # the newest health sample must be at most this old
FLAG_MEMORY = 5.0   # seconds of frame flags kept to place late OCR samples
TARGET_FLAGS = ('g0', 'g1', 'g2', 'g3')


class TTDEstimator:
    def __init__(self):
        self.reset()

    def reset(self):
        self.generation = None      # current flag colour of a known target
        self.since = None           # first frame showing that colour
        self.samples = []           # [(capturedAt, percent)] of this target
        self.flags = []             # [(frame capturedAt, flag state)]

    def _flag_at(self, captured):
        return next((state for t, state in reversed(self.flags) if t == captured), None)

    def update(self, data):
        """Consume one merged frame; return a JSON-safe estimate for the log/APL."""
        now = data.get('capturedAt')
        row = data.get('rows', {}).get('context/targetGeneration')
        if row is None:
            self.reset()
            return {'status': 'no_target_signal'}
        flag = row.get('state')
        self.flags = [(t, s) for t, s in self.flags if now - t <= FLAG_MEMORY] + [(now, flag)]
        if flag == 'none':
            self.generation = self.since = None
            self.samples = []
            return {'status': 'no_target'}
        if flag in TARGET_FLAGS and flag != self.generation:
            # A new colour is a new target; late samples of the old one are
            # rejected below by the flag of their own captured frame.
            self.generation, self.since, self.samples = flag, now, []
        if self.generation is None:
            return {'status': 'flag_unknown'}
        item = data.get('numbers', {}).get('resource/targetHealthPercent', {})
        at, value = item.get('capturedAt'), item.get('value')
        if (value is not None and at is not None and item.get('expiresAt', 0) > now
                and at >= self.since and self._flag_at(at) == self.generation
                and (not self.samples or at > self.samples[-1][0])):
            self.samples.append((at, float(value)))
        self.samples = [s for s in self.samples if now - s[0] <= WINDOW]
        result = {'generation': self.generation, 'targetSince': self.since, 'samples': len(self.samples)}
        if flag not in TARGET_FLAGS:
            # Keep the history, but a frame with an unreadable flag cannot say
            # whether the target is still the same one.
            return dict(result, status='flag_unknown')
        if not self.samples or now - self.samples[-1][0] > STALE:
            return dict(result, status='no_health')
        newest_at, percent = self.samples[-1]
        if percent <= 0:
            return dict(result, status='dead', low=0., high=0., healthPercent=0.)
        span = newest_at - self.samples[0][0]
        if now - self.since < WARMUP or len(self.samples) < MIN_SAMPLES or span < MIN_SPAN:
            return dict(result, status='warming', healthPercent=percent)
        n = len(self.samples)
        mean_t = sum(t for t, _ in self.samples) / n
        mean_h = sum(h for _, h in self.samples) / n
        variance = sum((t - mean_t) ** 2 for t, _ in self.samples)
        rate = -sum((t - mean_t) * (h - mean_h) for t, h in self.samples) / variance
        slack = 2 * RESOLUTION / span
        age = now - newest_at
        low = max(0., percent / ((max(rate, 0.) + slack) * SAFETY) - age)
        slow = (rate - slack) / SAFETY
        high = max(0., percent / slow - age) if slow > 0 else math.inf
        point = percent / rate - age if rate > 0 else math.inf
        return dict(result, status='estimate', healthPercent=percent, ratePerSecond=round(rate, 4),
                    span=round(span, 3), low=round(low, 2),
                    high=None if math.isinf(high) else round(high, 2), highUnbounded=math.isinf(high),
                    point=None if math.isinf(point) else round(max(point, 0.), 2))
