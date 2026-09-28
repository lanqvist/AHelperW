"""Append-only diagnostic sessions with a few small HUD crops."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import threading
import time
import uuid


class DebugLog:
    def __init__(self, root):
        self.session = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
        self.path = Path(root) / 'logs' / (self.session + '.jsonl')
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.sequence = 0
        self.error = None
        self.sample_counts = {}
        self.sample_times = {}
        self.event('session_start', pid=os.getpid())

    def event(self, event, **payload):
        with self.lock:
            self.sequence += 1
            record = {'schema': 'AHelperW.Debug', 'version': 1,
                      'session': self.session, 'sequence': self.sequence,
                      'loggedAt': time.time(), 'event': event, **payload}
            try:
                # Close after each complete line: available immediately to external readers.
                with self.path.open('a', encoding='utf-8') as stream:
                    stream.write(json.dumps(record, ensure_ascii=False, allow_nan=False) + '\n')
                self.error = None
            except (OSError, ValueError) as exc:
                self.error = str(exc)

    def save_samples(self, reader, image, data, numbers):
        """A few original spell squares, enough to diagnose missing countdowns."""
        for key, _, kind, spec in reader.entries:
            if kind != 'spell':
                continue
            counter = bool(spec.get('charges')) and key+'/stacks' in numbers
            countdown = data['rows'][key]['state'] in ('cd','almost') and key+'/timer' in numbers
            if not (counter or countdown):
                continue
            count = self.sample_counts.get(key, 0)
            when = data['capturedAt']
            if count >= 3 or when-self.sample_times.get(key, 0) < 5:
                continue
            directory = self.path.parent / (self.session + '-crops')
            name = key.replace(':','-') + f'-{count+1}'
            try:
                directory.mkdir(parents=True, exist_ok=True)
                reader.crop(image, spec['rect']).save(directory / (name + '-square.png'))
                reader.crop(image, reader.regions[key+'/timer']).save(directory / (name + '-timer.png'))
                if counter:
                    reader.crop(image, reader.regions[key+'/stacks']).save(directory / (name + '-stacks.png'))
                metadata = {'profileHash':reader.hash, 'capturedAt':when, 'key':key,
                            'rect':spec['rect'], 'timerRegion':reader.regions[key+'/timer'],
                            'color':data['rows'][key], 'ocr':numbers.get(key+'/timer'),
                            'stacks':numbers.get(key+'/stacks')}
                (directory/(name+'.json')).write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
                self.sample_counts[key] = count+1
                self.sample_times[key] = when
                self.event('debug_crop_saved', key=key, directory=str(directory), sample=name, capturedAt=when)
            except OSError as exc:
                self.event('debug_crop_error', key=key, error=str(exc))
