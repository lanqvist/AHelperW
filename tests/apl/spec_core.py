"""Shared runtime: hero trees, runes and runic power, DK placeholder profiles.

The DK probe is a test-only APLRuntime over synthetic lists
(fixtures/dk-probe); it is not the Frost/Unholy model.
"""
from pathlib import Path

from apl import APLRuntime, Unknown
from harness import DOCS, Scenario, build_export, fake_reader
from spec_71_arms import FIXTURE as ARMS

PROBE_ROOT = Path(__file__).resolve().parent / 'fixtures' / 'dk-probe'
DK_TRAITS = '../traits/death_knight-traits.json'


class FrostProbe(APLRuntime):
    spec_id = 251
    trait_file = str(DOCS / 'traits' / 'death_knight-traits.json')
    spells = {'obliterate': 49020, 'frost_strike': 49143, 'howling_blast': 49184, 'death_coil': 47541}
    buffs = {}


class UnholyProbe(FrostProbe):
    spec_id = 252


def probe(fixture, settings):
    cls = FrostProbe if fixture['specID'] == 251 else UnholyProbe
    cfg = build_export(fixture)
    bindings = {str(s): {'device': 'keyboard', 'vk': 0x70 + i, 'modifiers': []}
                for i, s in enumerate(cls.spells.values())}
    return cls(fake_reader(cfg), PROBE_ROOT, bindings, dict({'targets': None, 'phase': 'auto'}, **(settings or {})))


def dk(spec, hero, **extra):
    fixture = {'specID': spec, 'traitFile': DK_TRAITS, 'hero': hero, 'talents': [], 'runes': True,
               'squares': [('spell', s) for s in (49020, 49143, 49184, 47541)],
               'resources': ('runic_power',),
               'resourceMeta': {'runic_power': {'powerType': 6, 'max': 100}, 'runes': {'powerType': 5, 'max': 6}}}
    fixture.update(extra)
    return fixture


FROST_DB, FROST_RIDER, UNHOLY_SAN = dk(251, 33), dk(251, 32), dk(252, 31)
READY = {'obliterate': 'ready', 'frost_strike': 'ready', 'howling_blast': 'ready', 'death_coil': 'ready'}


def expressions(expected):
    """check(): resolve each expression on the decided frame; 'unknown' means Unknown."""
    def check(model, _result):
        wrong = []
        for name, want in expected.items():
            got = model.resolve(name)
            ok = isinstance(got, Unknown) if want == 'unknown' else (not isinstance(got, Unknown) and abs(got - want) < 1e-6)
            if not ok:
                wrong.append(f'{name}={got!r} (ожидалось {want})')
        return not wrong, '; '.join(wrong) or ', '.join(f'{k}={v}' for k, v in expected.items())
    return check


def hero(key):
    def check(model, _result):
        return model.hero_tree == key, f'hero_tree={model.hero_tree} (id {model.hero_tree_id})'
    return check


SCENARIOS = [
    # Hero trees
    Scenario('Frost / Deathbringer: ветка из строки талантов', fixture=FROST_DB, factory=probe, check=hero('deathbringer')),
    Scenario('Frost / Rider: ветка из строки талантов', fixture=FROST_RIDER, factory=probe, check=hero('rider_of_the_apocalypse')),
    Scenario("Unholy / San'layn: ветка из строки талантов", fixture=UNHOLY_SAN, factory=probe, check=hero('sanlayn')),
    Scenario('hero_tree.* в условиях: Deathbringer → Obliterate', ('ready', 'obliterate'), fixture=FROST_DB,
             factory=probe, spells=READY, runes=2, numbers={'resource/runic_power': 90}),
    Scenario('hero_tree.* в условиях: Rider → Frost Strike', ('ready', 'frost_strike'), fixture=FROST_RIDER,
             factory=probe, spells=READY, runes=2, numbers={'resource/runic_power': 90}),
    Scenario('hero_tree.* как число (30-10*hero_tree.sanlayn)', ('ready', 'death_coil'), fixture=UNHOLY_SAN,
             factory=probe, spells=READY, runes=2, numbers={'resource/runic_power': 20}),
    Scenario('ветка в экспорте не совпадает с талантами: отказ', ('refused', 'не совпадает'),
             fixture=dk(251, 33, heroTreeID=32), factory=probe),
    Scenario('героическая ветка не выбрана: отказ', ('refused', 'героической ветки'), fixture=dk(251, None), factory=probe),
    Scenario('Arms: hero_tree.slayer', fixture=ARMS, check=lambda m, _r: (m.hero_tree == 'slayer' and m.resolve('hero_tree.slayer') is True
                                                                          and m.resolve('hero_tree.colossus') is False, m.hero_tree)),
    # Runes and runic power
    Scenario('руны: 2 готовы, следующая через 3.0 с (кадр OCR старше на 0.5 с)', fixture=FROST_DB, factory=probe, runes=2, age=.5,
             numbers={'resource/runic_power': 70, 'context/runeNext': 3.},
             check=expressions({'rune': 2, 'rune.deficit': 4, 'rune.max': 6, 'rune.time_to_1': 0, 'rune.time_to_2': 0,
                                'rune.time_to_3': 2.5, 'rune.time_to_4': 'unknown', 'runic_power': 70,
                                'runic_power.max': 100, 'runic_power.deficit': 30})),
    Scenario('руны: одна не прочитана — число неизвестно, не ноль', fixture=FROST_DB, factory=probe,
             runes=['ready', 'ready', 'unknown', 'cd', 'cd', 'cd'], numbers={'context/runeNext': 3.},
             check=expressions({'rune': 'unknown', 'rune.deficit': 'unknown', 'rune.time_to_1': 'unknown'})),
    Scenario('руны не прочитаны: правило с rune блокируется', ('blocked', 'руны'), fixture=FROST_DB, factory=probe,
             spells=READY, runes=['unknown'] * 6, numbers={'resource/runic_power': 90}),
    Scenario('таймер следующей руны неизвестен', fixture=FROST_DB, factory=probe, runes=5,
             check=expressions({'rune.time_to_5': 0, 'rune.time_to_6': 'unknown'})),
    Scenario('сила рун неизвестна: дефицит неизвестен', ('blocked', 'resource/runic_power'), fixture=FROST_RIDER,
             factory=probe, spells=READY, runes=3, numbers={'resource/runic_power': None}),
    Scenario('максимум силы рун из HUD важнее снимка экспорта', fixture=FROST_DB, factory=probe, runes=6,
             numbers={'resource/runic_power': 100, 'context/maxrunic_power': 120},
             check=expressions({'runic_power.max': 120, 'runic_power.deficit': 20, 'rune.time_to_6': 0})),
    # Placeholder profiles refuse a model until the spec work adds one.
    Scenario('Frost: модели ещё нет — отказ', ('refused', 'модель APL ещё не реализована'), fixture=FROST_DB),
    Scenario('Unholy: модель из профиля (UnholyAPL)', fixture=UNHOLY_SAN,
             check=lambda m, _r: (type(m).__name__ == 'UnholyAPL' and m.hero_tree == 'sanlayn', type(m).__name__)),
]

FIXTURE = FROST_DB
