"""Unholy DK (Rider of the Apocalypse, San'layn) adapter over the pinned SimC APL.

Source lists: docs/dk-unholy-apl/build-requirements.json (every unholy() list; the
pinned APL has no hero_tree.* conditions, both trees share it). Readiness gates
follow the pinned sc_death_knight.cpp ready()/target_ready(); the HUD colour alone
does not encode them. Replacements cast from a base button are reported with their
own spellID for cast confirmation. Unknown inputs stay unknown; every adaptation is
labelled in each decision.
"""
import re
from apl import APLRuntime, Expression, Unknown, unknown, binary


class UnholyAPL(APLRuntime):
    spec_id = 252
    trait_file = '../traits/death_knight-traits.json'   # hero trees come from the profile
    require_cast_confirmation = True
    spells = {
        'festering_strike':85948, 'scourge_strike':55090, 'death_coil':47541, 'epidemic':207317,
        'putrefy':1247378, 'soul_reaper':343294, 'outbreak':77575, 'army_of_the_dead':42650,
        'dark_transformation':1233448, 'death_and_decay':43265, 'raise_dead':46584,
        'arcane_torrent':50613, 'lights_judgment':255647, 'bag_of_tricks':312411, 'berserking':26297,
        'blood_fury':20572, 'fireblood':265221, 'ancestral_call':274738, 'arcane_pulse':260364,
    }
    # Player auras (proc squares). festering_scythe_tt is a SimC player buff but a
    # debuff on the target in game (1241077): read on the current target.
    buffs = {
        'sudden_doom':81340, 'dark_transformation':1235391, 'forbidden_knowledge':1242223,
        'lesser_ghoul_ready':1254252, 'festering_scythe':458123, 'blightfall':1271975,
        'blighted':1271199, 'essence_of_the_blood_queen':433925, 'vampiric_strike':433899,
        'gift_of_the_sanlayn':434153, 'army_of_the_dead':42650, 'reaping':1242654,
        'power_infusion':10060,
    }
    debuffs = {'soul_reaper_debuff':1241521, 'virulent_plague':191587, 'dread_plague':1240996,
               'festering_scythe_tt':1241077}
    # SimC make_fallback: without the talent the buff exists but is never up.
    buff_talents = {
        'sudden_doom':'sudden_doom', 'dark_transformation':'dark_transformation',
        'forbidden_knowledge':'forbidden_knowledge', 'festering_scythe':'festering_scythe',
        'festering_scythe_tt':'festering_scythe', 'blightfall':'blightfall',
        'essence_of_the_blood_queen':'vampiric_strike', 'vampiric_strike':'vampiric_strike',
        'gift_of_the_sanlayn':'gift_of_the_sanlayn', 'army_of_the_dead':'army_of_the_dead',
        'reaping':'reaping',
    }
    # Action -> talent that grants it (ready() is false without the talent).
    talent_actions = {
        'scourge_strike':'scourge_strike', 'putrefy':'putrefy', 'soul_reaper':'soul_reaper',
        'outbreak':'outbreak', 'army_of_the_dead':'army_of_the_dead',
        'dark_transformation':'dark_transformation',
    }
    # set_replacement_action: action -> (cast name, spellID, aura, talent). The base
    # button casts the replacement while the aura is up.
    replacements = {
        'festering_strike':('festering_scythe', 458128, 'festering_scythe', 'festering_scythe'),
        'scourge_strike':('vampiric_strike', 433895, 'vampiric_strike', 'vampiric_strike'),
        'death_coil':('necrotic_coil', 1242174, 'forbidden_knowledge', 'forbidden_knowledge'),
        'epidemic':('graveyard', 383269, 'forbidden_knowledge', 'forbidden_knowledge'),
        'dark_transformation':('blightfall', 1271967, 'blightfall', 'blightfall'),
    }
    # raise_dead_t::ready() needs "no active ghoul"; the HUD has no pet state.
    not_executed = frozenset({'raise_dead'})
    max_stacks = {'essence_of_the_blood_queen':5}   # sc_spell_data.inc 433925
    durations = {'death_and_decay':10.}             # sc_spell_data.inc 43265
    cooldown_aliases = {'any_dnd':'death_and_decay'}
    soul_reaper_threshold = 35                      # soul_reaper_t::target_ready, spell effect 2

    def __init__(self, reader, root, bindings, settings):
        super().__init__(reader, root, bindings, settings)
        if self.cfg.get('apl',{}).get('sourceCommit') != '4c7c73621e596419b5bd6faa5d68940a9c640379':
            raise ValueError('Экспорт и пакет Unholy используют разные версии SimC')
        if 'runic_power' not in self.cfg.get('resources', {}) or not self.cfg.get('runes'):
            raise ValueError('Нужен экспорт рыцаря смерти с силой рун и рунами')
        self.adaptations = (
            'Текущая выбранная цель: target_if не переключает цели, active_dots — по дебаффу текущей цели',
            'Без предметов, зелий и планирования внешнего PI',
            'Событий рейда нет: raid_event.*.exists = ложь',
            'Время боя неизвестно: «бой кончается» не срабатывает, «бой продолжится» выполняется',
            'Питомцы: армия — по ауре Army of the Dead, горгулья — по её остатку >5 с; Raise Dead не нажимается',
            'Dark Transformation: наличие вурдалака — по готовности кнопки в HUD',
            'festering_scythe_tt — дебафф 1241077 на текущей цели вместо баффа SimC',
        )
        for rows in self.lists.values():
            for row in rows:
                if 'target_if' in row:
                    row['original_target_if'] = row.pop('target_if')
                    self.label(row, 'текущая цель вместо target_if='+row['original_target_if'])
        # Exact equivalence, not an adaptation: Lesser Ghoul stacks exist only while
        # the aura is up; its presence comes from colour, the digit is not read.
        self.rewrite(r'buff\.lesser_ghoul_ready\.stack=0\b', 'buff.lesser_ghoul_ready.down', 'stack=0 = аура снята')
        self.rewrite(r'buff\.lesser_ghoul_ready\.stack>=1\b', 'buff.lesser_ghoul_ready.up', 'stack>=1 = аура есть')
        # Unset fight length never assumes the fight is ending (as Fury's Bladestorm TTD).
        self.rewrite(r'fight_remains>([^&|)]+)', r'(!ahw_fight_known|fight_remains>\1)', 'время боя неизвестно — бой продолжится')
        self.rewrite(r'fight_remains<([^&|)]+)', r'(ahw_fight_known&fight_remains<\1)', 'время боя неизвестно — не конец боя')
        self.coverage_gaps = (
            'питомцы: состояние вурдалака/армии/горгульи не видно; Raise Dead вручную',
            'Death and Decay — наземное заклинание: бинд должен ставить его без прицела (макрос @player)',
            'DoT и target_if — только текущая цель',
            'предметы и зелья: исполнение не подключено',
            'ID, замены на кнопках и цвета рун в игре не проверены',
        )

    @staticmethod
    def label(row, text):
        row.setdefault('upstreamSource', row['source'])
        row.setdefault('adapted', []).append(text)
        condition = ',if='+row['if'] if 'if' in row else ''
        row['source'] = 'AHelperW ('+'; '.join(row['adapted'])+'): '+row['action']+condition

    def rewrite(self, pattern, replacement, text):
        found = 0
        for rows in self.lists.values():
            for row in rows:
                condition = row.get('if', '')
                changed = re.sub(pattern, replacement, condition)
                if changed != condition:
                    found += 1
                    row['if'] = changed
                    row['expressions'] = dict(row['expressions'], **{'if':Expression(changed)})
                    self.label(row, text)
        if not found:
            raise ValueError('Изменилось исходное условие Unholy: '+pattern)

    def fallback(self, name, field):
        """SimC fallback buff without its talent: never up."""
        talent = self.buff_talents.get(name)
        if talent and talent not in self.talents:
            return field == 'down' if field in ('up', 'react', 'down') else 0
        return None

    def charges(self, action, field):
        spell = self.spells.get(action)
        display = self.aliases.get(spell, spell)
        square = self.squares.get(('spell', display))
        if not square:
            return unknown(f'{action}.{field}')
        spec, multi = square[1], square[1].get('charges') not in (False, None)
        maximum = spec.get('maxCharges') if multi and spec.get('charges') != 'unknown-max' else (1 if not multi else None)
        if field == 'max_charges':
            return maximum if isinstance(maximum, (int, float)) and maximum > 0 else unknown(f'{action}.max_charges')
        if multi:
            return self.number(square[0]+'/stacks')
        # One charge: the cooldown state alone decides (nores/unusable is not a cooldown).
        state = self.state('spell', display)
        if state in ('ready', 'nores', 'unusable', 'outofrange'): return 1
        if state in ('cd', 'almost'): return 0
        return unknown(f'{action}.charges')

    def resolve(self, name):
        parts = name.split('.')
        if name == 'ahw_fight_known':
            return not isinstance(self.number('context/fight'), Unknown)
        if name == 'gcd.max':
            return super().resolve('gcd')
        if name in ('charges', 'max_charges'):
            return self.charges(self.current, name)
        if name == 'duration':
            return self.durations.get(self.current, unknown('длительность '+str(self.current)))
        if parts[0] == 'raid_event':
            # Adaptation: no scheduled raid events; other fields sit behind .exists.
            return False if parts[-1] == 'exists' else unknown(name)
        if parts[0] == 'trinket':
            # Disabled coordination model, NOT a claim about equipped items.
            return False if '.is.' in name or '.has_' in name or parts[-1] in ('up', 'react') else 0
        if parts[0] == 'pet':
            if name == 'pet.army_ghoul.active':
                return self.resolve('buff.army_of_the_dead.up')
            if name == 'pet.gargoyle.active':
                # Army of the Dead summons the gargoyle (25 s) with the army aura (30 s).
                if 'summon_gargoyle' not in self.talents:
                    return False
                return binary('>', self.resolve('buff.army_of_the_dead.remains'), 5)
            return unknown(name+' (питомцы не видны в HUD)')
        if parts[0] in ('buff', 'debuff', 'dot') and len(parts) == 3:
            kind, aura, field = parts
            constant = self.fallback(aura, field)
            if constant is not None:
                return constant
            if kind == 'buff' and field == 'max_stack':
                return self.max_stacks.get(aura, unknown(name))
            if kind == 'dot' and aura in self.debuffs and field == 'active_dots':
                # Adaptation: the current target stands for every enemy.
                up = self.aura('debuff', self.debuffs[aura], 'up')
                return up if isinstance(up, Unknown) else int(up)
            if kind == 'debuff' or (kind == 'buff' and aura in self.debuffs):
                return self.aura('debuff', self.debuffs[aura], field) if aura in self.debuffs else unknown(name)
            if kind == 'buff' and aura == 'vampiric_strike' and field in ('up', 'react', 'down'):
                # SimC triggers the Vampiric Strike buff when Gift of the San'layn starts;
                # either aura means the button casts Vampiric Strike.
                up = binary('|', self.aura('proc', 433899, 'up'), self.resolve('buff.gift_of_the_sanlayn.up'))
                return (not up if not isinstance(up, Unknown) else up) if field == 'down' else up
        if parts[0] == 'cooldown' and len(parts) == 3:
            action, field = self.cooldown_aliases.get(parts[1], parts[1]), parts[2]
            if action in self.spells:
                talent = self.talent_actions.get(action)
                if talent and talent not in self.talents:
                    return field in ('ready', 'up')
                if field in ('charges', 'max_charges'):
                    return self.charges(action, field)
                spell = self.spells[action]
                display = self.aliases.get(spell, spell)
                square = self.squares.get(('spell', display))
                if not square or field == 'duration':
                    return super().resolve('cooldown.'+action+'.'+field)
                state = self.state('spell', display)
                # cooldown.X.ready is about the cooldown only; lack of runes/RP or an
                # unusable button does not mean "on cooldown".
                if field in ('up', 'ready', 'remains') and state in ('ready', 'nores', 'unusable', 'outofrange'):
                    return field in ('ready', 'up') or 0
                if field in ('up', 'ready') and state in ('cd', 'almost'):
                    return False
                if field == 'remains' and state in ('cd', 'almost'):
                    return self.number(square[0]+'/timer')
                return unknown(name)
        return super().resolve(name)

    def available(self, action):
        if action in self.not_executed:
            return False
        talent = self.talent_actions.get(action)
        if talent and talent not in self.talents:
            return False
        result = super().available(action)
        if result is False:
            return False
        if action == 'soul_reaper':
            # target_ready: target at/below 35% or Reaping. Not the HUD colour alone.
            hp = self.number('resource/targetHealthPercent')
            allowed = binary('|', self.resolve('buff.reaping.up'), binary('<=', hp, self.soul_reaper_threshold))
            result = binary('&', result, allowed)
        return result

    def decide(self, data):
        result = super().decide(data)
        if result.get('status') == 'ready' and result['action'] in self.replacements:
            cast, spell, aura, talent = self.replacements[result['action']]
            if talent in self.talents:
                active = self.resolve('buff.'+aura+'.up')
                if isinstance(active, Unknown):
                    result = {'status':'blocked', 'missing':sorted(active.reasons), 'rule':result['rule'], 'list':result['list'],
                              'reason':'Нужны данные: замена кнопки '+result['action']+' на '+cast+': '+', '.join(sorted(active.reasons))}
                elif active:
                    # The press casts the replacement; confirmation expects its ID.
                    result = dict(result, spellID=spell, castAs=cast)
        result['mode'] = 'unholy-current-target-no-items'
        result['adaptations'] = self.adaptations
        return result
