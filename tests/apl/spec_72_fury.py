"""Fury / Slayer (72) offline scenarios. Synthetic build, not the user's."""
from harness import Scenario

FIXTURE = {
    'specID': 72, 'traitFile': '../arms-apl/warrior-traits.json', 'hero': 60,
    'talents': ['slayers_dominance', 'rampage', 'bloodthirst', 'raging_blow', 'recklessness', 'reckless_abandon'],
    'squares': [('spell', s) for s in (184367, 23881, 85288, 5308, 1719, 227847, 385059, 190411,
                                       107570, 100, 6552, 386196)]
               + [('proc', s) for s in (184362, 1719, 52437, 85739, 383873, 446035, 445606, 386196, 10060)],
    'aliases': {
        'crushing_blow': {'spellID': 335097, 'displaySpellID': 85288, 'sharesBindingWith': 'raging_blow'},
        'bloodbath': {'spellID': 335096, 'displaySpellID': 23881, 'sharesBindingWith': 'bloodthirst'},
    },
    'resources': ('rage',), 'resourceMeta': {'rage': {'powerType': 1, 'max': 130}},
}
AOE = dict(FIXTURE, talents=FIXTURE['talents'] + ['improved_whirlwind'])
ENRAGED = {'enrage': (3, 1), 'berserker_stance': 'up'}
CORE = {'raging_blow': 'ready', 'bloodthirst': 'ready', 'rampage': 'ready'}

SCENARIOS = [
    Scenario('одна цель, Enrage держится: Raging Blow', ('ready', 'raging_blow'),
             spells=CORE, buffs=ENRAGED, numbers={'resource/rage': 50}),
    Scenario('Enrage заканчивается: Rampage', ('ready', 'rampage'),
             spells=CORE, buffs=dict(ENRAGED, enrage=(0.5, 1)), numbers={'resource/rage': 90}),
    Scenario('Recklessness + Reckless Abandon: Bloodbath на кнопке Bloodthirst', ('ready', 'bloodbath'),
             spells={'bloodthirst': 'ready'}, buffs=dict(ENRAGED, recklessness=(10, 1)), numbers={'resource/rage': 50}),
    Scenario('Execute без Sudden Death выше порога не выбирается', ('ready', 'raging_blow'),
             spells=dict(CORE, execute='ready'), buffs=ENRAGED,
             numbers={'resource/rage': 50, 'resource/targetHealthPercent': 50}),
    Scenario('Execute ниже 20%', ('ready', 'execute'),
             spells=dict(CORE, execute='ready'), buffs=ENRAGED,
             numbers={'resource/rage': 50, 'resource/targetHealthPercent': 15}),
    Scenario('ярость неизвестна там, где она решает: блокировка', ('blocked', 'resource/rage'),
             spells=CORE, buffs=ENRAGED, numbers={'resource/rage': None}),
    Scenario('три цели, Improved Whirlwind без баффа: Whirlwind', ('ready', 'whirlwind'), fixture=AOE,
             spells=dict(CORE, whirlwind='ready'), buffs=ENRAGED,
             numbers={'resource/rage': 50, 'context/targets': 3}),
]
