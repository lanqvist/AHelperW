"""Frost DK (251) adapter over the pinned SimC APL: Deathbringer (33) and Rider (32).

Source lists: docs/dk-frost-apl/build-requirements.json (whole frost() lists; both
hero trees share them and differ only by runtime hero_tree.*/talent.* conditions).
Readiness gates, fallback buffs and replacement actions follow the pinned
sc_death_knight.cpp; the HUD colour alone does not encode them. Unknown stays unknown.
"""
import re
from apl import APLRuntime, Expression, Unknown, unknown, binary

COMMIT = '4c7c73621e596419b5bd6faa5d68940a9c640379'


class FrostAPL(APLRuntime):
    spec_id = 251
    trait_file = '../traits/death_knight-traits.json'
    require_cast_confirmation = True
    spells = {
        'obliterate':49020, 'frost_strike':49143, 'howling_blast':49184, 'frostscythe':207230,
        'glacial_advance':194913, 'remorseless_winter':196770, 'pillar_of_frost':51271,
        'breath_of_sindragosa':1249658, 'frostwyrms_fury':279302, 'empower_rune_weapon':47568,
        'reapers_mark':439843, 'raise_dead':46585, 'mind_freeze':47528,
        'blood_fury':20572, 'berserking':26297, 'arcane_pulse':260364, 'lights_judgment':255647,
        'ancestral_call':274738, 'fireblood':265221, 'bag_of_tricks':312411,
    }
    buffs = {
        'killing_machine':51124, 'rime':59052, 'pillar_of_frost':51271, 'breath_of_sindragosa':1249658,
        'remorseless_winter':196770, 'gathering_storm':211805, 'icy_onslaught':1230273,
        'bonegrinder_frost':377103, 'frostbane':1229310, 'unholy_strength':53365,
        'chosen_of_frostbrood_haste':1265630, 'chosen_of_frostbrood_fwf':1265639, 'power_infusion':10060,
        # MID1 Frost 4pc 1264802 effect #2 -> 1269322. SimC's ready()
        # permits this free ERW cast independently of ordinary charges.
        'mid1_4pc_buff':1269322,
    }
    debuffs = {'razorice':51714, 'frost_fever':55095, 'reapers_mark_debuff':434765}
    # Stacking auras: react is the stack count (react=2, react<2-...); a bare
    # react is rewritten to the equivalent .up so an unread digit cannot block it.
    stacked = ('buff.killing_machine', 'debuff.razorice')
    # make_fallback in create_buffs(): without the talent (rank) the buff never
    # rises, exactly like an absent aura. Chosen of Frostbrood ranks: 1 / 2 / 1
    # tiers (trait node 110400); the FWF recall buff needs the third tier.
    buff_talents = {
        'killing_machine':('killing_machine',1), 'pillar_of_frost':('pillar_of_frost',1),
        'breath_of_sindragosa':('breath_of_sindragosa',1), 'gathering_storm':('gathering_storm',1),
        'icy_onslaught':('icy_onslaught',1), 'bonegrinder_frost':('bonegrinder',1), 'frostbane':('frostbane',1),
        'chosen_of_frostbrood_haste':('chosen_of_frostbrood',1), 'chosen_of_frostbrood_fwf':('chosen_of_frostbrood',4),
    }
    # Action -> talent that grants it (the action's spell data is the talent).
    talent_actions = {
        'obliterate':'obliterate', 'frost_strike':'frost_strike', 'howling_blast':'howling_blast',
        'frostscythe':'frostscythe', 'pillar_of_frost':'pillar_of_frost', 'breath_of_sindragosa':'breath_of_sindragosa',
        'frostwyrms_fury':'frostwyrms_fury', 'empower_rune_weapon':'empower_rune_weapon',
        'reapers_mark':'reapers_mark', 'raise_dead':'raise_dead', 'mind_freeze':'mind_freeze',
    }
    # set_replacement_action: same APL action and button, another cast ID while
    # the buff is up (Frostbane 1228433, Chosen of Frostbrood recall 1265384).
    replacements = {'frost_strike':('frostbane',1228433,'frostbane'),
                    'frostwyrms_fury':('chosen_of_frostbrood',1265384,'chosen_of_frostbrood_fwf')}

    def __init__(self, reader, root, bindings, settings):
        super().__init__(reader, root, bindings, settings)
        if self.cfg.get('apl',{}).get('sourceCommit') != COMMIT:
            raise ValueError('Экспорт и пакет Frost DK используют разные версии SimC')
        if 'runic_power' not in self.cfg.get('resources', {}) or not self.cfg.get('runes'):
            raise ValueError('Нужен экспорт рыцаря смерти с силой рун и рунами')
        self.adaptations = (
            'Текущая выбранная цель: target_if не переключает цели (first: — условие на текущей цели)',
            'Без сценарных событий рейда: raid_event.* как в SimC без событий',
            'fight_remains<N — только при заданном прогнозе боя; без прогноза бой не считается заканчивающимся',
            'Без предметов, зелий, Anti-Magic Shell и внешнего PI',
            'Действия вне GCD (Breath of Sindragosa, ERW, расовые) — только при готовом GCD',
            'Raise Dead не нажимается: состояние гуля не видно, квадрат в игре «неизвестно»',
        )
        for name, rows in self.lists.items():
            self.lists[name] = [self.adapt(row) for row in rows]
        # Every active_enemies use compares with a constant <= 5: literals,
        # variable.frostscythe_priority (=3) and 3+(1*talent.deathly_blows) (<=4),
        # so 1..6 covers every outcome of an unknown target count.
        sources = [a.get('upstreamSource', a['source']) for rows in self.lists.values() for a in rows]
        scythe = [a for a in self.lists.get('variables', []) if a.get('name') == 'frostscythe_priority']
        rhs = [m for src in sources for m in re.findall(r'active_enemies(?:=|!=|<=|>=|<|>)([^&|)]+)', src)]
        allowed = re.compile(r'\d+|variable\.frostscythe_priority|3\+\(1\*talent\.deathly_blows')
        if (len(scythe) == 1 and scythe[0].get('value') == '3' and len(rhs) == sum(s.count('active_enemies') for s in sources)
                and all(allowed.fullmatch(r) for r in rhs)):
            self.enemy_values = tuple(range(1, 7))
        self.coverage_gaps = (
            'предметы, зелья, Anti-Magic Shell: не исполняются',
            'target_if на нескольких целях: только текущая цель',
            'в игре не проверено ничего: ID, цвета рун, OCR силы рун и стаков',
        )
        self.erw_free_cast_tracked = ('proc', self.buffs['mid1_4pc_buff']) in self.squares
        if self.erw_free_cast_tracked:
            self.adaptations += ('Бесплатное ERW от MID1 4pc — по отдельному баффу 1269322; обычные заряды и их перезарядка читаются отдельно',)
        else:
            # Older exports remain usable for the ordinary charged action. They
            # do not carry the new observation and cannot enable free ERW casts.
            self.coverage_gaps += ('Бесплатное ERW от MID1 4pc не подключено: нужен новый экспорт с баффом 1269322',)

    def adapt(self, row):
        """Labelled rewrites of one pinned rule; the upstream text is kept."""
        text, labels = row['source'], []
        target_if = row.get('target_if')
        if target_if is not None:
            text = text.replace(',target_if=' + target_if, '')
            if target_if.startswith('first:'):
                # SimC casts only on a target satisfying first:; here that is the current one.
                gate = '(' + target_if[6:] + ')'
                text = text.replace(',if=', ',if=' + gate + '&(', 1) + ')' if ',if=' in text else text + ',if=' + gate
            labels.append('текущая цель вместо target_if=' + target_if)
        adapted = re.sub(r'fight_remains<(\d+)', r'(ahw_fight_known&fight_remains<\1)', text)
        adapted = re.sub(r'fight_remains>(\d+)', r'(!ahw_fight_known|fight_remains>\1)', adapted)
        if adapted != text:
            text = adapted; labels.append('fight_remains только при заданном прогнозе')
        for aura in self.stacked:
            # react without a comparison is react>0, i.e. the aura is up.
            adapted = re.sub(re.escape(aura) + r'\.react(?![=<>!])', aura + '.up', text)
            if adapted != text:
                text = adapted; labels.append('эквивалент: ' + aura + '.react как .up')
        if not labels:
            return row
        pieces = [p for p in text.split(',') if p]
        action = {'action':pieces[0], 'list':row['list'], 'upstreamSource':row['source'],
                  'source':'AHelperW (' + '; '.join(labels) + '): ' + text}
        for p in pieces[1:]:
            key, value = p.split('=', 1); action[key] = value
        action['expressions'] = {k:Expression(action[k]) for k in ('if','value','value_else','condition') if k in action}
        return action

    def buff_id(self, name):
        # Frozen Dominion replaces the spec spell 196770 and its buff (trait 377226).
        if name == 'remorseless_winter' and 'frozen_dominion' in self.talents:
            return 1233152
        return self.buffs[name]

    def buff(self, name, field):
        gate = self.buff_talents.get(name)
        if gate and self.talent_ranks.get(gate[0], 0) < gate[1]:
            return field == 'down'
        if field == 'react' and 'buff.' + name in self.stacked:
            field = 'stack'
        return self.aura('proc', self.buff_id(name), field)

    def learned(self, action):
        talent = self.talent_actions.get(action)
        if talent and talent not in self.talents:
            return False
        return not (action == 'remorseless_winter' and 'frozen_dominion' in self.talents)

    def resolve(self, name):
        parts = name.split('.')
        if name == 'ahw_fight_known':
            return not isinstance(self.number('context/fight'), Unknown)
        if parts[0] == 'talent' and parts[-1] == 'rank':
            return self.talent_ranks.get(parts[1], 0)
        if name == 'gcd.max':
            return self.resolve('gcd')
        if parts[0] == 'raid_event':
            # Adaptation: SimC raid_event.cpp without matching events returns a
            # huge in/cooldown and 0 for exists/up/remains/duration.
            return 1e10 if parts[-1] in ('in', 'cooldown') else 0
        if name == 'main_hand.2h':
            equipment = self.cfg.get('equipment', [])
            main = next((i for i in equipment if i.get('slot') == 16 and i.get('itemID')), {})
            offhand = any(i.get('slot') == 17 and i.get('itemID') for i in equipment)
            loc = main.get('equipLoc')
            if loc == 'INVTYPE_2HWEAPON':
                # Contradictory static exports must not imply a weapon type.
                return unknown(name) if offhand else True
            if loc in ('INVTYPE_WEAPON', 'INVTYPE_WEAPONMAINHAND'):
                return False
            # Preserve the legacy dual-wield inference only when type metadata
            # is absent. One item alone never establishes a two-handed weapon.
            if loc is None and offhand:
                return False
            return unknown(name)
        if parts[0] == 'buff' and parts[1] in self.buffs:
            return self.buff(parts[1], parts[2])
        if parts[0] in ('debuff', 'dot') and parts[1] in self.debuffs:
            field = {'ticking':'up', 'react':'stack' if 'debuff.'+parts[1] in self.stacked else 'up'}.get(parts[2], parts[2])
            return self.aura('debuff', self.debuffs[parts[1]], field)
        if parts[0] == 'cooldown' and parts[1] in self.spells:
            action, field = parts[1:3]
            if not self.learned(action):
                # SimC: an unlearned cooldown never starts.
                return unknown(name) if field == 'duration' else (field in ('ready', 'up') or 0)
            spell = self.spells[action]
            display = self.aliases.get(spell, spell)
            square = self.squares.get(('spell', display))
            if not square or field == 'duration':
                return super().resolve(name)
            state = self.state('spell', display)
            if field == 'full_recharge_time':
                if not square[1].get('charges'):
                    return 0 if state in ('ready','nores','unusable','outofrange') else (
                        self.number(square[0]+'/timer') if state in ('cd','almost') else unknown(name))
                charges, maximum = self.number(square[0]+'/stacks'), square[1].get('maxCharges')
                if isinstance(charges, Unknown) or not isinstance(maximum, int):
                    return unknown(name)
                # Full: 0. One short: the running recharge. Deeper needs the
                # recharge duration, which the HUD does not show.
                if charges >= maximum: return 0
                if charges == maximum-1: return self.number(square[0]+'/timer')
                return unknown(name+' (нет длительности перезарядки)')
            # cooldown.X.ready is about the cooldown only: lack of runes/runic
            # power or an unusable button does not mean "on cooldown".
            if field in ('up', 'ready', 'remains') and state in ('ready', 'nores', 'unusable', 'outofrange'):
                return field in ('ready', 'up') or 0
            if field in ('up', 'ready') and state in ('cd', 'almost'):
                return False
            if field == 'remains' and state in ('cd', 'almost'):
                return self.number(square[0]+'/timer')
            return unknown(name)
        return super().resolve(name)

    # In game (log 20260929T090556Z-18333389) the Raise Dead square stayed unknown in
    # every frame and blocked the cooldown list; like Unholy, it is not pressed.
    not_executed = frozenset({'raise_dead'})

    def available(self, action):
        if action in self.not_executed:
            return False
        if action in self.spells and not self.learned(action):
            return False
        result = super().available(action)
        if action == 'empower_rune_weapon' and self.erw_free_cast_tracked:
            square = self.squares.get(('spell', self.spells[action]))
            if not square or not self.bindings.get(str(self.spells[action])):
                return False
            # The cooldown colour and digits describe ordinary charges, which
            # this specific proc bypasses. Do not bypass a refused/unknown button.
            if self.state('spell', self.spells[action]) in ('ready', 'cd', 'almost'):
                result = binary('|', result, self.buff('mid1_4pc_buff', 'up'))
        if result is False:
            return False
        replacement = self.replacements.get(action)
        if replacement:
            # The cast ID to confirm depends on the replacement buff; it must be known.
            state = self.buff(replacement[2], 'up')
            result = binary('&', result, state if isinstance(state, Unknown) else True)
        return result

    def decide(self, data):
        result = super().decide(data)
        if (result.get('status') == 'ready' and result['action'] == 'empower_rune_weapon'
                and self.erw_free_cast_tracked and self.buff('mid1_4pc_buff', 'up') is True):
            result = dict(result, freeChargeAuraID=self.buffs['mid1_4pc_buff'])
        if result.get('status') == 'ready' and result['action'] in self.replacements:
            name, spell, buff = self.replacements[result['action']]
            if self.buff(buff, 'up') is True:
                result = dict(result, spellID=spell, replacement=name)
        result['mode'] = 'dk-frost-current-target-no-items'
        result['adaptations'] = self.adaptations
        return result
