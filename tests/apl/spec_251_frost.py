"""Frost DK (251) offline scenarios: Deathbringer (33) and Rider (32). Synthetic builds, not the user's."""
from harness import Scenario

SPELLS = (49020, 49143, 49184, 207230, 194913, 196770, 51271, 1249658, 279302, 46585, 47528, 439843)
PROCS = (51124, 59052, 51271, 1249658, 196770, 1233152, 211805, 1230273, 377103, 1229310, 53365, 1265630, 1265639, 10060)
BASE = ['frost_strike', 'obliterate', 'howling_blast', 'killing_machine', 'empower_rune_weapon', 'pillar_of_frost',
        'frostwyrms_fury', 'raise_dead', 'mind_freeze']
FIXTURE = {
    'specID': 251, 'traitFile': '../traits/death_knight-traits.json', 'hero': 33, 'runes': True,
    'talents': BASE + ['reapers_mark'],
    'squares': [('spell', s) for s in SPELLS] + [('spell', 47568, {'charges': True, 'maxCharges': 2})]
               + [('proc', s) for s in PROCS] + [('debuff', s) for s in (51714, 55095, 434765)],
    'aliases': {
        'frostbane': {'spellID': 1228433, 'displaySpellID': 49143, 'procID': 1229310, 'sharesBindingWith': 'frost_strike'},
        'chosen_of_frostbrood': {'spellID': 1265384, 'displaySpellID': 279302, 'procID': 1265639, 'sharesBindingWith': 'frostwyrms_fury'},
    },
    'resources': ('runic_power',),
    'resourceMeta': {'runic_power': {'powerType': 6, 'max': 100}, 'runes': {'powerType': 5, 'max': 6}},
}
DB = FIXTURE
RIDER = dict(FIXTURE, hero=32, talents=BASE + ['apocalypse_now', 'bonegrinder'])
AOE_DB = dict(FIXTURE, talents=FIXTURE['talents'] + ['frostscythe'])
FROSTBANE = dict(RIDER, talents=RIDER['talents'] + ['frostbane', 'shattering_blade'])
NO_FROSTBANE_SQUARE = dict(FROSTBANE, squares=[s for s in FIXTURE['squares'] if s[1] != 1229310])
BREATH = dict(FIXTURE, talents=FIXTURE['talents'] + ['breath_of_sindragosa'])
DOMINION = dict(AOE_DB, talents=AOE_DB['talents'] + ['frozen_dominion'])
CORE = {'obliterate': 'ready', 'frost_strike': 'ready', 'howling_blast': 'ready'}
FIGHT = {'resource/runic_power': 50}


def rp(value, **more):
    return dict({'resource/runic_power': value}, **more)


def ready(action, **fields):
    """check(): ready action plus exact result fields (spellID, a rule fragment)."""
    def check(model, result):
        ok = result.get('status') == 'ready' and result.get('action') == action
        for key, want in fields.items():
            got = result.get(key) if key != 'rule' else result.get('rule', '')
            ok = ok and (want in got if key == 'rule' else got == want)
        return ok, f"{result.get('status')}: {result.get('action') or result.get('reason')} · {result.get('spellID')} · {result.get('rule')}"
    return check


SCENARIOS = [
    # In game the Raise Dead square stayed unknown and blocked the cooldown list.
    Scenario('Raise Dead «неизвестно» не блокирует ротацию (не нажимается)',
             check=lambda m, r: (r.get('status') == 'ready' and r.get('action') != 'raise_dead',
                                 f"{r.get('status')}: {r.get('action') or r.get('reason')}"),
             spells=dict(CORE, raise_dead='unknown'), runes=6, numbers=rp(0)),
    # Cooldowns and hero-tree rules
    Scenario('Deathbringer, начало: Pillar of Frost при 2+ рунах', ('ready', 'pillar_of_frost'),
             spells=dict(CORE, pillar_of_frost='ready'), runes=4, numbers=rp(20, **{'context/time': 1.})),
    Scenario('Deathbringer, Pillar при 1 руне без прогноза боя: не жмётся, ротация', ('ready', 'frost_strike'),
             spells=dict(CORE, pillar_of_frost='ready', obliterate='nores'), runes=1, numbers=rp(50)),
    Scenario('Deathbringer, Pillar при 1 руне и прогнозе боя 15 с: Pillar', ('ready', 'pillar_of_frost'),
             spells=dict(CORE, pillar_of_frost='ready', obliterate='nores'), runes=1, numbers=rp(50, **{'context/fight': 15.})),
    Scenario("Deathbringer: Reaper's Mark в Pillar of Frost (дебафф на цели не висит)",
             check=ready('reapers_mark', rule='текущая цель'),
             spells=dict(CORE, reapers_mark='ready'), buffs={'pillar_of_frost': (10, 1)}, runes=3, numbers=rp(40)),
    Scenario("Deathbringer: Reaper's Mark не жмётся, пока его дебафф на текущей цели", ('ready', 'obliterate'),
             spells=dict(CORE, reapers_mark='ready'), buffs={'pillar_of_frost': (10, 1), 'killing_machine': (8, 2)},
             debuffs={434765: (8, 1)}, runes=3, numbers=rp(40)),
    Scenario("Deathbringer: копим руны к Reaper's Mark (rune_pooling) — Frost Strike вместо Obliterate",
             ('ready', 'frost_strike'), spells=dict(CORE, reapers_mark=('cd', 4.)),
             buffs={'killing_machine': (8, 1)}, runes=2, numbers=rp(50)),
    Scenario('Rider: тот же кадр без rune_pooling — Obliterate с Killing Machine', ('ready', 'obliterate'), fixture=RIDER,
             spells=dict(CORE, reapers_mark=('cd', 4.)), buffs={'killing_machine': (8, 1)}, runes=2, numbers=rp(50)),
    Scenario("Rider: Frostwyrm's Fury с Apocalypse Now в Pillar + Bonegrinder",
             check=ready('frostwyrms_fury', spellID=279302), fixture=RIDER,
             spells=dict(CORE, frostwyrms_fury='ready'), buffs={'pillar_of_frost': (10, 1), 'bonegrinder_frost': (5, 1)},
             runes=3, numbers=rp(40)),
    Scenario('Breath of Sindragosa в Pillar of Frost', ('ready', 'breath_of_sindragosa'), fixture=BREATH,
             spells=dict(CORE, breath_of_sindragosa='ready'), buffs={'pillar_of_frost': (10, 1)}, runes=3, numbers=rp(80)),
    Scenario('ERW: 1 из 2 зарядов, полная перезарядка через 5 с', ('ready', 'empower_rune_weapon'),
             spells=dict(CORE, empower_rune_weapon=('ready', 5., 1)), runes=4, numbers=rp(50)),
    # Single-target rotation
    Scenario('Killing Machine ×2: Obliterate', ('ready', 'obliterate'),
             spells=CORE, buffs={'killing_machine': (8, 2)}, runes=2, numbers=rp(50)),
    Scenario('Rime: Howling Blast', ('ready', 'howling_blast'),
             spells=dict(CORE, obliterate='nores'), buffs={'rime': (10, 1)}, runes=1, numbers=rp(40)),
    Scenario('сила рун у потолка: Frost Strike', ('ready', 'frost_strike'), spells=CORE, runes=4, numbers=rp(90)),
    Scenario('рун не хватает на Obliterate: Frost Strike', ('ready', 'frost_strike'),
             spells=dict(CORE, obliterate='nores'), buffs={'killing_machine': (8, 1)}, runes=1, numbers=rp(50)),
    Scenario('Frostbane: Frost Strike с ID замены 1228433 (Razorice 5)', fixture=FROSTBANE,
             check=ready('frost_strike', spellID=1228433, replacement='frostbane'),
             spells=CORE, buffs={'frostbane': (10, 1)}, debuffs={51714: (12, 5)}, runes=1, numbers=rp(40)),
    # AoE branch
    Scenario('3 цели, Killing Machine и 3 руны: Frostscythe', ('ready', 'frostscythe'), fixture=AOE_DB,
             spells=dict(CORE, frostscythe='ready'), buffs={'killing_machine': (8, 1)}, runes=3,
             numbers=rp(40, **{'context/targets': 3})),
    Scenario('2 цели: Obliterate без выбора цели (адаптация target_if)', fixture=AOE_DB,
             check=ready('obliterate', rule='текущая цель'),
             spells=dict(CORE, frostscythe='ready'), buffs={'killing_machine': (8, 2)}, runes=2,
             numbers=rp(40, **{'context/targets': 2})),
    Scenario('2 цели: Remorseless Winter', ('ready', 'remorseless_winter'), fixture=AOE_DB,
             spells=dict(CORE, remorseless_winter='ready'), runes=3, numbers=rp(40, **{'context/targets': 2})),
    Scenario('Frozen Dominion: Remorseless Winter заменён, не жмётся', ('ready', 'obliterate'), fixture=DOMINION,
             spells=dict(CORE, remorseless_winter='ready'), buffs={'killing_machine': (8, 2)}, runes=2,
             numbers=rp(40, **{'context/targets': 2})),
    Scenario('число целей неизвестно, но решение одинаково: Obliterate', ('ready', 'obliterate'),
             spells=CORE, buffs={'killing_machine': (8, 2)}, runes=2, numbers=rp(50, **{'context/targets': None})),
    # Blocked with a reason
    Scenario('число целей неизвестно, ST и AoE расходятся: блокировка', ('blocked', 'context/targets'), fixture=AOE_DB,
             spells=dict(CORE, frostscythe='ready'), buffs={'killing_machine': (8, 1)}, runes=3,
             numbers=rp(40, **{'context/targets': None})),
    Scenario('стаки Killing Machine не прочитаны: блокировка', ('blocked', '51124'),
             spells=CORE, buffs={'killing_machine': 'up'}, runes=2, numbers=rp(50)),
    Scenario('руны не прочитаны: блокировка', ('blocked', 'руны'),
             spells=CORE, buffs={'killing_machine': (8, 1)}, runes=['unknown'] * 6, numbers=rp(50)),
    Scenario('сила рун неизвестна: блокировка', ('blocked', 'resource/runic_power'),
             spells=CORE, runes=4, numbers=rp(None)),
    Scenario('нет квадрата Frostbane при таланте: блокировка Frost Strike', ('blocked', '1229310'),
             fixture=NO_FROSTBANE_SQUARE, spells=dict(CORE, obliterate='nores'), runes=1, numbers=rp(90)),
    Scenario('дебафф Razorice не прочитан (Shattering Blade): блокировка', ('blocked', '51714'), fixture=FROSTBANE,
             spells=dict(CORE, obliterate='nores'), runes=1, numbers=rp(40),
             debuffs={51714: (None, None)}),
    Scenario('GCD не готов', ('waiting', 'Ожидание GCD'), gcd='cd',
             spells=CORE, buffs={'killing_machine': (8, 2)}, runes=2, numbers=rp(50)),
]
