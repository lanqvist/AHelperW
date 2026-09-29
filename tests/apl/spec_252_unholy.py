"""Unholy DK (252) offline scenarios, both hero trees. Synthetic builds, not the user's."""
from harness import Scenario

SPELLS = (85948, 55090, 47541, 207317, 1247378, 343294, 77575, 42650, 1233448, 43265)
PROCS = (81340, 1235391, 1242223, 1254252, 458123, 1271975, 1271199, 42650, 1242654, 10060)
SANLAYN_PROCS = (433899, 433925, 434153)
DEBUFFS = (191587, 1240996, 1241521, 1241077)
ALIASES = {
    'festering_scythe': {'spellID': 458128, 'displaySpellID': 85948, 'sharesBindingWith': 'festering_strike'},
    'vampiric_strike': {'spellID': 433895, 'displaySpellID': 55090, 'sharesBindingWith': 'scourge_strike'},
    'necrotic_coil': {'spellID': 1242174, 'displaySpellID': 47541, 'sharesBindingWith': 'death_coil'},
    'graveyard': {'spellID': 383269, 'displaySpellID': 207317, 'sharesBindingWith': 'epidemic'},
    'blightfall': {'spellID': 1271967, 'displaySpellID': 1233448, 'sharesBindingWith': 'dark_transformation'},
}
CORE = ['scourge_strike', 'putrefy', 'soul_reaper', 'outbreak', 'army_of_the_dead', 'dark_transformation',
        'sudden_doom', 'festering_scythe']


def unholy(hero, talents, procs=PROCS, debuffs=DEBUFFS, spells=SPELLS, **extra):
    fixture = {'specID': 252, 'traitFile': '../traits/death_knight-traits.json', 'hero': hero, 'talents': talents,
               'squares': [('spell', s) for s in spells] + [('proc', s) for s in procs] + [('debuff', s) for s in debuffs],
               'aliases': ALIASES, 'resources': ('runic_power',), 'runes': True,
               'resourceMeta': {'runic_power': {'powerType': 6, 'max': 100}, 'runes': {'powerType': 5, 'max': 6}}}
    fixture.update(extra)
    return fixture


SANLAYN = unholy(31, CORE + ['vampiric_strike', 'gift_of_the_sanlayn'], procs=PROCS + SANLAYN_PROCS)
RIDER = unholy(32, CORE + ['forbidden_knowledge', 'summon_gargoyle', 'cycle_of_death', 'riders_champion'])
# Festering Scythe window already applied to the target: rule 1 of single_target stays off.
PLAGUED = {191587: (20, 1), 1240996: (20, 1), 1241077: (20, 1)}
FIXTURE = SANLAYN


def cast(action, spell):
    """ready action whose press casts `spell` (confirmation expects that ID)."""
    def check(_model, result):
        ok = result.get('status') == 'ready' and result['action'] == action and result['spellID'] == spell
        return ok, f"{result.get('status')}: {result.get('action')} → {result.get('spellID')} ({result.get('castAs', '')}) · {result.get('rule') or result.get('reason')}"
    return check


SCENARIOS = [
    # Cooldowns and opener (both trees share the lists)
    Scenario("San'layn: плагов нет — Outbreak", ('ready', 'outbreak'),
             spells={'outbreak': 'ready', 'festering_strike': 'ready'}, runes=4, numbers={'resource/runic_power': 20}),
    Scenario('Rider: окно Festering Scythe на цели — Army of the Dead', ('ready', 'army_of_the_dead'), fixture=RIDER,
             spells={'army_of_the_dead': 'ready', 'festering_strike': 'ready'}, debuffs=PLAGUED, runes=4,
             numbers={'resource/runic_power': 20}),
    Scenario('армия на КД >30 с — Dark Transformation', ('ready', 'dark_transformation'),
             spells={'dark_transformation': 'ready', 'army_of_the_dead': ('cd', 60.), 'festering_strike': 'ready'},
             debuffs=PLAGUED, runes=4, numbers={'resource/runic_power': 20}),
    Scenario('Blightfall на кнопке Dark Transformation (аура 1271975)', fixture=unholy(32, CORE + ['blightfall']),
             spells={'dark_transformation': 'ready'}, buffs={'blightfall': 'up', 'dark_transformation': (1., 1)},
             debuffs=PLAGUED, runes=4, numbers={'resource/runic_power': 20},
             check=cast('dark_transformation', 1271967)),
    # Festering Strike / Scythe, Lesser Ghoul
    Scenario('бафф Festering Scythe истекает — удар заменяется на Festering Scythe', buffs={'festering_scythe': (2., 1)},
             spells={'festering_strike': 'ready', 'scourge_strike': 'ready'}, debuffs=PLAGUED, runes=4,
             numbers={'resource/runic_power': 20}, check=cast('festering_strike', 458128)),
    Scenario('бой кончается (время боя 5 с): Festering Scythe не тратится', ('ready', 'death_coil'),
             buffs={'festering_scythe': (2., 1), 'sudden_doom': 'up'},
             spells={'festering_strike': 'ready', 'death_coil': 'ready'}, debuffs=PLAGUED, runes=4,
             numbers={'resource/runic_power': 40, 'context/fight': 5.}),
    Scenario('Rider: Lesser Ghoul + Blighted — Scourge Strike (стаки по цвету)', ('ready', 'scourge_strike'), fixture=RIDER,
             spells={'scourge_strike': 'ready', 'death_coil': 'nores', 'festering_strike': 'ready'},
             buffs={'lesser_ghoul_ready': 'up', 'blighted': 'up'}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 20}),
    Scenario('без Lesser Ghoul и силы рун — Festering Strike', ('ready', 'festering_strike'), fixture=RIDER,
             spells={'scourge_strike': 'ready', 'death_coil': 'nores', 'festering_strike': 'ready'},
             debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 20}),
    # Runic power
    Scenario('Sudden Doom — Death Coil', spells={'death_coil': 'ready', 'scourge_strike': 'ready', 'festering_strike': 'ready'},
             buffs={'sudden_doom': 'up'}, debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 40},
             check=cast('death_coil', 47541)),
    Scenario('сила рун у капа (дефицит 5) — Death Coil', ('ready', 'death_coil'),
             spells={'death_coil': 'ready', 'scourge_strike': 'ready', 'festering_strike': 'ready'},
             buffs={'essence_of_the_blood_queen': (15., 5)}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 95}),
    Scenario('руны кончились, сила рун мала — ждать', ('waiting', 'Нет доступного'), fixture=RIDER,
             spells={'scourge_strike': 'nores', 'death_coil': 'nores', 'festering_strike': 'nores'},
             debuffs=PLAGUED, runes=0, numbers={'resource/runic_power': 20}),
    # Soul Reaper gate (target_ready)
    Scenario('Soul Reaper выше 35% без Reaping не выбирается — Putrefy', ('ready', 'putrefy'),
             spells={'soul_reaper': 'ready', 'putrefy': 'ready', 'dark_transformation': ('cd', 30.)},
             buffs={'dark_transformation': (10., 1)}, debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 40}),
    Scenario('Soul Reaper при 30% HP цели', ('ready', 'soul_reaper'),
             spells={'soul_reaper': 'ready', 'putrefy': 'ready'}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 40, 'resource/targetHealthPercent': 30.}),
    Scenario('Soul Reaper выше 35% с Reaping', ('ready', 'soul_reaper'), fixture=unholy(31, CORE + ['reaping', 'vampiric_strike'], procs=PROCS + SANLAYN_PROCS),
             spells={'soul_reaper': 'ready', 'putrefy': 'ready', 'dark_transformation': ('cd', 30.)},
             buffs={'dark_transformation': (10., 1), 'reaping': 'up'}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 40}),
    # San'layn
    Scenario("San'layn: Essence истекает — Vampiric Strike на кнопке Scourge Strike",
             spells={'scourge_strike': 'ready', 'death_coil': 'ready', 'festering_strike': 'ready'},
             buffs={'vampiric_strike': 'up', 'essence_of_the_blood_queen': (2., 3)}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 40}, check=cast('scourge_strike', 433895)),
    Scenario("San'layn: Gift of the San'layn тоже даёт Vampiric Strike",
             spells={'scourge_strike': 'ready', 'death_coil': 'nores', 'festering_strike': 'ready'},
             buffs={'gift_of_the_sanlayn': 'up', 'essence_of_the_blood_queen': (2., 3)}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 20}, check=cast('scourge_strike', 433895)),
    Scenario("San'layn: стаки Essence ниже максимума 5 — Scourge Strike", ('ready', 'scourge_strike'),
             spells={'scourge_strike': 'ready', 'death_coil': 'ready', 'festering_strike': 'ready'},
             buffs={'essence_of_the_blood_queen': (15., 3)}, debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 40}),
    Scenario('Rider: ауры San\'layn не нужны (Essence = нет) — Death Coil', ('ready', 'death_coil'), fixture=RIDER,
             spells={'death_coil': 'ready', 'scourge_strike': 'ready', 'festering_strike': 'ready'},
             buffs={'lesser_ghoul_ready': 'up'}, debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 40}),
    # AoE
    Scenario('3 цели, руны <2 — Epidemic', ('ready', 'epidemic'),
             spells={'epidemic': 'ready', 'death_coil': 'ready', 'festering_strike': 'ready'},
             debuffs=PLAGUED, runes=1, numbers={'resource/runic_power': 60, 'context/targets': 3}),
    Scenario('Rider, 3 цели, Cycle of Death, Putrefy на КД — Death and Decay', ('ready', 'death_and_decay'), fixture=RIDER,
             spells={'death_and_decay': 'ready', 'epidemic': 'ready', 'putrefy': ('cd', 10.)},
             debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 60, 'context/targets': 3}),
    Scenario('Rider, 3 цели, Forbidden Knowledge — Necrotic Coil вместо Epidemic', fixture=RIDER,
             spells={'epidemic': 'ready', 'death_coil': 'ready', 'death_and_decay': ('cd', 10.)},
             buffs={'forbidden_knowledge': (20., 1)}, debuffs=PLAGUED, runes=2,
             numbers={'resource/runic_power': 60, 'context/targets': 3}, check=cast('death_coil', 1242174)),
    Scenario('Rider, 4 цели, Forbidden Knowledge — Graveyard', fixture=RIDER,
             spells={'epidemic': 'ready', 'death_coil': 'ready', 'death_and_decay': ('cd', 10.)},
             buffs={'forbidden_knowledge': (20., 1)}, debuffs=PLAGUED, runes=2,
             numbers={'resource/runic_power': 60, 'context/targets': 4}, check=cast('epidemic', 383269)),
    # Blocked / waiting with a reason
    Scenario('AoE: руны не прочитаны — блокировка', ('blocked', 'руны'),
             spells={'epidemic': 'ready', 'death_coil': 'ready'}, debuffs=PLAGUED,
             runes=['ready', 'unknown', 'cd', 'cd', 'cd', 'cd'], numbers={'resource/runic_power': 60, 'context/targets': 3}),
    Scenario('число целей неизвестно, ST и AoE расходятся — блокировка', ('blocked', 'context/targets'),
             spells={'epidemic': 'ready', 'death_coil': 'ready'}, buffs={'sudden_doom': 'up'}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 60, 'context/targets': None}),
    Scenario('горгулья: остаток армии не прочитан — блокировка (питомец)', ('blocked', 'proc:42650'), fixture=RIDER,
             spells={'epidemic': 'ready', 'death_coil': 'ready', 'death_and_decay': ('cd', 10.)},
             buffs={'forbidden_knowledge': (20., 1), 'army_of_the_dead': 'up'}, debuffs=PLAGUED, runes=3,
             numbers={'resource/runic_power': 60, 'context/targets': 4}),
    Scenario('нет квадрата дебаффа Festering Scythe — блокировка', ('blocked', 'debuff:1241077'),
             fixture=unholy(32, CORE, debuffs=(191587, 1240996, 1241521)),
             spells={'festering_strike': 'ready', 'death_coil': 'ready'}, debuffs={191587: (20, 1), 1240996: (20, 1)},
             runes=3, numbers={'resource/runic_power': 40}),
    Scenario('сила рун неизвестна там, где решает — блокировка', ('blocked', 'resource/runic_power'), fixture=RIDER,
             spells={'death_coil': 'ready', 'festering_strike': 'ready'}, buffs={'dark_transformation': 'down'},
             debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': None}),
    Scenario("San'layn: стаки Essence не прочитаны — блокировка", ('blocked', 'proc:433925'),
             spells={'scourge_strike': 'ready', 'death_coil': 'ready'}, buffs={'essence_of_the_blood_queen': 'up'},
             debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 40}),
    Scenario("San'layn без квадратов Vampiric Strike: замена кнопки неизвестна — блокировка", ('blocked', 'замена кнопки'),
             fixture=unholy(31, CORE + ['vampiric_strike', 'gift_of_the_sanlayn'], procs=PROCS + (433925,)),
             spells={'scourge_strike': 'ready', 'death_coil': 'nores', 'festering_strike': 'ready'},
             buffs={'lesser_ghoul_ready': 'up'}, debuffs=PLAGUED, runes=3, numbers={'resource/runic_power': 20}),
    Scenario('вне боя: Raise Dead не нажимается (вурдалак не виден)', ('waiting', 'Нет доступного'),
             fixture=unholy(32, CORE, spells=SPELLS + (46584,)), combat=False,
             spells={46584: 'ready'}, debuffs=PLAGUED, runes=6, numbers={'resource/runic_power': 0}),
    Scenario('экспорт без рун: отказ', ('refused', 'рунами'), fixture=unholy(32, CORE, runes=False)),
]
