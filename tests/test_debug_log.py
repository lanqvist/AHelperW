"""Bounded colour diagnostics: synthetic HUD data, no capture or inputs."""
import ast
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reader'))
from debug_log import DebugLog


class ColourDiagnostics(unittest.TestCase):
    def test_rejection_reasons_preserve_states(self):
        # Compile just the pure colour classifier; never import the GUI/input code.
        source = ast.parse((ROOT / 'reader/reader.py').read_text(encoding='utf-8'))
        method = next(n for cls in source.body if isinstance(cls, ast.ClassDef)
                      for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == 'color')
        namespace = {'np': np}
        exec(compile(ast.Module(body=[method], type_ignores=[]), 'color', 'exec'), namespace)
        reader = SimpleNamespace(bounds=(0, 0, 10, 10), cfg={'display': {'colors': {
            'procoff': [.16, .16, .16], 'unknown': [.48, .35, 0]}}})
        matched = namespace['color'](reader, Image.new('RGB', (10, 10), (41, 41, 41)), 5, 5,
                                     ['procoff', 'unknown'])
        rejected = namespace['color'](reader, Image.new('RGB', (10, 10), (13, 13, 13)), 5, 5,
                                      ['procoff', 'unknown'])
        self.assertEqual((matched['state'], matched['colorReason']), ('procoff', 'matched'))
        self.assertEqual((rejected['state'], rejected['colorReason']), ('unknown', 'outside_palette'))

    def test_snapshots_are_bounded_and_profile_scoped(self):
        with tempfile.TemporaryDirectory() as directory:
            logger = DebugLog(directory)
            keys = ['proc:1:1', 'proc:2:2', 'spell:3:3']
            reader = SimpleNamespace(hash='a'*64, square_specs=dict.fromkeys(keys), bounds=(10, 20, 30, 40))
            image = Image.new('RGB', (20, 20))
            def save(when, reason='outside_palette', count=3):
                logger.save_color_anomaly(reader, image, {'capturedAt': when, 'rows': {
                    key: {'state': 'unknown', 'colorReason': reason} for key in keys[:count]}})
            save(100, 'matched')
            save(100, count=2)
            self.assertEqual(logger.sample_counts, {})
            for when in [100, 101, 105, 110, 115]: save(when)
            crops = Path(directory) / 'logs' / (logger.session + '-crops')
            self.assertEqual(len(list(crops.glob('*.png'))), 3)
            metadata = json.loads(next(crops.glob('*.json')).read_text(encoding='utf-8'))
            self.assertEqual(metadata['bounds'], [10, 20, 30, 40])
            self.assertEqual(len(metadata['rejected']), 3)
            reader.hash = 'b'*64
            save(115)
            self.assertEqual(len(list(crops.glob('*.png'))), 4)
            events = [json.loads(line)['event'] for line in logger.path.read_text(encoding='utf-8').splitlines()]
            self.assertEqual(events.count('hud_color_anomaly_saved'), 4)


if __name__ == '__main__':
    unittest.main()
