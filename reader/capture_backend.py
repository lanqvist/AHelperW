"""One region capture session per color worker; images own their pixel data."""
from PIL import Image, ImageGrab


class HudCapture:
    def __init__(self, preferred='mss'):
        if preferred not in ('mss', 'pillow'):
            raise ValueError('captureBackend: mss или pillow')
        self.preferred = preferred
        self.backend = preferred
        self.session = None
        self.fallback_error = None

    def grab(self, bounds):
        if self.backend == 'mss':
            try:
                if self.session is None:
                    from mss import MSS
                    self.session = MSS()
                shot = self.session.grab(bounds)
                # frombytes copies pixels; a later grab cannot overwrite the
                # frame concurrently consumed by the OCR thread.
                return Image.frombytes('RGB', shot.size, shot.bgra, 'raw', 'BGRX')
            except Exception as exc:
                self.fallback_error = str(exc)
                self.close()
                self.backend = 'pillow'
        return ImageGrab.grab(bbox=bounds, all_screens=True)

    def close(self):
        if self.session is not None:
            try:
                self.session.close()
            finally:
                self.session = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
