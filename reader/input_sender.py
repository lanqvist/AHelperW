"""Windows input pulses. No process memory, hooks or background targeting."""
import ctypes as ct
from ctypes import wintypes as wt
import time
from cast_receipt import CastObserver
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
        self.gcd_timing=GcdTiming(debug)

    def pause(self):
        self.pending=None
        self.cast_observer.pause()
        self.gcd_timing.pause()

    def step(self,data,focus_guard,halt):
        self.gcd_timing.before(data)
        decision=self._step(data,focus_guard,halt)
        self.gcd_timing.after(data,decision,sent_at=self.last_send)
        return decision

    def _step(self,data,focus_guard,halt):
        now=time.time()
        self.cast_observer.update(data)
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
        return dict(decision,status='sent',reason='Отправлено: '+decision['action'])
