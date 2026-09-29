"""Windows input pulses. No process memory, hooks or background targeting."""
import ctypes as ct
from ctypes import wintypes as wt
import time
from cast_receipt import CastObserver
from bindings_ui import label as binding_label
from gcd_timing import GcdTiming

U=ct.WinDLL('user32',use_last_error=True)
ULONG_PTR=ct.c_size_t


class MouseInput(ct.Structure):
    _fields_=[('dx',wt.LONG),('dy',wt.LONG),('mouseData',wt.DWORD),('flags',wt.DWORD),('time',wt.DWORD),('extra',ULONG_PTR)]


class KeyboardInput(ct.Structure):
    _fields_=[('vk',wt.WORD),('scan',wt.WORD),('flags',wt.DWORD),('time',wt.DWORD),('extra',ULONG_PTR)]


class HardwareInput(ct.Structure):
    _fields_=[('message',wt.DWORD),('low',wt.WORD),('high',wt.WORD)]


class Payload(ct.Union):
    _fields_=[('mouse',MouseInput),('key',KeyboardInput),('hardware',HardwareInput)]


class Input(ct.Structure):
    _fields_=[('type',wt.DWORD),('payload',Payload)]


U.SendInput.argtypes=[wt.UINT,ct.POINTER(Input),ct.c_int]
U.SendInput.restype=wt.UINT
U.GetAsyncKeyState.argtypes=[ct.c_int]
U.GetAsyncKeyState.restype=ct.c_short
EXTENDED={33,34,35,36,37,38,39,40,45,46,111,163,165}


def pressed(vk):
    return bool(U.GetAsyncKeyState(vk)&0x8000)


def stop_pressed():
    return pressed(119)  # F8, reserved by the binding editor.


def keyboard(vk,up=False):
    item=Input(); item.type=1
    item.payload.key=KeyboardInput(vk,0,(2 if up else 0)|(1 if vk in EXTENDED else 0),0,0)
    return item


def mouse(button,up=False):
    item=Input(); item.type=0
    flags=(0x40 if up else 0x20) if button=='middle' else (0x100 if up else 0x80)
    item.payload.mouse=MouseInput(0,0,0 if button=='middle' else (1 if button=='x1' else 2),flags,0,0)
    return item


def pulse(binding,focus_guard,halt):
    mods=[{'CTRL':17,'ALT':18,'SHIFT':16}[m] for m in binding['modifiers']]
    if any(pressed(vk) for vk in (16,17,18,91,92)):
        return 'physical_modifier_held'
    key=binding.get('vk') if binding['device']=='keyboard' else {'middle':4,'x1':5,'x2':6}[binding['button']]
    if pressed(key): return 'physical_key_held'
    down=keyboard(key) if binding['device']=='keyboard' else mouse(binding['button'])
    up=keyboard(key,True) if binding['device']=='keyboard' else mouse(binding['button'],True)
    releases=[up]+[keyboard(vk,True) for vk in reversed(mods)]
    events=[keyboard(vk) for vk in mods]+[down]+releases
    inputs=(Input*len(events))(*events)
    if halt.is_set() or stop_pressed() or not focus_guard(): return 'focus_or_stop'
    written=U.SendInput(len(inputs),inputs,ct.sizeof(Input))
    if written!=len(inputs):
        # A partial insertion may have left our modifiers down. Release only
        # the keys included in this pulse and stop, without privilege escalation.
        if written:
            cleanup=(Input*len(releases))(*releases)
            U.SendInput(len(cleanup),cleanup,ct.sizeof(Input))
        raise OSError(ct.get_last_error(),'Windows не приняла полный пакет клавиш')
    return 'sent'


class Executor:
    def __init__(self,apl,debug):
        self.apl=apl; self.debug=debug; self.pending=None; self.last_send=0
        self.cast_observer=CastObserver(debug)
        bindings=getattr(apl,'bindings',{}) or {}
        self.cast_observer.pressable={cast for (kind,spell),(_,spec) in getattr(apl,'squares',{}).items()
                                      if kind=='spell' and bindings.get(str(spell))
                                      for cast in (spec.get('castSpellIDs') or [spell])}
        self.gcd_timing=GcdTiming(debug)
        self.receipt_pending=None
        self.failure_reason=None
        self.rejected_at={}

    def pause(self):
        self.pending=None
        if self.receipt_pending:
            # Losing observation is not evidence that the input failed. The
            # observer below discards its baseline; discard the matching deadline
            # too, so returning to the game cannot time out an abandoned request.
            self.debug.event('input_confirmation_interrupted',
                             action=self.receipt_pending['action'], reason='reading_paused')
            self.receipt_pending=None
        if hasattr(self.apl, 'reset_observations'): self.apl.reset_observations()
        self.cast_observer.pause()
        self.gcd_timing.pause()

    def step(self,data,focus_guard,halt):
        self.gcd_timing.before(data)
        decision=self._step(data,focus_guard,halt)
        self.gcd_timing.after(data,decision,sent_at=self.last_send)
        return decision

    def _step(self,data,focus_guard,halt):
        now=time.time()
        if hasattr(self.apl, 'observe'): self.apl.observe(data)
        self.cast_observer.update(data)
        if self.failure_reason:
            return {'status':'blocked','reason':self.failure_reason}
        if getattr(self.apl, 'require_cast_confirmation', False):
            if self.receipt_pending:
                request=self.receipt_pending
                matched=any(c['action']==request['action'] and c['sentAt']==request['sentAt']
                            for c in data.get('castVerification',{}).get('confirmed',[]))
                # The client refusing the press (e.g. Execute as the target heals
                # back above 20%) turns the button unusable. A button that stays
                # ready without an event remains unexplained and still latches.
                state=data['rows'].get(request['row'],{}).get('state')
                captured=data.get('capturedAt',0)
                if captured>request['sentAt'] and state in ('unusable','nores','outofrange'):
                    request.setdefault('rejectedState',state)
                # A GCD that starts and clears within 0.5 s (a real one lasts >= 0.75 s)
                # is the client refusing the press even with the button still ready
                # (seen: Festering Strike, log 20260929T095028Z-88a4d40a). User decision.
                gcd=data['rows'].get('gcd',{}).get('state')
                if captured>request['sentAt']:
                    if gcd=='cd': request.setdefault('gcdBusyAt',captured)
                    elif gcd=='ready' and 'gcdBusyAt' in request and captured-request['gcdBusyAt']<0.5:
                        request.setdefault('rejectedState','gcd_flicker')
                if matched:
                    self.receipt_pending=None
                    self.pending=None
                elif now-request['sentAt']>2.5:
                    previous=self.rejected_at.get(request['action'])
                    if 'rejectedState' in request and not (previous and request['sentAt']-previous<10):
                        # One explained refusal per action per 10 s; a repeat latches.
                        self.rejected_at[request['action']]=request['sentAt']
                        self.receipt_pending=None
                        self.pending=None
                        self.debug.event('input_rejected_by_client',action=request['action'],
                                         buttonState=request['rejectedState'],
                                         note='No cast event; button became unavailable or the GCD only flickered after the press')
                        return {'status':'waiting','reason':'Клиент отклонил '+request['action']+'; повторная оценка APL'}
                    self.failure_reason='Применение '+request['action']+' не подтверждено; автонажатия заблокированы. Останови запись для разбора.'
                    other=self.cast_observer.unexpected_after(request['sentAt'],request.get('expected',()))
                    if other is not None:
                        # Seen in game: Ctrl+2 was set for Berserker Stance here, but cast Charge.
                        names={}
                        for (kind,spell),(_,spec) in self.apl.squares.items():
                            for cast in spec.get('castSpellIDs') or [spell]: names.setdefault(cast,spec.get('name') or str(spell))
                        # Your own presses land here too (seen: a manual Charge on the pull), so this
                        # only points at the binding as one possibility.
                        self.failure_reason=('После нажатия '+binding_label(request.get('binding'))+' ('+request.get('label',request['action'])
                                             +') пришло применение '+names.get(other,'заклинания')+' ('+str(other)+'), а нужного нет. '
                                             'Если вы не нажимали его сами — проверь бинд в игре. Автонажатия заблокированы.')
                    self.debug.event('input_confirmation_latched',action=request['action'],reason=self.failure_reason,
                                     observedSpellID=other)
                    return {'status':'blocked','reason':self.failure_reason}
                else:
                    return {'status':'waiting','reason':'Ожидание события применения '+request['action']}
            if data.get('castReceipt',{}).get('status')!='readable':
                return {'status':'waiting','reason':'Нет читаемой истории применений'}
        if data['rows'].get('context/inputAllowed',{}).get('state')!='ready':
            self.pause()
            return {'status':'waiting','reason':'Ввод закрыт: чат, меню, смерть или неизвестный сигнал HUD'}
        if self.pending:
            row=data['rows'].get(self.pending['row'],{})
            number=data['numbers'].get(self.pending['row']+'/stacks',{})
            charge=number.get('value') if number.get('expiresAt',0)>now else None
            changed=(row.get('state') in ('cd','nores','unusable') or
                     data['rows'].get('gcd',{}).get('state')=='cd' or
                     (charge is not None and self.pending['charges'] is not None and charge!=self.pending['charges']))
            if changed and data['capturedAt']>self.last_send:
                self.debug.event('action_response_observed',action=self.pending['action'],
                                 elapsedSeconds=now-self.last_send,
                                 note='HUD changed; this is not proof of a successful cast')
                self.pending=None
            elif now-self.last_send<1.2:
                return {'status':'waiting','reason':'Ожидание отклика HUD после нажатия'}
            else:
                self.debug.event('action_unconfirmed',action=self.pending['action'])
                self.pending=None
                return {'status':'waiting','reason':'Применение не подтверждено; повторная оценка APL'}
        if now-self.last_send<.3:
            return {'status':'waiting','reason':'Интервал между нажатиями'}
        decision=self.apl.decide(data)
        if decision['status']!='ready': return decision
        if time.time()-data['capturedAt']>.3 or halt.is_set():
            return {'status':'waiting','reason':'Кадр устарел перед нажатием'}
        result=pulse(decision['binding'],focus_guard,halt)
        if result!='sent':
            return {'status':'waiting','reason':'Клавиша удерживается вручную или изменился фокус','inputStatus':result}
        self.last_send=time.time()
        row=self.apl.squares.get(('spell',decision['bindingSpellID']),('',{}))[0]
        self.pending={'row':row,'charges':data['numbers'].get(row+'/stacks',{}).get('value'),'action':decision['action']}
        self.debug.event('key_sent',decision=decision,capturedAt=data['capturedAt'],sentAt=self.last_send)
        square=self.apl.squares.get(('spell',decision['bindingSpellID']),('',{}))[1]
        self.cast_observer.sent(decision,square,self.last_send,data.get('castReceipt',{}))
        if getattr(self.apl, 'require_cast_confirmation', False):
            expected=set(square.get('castSpellIDs') or [decision['bindingSpellID']]); expected.add(decision['spellID'])
            expected.update(decision.get('acceptSpellIDs',()))
            self.receipt_pending={'action':decision['action'],'sentAt':self.last_send,'row':row,
                                  'binding':decision['binding'],'expected':expected,
                                  'label':square.get('name') or decision['action']}
        return dict(decision,status='sent',reason='Отправлено: '+decision['action'])
