"""Versioned specialization packages. Geometry and personal bindings stay separate."""
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SpecProfile:
    id: str
    spec_id: int
    name: str
    data_directory: str
    hero_trees: frozenset
    resources: tuple
    status: str
    # Aura timers that gate core APL rules and must stay fresh (OCR period, s).
    fast_aura_timers: frozenset = frozenset()
    # On/off auras: their stack counter is not read, color carries the state.
    binary_auras: frozenset = frozenset()


PROFILES = {
    71: SpecProfile('warrior.arms.slayer', 71, 'Arms / Slayer', 'arms-apl',
                    frozenset({60}), ('rage',), 'game-observed',
                    binary_auras=frozenset({107574, 446035, 386164, 10060, 208086, 388539})),
    # Not yet observed in game: input stays off by default after loading.
    # Enrage 184362 gates rampage,if=buff.enrage.remains<gcd.
    72: SpecProfile('warrior.fury.slayer', 72, 'Fury / Slayer', 'fury-apl',
                    frozenset({60}), ('rage',), 'in-development',
                    fast_aura_timers=frozenset({184362}),
                    binary_auras=frozenset({184362, 1719, 446035, 386196, 10060, 383873})),
    269: SpecProfile('monk.windwalker.shado-pan', 269, 'ВВ / Шадо-Пан', 'windwalker-apl',
                     frozenset({65}), ('energy', 'chi'), 'experimental'),
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
    if profile.spec_id == 71:
        from apl import ArmsAPL
        model = ArmsAPL(reader, root, bindings, settings)
    elif profile.spec_id == 72:
        from fury_apl import FuryAPL
        model = FuryAPL(reader, root, bindings, settings)
    elif profile.spec_id == 269:
        from windwalker_apl import WindwalkerAPL
        model = WindwalkerAPL(reader, root, bindings, settings)
    else:
        raise ValueError(f'{profile.name}: модель APL ещё не реализована; доступно только чтение HUD')
    model.profile = profile
    return model
