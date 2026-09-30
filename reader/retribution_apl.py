"""Retribution adapter: pinned 12.1.0 APL, Templar and Herald of the Sun.

Explicit observations gate overrides; an unavailable/unknown HUD is not ready.
See docs/retribution-apl/README.md for adaptations and outstanding game checks.
"""
import re
from apl import APLRuntime, Expression, Unknown, unknown, binary

COMMIT = '4c7c73621e596419b5bd6faa5d68940a9c640379'
# Public cast journal events that start (Wake) or spend (Hammer) 427441.
HAMMER_EVENTS = {255937:'wake', 427453:'hammer'}
# Seconds a Light's Deliverance window must persist without a Wake event:
# the journal may report Wake a frame after the aura appears.
FREE_HAMMER_GRACE = .5


class RetributionAPL(APLRuntime):
    spec_id = 70
    trait_file = '../traits/paladin-traits.json'
    require_cast_confirmation = True
    spells = {
        'rebuke':96231, 'execution_sentence':343527, 'avenging_wrath':31884,
        'hammer_of_light':427453, 'divine_storm':53385, 'templars_verdict':85256,
        'wake_of_ashes':255937, 'divine_toll':375576, 'blade_of_justice':184575,
        'hammer_of_wrath':24275, 'judgment':20271, 'templar_strike':407480,
        'templar_slash':406647, 'crusader_strike':35395,
        'lights_judgment':255647, 'fireblood':265221, 'arcane_torrent':155145,
    }
    buffs = {
        'avenging_wrath':31884, 'hammer_of_light_ready':427441,
        'hammer_of_light_free':433732, 'undisputed_ruling':432629,
        'divine_arbiter_verdict':1306161, 'divine_arbiter_divine_storm':1306162,
        'empyrean_legacy':387178, 'art_of_war':406086, 'righteous_cause':402916,
        'templar_strikes':406648, 'divine_purpose':408458, 'empyrean_power':326733,
        'hammer_of_wrath':1277026,
    }
    debuffs = {'execution_sentence_debuff':343527, 'expurgation':383346}
    talent_actions = {
        'execution_sentence':'execution_sentence', 'avenging_wrath':'avenging_wrath',
        'divine_storm':'divine_storm', 'wake_of_ashes':'wake_of_ashes',
        'divine_toll':'divine_toll', 'blade_of_justice':'blade_of_justice',
        'hammer_of_wrath':'hammer_of_wrath', 'templar_strike':'templar_strikes',
        'templar_slash':'templar_strikes',
    }
    buff_talents = {
        'avenging_wrath':'avenging_wrath', 'empyrean_legacy':'empyrean_legacy',
        'art_of_war':'art_of_war', 'righteous_cause':'righteous_cause',
        'templar_strikes':'templar_strikes', 'divine_purpose':'divine_purpose',
        'empyrean_power':'empyrean_power', 'hammer_of_wrath':'hammer_of_wrath',
        'hammer_of_light_ready':'lights_guidance', 'hammer_of_light_free':'lights_deliverance',
        'undisputed_ruling':'undisputed_ruling',
    }
    # Off-target inventory/movement is not silently fabricated.
    not_executed = {'potion','use_item','invoke_external_buff'}

    def __init__(self, reader, root, bindings, settings):
        super().__init__(reader,root,bindings,settings)
        if self.cfg.get('apl',{}).get('sourceCommit') != COMMIT:
            raise ValueError('Экспорт и пакет Retribution используют разные версии SimC')
        if 'holy_power' not in self.cfg.get('resources',{}):
            raise ValueError('Нужен экспорт паладина с энергией Света')
        # These mappings are from pinned spell data/trait replacements, not from
        # the presence of a live cooldown. Bindings are on the base buttons.
        self.aliases.update({427453:255937,407480:35395,406647:35395,383328:85256})
        # Judgment and Hammer of Wrath are two forms of the user's same button.
        # Keep independent HUD readiness/charges and exact cast confirmation,
        # but resolve both through Judgment's one saved key. Do not duplicate
        # the binding in the personal file (the editor rejects duplicate keys).
        self.bindings = dict(self.bindings)
        self.bindings.pop('24275', None)
        if self.bindings.get('20271'):
            self.bindings['24275'] = self.bindings['20271']
        self.adaptations = (
            'Текущая цель; без предметов, зелий и планирования внешнего PI',
            'Без сценарных событий рейда; TTD — ручной прогноз или границы по здоровью цели, нерешённое сравнение ложно',
            'Execution Sentence требует доказанного TTD>10; пока границы его не подтверждают, триггер пропускается',
            'Пока TTD>10 не доказан, Wake не ждёт триггер Execution Sentence',
            'Действия вне GCD исполняются только при готовом GCD; каналы не прерываются',
        )
        self.coverage_gaps = (
            'Templar: есть ручная запись ресурсов/событий; автонажатия и Herald ещё не проверены',
            'Judgment/Hammer of Wrath: общий бинд; чтение двух форм и автонажатия требуют проверки',
            'Бесплатный Hammer of Light выводится из журнала применений, нативный 433732 не виден; target-аура Execution Sentence не подтверждена',
            'Полная логика предметов, внешних баффов и неизвестного прогноза боя не подключена',
        )
        self.lists = {name:[self.adapt(row) for row in rows] for name,rows in self.lists.items()}
        self.reset_observations()

    def reset_observations(self):
        # Journal position; latest Wake/Hammer event since the last observed
        # end of a 427441 window ('gap' = events lost); window start time.
        self.receipt_sequence = self.last_capture = None
        self.hammer_event = self.hammer_event_at = None
        self.ready_known = self.ready_since = None

    def observe(self, data):
        """Follow 427441 windows and the cast journal for Light's Deliverance.

        Pinned SimC starts 427441 only from Wake of Ashes and from Light's
        Deliverance, which grants 433732 with it (both 20 s, 427441 max 1
        stack). 433732 never lit on this client although three Hammers in the
        manual log spent no Holy Power, so its state is inferred here.
        """
        receipt = data.get('castReceipt', {})
        captured = data.get('capturedAt')
        if not data.get('valid') or receipt.get('status') != 'readable':
            self.reset_observations()
            return
        if captured == self.last_capture:
            return
        self.last_capture = captured
        # Window transitions first: a Wake event of this frame belongs to the
        # next window, a Hammer event of this frame cannot open one.
        state = data.get('rows',{}).get(self.squares[('proc',427441)][0],{}).get('state') \
            if ('proc',427441) in self.squares else None
        if state == 'procoff':
            if self.ready_known == 'proc':
                self.hammer_event = self.hammer_event_at = None
            self.ready_since = None
        elif state == 'proc' and self.ready_known != 'proc':
            # Onset seen only after a known off state; a first frame that is
            # already inside a window has an unobserved start.
            self.ready_since = captured if self.ready_known == 'procoff' else 'unobserved'
        if state in ('proc','procoff'):
            self.ready_known = state
        records = receipt.get('records', [])
        seqs = [r['sequence'] for r in records]
        fresh = []
        if self.receipt_sequence is not None:
            fresh = sorted((r for r in records if 0 < (r['sequence']-self.receipt_sequence)%65535 < 32768),
                           key=lambda r:(r['sequence']-self.receipt_sequence)%65535)
        if self.receipt_sequence is None or (records and self.receipt_sequence not in seqs and not fresh):
            # Baseline or a reset journal: the newest known Wake/Hammer decides.
            newest = next((s for s in seqs if all((s-t)%65535 < 32768 for t in seqs)), 0)
            self.receipt_sequence = newest
            latest = next((HAMMER_EVENTS[r['spellID']] for r in
                           sorted(records, key=lambda r:(newest-r['sequence'])%65535)
                           if r['spellID'] in HAMMER_EVENTS), None)
            self.hammer_event, self.hammer_event_at = latest, captured
            return
        for event in fresh:
            if (event['sequence']-self.receipt_sequence)%65535 != 1:
                self.hammer_event, self.hammer_event_at = 'gap', captured
            self.receipt_sequence = event['sequence']
            kind = HAMMER_EVENTS.get(event['spellID'])
            if kind:
                self.hammer_event, self.hammer_event_at = kind, captured

    def free_hammer(self, field):
        native = self.state('proc',433732)
        if native == 'proc':
            return self.aura('proc',433732,field)
        ready = self.aura('proc',427441,'up')
        if ready is False:
            return field=='down'
        missing = 'buff.hammer_of_light_free: '
        if isinstance(ready, Unknown):
            return unknown(missing+'нет 427441')
        if self.receipt_sequence is None or self.hammer_event == 'gap':
            return unknown(missing+'нет непрерывного журнала применений')
        if self.hammer_event == 'wake':
            # The window of an observed Wake: an ordinary 5 Holy Power Hammer.
            return field=='down'
        # No Wake since the window opened, or the window survived a Hammer:
        # only Light's Deliverance applies 427441 then (with 433732).
        if self.hammer_event == 'hammer':
            since = self.hammer_event_at
            if isinstance(self.ready_since, (int,float)):
                since = max(since, self.ready_since)
        elif isinstance(self.ready_since, (int,float)):
            since = self.ready_since
        else:
            return unknown(missing+'начало окна 427441 не наблюдалось')
        if self.data.get('capturedAt',0)-since < FREE_HAMMER_GRACE:
            return unknown(missing+'ожидание события Wake')
        # Light's Deliverance does not trigger while Wake is ready.
        if self.data.get('rows',{}).get('context/wakeCooldown',{}).get('state') != 'cd':
            return unknown(missing+'Wake не на КД')
        if field in ('up','react'): return True
        if field == 'down': return False
        if field == 'remains':
            # Applied together with 427441, same 20 s duration.
            return self.aura('proc',427441,'remains')
        return unknown(missing+field)

    def adapt(self, row):
        text, labels = row['source'], []
        # SimC pre_es_wake is reset to zero and never updated in this snapshot.
        if row['action']=='variable' and row.get('op')=='reset':
            text = 'variable,name='+row['name']+',value='+row.get('default','0')
            labels.append('op=reset к upstream default')
        for metric in ('target.time_to_die','fight_remains'):
            # Decided by a manual forecast or the reader's health-slope bounds;
            # an undecided comparison is false, as an unset forecast was before.
            pattern = re.escape(metric)+r'([<>]=?)(gcd(?:\*\d+(?:\.\d+)?)?|\d+(?:\.\d+)?)'
            new = re.sub(pattern,lambda m:'~('+m.group(0)+')',text)
            if new!=text:
                text=new; labels.append(metric+': нерешённое сравнение ложно')
        if row['action']=='wake_of_ashes':
            # While TTD>10 is not proven, the ES rule cannot fire. Do not wait
            # for its cooldown; no talent or TTD observation is altered.
            sync='(!talent.execution_sentence|'
            if sync in text:
                text=text.replace(sync,'(!~(target.time_to_die>10)|!talent.execution_sentence|')
                labels.append('пока TTD>10 не доказан, не ждать триггер Execution Sentence')
        if not labels: return row
        parts = text.split(',')
        result = {'action':parts[0],'list':row['list'],'upstreamSource':row['source'],
                  'source':'AHelperW ('+'; '.join(labels)+'): '+text}
        result.update(p.split('=',1) for p in parts[1:])
        result['expressions'] = {k:Expression(result[k]) for k in ('if','value','value_else','condition') if k in result}
        return result

    def buff(self, name, field):
        # Divine Arbiter is a MID2 4pc effect in this snapshot, not a talent.
        # Its native aura is required even when no such talent name is decoded.
        talent = self.buff_talents.get(name)
        if talent and talent not in self.talents:
            return field=='down'
        if name=='hammer_of_wrath' and field in ('up','down','react'):
            # Exact pinned lifecycle: avenging_wrath_t::execute triggers it;
            # the AW expire callback expires it. No health threshold is used.
            return self.buff('avenging_wrath',field)
        if name=='hammer_of_light_free':
            return self.free_hammer(field)
        spell = self.buffs[name]
        if name=='avenging_wrath' and 'radiant_glory' in self.talents:
            spell=454351
        return self.aura('proc',spell,field)

    def charges(self, action):
        display=self.aliases.get(self.spells[action],self.spells[action])
        square=self.squares.get(('spell',display))
        if not square: return unknown('заряды '+action)
        if square[1].get('charges'): return self.number(square[0]+'/stacks')
        # Non-charged buttons have a single use, but Walk into Light adds a charge.
        if action=='hammer_of_wrath' and 'walk_into_light' in self.talents:
            return unknown('Hammer of Wrath: нужен индикатор зарядов')
        state=self.state('spell',display)
        if state in ('ready','nores','unusable','outofrange'): return 1
        if state in ('cd','almost'): return 0
        return unknown('заряды '+action)

    def cooldown(self, action, field):
        if action=='avenging_wrath' and 'radiant_glory' in self.talents:
            # Radiant Glory makes AW a background Wake effect, with no button CD.
            return field in ('ready','up') if field in ('ready','up') else 0
        talent=self.talent_actions.get(action)
        if talent and talent not in self.talents:
            return field in ('ready','up') if field in ('ready','up') else 0
        if action=='wake_of_ashes':
            state=self.data.get('rows',{}).get('context/wakeCooldown',{}).get('state')
            if field in ('ready','up','remains'):
                if state=='ready': return field in ('ready','up') or 0
                if state=='cd':
                    return False if field in ('ready','up') else self.number('context/wakeCooldown')
                # An override's timer is not Wake's own cooldown.
                return unknown('базовый КД Wake of Ashes')
        if field=='charges': return self.charges(action)
        spell=self.aliases.get(self.spells[action],self.spells[action])
        square=self.squares.get(('spell',spell))
        if not square: return unknown('cooldown.'+action+'.'+field)
        if field=='duration':
            base=square[1].get('baseCooldownMs')
            return base/1000 if isinstance(base,(int,float)) else unknown('длительность КД '+action)
        state=self.state('spell',spell)
        if field in ('ready','up','remains') and state in ('ready','nores','unusable','outofrange'):
            return field in ('ready','up') or 0
        if state in ('cd','almost'):
            return False if field in ('ready','up') else self.number(square[0]+'/timer')
        return unknown('cooldown.'+action+'.'+field)

    def resolve(self, name):
        parts=name.split('.')
        if parts[0]=='buff' and len(parts)==3 and parts[1] in self.buffs:
            return self.buff(parts[1],parts[2])
        if name=='dot.expurgation.ticking':
            if 'expurgation' not in self.talents: return False
            return self.aura('debuff',383346,'up')
        if parts[0]=='debuff' and len(parts)==3 and parts[1] in self.debuffs:
            if parts[1]=='execution_sentence_debuff' and 'execution_sentence' not in self.talents:
                return parts[2]=='down'
            return self.aura('debuff',self.debuffs[parts[1]],parts[2])
        if parts[0]=='cooldown' and len(parts)==3 and parts[1] in self.spells:
            return self.cooldown(parts[1],parts[2])
        if parts[0]=='trinket' or parts[0]=='equipped':
            # Explicit no-items adaptation; this is not equipment discovery.
            return False
        if parts[0]=='raid_event': return 1e10 if parts[-1] in ('in','cooldown') else 0
        return super().resolve(name)

    def requires_display_charge(self, action):
        # Slash is the follow-up, not another charge of the base Strike button.
        return action!='templar_slash'

    def available(self, action):
        if action in self.not_executed: return False
        talent=self.talent_actions.get(action)
        if talent and talent not in self.talents: return False
        if action=='hammer_of_light' and (self.hero_tree!='templar' or 'lights_guidance' not in self.talents): return False
        if action=='avenging_wrath' and 'radiant_glory' in self.talents: return False
        if action=='crusader_strike' and self.talents.intersection({'templar_strikes','crusading_strikes'}): return False
        gate=True
        if action in ('hammer_of_light','wake_of_ashes'):
            gate=self.buff('hammer_of_light_ready','up' if action=='hammer_of_light' else 'down')
        elif action in ('templar_strike','templar_slash'):
            gate=self.buff('templar_strikes','up' if action=='templar_slash' else 'down')
        elif action in ('hammer_of_wrath','judgment'):
            gate=self.buff('hammer_of_wrath','up' if action=='hammer_of_wrath' else 'down')
        if gate is False: return False
        result=binary('&',super().available(action),gate)
        if result is False: return False
        if action=='rebuke':
            result=binary('&',result,self.resolve('target.debuff.casting.react'))
        if action in ('divine_storm','templars_verdict','hammer_of_light'):
            cost=5 if action=='hammer_of_light' else 3
            free=self.buff('divine_purpose','up')
            if action=='hammer_of_light': free=binary('|',free,self.buff('hammer_of_light_free','up'))
            if action=='divine_storm': free=binary('|',free,self.buff('empyrean_power','up'))
            enough=binary('|',binary('>=',self.number('resource/holy_power'),cost),free)
            result=binary('&',result,enough)
        return result

    def decide(self, data):
        self.observe(data)
        result=super().decide(data)
        if result.get('status')=='ready' and result['action']=='hammer_of_wrath':
            # bindingSpellID stays the observation square used by Executor;
            # this extra field records where the physical key was assigned.
            result=dict(result,bindingSourceSpellID=20271,acceptSpellIDs=[24275])
        if result.get('status')=='ready' and result['action']=='templars_verdict' and 'final_verdict' in self.talents:
            # Final Verdict is the actual cast, not its child damage event.
            result=dict(result,spellID=383328,castAs='final_verdict',acceptSpellIDs=[383328])
        result['mode']='retribution-current-target-no-items'
        result['adaptations']=self.adaptations
        return result
