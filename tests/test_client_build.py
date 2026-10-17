"""Client build of a HUD export against the trait table's pinned build."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reader'))
from apl import client_build_note  # noqa: E402

TABLES = ['docs/arms-apl/warrior-traits.json', 'docs/windwalker-apl/monk-traits.json',
          'docs/traits/death_knight-traits.json', 'docs/traits/paladin-traits.json']


class ClientBuildTest(unittest.TestCase):
    def test_exact_build(self):
        self.assertIsNone(client_build_note({'version': '12.1.5', 'build': '70448'}, '12.1.5.70448'))

    def test_hotfix_build_of_the_same_patch(self):
        note = client_build_note({'version': '12.1.5', 'build': 70512}, '12.1.5.70448')
        self.assertIn('12.1.5.70512', note)

    def test_other_patch_is_refused(self):
        for client in ({'version': '12.1.0', 'build': '69933'}, {'version': '12.2.0', 'build': '71000'}, {}):
            with self.assertRaisesRegex(ValueError, 'обновление AHelperW'):
                client_build_note(client, '12.1.5.70448')

    def test_every_table_is_pinned_to_one_build(self):
        builds = {json.loads((ROOT / path).read_text(encoding='utf-8'))['build'] for path in TABLES}
        self.assertEqual(builds, {'12.1.5.70448'})


if __name__ == '__main__':
    unittest.main()
