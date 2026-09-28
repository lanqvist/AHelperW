"""AHelperW desktop diagnostic reader. Screen capture only; values are observations."""
import ctypes as ct
from ctypes import wintypes as wt
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import shutil
import sys
import threading
import time
import traceback
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

ct.windll.user32.SetProcessDpiAwarenessContext(ct.c_void_p(-4))
from PIL import Image, ImageGrab, ImageTk, ImageOps
import numpy as np
from rapidocr_onnxruntime import RapidOCR
from debug_log import DebugLog
from state_writer import StateWriter
from ocr_plan import OcrPlan
from bindings_ui import BindingEditor, load_bindings, label as binding_label
from apl import ArmsAPL
from input_sender import Executor, stop_pressed
from capture_backend import HudCapture
from cast_receipt import decode as decode_cast_receipt

ASSETS = Path(__file__).resolve().parent
PACKAGED = bool(getattr(sys, 'frozen', False))
ROOT = Path(os.environ['LOCALAPPDATA'])/'AHelperW' if PACKAGED else ASSETS
APL_ROOT = ASSETS/'apl-data' if PACKAGED else ASSETS.parent/'docs'/'arms-apl'
ROOT.mkdir(parents=True, exist_ok=True)
if PACKAGED:
    for name in ('pipeline.json', 'ocr_policy.json'):
        if not (ROOT/name).exists():
            shutil.copyfile(ASSETS/name, ROOT/name)
U, K = ct.windll.user32, ct.windll.kernel32
U.GetForegroundWindow.restype = wt.HWND
U.GetWindowThreadProcessId.argtypes = [wt.HWND, ct.POINTER(wt.DWORD)]
U.GetClientRect.argtypes = [wt.HWND, ct.POINTER(wt.RECT)]
U.ClientToScreen.argtypes = [wt.HWND, ct.POINTER(wt.POINT)]
K.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
K.OpenProcess.restype = wt.HANDLE
K.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ct.POINTER(wt.DWORD)]
K.CloseHandle.argtypes = [wt.HANDLE]

NAMES = dict(zip(
    [12294,7384,845,260708,167105,107574,227847,163201,1464,107570,100,6552,
     386164,52437,386633,334783,445606,456120,445584,446035,1269391,10060,208086,388539],
    ['Смертельный удар','Превосходство','Рассекающий удар','Размашистые удары',
     'Удар колосса','Аватара','Вихрь клинков','Казнь','Мощный удар','Удар громовержца',
     'Рывок','Зуботычина','Боевая стойка','Внезапная смерть','Точность палача',
     'Сопутствующий ущерб','Неминуемая смерть','Оппортунизм','Палач',
     'Вихрь клинков (аура)','Мастер военного дела','Придание сил','Удар колосса (цель)','Кровопускание']))
LABELS = {'ready':'Готово','cd':'КД','almost':'Скоро','nores':'Нет ресурса',
          'outofrange':'Вне дистанции','unusable':'Недоступно','proc':'Активен',
          'debuff':'Активен','procoff':'Не активен','unknown':'Неизвестно'}
TARGET_STATUS_COLORS = {
    'estimate':[0,1,.53], 'manual':[.6,.4,1], 'stabilizing':[1,.8,0],
    'no_nameplates':[.16,.16,.16], 'no_melee_observation':[.9,.3,0],
    'range_unknown':[0,.8,1], 'unit_unknown':[.75,0,.75], 'waiting':[.48,.35,0],
}
LABELS.update(estimate='Автооценка получена',manual='Ручной режим',stabilizing='Стабилизация числа целей',
              no_nameplates='Нет видимых неймплейтов',no_melee_observation='Нет подтверждённых ближних врагов',
              range_unknown='Дистанция соседних целей неизвестна',unit_unknown='Данные соседних целей недоступны',
              waiting='Ожидание первого подсчёта')

def game_origin(screen):
    hwnd = U.GetForegroundWindow()
    pid = wt.DWORD()
    U.GetWindowThreadProcessId(hwnd, ct.byref(pid))
    handle = K.OpenProcess(0x1000, False, pid.value)
    if not handle:
        raise ValueError('WoW должен быть на переднем плане')
    try:
        buf, length = ct.create_unicode_buffer(32768), wt.DWORD(32768)
        if not K.QueryFullProcessImageNameW(handle, 0, buf, ct.byref(length)):
            raise ValueError('Не удалось определить активное приложение')
        if Path(buf.value).name.lower() not in ('wow.exe', 'wowt.exe', 'wowb.exe'):
            raise ValueError('Пауза: WoW не в фокусе')
    finally:
        K.CloseHandle(handle)
    rect, point = wt.RECT(), wt.POINT()
    if not U.GetClientRect(hwnd, ct.byref(rect)) or not U.ClientToScreen(hwnd, ct.byref(point)):
        raise ValueError('Не удалось определить окно WoW')
    if (rect.right, rect.bottom) != (screen['width'], screen['height']):
        raise ValueError(f'Размер окна {rect.right}×{rect.bottom} не совпадает с экспортом')
    return hwnd, point.x, point.y

def box(r):
    return (r['x'], r['y'], r['x'] + r['width'], r['y'] + r['height'])

class Reader:
    def __init__(self, path):
        raw = Path(path).read_bytes()
        self.hash = hashlib.sha256(raw).hexdigest()
        self.cfg = json.loads(raw.decode('utf-8-sig'))
        pipeline_path=ROOT/'pipeline.json'
        self.pipeline=json.loads(pipeline_path.read_text(encoding='utf-8')) if pipeline_path.exists() else {}
        self.capture_backend=self.pipeline.get('captureBackend','mss')
        if self.capture_backend not in ('mss','pillow'): raise ValueError('Неизвестный captureBackend')
        self.color_interval=max(.025,min(.25,float(self.pipeline.get('colorIntervalMs',50))/1000))
        c = self.cfg
        if c.get('schema') != 'AHelperW.HUD' or c.get('version') != 1:
            raise ValueError('Нужен экспорт AHelperW.HUD версии 1')
        if c['screen'].get('origin') != 'top-left' or c['screen'].get('units') != 'physical-pixels':
            raise ValueError('Неподдерживаемая система координат')
        self.entries = []
        for s in c['squares']:
            kind = s['kind']
            if kind not in ('spell','proc','debuff'):
                raise ValueError('Неизвестный тип квадрата')
            self.entries.append((f"{kind}:{s['spellID']}:{s['index']}",
                f"{s['index']:02} {NAMES.get(s['spellID'], str(s['spellID']))}", kind, s))
        self.regions = {}
        self.square_specs = {key:s for key,_,_,s in self.entries}
        for key, _, kind, s in self.entries:
            # Export's timer box can clip 4-digit decimals: include full cell width.
            r = dict(s['timerRegion'])
            if c['display'].get('timerLayout') != 'split-v1':
                r['x'] = s['rect']['x']; r['width'] = s['rect']['width']
            self.regions[key + '/timer'] = r
            self.regions[key + '/stacks'] = s['stackRegion']
        for key, r in c['resources'].items():
            if key != 'gcd': self.regions['resource/' + key] = r
        for key, r in c['context'].items():
            if key in ('autoAttack','targetCast','playerCast','inputAllowed','targetInterrupt','targetCountStatus'): continue
            explicit = c.get('contextNumbers',{}).get(key)
            r = dict(explicit or r)
            if not explicit:
                dy = int(r['height'] * .5)
                r['y'] += dy; r['height'] -= dy
            self.regions['context/' + key] = r
        rects = [s['rect'] for _,_,_,s in self.entries] + list(c['resources'].values()) + list(c['context'].values())
        if c.get('castReceipt',{}).get('rect'): rects.append(c['castReceipt']['rect'])
        for r in rects + list(self.regions.values()):
            if not all(isinstance(r[k], (int,float)) and math.isfinite(r[k]) for k in ('x','y','width','height')):
                raise ValueError('Некорректные координаты')
            x,y,x2,y2 = box(r)
            if x < 0 or y < 0 or x2 > c['screen']['width'] or y2 > c['screen']['height'] or x2 <= x or y2 <= y:
                raise ValueError('Область вне экрана: нужен новый экспорт')
        self.bounds = (min(r['x'] for r in rects), min(r['y'] for r in rects),
                       max(box(r)[2] for r in rects), max(box(r)[3] for r in rects))
        self.ocr = None
        self.context_colors={k:r for k,r in c['context'].items()
                             if k in ('targets','time','range','chargeRange','playerCast','targetCast',
                                      'trinket1','trinket2','potion','inputAllowed','targetInterrupt','targetCountStatus')}
        self.lock = threading.Lock()
        # Only these counters have a constant, opaque background. Their pixels
        # can be validated independently from the square's changing state colour.
        self.charge_regions = {
            key+'/stacks':self.regions[key+'/stacks']
            for key,spec in self.square_specs.items()
            if spec['kind']=='spell' and spec.get('charges')
            and c['display'].get('chargeText')=='white-on-black'
        }
        self.pixel_regions = dict(self.charge_regions)
        if 'context/targets' in self.regions:
            self.pixel_regions['context/targets'] = self.regions['context/targets']
        self.plan = OcrPlan(self, ROOT/'ocr_policy.json')
        self.ocr_stats = {}

    def crop(self, image, r):
        x,y,x2,y2 = box(r); bx,by,_,_ = self.bounds
        return image.crop((x-bx,y-by,x2-bx,y2-by))

    def color(self, image, x, y, candidates, palette=None):
        bx,by,_,_ = self.bounds
        patch = np.asarray(image.crop((x-bx-2,y-by-2,x-bx+3,y-by+3))).astype(float)
        rgb = np.median(patch.reshape(-1,3), axis=0)
        palette = palette or self.cfg['display']['colors']
        distances = sorted((float(np.linalg.norm(rgb-np.array(palette[name])*255)),name) for name in candidates)
        distance,state = distances[0]
        # Reject mixed pixels, unrecognised colors and ambiguous matches.
        confidence = max(0., 1-distance/50)
        agreement = np.mean(np.linalg.norm(patch-rgb,axis=2) < 25)
        if distance > 35 or agreement < .8 or (len(distances)>1 and distances[1][0]-distance<12):
            state = 'unknown'
        return {'state':state,'colorConfidence':round(confidence,3),'rgb':rgb.astype(int).tolist()}

    def numbers(self, image, rows, captured_at):
        work_started=time.perf_counter()
        # Coordinates already locate each text line. A detector on a large atlas
        # downscaled tiny stack digits away; recognize the crops directly in batches.
        keys, crops, raw_crops = [], [], {}
        masks, fingerprints = {}, {}
        now=time.time()
        out = {}
        stats={'modelCrops':0,'retryCrops':0,'pixelCacheHits':0,'disabled':len(self.plan.disabled),'aliases':len(self.plan.aliases)}
        for key in self.plan.due(self.regions,now):
            region=self.regions[key]
            owner = key.rsplit('/', 1)[0]
            state = rows.get(owner, {}).get('state')
            out[key]={'value':None,'raw':'','confidence':0.,'reason':'blank_or_inactive'}
            if owner.startswith(('proc:', 'debuff:')) and state not in ('proc', 'debuff'):
                self.plan.attempts[key]=now
                continue
            if owner.startswith('spell:') and key.endswith('/timer') and not self.square_specs[owner].get('charges') and state not in ('cd','almost'):
                self.plan.attempts[key]=now
                continue
            crop = self.crop(image, region)
            fingerprint=self.plan.fingerprint(crop,None if key in self.pixel_regions else state,self.hash)
            reused=self.plan.reuse(key,fingerprint,now)
            if reused is not None:
                self.plan.attempts[key]=now
                out[key]=reused; stats['pixelCacheHits']+=1
                continue
            if len(keys)>=self.plan.batch_limit:
                del out[key]
                continue
            self.plan.attempts[key]=now
            fingerprints[key]=fingerprint
            pixels = np.asarray(crop)
            dark = key.endswith('/stacks') and (state in ('proc', 'debuff') or
                (self.cfg['display'].get('chargeText')!='white-on-black' and
                 self.square_specs.get(owner,{}).get('charges') and state in ('ready','almost')))
            if dark:
                ink = np.max(pixels, axis=2) < 85
                mode = 'dark_stack'
            elif owner.startswith('spell:') and key.endswith('/timer'):
                # Native countdown text may be yellow/red as well as white.
                # Subtract the measured flat background, keeping bright strokes.
                background = np.array(rows[owner]['rgb'], dtype=float)
                contrast = np.linalg.norm(pixels.astype(float)-background, axis=2)
                ink = (np.max(pixels, axis=2) > 145) & (contrast > 65)
                mode = 'colored_countdown'
            else:
                # White and neutral gray text, excluding saturated backgrounds.
                ink = (np.min(pixels, axis=2) > 130) & (np.ptp(pixels.astype(int), axis=2) < 55)
                mode = 'neutral_text'
            ys, xs = np.nonzero(ink)
            out[key]['preprocess'] = {'mode':mode, 'inkPixels':len(xs)}
            if len(xs) < 5:
                continue
            normalized = Image.fromarray(np.where(ink, 0, 255).astype('uint8')).convert('RGB')
            normalized = normalized.crop((int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1))
            normalized = ImageOps.expand(normalized, border=3, fill='white')
            normalized = normalized.resize((normalized.width*3, normalized.height*3), Image.Resampling.NEAREST)
            keys.append(key); crops.append(np.asarray(normalized))
            masks[key] = out[key]['preprocess']
            # Preserve grayscale and antialiasing for a selective second pass.
            raw = crop.crop((int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1))
            bg = tuple(int(v) for v in pixels[0,0])
            raw = ImageOps.expand(raw,border=(7,4,7,4),fill=bg)
            raw = raw.resize((raw.width*3,raw.height*3),Image.Resampling.LANCZOS)
            raw_crops[key] = np.asarray(raw)[:,:,::-1].copy()
        before_inference=time.perf_counter()
        stats['preprocessSeconds']=before_inference-work_started
        results, _ = self.ocr.text_rec(crops) if crops else ([], 0.)
        stats['primaryInferenceSeconds']=time.perf_counter()-before_inference
        fallback_keys = []
        def parse(key, raw, confidence):
            numeric=raw
            if key in ('context/ttd','context/fight','context/targets'):
                numeric=raw.removeprefix('~')
            if key=='context/targets' and raw=='3+': numeric='3'
            pattern = r'\d{1,9}(?:[.,]\d)?%?'
            if key.endswith('/stacks'): pattern=r'\d{1,2}'
            elif key.endswith('/timer'): pattern=r'\d{1,4}(?:[.,]\d)?'
            if confidence<.92 or not re.fullmatch(pattern,numeric):
                return None
            value=float(numeric.rstrip('%').replace(',','.'))
            if key.endswith('/stacks') and (not value.is_integer() or value>99): return None
            spec=self.square_specs.get(key.rsplit('/',1)[0],{})
            maximum=spec.get('maxCharges')
            if key.endswith('/stacks') and isinstance(maximum,(int,float)) and value>maximum: return None
            if key=='resource/targetHealthPercent' and value>100: return None
            if key=='context/targets' and (not value.is_integer() or not 1<=value<=80): return None
            return value
        for key, result in zip(keys, results):
            raw, confidence = result[0].strip(), float(result[1])
            value=parse(key,raw,confidence)
            out[key]={'value':value,'raw':raw,'confidence':round(confidence,3),
                      'reason': 'recognized' if value is not None else 'rejected',
                      'preprocess':masks[key], 'variants':[{'method':'mask','raw':raw,'confidence':round(confidence,3)}]}
            if value is None and (key.endswith(('/timer','/stacks')) or key.startswith('resource/')
                                  or key in ('context/speed','context/haste','context/time','context/maxrage','context/last')):
                fallback_keys.append(key)
        before_retry=time.perf_counter()
        retried, _ = self.ocr.text_rec([raw_crops[k] for k in fallback_keys]) if fallback_keys else ([],0.)
        stats['retryInferenceSeconds']=time.perf_counter()-before_retry
        for key, result in zip(fallback_keys, retried):
            raw, confidence = result[0].strip(), float(result[1])
            item=out[key]
            item['variants'].append({'method':'original_padded','raw':raw,'confidence':round(confidence,3)})
            value=parse(key,raw,confidence)
            # If the first pass saw a number with medium confidence, require
            # agreement. Never convert O->0 or accept repeated low-confidence guesses.
            primary=item['raw'].replace(',','.')
            conflicts = (value is not None and item['confidence']>=.75 and re.fullmatch(r'\d+(?:\.\d+)?%?',primary)
                         and float(primary.rstrip('%')) != value)
            if value is not None and not conflicts:
                item.update(value=value,raw=raw,confidence=round(confidence,3),reason='recognized_original')
            elif conflicts:
                item['reason']='variant_disagreement'
        for key,value in out.items():
            if key in fingerprints:
                value['recognizedAt']=captured_at
                if key in self.pixel_regions:
                    value['pixelFingerprint']=fingerprints[key]
                self.plan.remember(key,fingerprints[key],value)
            value['capturedAt']=captured_at
            value['expiresAt']=captured_at+self.plan.ttl(key)
        stats['modelCrops']=len(keys); stats['retryCrops']=len(fallback_keys)
        stats['fieldsUpdated']=len(out)
        stats['numbersTotalSeconds']=time.perf_counter()-work_started
        self.ocr_stats=stats
        return out

    def capture(self, grabber):
        begin=time.perf_counter()
        hwnd,ox,oy=game_origin(self.cfg['screen'])
        after_focus=time.perf_counter()
        # Conservative frame age: timestamp before sampling, not after decoding.
        timestamp=time.time()
        image=grabber.grab(tuple(v+(ox if i%2==0 else oy) for i,v in enumerate(self.bounds)))
        captured_end=time.time()
        after_grab=time.perf_counter()
        rows={}
        for key,_,kind,s in self.entries:
            candidates=['ready','cd','almost','nores','outofrange','unusable','unknown'] if kind=='spell' else [kind,'procoff','unknown']
            rows[key]=self.color(image, s['colorSample']['x'],s['colorSample']['y'],candidates)
        flag_colors={'ready':[0,1,.53],'cd':[1,.15,.15],'unknown':[.48,.35,0],'procoff':[.16,.16,.16]}
        for key,r in self.context_colors.items():
            if key=='targetCountStatus':
                palette=self.cfg.get('targetCounting',{}).get('statusColors',TARGET_STATUS_COLORS)
                rows['context/'+key]=self.color(image,int(r['x']+r['width']/2),int(r['y']+r['height']/2),list(palette),palette)
                continue
            flag=key in ('inputAllowed','targetInterrupt')
            x=r['x']+r['width']/2 if flag else r['x']+4
            y=r['y']+r['height']/2 if flag else r['y']+r['height']*.45
            sample=self.cfg.get('contextSamples',{}).get(key)
            if sample and not flag: x,y=sample['x'],sample['y']
            candidates=['ready','cd','unknown','procoff'] if flag else ['ready','cd','nores','procoff','unknown']
            rows['context/'+key]=self.color(image,int(x),int(y),candidates,flag_colors if flag else None)
        after_colors=time.perf_counter()
        # Capture and color decoding never wait for OCR.
        if game_origin(self.cfg['screen']) != (hwnd,ox,oy): raise ValueError('Окно переместилось: кадр отброшен')
        gcd=self.cfg['resources'].get('gcd')
        if gcd:
            gcd_palette = self.cfg['display'].get('gcdColors',
                {'ready': [0,1,.53], 'cd': [.65,.12,.12], 'unknown': [.16,.16,.16]})
            rows['gcd']=self.color(image,gcd['x']+5,gcd['y']+gcd['height']-5,
                                   ['ready','cd','unknown'],gcd_palette)
        return {'schema':'AHelperW.Reader','version':1,'profileHash':self.hash,'valid':True,
                'capturedAt':timestamp,'expiresAt':timestamp+.8,'rows':rows,'numbers':{},
                'castReceipt':decode_cast_receipt(image,self.cfg.get('castReceipt'),self.bounds),
                'captureCompletedAt':captured_end,'captureBackend':grabber.backend,
                'captureFallbackError':grabber.fallback_error,
                'timings':{'focusBeforeSeconds':after_focus-begin,'grabSeconds':after_grab-after_focus,
                           'colorDecodeSeconds':after_colors-after_grab,
                           'focusAfterAndGcdSeconds':time.perf_counter()-after_colors,
                           'captureTotalSeconds':time.perf_counter()-begin},
                'window':{'handle':int(hwnd),'x':ox,'y':oy},
                'numberTimestampsRequired': True,
                'note':'OCR observations, not authoritative game state. Empty values are unknown.'},image

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('AHelperW — диагностика HUD')
        self.geometry('1150x780')
        self.debug = DebugLog(ROOT)
        self.writer = StateWriter(ROOT, self.debug)
        self.closing = False
        self.binding_editor = None
        self.running=False; self.events=queue.Queue(maxsize=16); self.generation=0
        self.stop_event = threading.Event()
        self.reader=None; self.latest=None; self.last_good=None; self.last_ocr_good=None; self.photo=None
        bar=ttk.Frame(self); bar.pack(fill='x',padx=8,pady=8)
        ttk.Button(bar,text='Открыть экспорт',command=self.choose).pack(side='left')
        self.toggle=ttk.Button(bar,text='Начать',command=self.start_stop); self.toggle.pack(side='left',padx=8)
        ttk.Button(bar,text='Назначение клавиш',command=self.open_bindings).pack(side='left',padx=(0,8))
        ttk.Label(bar,text='Переключись в WoW после запуска. OCR: ? означает неизвестно.').pack(side='left')
        execution=ttk.Frame(self); execution.pack(fill='x',padx=8,pady=(0,6))
        self.auto_input=tk.BooleanVar(value=not PACKAGED)
        ttk.Checkbutton(execution,text='Автонажатия по APL',variable=self.auto_input,
                        command=lambda:self.stop() if self.running else None).pack(side='left')
        ttk.Label(execution,text='Целей:').pack(side='left',padx=(12,4))
        self.targets_choice=ttk.Combobox(execution,values=['Из HUD','1','2','3+'],state='readonly',width=8)
        self.targets_choice.set('Из HUD'); self.targets_choice.pack(side='left')
        ttk.Label(execution,text='Фаза:').pack(side='left',padx=(12,4))
        self.phase_choice=ttk.Combobox(execution,values=['По HP цели','Обычная (вручную)','Казнь (вручную)'],state='readonly',width=20)
        self.phase_choice.set('По HP цели'); self.phase_choice.pack(side='left')
        ttk.Label(execution,text='F8 — остановить').pack(side='left',padx=12)
        self.apl_status=ttk.Label(self,text='APL остановлен. Назначаются только способности с клавишами.',wraplength=1100)
        self.apl_status.pack(fill='x',padx=8)
        self.status=ttk.Label(self,text=''); self.status.pack(fill='x',padx=8)
        self.log_status=ttk.Label(self,text=f'Дебаг: {self.debug.path}')
        self.log_status.pack(fill='x',padx=8)
        self.table=ttk.Treeview(self,columns=('kind','state','timer','stacks','confidence','binding'),show='tree headings',height=24)
        self.table.heading('#0',text='Индикатор'); self.table.column('#0',width=290)
        for col,title,width in [('kind','Тип',85),('state','Состояние / число',145),('timer','Секунды OCR',110),('stacks','Стаки OCR',100),('confidence','Цвет / OCR',105),('binding','Клавиша',140)]:
            self.table.heading(col,text=title); self.table.column(col,width=width)
        self.table.pack(fill='both',expand=True,padx=8,pady=8)
        self.table.bind('<<TreeviewSelect>>',self.show_crop)
        self.table.bind('<Double-1>',self.edit_row_binding)
        self.detail=ttk.Label(self,text='Двойной щелчок по способности — назначить клавишу. Выбор строки — показать кадр.')
        self.detail.pack(pady=6)
        self.image_label=ttk.Label(self); self.image_label.pack(pady=6)
        self.protocol('WM_DELETE_WINDOW',self.close)
        if (ROOT/'profile.json').exists():
            self.load(ROOT/'profile.json')
        else:
            self.status.config(text='Первый запуск: настрой HUD в WoW, выполни /ahw export и нажми «Открыть экспорт».')
            self.apl_status.config(text='После импорта назначь клавиши. Чтение и автонажатия сейчас выключены. F8 — остановить.')
        self.after(100,self.poll)

    def load(self,path):
        try: reader=Reader(path)
        except Exception as e:
            self.debug.event('profile_error', path=str(path), error=str(e), traceback=traceback.format_exc())
            messagebox.showerror('Экспорт',str(e)); return
        if self.binding_editor and self.binding_editor.winfo_exists() and not self.binding_editor.close():
            return
        self.stop()
        if PACKAGED and Path(path).resolve() != (ROOT/'profile.json').resolve():
            try:
                destination = ROOT/'profile.json'
                temporary = ROOT/'profile.import.tmp'
                temporary.write_text(json.dumps(reader.cfg, ensure_ascii=False, indent=2), encoding='utf-8')
                if destination.exists():
                    shutil.copyfile(destination, ROOT/'profile.previous.json')
                os.replace(temporary, destination)
            except OSError as exc:
                messagebox.showerror('Экспорт', 'Не удалось сохранить профиль: '+str(exc), parent=self)
                return
        self.stop(); self.reader=reader; self.last_good=None; self.last_ocr_good=None
        self.debug.event('profile_loaded', path=str(path), profileHash=reader.hash, profile=reader.cfg)
        self.table.delete(*self.table.get_children())
        for key,name,kind,_ in reader.entries: self.table.insert('', 'end',iid=key,text=name,values=(kind,'?','?','?','—'))
        self.table.insert('','end',iid='gcd',text='GCD',values=('resource','?','?','?','—'))
        for key in reader.regions:
            if key.startswith(('resource/','context/')): self.table.insert('','end',iid=key,text=key,values=('OCR','?','—','—','—'))
        for key in reader.context_colors:
            iid='context/'+key
            if not self.table.exists(iid): self.table.insert('','end',iid=iid,text=iid,values=('context','?','—','—','—'))
        self.refresh_bindings()
        if reader.cfg.get('specID')==71:
            try:
                model=ArmsAPL(reader,APL_ROOT,{}, {'targets':None,'phase':'auto'})
                self.debug.event('apl_model_loaded',profileHash=reader.hash,talents=sorted(model.talents),
                                 lists={k:len(v) for k,v in model.lists.items()})
                self.apl_status.config(text='APL Arms / Slayer загружен. Назначь клавиши и выбери число целей. F8 — остановить.')
            except Exception as exc:
                self.debug.event('apl_model_error',error=str(exc),traceback=traceback.format_exc())
                self.apl_status.config(text='APL недоступен: '+str(exc))
        self.status.config(text=f'{Path(path).name}: {len(reader.entries)} квадратов; {reader.cfg["screen"]["width"]}×{reader.cfg["screen"]["height"]}. Остановлено.')

    def choose(self):
        path=filedialog.askopenfilename(filetypes=[('Экспорт','*.json *.txt'),('Все файлы','*.*')])
        if path: self.load(path)

    def refresh_bindings(self):
        path=ROOT/'bindings'/f"spec-{self.reader.cfg['specID']}.json"
        try:
            _,bindings=load_bindings(path,self.reader.cfg['specID'])
        except Exception as exc:
            self.debug.event('bindings_error',error=str(exc),traceback=traceback.format_exc())
            messagebox.showerror('Назначение клавиш',str(exc),parent=self)
            bindings={}
        for key in self.table.get_children():
            spec=self.reader.square_specs.get(key,{})
            text=binding_label(bindings.get(str(spec['spellID']))) if spec.get('kind')=='spell' else '—'
            self.table.set(key,'binding',text)

    def edit_row_binding(self,event):
        key=self.table.identify_row(event.y)
        spec=self.reader.square_specs.get(key,{}) if self.reader else {}
        if spec.get('kind')=='spell':
            self.table.selection_set(key)
            self.open_bindings(str(spec['spellID']))

    def open_bindings(self,spell_id=None):
        if not self.reader:
            return
        if self.running:
            self.stop()
        if self.binding_editor and self.binding_editor.winfo_exists():
            if spell_id:
                self.binding_editor.select_spell(spell_id)
            else:
                self.binding_editor.show_all()
            self.binding_editor.lift(); self.binding_editor.focus_set(); return
        try:
            self.binding_editor=BindingEditor(self,self.reader,ROOT,spell_id)
        except Exception as exc:
            self.debug.event('bindings_error',error=str(exc),traceback=traceback.format_exc())
            messagebox.showerror('Назначение клавиш',str(exc),parent=self)

    def publish(self,data):
        self.writer.submit(data, self.generation)

    def enqueue(self, event):
        while True:
            try:
                self.events.put_nowait(event)
                return
            except queue.Full:
                try: self.events.get_nowait()
                except queue.Empty: pass

    def report_callback_exception(self, exc_type, value, tb):
        self.debug.event('ui_error', error=str(value), traceback=''.join(traceback.format_exception(exc_type,value,tb)))
        self.status.config(text='Ошибка интерфейса записана в лог. Публикация работает отдельно.')

    def stop(self):
        self.debug.event('reading_stopped', generation=self.generation)
        self.stop_event.set()
        self.running=False; self.generation+=1; self.toggle.config(text='Начать')
        self.targets_choice.config(state='readonly'); self.phase_choice.config(state='readonly')
        self.apl_status.config(text='APL остановлен. F8 — остановить исполнение при следующем запуске.')
        self.latest=None
        for iid in self.table.get_children():
            values=list(self.table.item(iid,'values')); values[1:5]=['?','?','?','—']; self.table.item(iid,values=values)
        self.publish({'schema':'AHelperW.Reader','version':1,'valid':False,'reason':'stopped','capturedAt':time.time(),'rows':{},'numbers':{}})

    def start_stop(self):
        if self.running:
            self.stop(); self.status.config(text='Остановлено. Значения сброшены.'); return
        if not self.reader: return
        executor=None
        settings={'targets':{'1':1,'2':2,'3+':3}.get(self.targets_choice.get()),
                  'phase':{'Обычная (вручную)':'normal','Казнь (вручную)':'execute'}.get(self.phase_choice.get(),'auto')}
        if self.auto_input.get():
            try:
                _,bindings=load_bindings(ROOT/'bindings'/f"spec-{self.reader.cfg['specID']}.json",self.reader.cfg['specID'])
                executor=Executor(ArmsAPL(self.reader,APL_ROOT,bindings,settings),self.debug)
            except Exception as exc:
                self.debug.event('apl_start_error',error=str(exc),traceback=traceback.format_exc())
                messagebox.showerror('APL',str(exc),parent=self)
                return
        self.running=True; self.generation+=1; token=self.generation; reader=self.reader
        self.targets_choice.config(state='disabled'); self.phase_choice.config(state='disabled')
        halt = threading.Event(); self.stop_event = halt
        shared_lock = threading.Lock()
        frame_ready = threading.Event()
        shared = {'pending': None, 'cache': {}, 'epoch': 0, 'versions': {}, 'states': {}}
        self.debug.event('reading_started', generation=token, profileHash=reader.hash,
                         executionEnabled=executor is not None,executionSettings=settings,
                         pipeline={'captureBackend':reader.capture_backend,'colorIntervalMs':reader.color_interval*1000},
                         ocrPlan={'disabled':reader.plan.disabled,'aliases':reader.plan.aliases,
                                  'periodSeconds':reader.plan.periods,'batchLimit':reader.plan.batch_limit})
        self.toggle.config(text='Остановить'); self.status.config(text='Загрузка OCR. Затем переключись в WoW…')
        def ocr_worker():
            try:
                with reader.lock:
                    if reader.ocr is None: reader.ocr=RapidOCR(intra_op_num_threads=2,inter_op_num_threads=2)
                    reader.plan.attempts.clear()
                    reader.plan.cache.clear()
                while not halt.is_set():
                    frame_ready.wait(.05)
                    frame_ready.clear()
                    with shared_lock:
                        job=shared['pending']; shared['pending']=None
                    if job is None:
                        continue
                    data,img,epoch,versions=job
                    attempt=time.time()
                    try:
                        with reader.lock:
                            numbers=reader.numbers(img,data['rows'],data['capturedAt'])
                            stats=dict(reader.ocr_stats)
                        if not halt.is_set():
                            self.debug.save_samples(reader,img,data,numbers)
                        accepted=False
                        with shared_lock:
                            if epoch==shared['epoch'] and not halt.is_set():
                                shared['cache'].update({key:(value,versions.get(key.rsplit('/',1)[0]))
                                                       for key,value in numbers.items()})
                                accepted=True
                        self.debug.event('ocr_result', generation=token, profileHash=reader.hash,
                                         capturedAt=data['capturedAt'], durationSeconds=time.time()-attempt,
                                         frameAgeAtStartSeconds=attempt-data['capturedAt'],
                                         resultAgeSeconds=time.time()-data['capturedAt'],
                                         accepted=accepted, stats=stats, numbers=numbers)
                        if accepted:
                            self.enqueue((token, {'ocrSnapshot':True, 'capturedAt':data['capturedAt'],
                                                     'numbers':numbers}, img, None))
                    except Exception as e:
                        with shared_lock: shared['cache']={}
                        self.debug.event('ocr_error', generation=token, error=str(e), traceback=traceback.format_exc())
                        self.enqueue((token, {'ocrError':str(e)}, None, None))
            except Exception as e:
                self.debug.event('worker_error', generation=token, error=str(e), traceback=traceback.format_exc())
                self.enqueue((token, {'ocrError':str(e)}, None, None))

        def color_worker():
            last_target_diagnostic = None
            last_capture_at = None
            grabber=HudCapture(reader.capture_backend)
            while not halt.is_set():
                attempt=time.time()
                try:
                    if stop_pressed():
                        halt.set()
                        self.enqueue((token,{'executionStop':'Остановлено по F8'},None,None))
                        self.writer.submit({'schema':'AHelperW.Reader','version':1,'valid':False,'reason':'F8','capturedAt':time.time(),'rows':{},'numbers':{}},token)
                        break
                    data,img=reader.capture(grabber)
                    data['timings']['sincePreviousFrameSeconds']=(data['capturedAt']-last_capture_at) if last_capture_at is not None else None
                    last_capture_at=data['capturedAt']
                    merge_started=time.perf_counter()
                    charge_pixels={key:reader.plan.fingerprint(reader.crop(img,region),None,reader.hash)
                                   for key,region in reader.pixel_regions.items()}
                    with shared_lock:
                        for key,row in data['rows'].items():
                            if row['state']!=shared['states'].get(key):
                                shared['versions'][key]=shared['versions'].get(key,0)+1
                            shared['states'][key]=row['state']
                        for key in reader.regions:
                            if key in reader.plan.disabled:
                                data['numbers'][key]={'value':None,'raw':'','confidence':0.,
                                                      'reason':reader.plan.disabled[key]}
                                continue
                            source=reader.plan.aliases.get(key,key)
                            cached=shared['cache'].get(source)
                            owner=source.rsplit('/',1)[0]
                            same_observation = cached and cached[1]==shared['versions'].get(owner)
                            if cached and source in charge_pixels:
                                # A changed colour alone does not invalidate a
                                # charge. Changed digits do, even if colour stays.
                                same_observation = cached[0].get('pixelFingerprint')==charge_pixels[source]
                            if source=='context/targets' and data['rows'].get(source,{}).get('state')!='nores':
                                same_observation = False
                            if cached and cached[0]['expiresAt']>time.time() and same_observation:
                                data['numbers'][key]=dict(cached[0])
                                if source in charge_pixels:
                                    data['numbers'][key].update(pixelValidatedAt=data['capturedAt'],
                                                                validation='target_count_pixels' if source=='context/targets' else 'charge_pixels')
                                if source!=key:
                                    data['numbers'][key].update(sourceKey=source,derived=True)
                            else:
                                reason='awaiting_fresh_ocr'
                                if cached and source in charge_pixels and not same_observation:
                                    reason='target_count_changed_or_unknown' if source=='context/targets' else 'charge_pixels_changed'
                                data['numbers'][key]={'value':None,'raw':'','confidence':0.,'reason':reason}
                        shared['pending']=(data,img,shared['epoch'],dict(shared['versions']))
                    data['timings']['fingerprintAndMergeSeconds']=time.perf_counter()-merge_started
                    frame_ready.set()
                    target_status=data['rows'].get('context/targetCountStatus',{}).get('state','unavailable')
                    target_number=data['numbers'].get('context/targets',{})
                    data['targetCountDiagnostic']={
                        'sourceStatus':target_status,
                        'sourceLabel':LABELS.get(target_status,'Нет индикатора причины в экспорте'),
                        'value':target_number.get('value'),
                        'ocrReason':target_number.get('reason'),
                        'capturedAt':data['capturedAt'],
                    }
                    target_signature=(target_status,target_number.get('value'),target_number.get('reason'))
                    if target_signature != last_target_diagnostic:
                        self.debug.event('target_count_changed',generation=token,diagnostic=data['targetCountDiagnostic'])
                        last_target_diagnostic=target_signature
                    decision_started=time.perf_counter()
                    if executor and not halt.is_set():
                        window=data['window']
                        try:
                            data['execution']=executor.step(data,
                                lambda:game_origin(reader.cfg['screen'])==(window['handle'],window['x'],window['y']),halt)
                            self.debug.event('apl_decision',generation=token,decision=data['execution'],capturedAt=data['capturedAt'])
                        except Exception as exc:
                            self.debug.event('execution_error',error=str(exc),traceback=traceback.format_exc())
                            halt.set()
                            self.enqueue((token,{'executionStop':'Исполнение остановлено: '+str(exc)},None,None))
                            self.writer.submit({'schema':'AHelperW.Reader','version':1,'valid':False,'reason':'execution_error','capturedAt':time.time(),'rows':{},'numbers':{}},token)
                    elif not executor:
                        data['execution']={'status':'disabled','reason':'Режим диагностики: автонажатия выключены'}
                    data['timings']['decisionAndInputSeconds']=time.perf_counter()-decision_started
                    data['timings']['frameAgeAtDecisionSeconds']=time.time()-data['capturedAt']
                    if not halt.is_set():
                        self.debug.event('capture_result', generation=token, profileHash=reader.hash,
                                         durationSeconds=time.time()-attempt, data=data)
                        self.writer.submit(data,token)
                        self.enqueue((token,data,img,None))
                except Exception as e:
                    if executor: executor.pause()
                    with shared_lock:
                        shared['epoch']+=1; shared['pending']=None; shared['cache']={}
                        shared['states']={}; shared['versions']={}
                    if not halt.is_set():
                        self.debug.event('capture_error', generation=token, error=str(e), traceback=traceback.format_exc())
                        self.writer.submit({'schema':'AHelperW.Reader','version':1,'valid':False,
                                            'reason':str(e),'capturedAt':time.time(),'rows':{},'numbers':{}},token)
                        self.enqueue((token,None,None,str(e)))
                    halt.wait(.4)
                halt.wait(max(0,reader.color_interval-(time.time()-attempt)))
            grabber.close()
        threading.Thread(target=ocr_worker,daemon=True).start()
        threading.Thread(target=color_worker,daemon=True).start()

    def poll(self):
        try:
            self.poll_once()
        except Exception as exc:
            self.report_callback_exception(type(exc),exc,exc.__traceback__)
        finally:
            if not self.closing:
                self.after(100,self.poll)

    def poll_once(self):
        try:
            for _ in range(16):
                token,data,img,error=self.events.get_nowait()
                if token!=self.generation:
                    self.debug.event('result_discarded', generation=token, reason='generation_changed')
                    continue
                if data and 'executionStop' in data:
                    reason=data['executionStop']
                    self.stop(); self.apl_status.config(text=reason)
                    continue
                if data and 'ocrError' in data:
                    self.detail.config(text='Ошибка OCR: '+data['ocrError'])
                    continue
                if data and data.get('ocrSnapshot'):
                    self.last_ocr_good=(data,img)
                    continue
                if error or (data and time.time()>data['expiresAt']):
                    self.status.config(text=error or 'Цветовой кадр устарел')
                    self.apl_status.config(text='Нажатия приостановлены: '+(error or 'кадр устарел'))
                    self.latest=None
                    for iid in self.table.get_children():
                        values=list(self.table.item(iid,'values')); values[1:5]=['?','?','?','—']; self.table.item(iid,values=values)
                    continue
                self.latest=(data,img); self.last_good=(data,img)
                execution=data.get('execution',{})
                self.apl_status.config(text='APL: '+execution.get('reason','ожидание')+
                                       (' · '+execution['list'] if execution.get('list') else '')+
                                       (' · Цели: '+data['targetCountDiagnostic']['sourceLabel']
                                        if data.get('targetCountDiagnostic',{}).get('sourceStatus') not in (None,'estimate','manual','unavailable') else ''))
                def number(key):
                    item=data['numbers'].get(key,{})
                    value=item.get('value') if item.get('expiresAt',0)>time.time() else None
                    return '?' if value is None else f'{value:g}'
                for key,state in data['rows'].items():
                    self.table.set(key,'state',LABELS[state['state']])
                    self.table.set(key,'confidence',f"{state['colorConfidence']:.0%}")
                    for col,suffix in [('timer','timer'),('stacks','stacks')]:
                        self.table.set(key,col,number(key+'/'+suffix))
                for key,item in data['numbers'].items():
                    if self.table.exists(key):
                        self.table.set(key,'state',number(key)); self.table.set(key,'confidence',f"{item['confidence']:.0%}")
                ages=[time.time()-v['capturedAt'] for v in data['numbers'].values() if v.get('value') is not None]
                age=f'{max(ages):.1f} с' if ages else 'ожидание'
                self.status.config(text=f"Цвета: {time.time()-data['capturedAt']:.2f} с • Возраст OCR: {age} • {data.get('captureBackend','?')} • задано {1/self.reader.color_interval:g} Гц")
                self.show_crop()
        except queue.Empty: pass
        if self.latest and time.time()>self.latest[0]['expiresAt']:
            self.latest=None
            for iid in self.table.get_children():
                values=list(self.table.item(iid,'values')); values[1:5]=['?','?','?','—']; self.table.item(iid,values=values)
        if self.writer.error:
            self.log_status.config(text='ОШИБКА state.json (повторяем запись): '+self.writer.error)
        elif self.debug.error:
            self.log_status.config(text='ОШИБКА ЗАПИСИ ДЕБАГА: '+self.debug.error)
        else:
            self.log_status.config(text=f'Дебаг: {self.debug.path.name} • записей: {self.debug.sequence}')

    def show_crop(self,event=None):
        selected=self.table.selection()
        if not selected or not self.last_good: return
        key=selected[0]; data,img=self.last_ocr_good or self.last_good
        r=self.reader.regions.get(key)
        if r is None:
            r=self.reader.context_colors.get(key.removeprefix('context/'))
        if r is None:
            r=next((s['rect'] for k,_,_,s in self.reader.entries if k==key),self.reader.cfg['resources'].get('gcd'))
        crop=self.reader.crop(img,r); crop.thumbnail((440,110)); self.photo=ImageTk.PhotoImage(crop)
        self.image_label.config(image=self.photo)
        observations={k:v for k,v in data['numbers'].items() if k==key or k.startswith(key+'/')}
        self.detail.config(text='Исторический кадр '+time.strftime('%H:%M:%S',time.localtime(data['capturedAt']))+': '+json.dumps(observations,ensure_ascii=False))

    def close(self):
        if self.binding_editor and self.binding_editor.winfo_exists() and not self.binding_editor.close():
            return
        self.closing=True
        self.stop(); self.writer.close(); self.debug.event('session_end'); self.destroy()

if __name__=='__main__':
    K.CreateMutexW.argtypes = [ct.c_void_p, wt.BOOL, wt.LPCWSTR]
    K.CreateMutexW.restype = wt.HANDLE
    mutex_name = 'Local\\AHelperW.Reader.Installed' if PACKAGED else 'Local\\AHelperW.Reader.' + hashlib.sha256(str(ROOT).encode()).hexdigest()[:16]
    mutex = K.CreateMutexW(None, False, mutex_name)
    if not mutex or K.GetLastError() == 183:
        ct.windll.user32.MessageBoxW(None,'Считыватель уже открыт или запуск заблокирован системой.', 'AHelperW', 64)
        raise SystemExit
    try:
        app=App()
        if '--bindings' in sys.argv:
            app.after(150,app.open_bindings)
        app.mainloop()
    except Exception:
        import traceback
        (ROOT/'error.log').write_text(traceback.format_exc(),encoding='utf-8')
        ct.windll.user32.MessageBoxW(None,'Не удалось запустить считыватель. Подробности: '+str(ROOT/'error.log'), 'AHelperW',16)
    finally:
        K.CloseHandle(mutex)
