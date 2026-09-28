"""Fury/Slayer adapter over the pinned SimC APL, with explicit coverage gaps.

Source lists: docs/fury-apl/build-requirements.json (Mountain Thane removed).
Readiness gates follow the pinned sc_warrior.cpp ready() overrides; the HUD
colour alone does not encode them. Unknown inputs stay unknown.
"""
from apl import APLRuntime, Expression, Unknown, unknown, binary


class FuryAPL(APLRuntime):
    spec_id = 72
    # The class trait table is shared with Arms and pinned to the same build.
    trait_file = '../arms-apl/warrior-traits.json'
    allowed_heroes = {60}
    require_cast_confirmation = True
    spells = {
        'rampage':184367, 'bloodthirst':23881, 'bloodbath':335096, 'raging_blow':85288,
        'crushing_blow':335097, 'execute':5308, 'recklessness':1719, 'avatar':107574,
        'bladestorm':227847, 'odyns_fury':385059, 'whirlwind':190411, 'storm_bolt':107570,
        'charge':100, 'pummel':6552, 'berserker_stance':386196,
        'arcane_torrent':69179, 'lights_judgment':255647, 'bag_of_tricks':312411,
        'berserking':26297, 'blood_fury':20572, 'fireblood':265221, 'ancestral_call':274738,
    }
    buffs = {
        'enrage':184362, 'recklessness':1719, 'whirlwind':85739, 'bladestorm':446035,
        'hack_and_slash':383873, 'berserker_stance':386196, 'power_infusion':10060,
        # Observed in the first manual fight; 280776 (early research) never lit.
        'sudden_death':52437,
    }
    # Action -> talent that grants it (ready() is false without the talent).
    talent_actions = {
        'rampage':'rampage', 'bloodthirst':'bloodthirst', 'raging_blow':'raging_blow',
        'recklessness':'recklessness', 'avatar':'avatar', 'bladestorm':'bladestorm',
        'odyns_fury':'odyns_fury', 'storm_bolt':'storm_bolt', 'berserker_stance':'berserker_stance',
        'bloodbath':'reckless_abandon', 'crushing_blow':'reckless_abandon',
    }

    def __init__(self, reader, root, bindings, settings):
        super().__init__(reader, root, bindings, settings)
        if self.cfg.get('apl',{}).get('sourceCommit') != '4c7c73621e596419b5bd6faa5d68940a9c640379':
            raise ValueError('Экспорт и пакет Fury используют разные версии SimC')
        if 'rage' not in self.cfg.get('resources', {}):
            raise ValueError('Нужен экспорт воина с регионом ярости')
        self.adaptations = (
            'Без предметов, зелий и планирования внешнего PI',
            'Bladestorm вне Recklessness по TTD<=5 только при заданном TTD',
        )
        # Upstream: bladestorm,if=buff.recklessness.up|target.time_to_die<=5.
        # An unset TTD would block the whole list outside Recklessness; the
        # adaptation drops only the short-lifetime trigger, never assumes it.
        gate = 'target.time_to_die<=5'
        for rows in self.lists.values():
            for row in rows:
                if row['action'] == 'bladestorm' and gate in row.get('if', ''):
                    condition = row['if'].replace(gate, 'ahw_ttd_known&' + gate)
                    row.update({'if':condition, 'upstreamSource':row['source'],
                                'source':'AHelperW adapted TTD gate: bladestorm,if='+condition,
                                'expressions':dict(row['expressions'], **{'if':Expression(condition)})})
        self.coverage_gaps = (
            'предметы и зелья: исполнение не подключено',
            'ротация, ID замен и подтверждения применений ещё не проверены в игре',
        )

    def execute_threshold(self):
        return 35 if 'massacre' in self.talents else 20

    def resolve(self, name):
        parts = name.split('.')
        if name == 'ahw_ttd_known':
            return not isinstance(self.number('context/ttd'), Unknown)
        if parts[0] == 'cooldown' and parts[1] in self.spells:
            action, field = parts[1:3]
            talent = self.talent_actions.get(action)
            if talent and talent not in self.talents:
                return field in ('ready', 'up')
            spell = self.spells[action]
            display = self.aliases.get(spell, spell)
            square = self.squares.get(('spell', display))
            if not square or field == 'duration':
                return super().resolve(name)
            state = self.state('spell', display)
            # cooldown.X.ready is about the cooldown only; lack of rage or an
            # unusable Execute above the threshold does not mean "on cooldown".
            if field in ('up', 'ready', 'remains') and state in ('ready', 'nores', 'unusable', 'outofrange'):
                return field in ('ready', 'up') or 0
            if field in ('up', 'ready') and state in ('cd', 'almost'):
                return False
            if field == 'remains' and state in ('cd', 'almost'):
                return self.number(square[0]+'/timer')
            return unknown(name)
        return super().resolve(name)

    def available(self, action):
        talent = self.talent_actions.get(action)
        if talent and talent not in self.talents:
            return False
        result = super().available(action)
        if result is False:
            return False
        if 'reckless_abandon' in self.talents:
            # sc_warrior.cpp ready(): during Recklessness Bloodthirst/Raging Blow
            # become Bloodbath/Crushing Blow on the same buttons, and not otherwise.
            if action in ('bloodthirst', 'raging_blow'):
                result = binary('&', result, self.aura('proc', 1719, 'down'))
            elif action in ('bloodbath', 'crushing_blow'):
                result = binary('&', result, self.aura('proc', 1719, 'up'))
        if action == 'berserker_stance':
            result = binary('&', result, self.aura('proc', 386196, 'down'))
        if action == 'execute':
            # target_ready: Sudden Death or target at/below the execute threshold.
            # The HUD's usable state is not relied on alone (Touch of Death lesson).
            hp = self.number('resource/targetHealthPercent')
            allowed = binary('|', self.aura('proc', 52437, 'up'), binary('<=', hp, self.execute_threshold()))
            result = binary('&', result, allowed)
        return result

    def decide(self, data):
        result = super().decide(data)
        result['mode'] = 'fury-slayer-no-items'
        result['adaptations'] = self.adaptations
        return result
