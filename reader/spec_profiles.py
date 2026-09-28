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


PROFILES = {
    71: SpecProfile('warrior.arms.slayer', 71, 'Arms / Slayer', 'arms-apl',
                    frozenset({60}), ('rage',), 'game-observed'),
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
    else:
        from windwalker_apl import WindwalkerAPL
        model = WindwalkerAPL(reader, root, bindings, settings)
    model.profile = profile
    return model
