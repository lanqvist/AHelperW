"""Pinned SimC Arms/Slayer APL interpreter with explicit unknown values."""
import json
import math
import re
import time
from dataclasses import dataclass
from spec_profiles import PROFILES
SPELLS={'mortal_strike':12294,'overpower':7384,'cleave':845,'sweeping_strikes':260708,
        'colossus_smash':167105,'avatar':107574,'bladestorm':227847,'execute':163201,
        'slam':1464,'heroic_strike':1269383,'storm_bolt':107570,'charge':100,
        'pummel':6552,'battle_stance':386164,'wrecking_throw':384110,'rend':772,
        'ravager':228920,'arcane_torrent':69179,'lights_judgment':255647,
        'bag_of_tricks':312411,'berserking':26297,'blood_fury':20572,
        'fireblood':265221,'ancestral_call':274738}
BUFFS={'sudden_death':52437,'executioners_precision':386633,'collateral_damage':334783,
       'imminent_demise':445606,'opportunist':456120,'executioner':445584,
       'sweeping_strikes':260708,'avatar':107574,'bladestorm':446035,
       'master_of_warfare_proc':1269391,'battle_stance':386164,'power_infusion':10060}


# SimC snapshot of every APL package (docs/*/source.json); the addon writes the
# same commit into its export (Export.lua), so an old export is refused.
SIMC_COMMIT='b36fc0a2e299f925bc0f72375eea013d7ff5b1cf'


def client_build_note(client,table_build):
    """Accept a client of the trait table's patch; refuse another patch.

    Hotfix builds of one patch keep the talent trees (12.1.5: 70340, 70391, 70448
    within a week), and the decoder still rejects a string that does not fit the
    table. A new patch can move nodes, so it needs a re-pinned package. Returns
    a note when the build differs, None on an exact match.
    """
    version,build=table_build.rsplit('.',1)
    seen=f"{client.get('version')}.{client.get('build')}"
    if str(client.get('version'))!=version:
        raise ValueError(f'Пакеты APL подготовлены для клиента {table_build}, экспорт HUD — с клиента {seen}. '
                         'Нужно обновление AHelperW под этот патч')
    if str(client.get('build'))!=build:
        return f'Клиент {seen}, таблица талантов {table_build}: тот же патч, строка талантов проверена декодером'
    return None


@dataclass(frozen=True)
class Unknown:
    reasons: frozenset


def unknown(reason):
    return Unknown(frozenset([reason]))


@dataclass(frozen=True)
class Interval:
    """An observed bound, e.g. target TTD in [low, high]; high may be infinite.

    A comparison is decided only when every value inside the bounds agrees;
    otherwise it stays unknown. Arithmetic on bounds is not defined here.
    """
    low: float
    high: float
    source: str


def compare_interval(op,a,b):
    if isinstance(b,Interval):
        if isinstance(a,Interval): return unknown('сравнение двух оценок: '+a.source+', '+b.source)
        flipped={'<':'>','<=':'>=','>':'<','>=':'<=','=':'=','!=':'!='}
        return compare_interval(flipped[op],b,a)
    low,high=a.low,a.high
    decided={'>':(low>b, high<=b), '>=':(low>=b, high<b), '<':(high<b, low>=b),
             '<=':(high<=b, low>b), '=':(low==high==b, b<low or b>high)}
    if op=='!=':
        result=compare_interval('=',a,b)
        return result if isinstance(result,Unknown) else not result
    true,false=decided[op]
    if true: return True
    if false: return False
    shown='∞' if math.isinf(high) else f'{high:g}'
    return unknown(f'{a.source} [{low:g}, {shown}] не решает {op}{b:g}')


def combine(a,b):
    return Unknown(frozenset().union(*(v.reasons for v in (a,b) if isinstance(v,Unknown))))


def binary(op,a,b):
    if op=='&':
        if (not isinstance(a,Unknown) and not a) or (not isinstance(b,Unknown) and not b): return False
    if op=='|':
        if (not isinstance(a,Unknown) and a) or (not isinstance(b,Unknown) and b): return True
    if isinstance(a,Unknown) or isinstance(b,Unknown): return combine(a,b)
    if isinstance(a,Interval) or isinstance(b,Interval):
        if op in ('<','<=','>','>=','=','!='): return compare_interval(op,a,b)
        return unknown('арифметика над оценкой '+next(v.source for v in (a,b) if isinstance(v,Interval)))
    if op=='&': return bool(a and b)
    if op=='|': return bool(a or b)
    if op=='=': return a==b
    if op=='!=': return a!=b
    if op=='<': return a<b
    if op=='<=': return a<=b
    if op=='>': return a>b
    if op=='>=': return a>=b
    if op=='+': return a+b
    if op=='-': return a-b
    if op=='*': return a*b
    if op in ('%','%%'):
        if b==0: return unknown('деление на ноль в APL')
        return a/b if op=='%' else a%b
    raise ValueError('Неподдерживаемый оператор '+op)


class Expression:
    # `~X` is an explicit adaptation: X when decided, false when unknown.
    token=re.compile(r'\s*(\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_.]*|%%|!=|<=|>=|[()!~&|=<>+*%\-])')
    precedence={'|':1,'&':2,'=':3,'!=':3,'<':3,'<=':3,'>':3,'>=':3,'+':4,'-':4,'*':5,'%':5,'%%':5}

    def __init__(self,text):
        self.tokens=[]; self.pos=0
        cursor=0
        while cursor<len(text):
            match=self.token.match(text,cursor)
            if not match: raise ValueError('Неизвестное выражение APL: '+text[cursor:])
            self.tokens.append(match.group(1)); cursor=match.end()
        self.tree=self.parse(0)
        if self.pos!=len(self.tokens): raise ValueError('Лишние токены APL: '+text)

    def parse(self,minimum):
        if self.pos>=len(self.tokens): raise ValueError('Оборванное выражение APL')
        token=self.tokens[self.pos]; self.pos+=1
        if token in ('!','-','+','~'):
            node=('unary',token,self.parse(6))
        elif token=='(':
            node=self.parse(0)
            if self.pos>=len(self.tokens) or self.tokens[self.pos]!=')': raise ValueError('Скобки APL')
            self.pos+=1
        elif token[0].isdigit(): node=('number',float(token))
        elif token[0].isalpha() or token[0]=='_': node=('name',token)
        else: raise ValueError('Неожиданный токен APL '+token)
        while self.pos<len(self.tokens):
            op=self.tokens[self.pos]; priority=self.precedence.get(op,-1)
            if priority<minimum: break
            self.pos+=1
            node=('binary',op,node,self.parse(priority+1))
        return node

    def evaluate(self,resolve):
        def visit(node):
            if node[0]=='number': return node[1]
            if node[0]=='name': return resolve(node[1])
            if node[0]=='unary':
                value=visit(node[2])
                if node[1]=='~': return False if isinstance(value,(Unknown,Interval)) else value
                if isinstance(value,Unknown): return value
                if isinstance(value,Interval): return unknown('операция над оценкой '+value.source)
                return not value if node[1]=='!' else (-value if node[1]=='-' else value)
            left=visit(node[2])
            if not isinstance(left,Unknown):
                if node[1]=='&' and not left: return False
                if node[1]=='|' and left: return True
            return binary(node[1],left,visit(node[3]))
        return visit(self.tree)


def decode_talents(text,table):
    from talent_decode import decode
    return set(decode(text,table,71,{60})[0])


class APLRuntime:
    # Lists narrowed for this integration; a model may override per hero tree.
    requirements_file='build-requirements.json'

    def __init__(self,reader,root,bindings,settings):
        self.reader=reader; self.cfg=reader.cfg; self.bindings=bindings; self.settings=settings
        if self.cfg.get('specID')!=self.spec_id: raise ValueError('Неверная специализация пакета APL')
        self.profile=PROFILES.get(self.spec_id)
        table=json.loads((root/self.trait_file).read_text(encoding='utf-8'))
        self.build_note=client_build_note(self.cfg.get('client',{}),table['build'])
        from talent_decode import decode
        # Legacy models pin allowed_heroes; otherwise every tree of the profile.
        allowed=getattr(self,'allowed_heroes',None) or {t.subtree for t in self.profile.hero_trees}
        self.talent_ranks,self.hero_trees=decode(self.cfg['talents'],table,self.spec_id,allowed)
        self.talents=set(self.talent_ranks)
        # Exactly one subtree is active (decode enforces it); hero_tree.<key>
        # in APL conditions compares against its SimC key.
        self.hero_tree_id=next(iter(self.hero_trees))
        tree=self.profile.hero_tree(self.hero_tree_id) if self.profile else None
        self.hero_tree=tree.key if tree else None
        declared=self.cfg.get('apl',{}).get('heroTreeID')
        if declared is not None and declared!=self.hero_tree_id:
            raise ValueError('Героическая ветка в экспорте не совпадает со строкой талантов')
        self.squares={(s['kind'],s['spellID']):(key,s) for key,s in reader.square_specs.items()}
        self.aliases={a['spellID']:a['displaySpellID'] for a in self.cfg.get('aliases',{}).values() if 'spellID' in a and 'displaySpellID' in a}
        self.lists={}
        source=json.loads((root/self.requirements_file).read_text(encoding='utf-8'))
        for row in source['actions']:
            pieces=[p for p in row['expression'].split(',') if p]; action={'action':pieces[0],'source':row['expression'],'list':row['list']}
            for p in pieces[1:]:
                key,value=p.split('=',1); action[key]=value
            action['expressions']={k:Expression(action[k]) for k in ('if','value','value_else','condition') if k in action}
            self.lists.setdefault(row['list'],[]).append(action)
        self.variables={}; self.data={}; self.current=None
        # Every active_enemies use is a comparison with an integer, so 1..max+1
        # covers every distinct outcome. Any other use disables the shortcut.
        sources=[a['source'] for rows in self.lists.values() for a in rows]
        uses=sum(src.count('active_enemies') for src in sources)
        limits=[int(m) for src in sources for m in re.findall(r'active_enemies(?:=|!=|<=|>=|<|>)(\d+)',src)]
        self.enemy_values=tuple(range(1,max(limits,default=0)+2)) if uses==len(limits) else ()

    def number(self,key):
        item=self.data.get('numbers',{}).get(key,{})
        value=item.get('value')
        if value is None or item.get('expiresAt',0)<=time.time(): return unknown(key)
        return value

    def resource_max(self,name):
        # The HUD shows the live maximum (context/max<name>); the export's value
        # is a snapshot and can be lower than the current maximum.
        live=self.number('context/max'+name)
        if not isinstance(live,Unknown) and live>0: return live
        value=self.cfg.get('resourceMeta',{}).get(name,{}).get('max')
        return value if isinstance(value,(int,float)) and value>0 else unknown(name+'.max')

    def rune_count(self):
        """Ready runes from the six rune colours; one unreadable rune makes it unknown."""
        rows=self.data.get('rows',{})
        states=[rows.get(f'rune/{i}',{}).get('state') for i in range(1,7)]
        if not all(state in ('ready','cd') for state in states):
            return unknown('руны: состояние не прочитано')
        return states.count('ready')

    def rune(self,name):
        count=self.rune_count()
        field=name[5:]
        if name=='rune': return count
        if field in ('max','deficit'):
            if not self.cfg.get('runes'): return unknown(name)
            return 6 if field=='max' else binary('-',6,count)
        match=re.fullmatch(r'time_to_(\d)',field)
        if not match or not 1<=int(match.group(1))<=6: return unknown(name)
        wanted=int(match.group(1))
        if isinstance(count,Unknown): return count
        if wanted<=count: return 0
        if wanted==count+1:
            # HUD countdown to the next rune, invalidated by any rune colour
            # change; corrected by the age of the OCR frame it came from.
            value=self.number('context/runeNext')
            if not isinstance(value,Unknown):
                captured=self.data.get('capturedAt',0)
                age=captured-self.data['numbers']['context/runeNext'].get('capturedAt',captured)
                return max(0.,value-max(0.,age))
        return unknown(name+' (время восстановления рун)')

    def state(self,kind,spell):
        square=self.squares.get((kind,spell))
        return self.data['rows'].get(square[0],{}).get('state','unknown') if square else 'unknown'

    def aura(self,kind,spell,field):
        state=self.state(kind,spell)
        if state=='procoff': return field=='down'
        if state!=kind: return unknown(f'{kind}:{spell}.{field}')
        if field in ('up','react'): return True
        if field=='down': return False
        key=self.squares[(kind,spell)][0]
        return self.number(key+('/stacks' if field in ('stack','stacks') else '/timer'))

    def time_to_die(self):
        """Manual /ahw ttd forecast first, then the reader's health-slope bounds."""
        manual=self.number('context/ttd')
        if not isinstance(manual,Unknown): return manual
        estimate=self.data.get('ttdEstimate') or {}
        status=estimate.get('status','нет оценки')
        if status=='dead': return 0.
        if status=='estimate' and isinstance(estimate.get('low'),(int,float)):
            high=math.inf if estimate.get('highUnbounded') else estimate.get('high')
            if isinstance(high,(int,float)):
                return Interval(float(estimate['low']),float(high),'TTD по здоровью цели')
        return unknown('target.time_to_die: '+status)

    def fight_remains(self):
        """Manual /ahw fight forecast; otherwise only a lower bound: the fight
        lasts at least as long as the current target. Other enemies are unseen."""
        manual=self.number('context/fight')
        if not isinstance(manual,Unknown): return manual
        ttd=self.time_to_die()
        if isinstance(ttd,Unknown): return unknown('fight_remains: '+', '.join(sorted(ttd.reasons)))
        low=ttd.low if isinstance(ttd,Interval) else ttd
        return Interval(float(low),math.inf,'fight_remains ≥ TTD цели')

    def resolve(self,name):
        if name.startswith('talent.'):
            return name.split('.')[1] in self.talents
        if name.startswith('hero_tree.'):
            return self.hero_tree==name[10:] if self.hero_tree else unknown(name)
        if name.startswith('variable.'):
            if name=='variable.execute_phase' and self.settings.get('phase') in ('normal','execute'):
                return self.settings['phase']=='execute'
            return self.variables.get(name[9:],unknown(name))
        if name=='active_enemies':
            return self.settings.get('targets') or self.number('context/targets')
        if name=='target.time_to_die': return self.time_to_die()
        if name=='fight_remains': return self.fight_remains()
        if name in ('rage','time','target.health.pct'):
            return self.number({'rage':'resource/rage','time':'context/time',
                                'target.health.pct':'resource/targetHealthPercent'}[name])
        if name=='gcd':
            haste=self.number('context/haste')
            return haste if isinstance(haste,Unknown) else max(.75,1.5/(1+haste/100))
        if name=='gcd.remains':
            return 0 if self.data['rows'].get('gcd',{}).get('state')=='ready' else unknown(name)
        if name=='charges':
            square=self.squares.get(('spell',self.spells.get(self.current)))
            return self.number(square[0]+'/stacks') if square else unknown(name)
        if name=='target.debuff.casting.react':
            state=self.data['rows'].get('context/targetCast',{}).get('state')
            if state=='procoff': return False
            flag=self.data['rows'].get('context/targetInterrupt',{}).get('state')
            if state=='nores' and flag in ('ready','cd'): return flag=='ready'
            return unknown('прерываемость каста цели')
        parts=name.split('.')
        if parts[0]=='rune': return self.rune(name)
        if parts[0] in self.cfg.get('resourceMeta',{}) and parts[0]!='runes' and len(parts)<=2:
            # Numeric resources from the HUD: <name>, <name>.max, <name>.deficit.
            if len(parts)==1: return self.number('resource/'+parts[0])
            if parts[1]=='max': return self.resource_max(parts[0])
            if parts[1]=='deficit': return binary('-',self.resource_max(parts[0]),self.number('resource/'+parts[0]))
        if parts[0]=='buff' and parts[1] in self.buffs:
            return self.aura('proc',self.buffs[parts[1]],parts[2])
        if name.startswith('debuff.colossus_smash.'):
            return self.aura('debuff',208086,parts[2])
        if name=='dot.rend_dot.remains': return self.aura('debuff',388539,'remains')
        if parts[0]=='cooldown' and parts[1] in self.spells:
            spell=self.spells[parts[1]]; square=self.squares.get(('spell',spell))
            if not square: return unknown(name)
            state=self.state('spell',spell)
            if parts[2]=='duration':
                base=square[1].get('baseCooldownMs')
                return base/1000 if isinstance(base,(int,float)) else unknown(name)
            if state=='ready': return True if parts[2]=='ready' else 0
            if state in ('cd','almost'):
                return False if parts[2]=='ready' else self.number(square[0]+'/timer')
            return unknown(name)
        if parts[0]=='trinket':
            slot=int(parts[1])+12
            item=next((i for i in self.cfg.get('equipment',[]) if i['slot']==slot),{})
            meta=item.get('aplMetadata') or {}
            if parts[2:] == ['has_cooldown']: return bool(item.get('useSpellID'))
            if not item.get('useSpellID'):
                if parts[2:] in (['has_use_buff'],['has_buff','strength']): return False
            if parts[2:]==['ilvl']: return item.get('itemLevel',unknown(name))
            if parts[2]=='is': return unknown(name)
            return unknown(name)
        return unknown(name)

    def requires_display_charge(self, action):
        return True

    def available(self,action):
        spell=self.spells.get(action)
        if spell is None: return False
        display=self.aliases.get(spell,spell)
        if not self.bindings.get(str(display)): return False
        if action=='ravager' and 'ravager' not in self.talents: return False
        state=self.state('spell',display)
        if state in ('cd','almost','nores','outofrange','unusable'): return False
        result=state=='ready' if state!='unknown' else unknown('готовность '+action)
        if action=='heroic_strike': result=binary('&',result,self.aura('proc',1269391,'up'))
        if action=='slam': result=binary('&',result,self.aura('proc',1269391,'down'))
        if action=='battle_stance': result=binary('&',result,self.aura('proc',386164,'down'))
        square=self.squares.get(('spell',display))
        if square and square[1].get('charges') and self.requires_display_charge(action):
            result=binary('&',result,binary('>',self.number(square[0]+'/stacks'),0))
        return result

    def evaluate_list(self,name,depth=0):
        if depth>8: raise ValueError('Рекурсия списков APL')
        for action in self.lists.get(name,[]):
            verb=action['action']; expressions=action['expressions']; self.current=verb
            if verb=='variable':
                if action.get('op')=='setif':
                    check=expressions['condition'].evaluate(self.resolve)
                    value=check if isinstance(check,Unknown) else expressions['value' if check else 'value_else'].evaluate(self.resolve)
                else: value=expressions['value'].evaluate(self.resolve)
                self.variables[action['name']]=value
                continue
            # Simulated external buffs, auto-attack and unbound actions are not
            # executable buttons in this profile. Their aura inputs still apply.
            if verb in ('snapshot_stats','auto_attack','invoke_external_buff'): continue
            call=verb in ('call_action_list','run_action_list')
            ready=True if call else self.available(verb)
            if ready is False: continue
            condition=expressions['if'].evaluate(self.resolve) if 'if' in expressions else True
            verdict=binary('&',ready,condition)
            if verdict is False: continue
            if isinstance(verdict,Unknown):
                return {'status':'blocked','reason':'Нужны данные: '+', '.join(sorted(verdict.reasons)),
                        'missing':sorted(verdict.reasons),'rule':action['source'],'list':name}
            if 'target_if' in action:
                enemies=self.resolve('active_enemies')
                if isinstance(enemies,Unknown) or enemies!=1:
                    return {'status':'blocked','reason':'Для target_if нужны данные остальных целей','rule':action['source'],'list':name}
            if call:
                answer=self.evaluate_list(action['name'],depth+1)
                if answer or verb=='run_action_list': return answer
                continue
            spell=self.spells[verb]; display=self.aliases.get(spell,spell)
            return {'status':'ready','action':verb,'spellID':spell,'bindingSpellID':display,
                    'binding':self.bindings[str(display)],'rule':action['source'],'list':name}
        return None

    def decide(self,data):
        result=self._decide(data)
        # An unknown target count only matters if it changes the action. When
        # every possible count yields the same ready action, that is exact.
        if (result.get('status')=='blocked' and result.get('missing')==['context/targets']
                and not self.settings.get('targets') and self.enemy_values):
            # A pixel-validated "N+" from the HUD narrows the counts to N and up;
            # every count above the largest APL threshold behaves like max+1.
            lower=self.number('context/targetsMin')
            candidates=self.enemy_values
            if not isinstance(lower,Unknown):
                candidates=tuple(v for v in self.enemy_values if v>=lower) or self.enemy_values[-1:]
            saved=self.settings.get('targets')
            try:
                answers=[]
                for count in candidates:
                    self.settings['targets']=count
                    answers.append(self._decide(data))
            finally:
                self.settings['targets']=saved
            first=answers[0]
            if first.get('status')=='ready' and all(a.get('status')=='ready' and a['action']==first['action']
                                                    and a['binding']==first['binding'] for a in answers):
                return dict(first,targetsIndependent=list(candidates),
                            targetsLowerBound=None if isinstance(lower,Unknown) else lower)
        return result

    def _decide(self,data):
        self.data=data; self.variables={}
        if not data.get('valid') or data.get('expiresAt',0)<=time.time():
            return {'status':'blocked','reason':'Нет свежего кадра HUD'}
        if not any(self.bindings.values()): return {'status':'blocked','reason':'Назначь клавиши способностям'}
        # The precombat variables are static metadata; state preparation is
        # intentionally deferred until a hostile target and combat are visible.
        for action in self.lists.get('precombat',[]):
            if action['action']!='variable': continue
            expressions=action['expressions']
            if action.get('op')=='setif':
                check=expressions['condition'].evaluate(self.resolve)
                value=check if isinstance(check,Unknown) else expressions['value' if check else 'value_else'].evaluate(self.resolve)
            else: value=expressions['value'].evaluate(self.resolve)
            self.variables[action['name']]=value
        combat=data['rows'].get('context/time',{}).get('state')
        if combat not in ('nores','procoff'):
            return {'status':'waiting','reason':'Состояние боя неизвестно'}
        if data['rows'].get('context/range',{}).get('state') not in ('ready','cd'):
            return {'status':'waiting','reason':'Нет подтверждённой враждебной живой цели'}
        if data['rows'].get('gcd',{}).get('state')!='ready':
            return {'status':'waiting','reason':'Ожидание GCD'}
        if combat=='procoff':
            preparation=self.evaluate_list('precombat')
            if preparation: return preparation
        decision=self.evaluate_list('default_') or {'status':'waiting','reason':'Нет доступного назначенного действия'}
        if decision['status']=='ready' and data['rows'].get('context/playerCast',{}).get('state')!='procoff':
            if not (decision['action']=='storm_bolt' and self.aura('proc',446035,'up') is True):
                return {'status':'waiting','reason':'Ожидание окончания каста/канала'}
        return decision


class ArmsAPL(APLRuntime):
    spec_id = 71
    trait_file = 'warrior-traits.json'
    allowed_heroes = {60}
    spells = SPELLS
    buffs = BUFFS

    def __init__(self,reader,root,bindings,settings):
        super().__init__(reader,root,bindings,settings)
        # Upstream picks slayer_execute by target_if=min:target.health.pct. The
        # other enemies' health is unseen, so with 2 targets that rule blocked
        # the whole rotation in execute phase. The selected target decides.
        self.adaptations=('Текущая выбранная цель; target_if не переключает цели',)
        for rows in self.lists.values():
            for row in rows:
                if 'target_if' in row:
                    row['original_target_if']=row.pop('target_if')

    def decide(self,data):
        result=super().decide(data)
        result['adaptations']=self.adaptations
        return result
