"""Latest-value publisher, independent of Tk. Retries Windows file sharing errors."""
import json
import os
import threading
import time
import traceback


class StateWriter:
    def __init__(self, root, debug):
        self.root, self.debug = root, debug
        self.condition = threading.Condition()
        self.generation = -1
        self.pending = None
        self.revision = 0
        self.written = -1
        self.stopping = False
        self.error = None
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def submit(self, data, generation):
        with self.condition:
            if self.stopping or generation < self.generation:
                return
            self.generation = generation
            self.pending = data
            self.revision += 1
            self.condition.notify()

    def write(self, name, data):
        target = self.root / name
        temp = self.root / (name + '.tmp')
        temp.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False), encoding='utf-8')
        os.replace(temp, target)

    def run(self):
        while True:
            with self.condition:
                if self.stopping:
                    return
                if self.pending and self.pending.get('valid') and time.time() > self.pending['expiresAt']:
                    self.pending = {'schema':'AHelperW.Reader','version':1,'valid':False,
                                    'reason':'stale','capturedAt':time.time(),'rows':{},'numbers':{}}
                    self.revision += 1
                if self.pending is None or self.written == self.revision:
                    self.condition.wait(.1)
                    continue
                # Hold the lock during commit so an old frame cannot overwrite a
                # stop/new-generation state that has already been accepted.
                data, revision = self.pending, self.revision
                try:
                    self.write('state.json', data)
                    self.written = revision
                    self.error = None
                    self.debug.event('state_published', revision=revision, generation=self.generation,
                                     publishedAt=time.time(), data=data)
                    if data.get('valid'):
                        try:
                            self.write('last_success.json', {'historical':True,'savedAt':time.time(),
                                       'session':self.debug.session,'observation':data})
                        except Exception as exc:
                            self.debug.event('snapshot_write_error', error=str(exc), traceback=traceback.format_exc())
                except Exception as exc:
                    self.error = str(exc)
                    self.debug.event('state_write_error', revision=revision, error=str(exc), traceback=traceback.format_exc())
                    # Release the lock: newer captures/stop can replace the failed frame.
                    self.condition.wait(.1)

    def close(self):
        deadline = time.monotonic() + 1
        while time.monotonic() < deadline:
            with self.condition:
                if self.written == self.revision:
                    break
            time.sleep(.02)
        with self.condition:
            self.stopping = True
            self.condition.notify()
        self.thread.join(timeout=1)
