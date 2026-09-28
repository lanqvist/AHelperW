"""Experimental pinned Windwalker/Shado-Pan adapter, with explicit coverage gaps.

No absent channel, target-selection or recharge input is replaced by a guess.
Source IDs: docs/windwalker-apl/source.json, pinned sc_monk.cpp and spell dump.
"""
from apl import APLRuntime, Expression, Unknown, unknown, binary


class WindwalkerAPL(APLRuntime):
    spec_id = 269
    trait_file = 'monk-traits.json'
    allowed_heroes = {65}
    require_cast_confirmation = True
    spells = {
        'tiger_palm':100780, 'blackout_kick':100784, 'rising_sun_kick':107428,
        'rushing_wind_kick':467307, 'fists_of_fury':113656, 'spinning_crane_kick':101546,
        'whirling_dragon_punch':152175, 'zenith':1249625, 'zenith_stomp':1272696,
        'touch_of_death':322109, 'touch_of_karma':122470, 'strike_of_the_windlord':392983,
        'invoke_xuen_the_white_tiger':123904, 'celestial_conduit':443028,
        'slicing_winds':1217413, 'arcane_torrent':129597, 'berserking':26297,
        'blood_fury':20572, 'fireblood':265221, 'ancestral_call':274738,
        'lights_judgment':255647, 'bag_of_tricks':312411, 'haymaker':287712,
        'arcane_pulse':260364, 'rocket_barrage':69041,
    }
    buffs = {
        'combo_breaker':116768, 'dance_of_chiji':325202, 'zenith':1249625,
        'zenith_stomp':1291484, 'tigereye_brew_1':1261724,
        'rushing_wind_kick':1250554, 'whirling_dragon_punch':196742,
        'unbroken_rhythm':1297033, 'power_infusion':10060,
        'invoke_xuen_the_white_tiger':123904, 'heart_of_the_jade_serpent':443421,
        'heart_of_the_jade_serpent_unity_within':443616,
        'heart_of_the_jade_serpent_yulons_avatar':1238904,
    }
    talent_actions = {'zenith', 'zenith_stomp', 'rising_sun_kick', 'rushing_wind_kick',
                      'fists_of_fury', 'whirling_dragon_punch', 'strike_of_the_windlord',
                      'invoke_xuen_the_white_tiger', 'celestial_conduit', 'slicing_winds'}
    bloodlust = (2825,32182,80353,90355,160452,264667,390386)
    combo_ids = {100780,100784,107428,467307,113656,101546,152175,1249625,
                 1272696,322109,392983,1217413}
    # Deferred with the user: preserve the APL rule but do not execute it until
    # the separate usable action has been observed on the character.
    deferred_actions = frozenset({'zenith_stomp'})
    # Whirling Dragon Punch and Touch of Death markers matched their cast events
    # in log 20260928T210541Z-aee16ff5 (152175 at +30.09 s, 322109 at +15.55 s).
    observed_combo_markers = frozenset({'tiger_palm', 'blackout_kick', 'rising_sun_kick',
                                       'fists_of_fury', 'spinning_crane_kick', 'zenith_stomp',
                                       'whirling_dragon_punch', 'touch_of_death'})

    def __init__(self, reader, root, bindings, settings):
        super().__init__(reader, root, bindings, settings)
        self.adaptations = (
            'Текущая выбранная цель; target_if не переключает цели',
            'Без предметов, зелий и планирования внешнего PI',
            'Зенит: стаки и откаты из SimC; расход двух зарядов без прогноза времени боя',
        )
        for rows in self.lists.values():
            for row in rows:
                if 'target_if' in row:
                    row['original_target_if'] = row.pop('target_if')
        # User-approved first playable mode. Keep the upstream source files
        # intact and label this replacement explicitly in every decision.
        condition = ('!buff.zenith.up&combo_strike&charges>=2&'
                     '(cooldown.rising_sun_kick.remains|chi<2&energy<50|active_enemies>1)')
        sync_rows = [r for r in self.lists['zenith'] if 'buff.tigereye_brew_1.stack' in r.get('if','')]
        if len(sync_rows) != 1:
            raise ValueError('Не найдено единственное правило Zenith со стаками отвара')
        sync = sync_rows[0]
        sync_condition = sync['if']
        # Keep upstream talent-dependent stack thresholds and cooldown windows.
        # The selected-target/no-items mode omits only lifetime gates here;
        # item expressions continue to use its explicit disabled-item model.
        for gate in (
            '(variable.patchwerk|fight_style.dungeonroute&target.time_to_die>27+5*talent.drinking_horn_cover)&',
            '(target.time_to_die>30&fight_style.dungeonroute|target.time_to_die>25&!fight_style.dungeonroute)&',
        ):
            if sync_condition.count(gate) != 1:
                raise ValueError('Изменилось исходное условие времени жизни для Zenith')
            sync_condition = sync_condition.replace(gate,'',1)
        sync_condition = '!buff.zenith.up&combo_strike&(' + sync_condition + ')'
        self.lists['zenith'] = [{
            'action':'zenith', 'list':'zenith', 'if':condition,
            'source':'AHelperW adapted capped charges: zenith,if='+condition,
            'expressions':{'if':Expression(condition)},
        }, {
            'action':'zenith', 'list':'zenith', 'if':sync_condition,
            'source':'AHelperW adapted stack/cooldown sync: zenith,if='+sync_condition,
            'upstreamSource':sync['source'],
            'expressions':{'if':Expression(sync_condition)},
        }]
        if self.cfg.get('apl',{}).get('sourceCommit') != '4c7c73621e596419b5bd6faa5d68940a9c640379':
            raise ValueError('Экспорт и пакет ВВ используют разные версии SimC')
        for key in ('energy', 'chi'):
            if key not in self.cfg.get('resources', {}):
                raise ValueError('Нужен новый экспорт монаха с ресурсом '+key)
        self.sequence = None
        self.last_combo = None
        self.last_cast = None
        self.last_capture = None
        self.coverage_gaps = (
            'zenith_stomp: отдельное применение отложено до подтверждения на персонаже',
            'адаптация: текущая цель вместо сравнения времени жизни всех целей',
            'каналы: ожидание завершения, без раннего прерывания и cast-during',
            'предметы и зелья: исполнение не подключено',
            'ротация и ID заменяющих спеллов ещё не проверены в игре',
        )

    def reset_observations(self):
        self.sequence = self.last_combo = self.last_cast = self.last_capture = None

    def baseline_combo(self, records):
        """Seed only from the newest classified event, never scan past unknowns.

        Zenith can trigger an automatic combo action absent from the journal;
        native markers must resolve it. This baseline is combo history only,
        not confirmation of any input sent by the reader.
        """
        seqs = [r['sequence'] for r in records]
        self.sequence = next((s for s in seqs if all((s-t)%65535 < 32768 for t in seqs)), None)
        latest = next((r for r in records if r['sequence'] == self.sequence), None)
        self.last_combo = self.last_cast = None
        if latest and latest['spellID'] in self.combo_ids and latest['spellID'] != 1249625:
            self.last_combo = self.last_cast = latest['spellID']

    def observe(self, data):
        """Read every fresh frame, including frames while waiting for input feedback.

        A classified latest event establishes the baseline. Subsequent events
        must be contiguous; native markers remain the preferred evidence.
        """
        receipt = data.get('castReceipt', {})
        captured = data.get('capturedAt')
        if receipt.get('status') != 'readable' or not data.get('valid'):
            self.reset_observations()
            return
        if captured == self.last_capture:
            return
        self.last_capture = captured
        records = receipt.get('records', [])
        if not records:
            self.sequence = 0
            self.last_combo = self.last_cast = None
            return
        seqs = [r['sequence'] for r in records]
        if self.sequence is None:
            self.baseline_combo(records)
            return
        fresh = sorted((r for r in records if 0 < (r['sequence']-self.sequence)%65535 < 32768),
                       key=lambda r:(r['sequence']-self.sequence)%65535)
        if self.sequence not in seqs and not fresh:
            # Reload/reset or a backwards journal: never retain old combo state.
            self.baseline_combo(records)
            return
        for event in fresh:
            if (event['sequence']-self.sequence)%65535 != 1:
                self.last_combo = self.last_cast = None
            self.sequence = event['sequence']
            spell = event['spellID']
            if spell in self.combo_ids:
                self.last_combo = spell
            else:
                # An unclassified event could be an override or an automatic
                # combo action. Do not silently carry the previous attack over it.
                self.last_combo = None
            if spell == 1249625 and 'zenith_stomp' in self.talents:
                # SimC Zenith also triggers Stomp; public receipt ordering must
                # be checked against the native helper markers on this client.
                self.last_combo = None
            self.last_cast = spell

    def absent_buff(self, name):
        # SimC constructs fallback buffs for the inactive Conduit tree.
        return (name.startswith('heart_of_the_jade_serpent') or
                name == 'invoke_xuen_the_white_tiger') and 65 in self.hero_trees

    def resolve(self, name):
        parts = name.split('.')
        if parts[0] == 'talent':
            return self.talent_ranks.get(parts[1],0) if parts[-1] == 'rank' else parts[1] in self.talents
        if name in ('chi','energy'):
            return self.number('resource/'+name)
        if name == 'energy.max':
            # The HUD shows the live maximum; the export's snapshot can be stale
            # (exported 120 while the character had 150 in the next fight).
            live = self.number('context/maxenergy')
            if not isinstance(live, Unknown) and live > 0:
                return live
        if name in ('chi.max','energy.max'):
            value = self.cfg.get('resourceMeta',{}).get(parts[0],{}).get('max')
            return value if isinstance(value,(int,float)) and value > 0 else unknown(name)
        if name == 'energy.regen':
            return self.number('context/energyRegen')
        if name == 'energy.time_to_max':
            deficit = binary('-',self.resolve('energy.max'),self.resolve('energy'))
            regen = self.resolve('energy.regen')
            return binary('%',deficit,regen)
        if name in ('gcd','gcd.max'):
            # Monk base melee GCD is 1s, non-hasted in this pinned source.
            return 1.0
        if name == 'combo_strike':
            history = self.data.get('comboHistory', {})
            active = history.get('active', [])
            if (history.get('status') == 'readable' and len(active) == 1
                    and active[0] in self.observed_combo_markers):
                # These markers were compared with manual casts in the first WW
                # recording. Automatic Zenith Stomp is visible here even when
                # UNIT_SPELLCAST_SUCCEEDED only reports Zenith itself.
                return self.current != active[0]
            if self.last_combo is None:
                return unknown('история комбо: нужно наблюсти применение удара')
            return self.spells.get(self.current) != self.last_combo
        if parts[0] == 'prev':
            return self.last_cast == self.spells.get(parts[1]) if self.last_cast is not None else unknown(name)
        if parts[0] == 'fight_style':
            style = self.settings.get('fightStyle')
            return style == parts[1] if style else unknown('тип боя SimC не выбран')
        if name.startswith('trinket.'):
            # Disabled coordination model, NOT a claim about equipped items.
            return False if '.is.' in name or '.has_' in name else 0
        if name.startswith('cooldown.potion.'):
            return 0
        if name == 'cooldown.invoke_power_infusion_0.duration':
            return 0
        if parts[0] == 'buff' and self.absent_buff(parts[1]):
            return parts[-1] == 'down'
        if parts[:2] == ['buff','bloodlust']:
            values = [self.aura('proc',spell,parts[2]) for spell in self.bloodlust]
            if parts[2] in ('up','react','down'):
                result = False
                for spell in self.bloodlust:
                    result = binary('|',result,self.aura('proc',spell,'up'))
                return (not result if not isinstance(result,Unknown) else result) if parts[2]=='down' else result
            active = [v for v in values if not isinstance(v,Unknown) and v > 0]
            return max(active) if active else (next((v for v in values if isinstance(v,Unknown)),0))
        if parts[0] == 'cooldown' and parts[1] in self.spells:
            action, field = parts[1:3]
            if action in self.talent_actions and action not in self.talents:
                return field in ('ready','up')
            spell = self.spells[action]
            display = self.aliases.get(spell,spell)
            square = self.squares.get(('spell',display))
            if not square:
                return unknown(name)
            state = self.state('spell',display)
            if field in ('full_recharge_time','charges_fractional'):
                # Current duration comes from a separate native-rendered field.
                # Base spell cooldown is not the duration of a charge recharge.
                charges = self.number(square[0]+'/stacks')
                maximum = square[1].get('maxCharges')
                if not isinstance(charges,Unknown) and maximum and charges == maximum:
                    return 0 if field == 'full_recharge_time' else charges
                duration = self.number('context/zenithRecharge') if action=='zenith' else unknown(name)
                remains = self.number(square[0]+'/timer')
                if (not any(isinstance(v,Unknown) for v in (charges,duration,remains))
                        and maximum and 0 <= charges < maximum and duration > 0 and 0 <= remains <= duration):
                    return remains + (maximum-charges-1)*duration if field=='full_recharge_time' else charges+1-remains/duration
                return unknown(name+' (нет длительности перезарядки)')
            if field in ('up','ready','remains') and state in ('ready','nores','unusable','outofrange'):
                return field in ('ready','up')
            if field in ('up','ready') and state in ('cd','almost'):
                return False
            if field == 'remains' and state in ('cd','almost'):
                return self.number(square[0]+'/timer')
        return super().resolve(name)

    def requires_display_charge(self, action):
        # Stomp spends its own aura, not a charge of the base Zenith button.
        return action != 'zenith_stomp'

    def available(self, action):
        if action in self.deferred_actions:
            return False
        if action in self.talent_actions and action not in self.talents:
            return False
        result = super().available(action)
        if action == 'touch_of_death':
            # SimC target_ready is separate from the APL expression. The HUD
            # currently has percent HP, not target absolute HP vs player max HP.
            # First mode supports only the confirmed Improved ToD execute branch.
            if 'improved_touch_of_death' not in self.talents:
                return False
            hp = self.number('resource/targetHealthPercent')
            result = binary('&', result, binary('&', binary('>', hp, 0), binary('<', hp, 15)))
        if action in ('rising_sun_kick','rushing_wind_kick') and 'rushing_wind_kick' in self.talents:
            result = binary('&',result,self.aura('proc',1250554,'down' if action=='rising_sun_kick' else 'up'))
        if action in ('zenith','zenith_stomp'):
            result = binary('&',result,self.aura('proc',1291484,'down' if action=='zenith' else 'up'))
        return result

    def decide(self, data):
        self.observe(data)
        result = super().decide(data)
        result['mode'] = 'ww-current-target-no-items'
        result['adaptations'] = self.adaptations
        if result.get('status') == 'ready':
            # Channel controls must never silently disappear during extraction.
            row = next((r for r in self.lists[result['list']] if r['source']==result['rule']),{})
            if any(key in row for key in ('cancel_if','interrupt_if','interrupt','chain')):
                return {'status':'blocked','reason':'Правило требует ещё не подключённого управления каналом',
                        'rule':result['rule'],'list':result['list']}
        return result
