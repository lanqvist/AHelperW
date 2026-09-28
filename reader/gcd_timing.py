"""Observation-only GCD timing. Never predicts server readiness or schedules input."""
import time


class GcdTiming:
    def __init__(self, debug):
        self.debug = debug
        self.previous = None
        self.window = None
        self.cycle = 0

    def _finish(self, outcome, now, **extra):
        if self.window is None:
            return
        w = self.window
        self._accrue(now)
        self.debug.event('gcd_ready_window_end', cycle=w['cycle'], outcome=outcome,
                         readyFrameAt=w['start'], readyObservedBy=w['observed'],
                         lastBusyFrameAt=w['lastBusy'],
                         afterReadyObservationSeconds=max(0., now-w['observed']),
                         hudTransitionBracketSeconds=w['observed']-w['lastBusy'],
                         waitSecondsByReason=w['waits'], frames=w['frames'], **extra)
        self.window = None

    def _accrue(self, now):
        w = self.window
        if w is not None and w['reason'] is not None:
            reason = w['reason']
            w['waits'][reason] = w['waits'].get(reason, 0.) + max(0., now-w['reasonAt'])
            w['reasonAt'] = now

    def pause(self):
        self._finish('reading_paused', time.time())
        self.previous = None

    def before(self, data):
        state = data['rows'].get('gcd', {}).get('state', 'unknown')
        stamp = data['capturedAt']
        completed = data.get('captureCompletedAt', stamp)
        previous = self.previous
        gap = previous is not None and not 0 < stamp-previous['stamp'] <= .25
        if gap:
            # The missing interval cannot be attributed to a particular wait reason.
            self._finish('frame_gap', previous['completed'])
        elif state != 'ready':
            self._finish('gcd_became_busy' if state == 'cd' else 'gcd_unknown', completed)
        if state == 'ready' and previous and previous['state'] == 'cd' and not gap:
            self.cycle += 1
            self.window = {'cycle': self.cycle, 'start': stamp, 'observed': completed,
                           'lastBusy': previous['stamp'], 'frames': 0,
                           'waits': {}, 'reason': None, 'reasonAt': completed}
            self.debug.event('gcd_ready_observed', cycle=self.cycle,
                             lastBusyFrameAt=previous['stamp'], readyFrameAt=stamp,
                             readyObservedBy=completed,
                             note='HUD transition bracket, not the exact server GCD end')
        self.previous = {'state': state, 'stamp': stamp, 'completed': completed}

    def after(self, data, decision, sent_at=None, now=None):
        now = time.time() if now is None else now
        w = self.window
        if w is None:
            return
        w['frames'] += 1
        if decision.get('status') == 'sent':
            sent_at = now if sent_at is None else sent_at
            ages = {key: max(0., sent_at-value['capturedAt'])
                    for key, value in data.get('numbers', {}).items()
                    if key in ('resource/rage', 'resource/targetHealthPercent', 'context/targets', 'context/haste')
                    and value.get('value') is not None and value.get('capturedAt') is not None}
            self._finish('key_sent', sent_at, action=decision.get('action'), sentAt=sent_at,
                         firstReadyFrame=w['frames'] == 1,
                         numberAgeSeconds=ages,
                         targetCountDiagnostic=data.get('targetCountDiagnostic'))
            return
        reason = decision.get('reason', decision.get('status', 'unknown'))
        self._accrue(now)
        if reason != w['reason']:
            w['reason'] = reason
            w['reasonAt'] = now
            self.debug.event('gcd_ready_wait', cycle=w['cycle'], reason=reason,
                             elapsedSeconds=max(0., now-w['observed']),
                             bladestormState=next((v.get('state') for k, v in data['rows'].items()
                                                  if k.startswith('proc:446035:')), None),
                             targetCountDiagnostic=data.get('targetCountDiagnostic'))
        data['gcdTiming'] = {'cycle': w['cycle'], 'waitingSeconds': max(0., now-w['observed']),
                             'reason': reason}
