"""Decode the visible public-cast journal; correlate events, never infer success from GCD."""
import time


def decode(image, config, bounds):
    if not config or not config.get('rect'):
        return {'status': 'not_configured'}
    # v1: fixed four rows; v2: row count from the export (eight in 0.2.14+).
    if config.get('version') == 1:
        rows = 4
    elif config.get('version') == 2 and config.get('rows') in range(4, 17):
        rows = config['rows']
    else:
        return {'status': 'not_configured'}
    r = config['rect']
    if r['width'] < 112 or r['height'] < 2 * rows:
        return {'status': 'too_small'}
    records = []
    for row in range(rows):
        bits = []
        for col in range(56):
            x = int(r['x'] - bounds[0] + (col + .5) * r['width'] / 56)
            y = int(r['y'] - bounds[1] + (row + .5) * r['height'] / rows)
            if not (0 <= x < image.width and 0 <= y < image.height):
                return {'status': 'outside_frame'}
            rgb = image.getpixel((x, y))[:3]
            if max(rgb) <= 55: bits.append(0)
            elif min(rgb) >= 200: bits.append(1)
            else: return {'status': 'unreadable'}
        values = [sum(bits[b*8+i] << (7-i) for i in range(8)) for b in range(7)]
        if values[0] != 165 or sum(values[:6]) % 256 != values[6]:
            return {'status': 'invalid_checksum'}
        sequence = values[1]*256 + values[2]
        spell = values[3]*65536 + values[4]*256 + values[5]
        if sequence:
            records.append({'sequence': sequence, 'spellID': spell})
    return {'status': 'readable', 'records': records}


class CastObserver:
    def __init__(self, debug):
        self.debug = debug
        self.last_sequence = None
        self.waiting = []
        self.status = None
        self.recent = []

    def unexpected_after(self, sent_at, expected, window=.8):
        """First other spell cast just after a press: a hint that the key is bound
        to a different action in the game. Nearby procs can also appear here."""
        return next((spell for spell, at in self.recent
                     if sent_at < at <= sent_at + window and spell not in expected), None)

    def pause(self):
        for item in self.waiting:
            self.debug.event('action_cast_unobserved', action=item['action'], reason='reading_paused')
        self.waiting.clear()
        self.last_sequence = None

    def sent(self, decision, square, sent_at, receipt):
        # Without a baseline, an old event cannot confirm a newly sent action.
        if receipt.get('status') != 'readable' or self.last_sequence is None:
            self.debug.event('cast_verification_unavailable', action=decision['action'], reason=receipt.get('status'))
            return
        expected = set(square.get('castSpellIDs', [decision['bindingSpellID']]))
        expected.add(decision['spellID'])
        self.waiting.append({'action': decision['action'], 'expected': expected, 'sentAt': sent_at})

    def update(self, data):
        now = time.time()
        confirmed = []
        receipt = data.get('castReceipt', {'status': 'not_configured'})
        if receipt['status'] != self.status:
            self.debug.event('cast_receipt_status', status=receipt['status'])
            self.status = receipt['status']
        if receipt['status'] == 'readable':
            records = receipt['records']
            if not records and self.last_sequence not in (None, 0):
                self.debug.event('cast_receipt_reset', reason='empty_journal_after_reload')
                self.pause()
            if self.last_sequence is None:
                # Baseline only: never associate events already on screen with an input.
                seqs = [x['sequence'] for x in records]
                self.last_sequence = next((s for s in seqs if all((s-t) % 65535 < 32768 for t in seqs)), 0)
            else:
                fresh = sorted((x for x in records if 0 < (x['sequence']-self.last_sequence) % 65535 < 32768),
                               key=lambda x: (x['sequence']-self.last_sequence) % 65535)
                for event in fresh:
                    delta = (event['sequence']-self.last_sequence) % 65535
                    if delta > 1:
                        self.debug.event('cast_receipt_gap', missed=delta-1)
                    self.last_sequence = event['sequence']
                    self.debug.event('player_cast_observed', **event, capturedAt=data['capturedAt'])
                    self.recent = (self.recent + [(event['spellID'], data['capturedAt'])])[-24:]
                    match = next((item for item in self.waiting if event['spellID'] in item['expected']
                                  and item['sentAt'] < data['capturedAt'] <= item['sentAt'] + 2.5), None)
                    if match:
                        confirmed.append({'action':match['action'], 'sentAt':match['sentAt'],
                                          'spellID':event['spellID'], 'sequence':event['sequence']})
                        self.debug.event('action_cast_observed', action=match['action'], **event,
                                         elapsedSeconds=data['capturedAt']-match['sentAt'],
                                         note='Matching player cast observed; manual input attribution is unknown')
                        self.waiting.remove(match)
        for item in list(self.waiting):
            if now-item['sentAt'] > 2.5:
                other = self.unexpected_after(item['sentAt'], item['expected'])
                if other is not None:
                    self.debug.event('input_binding_mismatch_suspected', action=item['action'], observedSpellID=other,
                                     expectedSpellIDs=sorted(item['expected']),
                                     note='Another spell was cast right after the key; check the in-game binding')
                self.debug.event('action_cast_unobserved', action=item['action'],
                                 expectedSpellIDs=sorted(item['expected']), reason='no_matching_event_observed',
                                 receiptStatus=receipt['status'], note='Not proof of cast failure')
                self.waiting.remove(item)
        data['castVerification'] = {'status': receipt['status'], 'pending': len(self.waiting),
                                    'confirmed':confirmed}
