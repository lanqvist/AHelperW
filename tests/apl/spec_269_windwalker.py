"""Windwalker / Shado-Pan (269) offline scenarios. Synthetic build, not the user's."""
from harness import Scenario

FIXTURE = {
    'specID': 269, 'traitFile': 'monk-traits.json', 'hero': 65,
    'talents': ['rising_sun_kick', 'fists_of_fury'],
    'squares': [('spell', s) for s in (100780, 100784, 107428, 113656, 101546, 152175, 322109, 122470,
                                       116705, 392983, 123904, 443028, 1217413)]
               + [('spell', 1249625, {'charges': True, 'maxCharges': 2})]
               + [('proc', s) for s in (116768, 325202, 1261724, 1249625, 1291484, 1250554, 196742,
                                        1297033, 10060, 2825)],
    'aliases': {
        'rushing_wind_kick': {'spellID': 467307, 'displaySpellID': 107428, 'sharesBindingWith': 'rising_sun_kick'},
        'zenith_stomp': {'spellID': 1272696, 'displaySpellID': 1249625, 'procID': 1291484, 'sharesBindingWith': 'zenith'},
    },
    'resources': ('energy', 'chi'),
    'resourceMeta': {'energy': {'powerType': 3, 'max': 100}, 'chi': {'powerType': 12, 'max': 5}},
}
OPENER = {'context/time': 1., 'resource/chi': 2, 'resource/energy': 100, 'context/energyRegen': 10}
PATCHWERK = {'fightStyle': 'patchwerk'}


def combo(last):
    """Native 'last combo strike' marker, as reader.py decodes it."""
    return {'status': 'readable', 'active': [last], 'markers': {last: 'active'}, 'diagnosticOnly': True}


SCENARIOS = [
    Scenario('начало боя без истории комбо: блокировка', ('blocked', 'история комбо'),
             settings=PATCHWERK, spells={'tiger_palm': 'ready'}, numbers=OPENER),
    Scenario('начало боя, последний удар Blackout Kick: Tiger Palm', ('ready', 'tiger_palm'),
             settings=PATCHWERK, spells={'tiger_palm': 'ready'}, numbers=OPENER, comboHistory=combo('blackout_kick')),
    Scenario('последний удар Tiger Palm: повтор запрещён, Rising Sun Kick', ('ready', 'rising_sun_kick'),
             settings=PATCHWERK, spells={'tiger_palm': 'ready', 'rising_sun_kick': 'ready'},
             numbers=dict(OPENER, **{'context/time': 30.}), comboHistory=combo('tiger_palm')),
    Scenario('GCD не готов', ('waiting', 'Ожидание GCD'), gcd='cd',
             settings=PATCHWERK, spells={'tiger_palm': 'ready'}, numbers=OPENER, comboHistory=combo('blackout_kick')),
]
