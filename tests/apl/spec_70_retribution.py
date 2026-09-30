"""Retribution / Templar (70) offline scenarios. Synthetic build, not the user's.

Light's Deliverance: 433732 is not shown by the client, so a free Hammer of
Light is inferred from a 427441 window that opened without a Wake event.
"""
import time

from harness import Scenario, frame, make_model

FIXTURE = {
    'specID': 70, 'traitFile': '../traits/paladin-traits.json', 'hero': 48,
    'talents': ['wake_of_ashes', 'blade_of_justice', 'lights_guidance', 'lights_deliverance'],
    'squares': [('spell', s) for s in (255937, 184575, 20271)]
               + [('proc', s) for s in (427441, 433732)],
    'resources': ('holy_power',),
    'resourceMeta': {'holy_power': {'powerType': 9, 'max': 5}},
}
NO_DELIVERANCE = dict(FIXTURE, talents=['wake_of_ashes', 'blade_of_justice', 'lights_guidance'])
BLADE = 184575
WAKE = 255937
LOW = {'resource/holy_power': 2}
SPELLS = {'hammer_of_light': 'ready', 'blade_of_justice': 'ready'}
WAKE_CD = {'wakeCooldown': 'cd'}


def journal(*spells):
    return {'status': 'readable', 'records': [{'sequence': i, 'spellID': s} for i, s in enumerate(spells, 1)]}


def history(*steps, fixture=None):
    """Feed earlier frames: (seconds ago, 427441 'up'/'down', journal spells)."""
    def factory(default, settings):
        model = make_model(fixture or default, settings)
        now = time.time()
        for ago, ready, spells in steps:
            buffs = {'hammer_of_light_ready': (18., 1)} if ready == 'up' else {}
            model.observe(frame(model, spells=SPELLS, buffs=buffs, numbers=LOW, context=WAKE_CD,
                                capturedAt=now - ago, castReceipt=journal(*spells)))
        return model
    return factory


def final(spells, remains=1., **extra):
    return dict(spells=SPELLS, buffs={'hammer_of_light_ready': (remains, 1)}, numbers=LOW,
                context=WAKE_CD, castReceipt=journal(*spells), **extra)


SCENARIOS = [
    Scenario('окно 427441 без Wake, 2 энергии: бесплатный Hammer of Light у конца', ('ready', 'hammer_of_light'),
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE]), (1., 'up', [BLADE])),
             **final([BLADE])),
    Scenario('окно после события Wake, 2 энергии: обычный молот недоступен', ('ready', 'blade_of_justice'),
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE, WAKE]), (1., 'up', [BLADE, WAKE])),
             **final([BLADE, WAKE])),
    Scenario('бесплатный молот с запасом времени: SimC держит его', ('ready', 'blade_of_justice'),
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE]), (1., 'up', [BLADE])),
             **final([BLADE], remains=15.)),
    Scenario('окно 427441 открылось 0.2 с назад без Wake: ждём событие', ('blocked', 'hammer_of_light_free'),
             factory=history((3., 'down', [BLADE]), (.2, 'up', [BLADE])),
             **final([BLADE])),
    Scenario('окно пережило применение молота: новый прок Light\'s Deliverance', ('ready', 'hammer_of_light'),
             factory=history((4., 'down', [BLADE]), (3., 'up', [BLADE, WAKE]), (2., 'up', [BLADE, WAKE, 427453]),
                             (1., 'up', [BLADE, WAKE, 427453])),
             **final([BLADE, WAKE, 427453])),
    Scenario('пропуск в журнале применений: происхождение окна неизвестно', ('blocked', 'журнала'),
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE])),
             **dict(final([BLADE]), castReceipt={'status': 'readable', 'records': [
                 {'sequence': 1, 'spellID': BLADE}, {'sequence': 3, 'spellID': BLADE}]})),
    Scenario('журнал нечитаем: без вывода бесплатного молота', ('blocked', 'журнала'),
             factory=history((3., 'down', [BLADE]), (1., 'up', [BLADE])),
             **dict(final([BLADE]), castReceipt={'status': 'unreadable'})),
    Scenario('без Light\'s Deliverance окно без Wake не бесплатное', ('ready', 'blade_of_justice'),
             fixture=NO_DELIVERANCE,
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE]), (1., 'up', [BLADE])),
             **final([BLADE])),
    Scenario('Wake не на КД: Light\'s Deliverance невозможен', ('blocked', 'Wake не на КД'),
             factory=history((3., 'down', [BLADE]), (2., 'up', [BLADE]), (1., 'up', [BLADE])),
             **dict(final([BLADE]), context={'wakeCooldown': 'ready'})),
]

# Execution Sentence and the Wake sync decided by TTD bounds (reader health slope).
ES_FIXTURE = dict(FIXTURE, talents=FIXTURE['talents'] + ['execution_sentence', 'avenging_wrath'],
                  squares=FIXTURE['squares'] + [('spell', 343527), ('spell', 31884)])
ES_SPELLS = {'wake_of_ashes': 'ready', 'blade_of_justice': 'ready', 'execution_sentence': 'ready',
             'avenging_wrath': ('cd', 60.)}
LONG = {'status': 'estimate', 'low': 40., 'high': None, 'highUnbounded': True}
UNDECIDED = {'status': 'estimate', 'low': 5., 'high': 30., 'highUnbounded': False}
READY_WAKE = {'wakeCooldown': 'ready'}

SCENARIOS += [
    Scenario('TTD доказан >10 по границам: Execution Sentence', ('ready', 'execution_sentence'),
             fixture=ES_FIXTURE, spells=ES_SPELLS, numbers=LOW, context=READY_WAKE, ttdEstimate=LONG),
    Scenario('TTD не решён: ES пропускается, Wake не ждёт её', ('ready', 'wake_of_ashes'),
             fixture=ES_FIXTURE, spells=ES_SPELLS, numbers=LOW, context=READY_WAKE, ttdEstimate=UNDECIDED),
    Scenario('оценки нет: как раньше без прогноза, Wake', ('ready', 'wake_of_ashes'),
             fixture=ES_FIXTURE, spells=ES_SPELLS, numbers=LOW, context=READY_WAKE),
    Scenario('TTD доказан, но AW скоро: ES ждёт, Wake ждёт ES', ('ready', 'blade_of_justice'),
             fixture=ES_FIXTURE, spells=dict(ES_SPELLS, avenging_wrath=('cd', 10.)), numbers=LOW,
             context=READY_WAKE, ttdEstimate=LONG),
    Scenario('ручной прогноз TTD 5 с важнее оценки: ES нет, Wake', ('ready', 'wake_of_ashes'),
             fixture=ES_FIXTURE, spells=ES_SPELLS, numbers=dict(LOW, **{'context/ttd': 5}),
             context=READY_WAKE, ttdEstimate=LONG),
]
