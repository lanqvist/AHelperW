"""Offline APL scenario harness: synthetic export + synthetic frames -> model.decide.

No game, capture, OCR or input. Frames have the shape reader.py passes to
model.decide(data): rows (colour states), numbers (OCR values with capturedAt/
expiresAt), castReceipt/comboHistory. Unset values are absent, i.e. unknown.
"""
import json
import os
import re
import sys
import time
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'reader'))
DOCS = ROOT / 'docs'
COMMIT = '4c7c73621e596419b5bd6faa5d68940a9c640379'
ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

from spec_profiles import PROFILES, create_apl  # noqa: E402


def slug(name):
    return re.sub('[^a-z0-9]+', '_', name.lower().replace("'", ''))


def encode_talents(table, spec_id, hero=None, talents=()):
    """Synthetic v2 loadout string (reader/talent_decode.py protocol).

    Every selected node is taken at full rank; a choice node picks the entry
    whose slugged name is listed. `hero` selects the subtree switch entry.
    """
    wanted = set(talents)
    nodes = {}
    for trait in table['entries']:
        nodes.setdefault(trait['nodeId'], []).append(trait)
    bits = []
    def put(value, count):
        bits.extend((value >> i) & 1 for i in range(count))
    put(2, 8); put(spec_id, 16); put(0, 128)
    found = set()
    for _, node in sorted(nodes.items()):
        first, choice = node[0], None
        if first['tree'] == 4 and first['nodeType'] == 3 and spec_id in first['specs']:
            if hero is not None:
                choice = next((i for i, t in enumerate(node) if t['subtree'] == hero), None)
                if choice is None:
                    raise ValueError(f'Поддерево {hero} недоступно спеку {spec_id}')
        else:
            for i, trait in enumerate(node):
                if slug(trait['name']) in wanted and (trait['tree'] == 3 or not trait['specs'] or spec_id in trait['specs']):
                    choice = i; found.add(slug(trait['name']))
                    break
        if choice is None:
            put(0, 1); continue
        put(1, 1); put(1, 1); put(0, 1)          # selected, full rank, not partial
        if first['nodeType'] in (2, 3) and len(node) > 1:
            put(1, 1); put(choice, 2)
        else:
            put(0, 1)
            if choice:
                raise ValueError('Выбор возможен только в узле выбора: ' + node[choice]['name'])
    missing = wanted - found
    if missing:
        raise ValueError('Нет таланта в таблице: ' + ', '.join(sorted(missing)))
    while len(bits) % 6:
        bits.append(0)
    return ''.join(ALPHABET[sum(bits[i + j] << j for j in range(6))] for i in range(0, len(bits), 6))


def rect(i, width=40):
    return {'x': 10 + i * 45, 'y': 10, 'width': width, 'height': 40}


def build_export(fixture):
    """Synthetic AHelperW.HUD export from a spec fixture (FIXTURE in spec_*.py).

    Keys: specID, traitFile (relative to the package directory), hero, talents
    (slugged names), squares [(kind, spellID, {options})], aliases, resources,
    resourceMeta, runes (bool), heroTreeID (as the addon exports it), bound.
    """
    spec = fixture['specID']
    profile = PROFILES[spec]
    table = json.loads(Path(os.path.normpath(DOCS / profile.data_directory / fixture['traitFile'])).read_text(encoding='utf-8'))
    squares = []
    for i, (kind, spell, *options) in enumerate(fixture['squares'], 1):
        r = rect(i)
        # Same derived boxes as Export.lua.
        square = {'index': i, 'kind': kind, 'spellID': spell, 'name': str(spell), 'rect': r,
                  'castSpellIDs': [spell] if kind == 'spell' else [], 'charges': False,
                  'colorSample': {'x': r['x'] + 4, 'y': r['y'] + 32},
                  'timerRegion': {'x': r['x'] + 2, 'y': r['y'] + 5, 'width': r['width'] - 4, 'height': 17},
                  'stackRegion': {'x': r['x'] + 24, 'y': r['y'] + 28, 'width': 16, 'height': 12}}
        square.update(options[0] if options else {})
        squares.append(square)
    cfg = {'schema': 'AHelperW.HUD', 'version': 1, 'static': True,
           'client': {'version': '12.1.0', 'build': '69933', 'interface': 120100},
           'specID': spec, 'talents': encode_talents(table, spec, fixture.get('hero'), fixture.get('talents', ())),
           'apl': {'profileID': profile.id, 'sourceCommit': COMMIT, 'assumedBuild': '69933', 'talentsVerified': False},
           'screen': {'width': 1920, 'height': 1080, 'origin': 'top-left', 'units': 'physical-pixels'},
           'squares': squares, 'aliases': fixture.get('aliases', {}), 'equipment': [],
           'resources': {key: rect(0) for key in fixture.get('resources', ())},
           'resourceMeta': fixture.get('resourceMeta', {}), 'context': {}}
    if fixture.get('heroTreeID') is not None:
        cfg['apl']['heroTreeID'] = fixture['heroTreeID']
    if fixture.get('runes'):
        cfg['runes'] = {'version': 1, 'count': 6, 'rects': [rect(i, 15) for i in range(6)]}
    return cfg


def fake_reader(cfg):
    return types.SimpleNamespace(cfg=cfg, square_specs={f"{s['kind']}:{s['spellID']}:{s['index']}": s for s in cfg['squares']})


def make_model(fixture, settings=None, bindings=None):
    cfg = build_export(fixture)
    if bindings is None:
        # One distinct key per bound spell square; unbound actions are skipped by the model.
        bound = fixture.get('bound', [s[1] for s in fixture['squares'] if s[0] == 'spell'])
        bindings = {str(spell): {'device': 'keyboard', 'vk': 0x70 + i, 'modifiers': []} for i, spell in enumerate(bound)}
    settings = dict({'targets': None, 'phase': 'auto', 'fightStyle': None}, **(settings or {}))
    return create_apl(fake_reader(cfg), DOCS, bindings, settings)


def frame(model, spells=None, buffs=None, debuffs=None, numbers=None, combat=True, target=True,
          gcd='ready', casting=False, runes=None, age=0., **extra):
    """Frame dict as reader.py builds it.

    spells: {action or spellID: state | (state, timer) | (state, timer, stacks)};
      unlisted spell squares are on cooldown (timer 20 s).
    buffs/debuffs: {name or ID: 'up' | 'down' | 'unknown' | (remains, stacks)}; unlisted
      auras are absent (procoff). Names map through model.buffs.
    numbers: OCR values by key; None removes a default (unknown).
    runes: six states ('ready' / 'cd' / 'unknown') or a ready count.
    age: seconds between the OCR frame and this frame for every number.
    """
    now = time.time()
    rows, values = {}, {'context/targets': 1, 'context/haste': 20., 'context/time': 10.,
                        'resource/targetHealthPercent': 80.}
    by_display = {(spec['kind'], spec['spellID']): key for key, spec in model.reader.square_specs.items()}

    def square_key(kind, name, table):
        spell = table.get(name, name) if isinstance(name, str) else name
        if kind == 'spell':
            spell = model.aliases.get(spell, spell)
        key = by_display.get((kind, spell))
        if key is None:
            raise KeyError(f'Нет квадрата {kind} {name}')
        return key

    for key, spec in model.reader.square_specs.items():
        rows[key] = {'state': 'cd' if spec['kind'] == 'spell' else 'procoff', 'colorConfidence': 1., 'rgb': [0, 0, 0]}
        if spec['kind'] == 'spell':
            values[key + '/timer'] = 20.
    for name, value in (spells or {}).items():
        key = square_key('spell', name, model.spells)
        state, timer, stacks = (value, None, None) if isinstance(value, str) else (tuple(value) + (None, None))[:3]
        rows[key]['state'] = state
        values.pop(key + '/timer', None)
        if timer is not None: values[key + '/timer'] = timer
        if stacks is not None: values[key + '/stacks'] = stacks
    for kind, table, auras in (('proc', model.buffs, buffs), ('debuff', {}, debuffs)):
        for name, value in (auras or {}).items():
            key = square_key(kind, name, table)
            if value == 'down':
                continue
            if value == 'unknown':
                rows[key]['state'] = 'unknown'
                continue
            rows[key]['state'] = kind
            if value != 'up':
                values[key + '/timer'], values[key + '/stacks'] = value
    rows['gcd'] = {'state': gcd}
    rows['context/time'] = {'state': 'nores' if combat else 'procoff'}
    rows['context/range'] = {'state': 'ready' if target else 'unusable'}
    rows['context/playerCast'] = {'state': 'nores' if casting else 'procoff'}
    rows['context/targetCast'] = {'state': 'procoff'}
    if runes is not None:
        states = ['ready'] * runes + ['cd'] * (6 - runes) if isinstance(runes, int) else runes
        rows.update({f'rune/{i}': {'state': s} for i, s in enumerate(states, 1)})
    values.update(numbers or {})
    captured = now - age
    data = {'schema': 'AHelperW.Reader', 'version': 1, 'valid': True, 'capturedAt': now, 'expiresAt': now + .8,
            'rows': rows, 'numbers': {k: {'value': v, 'capturedAt': captured, 'expiresAt': now + 5}
                                      for k, v in values.items() if v is not None},
            'castReceipt': {'status': 'not_configured'}, 'comboHistory': {'status': 'not_configured', 'active': []}}
    data.update(extra)
    return data


class Scenario:
    """expect: ('ready', action) | ('blocked', text) | ('waiting', text) | ('refused', text).

    'blocked'/'waiting' match `text` in the reason or the missing inputs;
    'refused' expects model construction (create_apl) to raise with `text`.
    `check(model, result) -> (ok, detail)` replaces the default comparison;
    `fixture` and `settings` override the module's FIXTURE and defaults;
    `factory(fixture, settings)` builds the model instead of create_apl.
    """
    def __init__(self, name, expect=None, fixture=None, settings=None, check=None, factory=None, **frame_args):
        self.name, self.expect, self.fixture, self.settings = name, expect, fixture, settings
        self.check, self.factory, self.frame_args = check, factory, frame_args


def run_scenario(module, scenario):
    fixture = scenario.fixture or module.FIXTURE
    status, text = scenario.expect or (None, None)
    try:
        model = (scenario.factory or make_model)(fixture, scenario.settings)
    except ValueError as exc:
        if status == 'refused' and text in str(exc):
            return True, f'отказ: {exc}'
        return False, f'модель не создана: {exc}'
    if status == 'refused':
        return False, 'ожидался отказ, модель создана'
    result = model.decide(frame(model, **scenario.frame_args))
    if scenario.check:
        return scenario.check(model, result)
    got = result.get('status')
    detail = result.get('action') or result.get('reason')
    if got != status:
        return False, f'{got}: {detail} ({result.get("rule")})'
    if status == 'ready':
        return result['action'] == text, f"{result['action']} · {result.get('list')} · {result.get('rule')}"
    haystack = ' '.join([result.get('reason', '')] + list(result.get('missing', [])))
    return text in haystack, f'{detail} · {result.get("rule", "")}'
