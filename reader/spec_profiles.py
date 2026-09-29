"""Versioned specialization packages. Geometry and personal bindings stay separate."""
from dataclasses import dataclass
import importlib
from pathlib import Path


@dataclass(frozen=True)
class HeroTree:
    subtree: int
    key: str    # SimC hero_tree.<key>
    name: str


@dataclass(frozen=True)
class SpecProfile:
    id: str
    spec_id: int
    name: str
    data_directory: str
    # Supported hero trees; the active one comes from the talent string's
    # subtree switch (talent_decode). Any other tree is refused.
    hero_trees: tuple
    resources: tuple
    status: str
    # Aura timers that gate core APL rules and must stay fresh (OCR period, s).
    fast_aura_timers: frozenset = frozenset()
    # On/off auras: their stack counter is not read, color carries the state.
    binary_auras: frozenset = frozenset()
    # 'module:Class' of the reader model; empty means reading the HUD only.
    model: str = ''

    def hero_tree(self, subtree):
        return next((t for t in self.hero_trees if t.subtree == subtree), None)


SLAYER = HeroTree(60, 'slayer', 'Slayer')
DEATHBRINGER = HeroTree(33, 'deathbringer', 'Deathbringer')
RIDER = HeroTree(32, 'rider_of_the_apocalypse', 'Rider of the Apocalypse')
SANLAYN = HeroTree(31, 'sanlayn', "San'layn")

PROFILES = {
    71: SpecProfile('warrior.arms.slayer', 71, 'Arms / Slayer', 'arms-apl',
                    (SLAYER,), ('rage',), 'game-observed',
                    binary_auras=frozenset({107574, 446035, 386164, 10060, 208086, 388539}),
                    model='apl:ArmsAPL'),
    # Not yet observed in game: input stays off by default after loading.
    # Enrage 184362 gates rampage,if=buff.enrage.remains<gcd.
    72: SpecProfile('warrior.fury.slayer', 72, 'Fury / Slayer', 'fury-apl',
                    (SLAYER,), ('rage',), 'experimental',
                    fast_aura_timers=frozenset({184362}),
                    binary_auras=frozenset({184362, 1719, 446035, 386196, 10060, 383873, 85739}),
                    model='fury_apl:FuryAPL'),
    269: SpecProfile('monk.windwalker.shado-pan', 269, 'ВВ / Шадо-Пан', 'windwalker-apl',
                     (HeroTree(65, 'shado_pan', 'Шадо-Пан'),), ('energy', 'chi'), 'experimental',
                     model='windwalker_apl:WindwalkerAPL'),
    # Death Knight: offline development (docs/melee-dps-plan.md). The spec work
    # adds the model, fast/binary auras and the data package.
    # --- Frost DK (251): edited only by the Frost work ---
    # Pillar of Frost 51271 and Remorseless Winter 196770 / Frozen Dominion
    # 1233152 remains gate rules against gcd.max. Stacks are read only for
    # Killing Machine 51124, Razorice 51714, Gathering Storm 211805, Icy Onslaught 1230273.
    251: SpecProfile('deathknight.frost', 251, 'Frost DK', 'dk-frost-apl',
                     (DEATHBRINGER, RIDER), ('runic_power', 'runes'), 'in-development',
                     fast_aura_timers=frozenset({51271, 196770, 1233152}),
                     binary_auras=frozenset({59052, 51271, 1249658, 196770, 1233152, 377103, 1229310, 53365,
                                             1265630, 1265639, 10060, 55095, 434765}),
                     model='dk_frost_apl:FrostAPL'),
    # --- Unholy DK (252): edited only by the Unholy work ---
    # Fast timers: Dark Transformation (remains<gcd*2 / >5), Essence of the Blood
    # Queen (remains<gcd*3), Festering Scythe (remains<=3). Binary: on/off auras and
    # target debuffs; Lesser Ghoul stack=0/>=1 is read as aura down/up.
    252: SpecProfile('deathknight.unholy', 252, 'Unholy DK', 'dk-unholy-apl',
                     (RIDER, SANLAYN), ('runic_power', 'runes'), 'in-development',
                     fast_aura_timers=frozenset({1235391, 433925, 458123}),
                     binary_auras=frozenset({81340, 1235391, 1242223, 1254252, 458123, 1271975, 1271199,
                                             42650, 1242654, 433899, 434153, 10060,
                                             191587, 1240996, 1241521, 1241077}),
                     model='dk_unholy_apl:UnholyAPL'),
    # --- end of DK entries ---
}


def profile_for(spec_id):
    try:
        return PROFILES[spec_id]
    except KeyError:
        raise ValueError('Для этой специализации пакет APL ещё не подключён') from None


def create_apl(reader, data_root, bindings, settings):
    profile = profile_for(reader.cfg.get('specID'))
    root = Path(data_root) / profile.data_directory
    declared = reader.cfg.get('apl', {}).get('profileID')
    if declared and declared != profile.id:
        raise ValueError('Специализация и пакет APL в экспорте не совпадают')
    if not profile.model:
        raise ValueError(f'{profile.name}: модель APL ещё не реализована; доступно только чтение HUD')
    module, _, name = profile.model.partition(':')
    model = getattr(importlib.import_module(module), name)(reader, root, bindings, settings)
    model.profile = profile
    return model
