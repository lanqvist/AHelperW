"""Arms / Slayer (71) offline scenarios. Synthetic build, not the user's."""
from harness import Scenario

FIXTURE = {
    'specID': 71, 'traitFile': 'warrior-traits.json', 'hero': 60,
    'talents': ['slayers_dominance', 'mortal_strike', 'overpower', 'colossus_smash', 'avatar', 'bladestorm'],
    'squares': [('spell', s) for s in (12294, 7384, 845, 163201, 1464, 260708, 167105, 107574, 227847,
                                       107570, 100, 6552, 386164)]
               + [('proc', s) for s in (52437, 445606, 456120, 445584, 386633, 334783, 260708, 107574,
                                        446035, 1269391, 386164, 10060)]
               + [('debuff', s) for s in (208086, 388539)],
    'aliases': {'heroic_strike': {'spellID': 1269383, 'displaySpellID': 1464, 'procID': 1269391, 'sharesBindingWith': 'slam'}},
    'resources': ('rage',), 'resourceMeta': {'rage': {'powerType': 1, 'max': 100}},
}
STANCE = {'battle_stance': 'up'}
REND = {388539: (12, 1)}

SCENARIOS = [
    Scenario('вне боя: боевая стойка из precombat', ('ready', 'battle_stance'),
             combat=False, spells={'battle_stance': 'ready', 'mortal_strike': 'ready'}),
    Scenario('GCD не готов', ('waiting', 'Ожидание GCD'), gcd='cd', spells={'mortal_strike': 'ready'}, buffs=STANCE),
    Scenario('нет живой враждебной цели', ('waiting', 'враждебной'), target=False, spells={'mortal_strike': 'ready'}),
    Scenario('одна цель: Mortal Strike', ('ready', 'mortal_strike'),
             spells={'mortal_strike': 'ready'}, buffs=STANCE, debuffs=REND),
    Scenario('Sudden Death ×2 раньше Mortal Strike', ('ready', 'execute'),
             spells={'mortal_strike': 'ready', 'execute': 'ready'}, buffs=dict(STANCE, sudden_death=(8, 2)), debuffs=REND),
    Scenario('канал/каст игрока: ждать', ('waiting', 'каста'), casting=True,
             spells={'mortal_strike': 'ready'}, buffs=STANCE, debuffs=REND),
    Scenario('число целей неизвестно, выбор одинаков для 1..N', ('ready', 'mortal_strike'),
             numbers={'context/targets': None}, spells={'mortal_strike': 'ready'}, buffs=STANCE, debuffs=REND),
    Scenario('число целей неизвестно и меняет выбор: блокировка', ('blocked', 'context/targets'),
             numbers={'context/targets': None}, spells={'mortal_strike': 'ready', 'sweeping_strikes': 'ready'},
             buffs=STANCE, debuffs=REND),
    Scenario('Colossus не поддержан: отказ модели', ('refused', 'героической ветки'),
             fixture=dict(FIXTURE, hero=62, talents=['mortal_strike'])),
]
