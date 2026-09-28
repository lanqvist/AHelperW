"""Budgeted OCR schedule. Keeps unknown/missing values distinct from zero."""
import hashlib
import json
import time

from spec_profiles import PROFILES


class OcrPlan:
    def __init__(self, reader, config_path):
        self.cache = {}
        self.attempts = {}
        self.aliases = {}
        self.disabled = {}
        self.periods = {}
        self.batch_limit = 12
        specs = reader.square_specs
        procs = {s['spellID']: key for key, s in specs.items() if s['kind']=='proc'}
        arms = reader.cfg.get('specID') == 71
        profile = PROFILES.get(reader.cfg.get('specID'))
        binary = profile.binary_auras if profile else frozenset()
        fast_timers = profile.fast_aura_timers if profile else frozenset()
        for key in reader.regions:
            owner, field = key.rsplit('/',1)
            spec = specs.get(owner)
            self.periods[key] = .6
            if spec:
                if field=='stacks':
                    self.periods[key] = .15
                    if spec['kind']=='spell' and not spec.get('charges'):
                        linked = spec.get('stackAuraID')
                        if linked is None and arms:
                            linked = {260708:260708,227847:445606}.get(spec['spellID'])
                        if linked in procs:
                            self.aliases[key] = procs[linked]+'/stacks'
                        elif linked is None:
                            self.disabled[key] = 'no_counter'
                    elif spec['spellID'] in binary:
                        self.disabled[key] = 'binary_aura_use_color'
                elif field=='timer' and spec['kind']=='proc' and spec['spellID'] in fast_timers:
                    self.periods[key] = .2
                elif spec['spellID'] in (386164, 386196) and spec['kind']=='proc':
                    self.disabled[key] = 'no_duration_display'
            elif key in ('resource/rage','resource/energy','resource/chi'): self.periods[key]=.15
            elif key=='context/energyRegen': self.periods[key]=.5
            elif key=='context/zenithRecharge': self.periods[key]=.5
            elif key=='context/targets': self.periods[key]=.2
            elif key in ('resource/playerHealth','context/maxrage','context/maxenergy'): self.periods[key]=2.
            elif key=='resource/targetHealth': self.disabled[key]='use_targetHealthPercent'
            elif key in ('context/range','context/chargeRange','context/potion','context/trinket1','context/trinket2'):
                self.disabled[key]='text_status_not_numeric'
            elif key in ('context/haste','context/speed','resource/targetHealthPercent'): self.periods[key]=.5
            elif key.startswith('context/'): self.periods[key]=1.
        if config_path.exists():
            config=json.loads(config_path.read_text(encoding='utf-8-sig'))
            self.batch_limit=max(1,min(32,int(config.get('batchLimit',12))))
            if config.get('mode')=='full':
                self.disabled.clear(); self.aliases.clear()
            for key, period in config.get('periodSeconds',{}).items():
                if key in self.periods: self.periods[key]=max(.1,min(10,float(period)))

    def ttl(self,key):
        return max(1.,min(5.,self.periods.get(key,.6)*2.5))

    def due(self, regions, now):
        keys=[k for k in regions if k not in self.disabled and k not in self.aliases
              and now-self.attempts.get(k,0)>=self.periods[k]]
        return sorted(keys,key=lambda k: (-(now-self.attempts.get(k,now-10))/self.periods[k],k))

    def fingerprint(self,crop,state,profile):
        return hashlib.blake2b(crop.tobytes()+str((state,profile)).encode(),digest_size=16).hexdigest()

    def remember(self,key,fingerprint,result):
        self.cache[key]=(fingerprint,dict(result),time.time())

    def reuse(self,key,fingerprint,now):
        old=self.cache.get(key)
        if old and old[0]==fingerprint and now-old[2]<10:
            result=dict(old[1])
            result['reusedPixels']=True
            return result
        return None
