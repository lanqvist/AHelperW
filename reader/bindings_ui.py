"""Local binding editor; key capture is confined to its focused input field."""
import ctypes
import json
import os
from pathlib import Path
import shutil
import tkinter as tk
from tkinter import ttk, messagebox


KEY_NAMES = {
    8:'Backspace', 9:'Tab', 13:'Enter', 19:'Pause', 20:'Caps Lock',
    27:'Esc', 32:'Space', 33:'Page Up', 34:'Page Down', 35:'End', 36:'Home',
    37:'Left', 38:'Up', 39:'Right', 40:'Down', 45:'Insert', 46:'Delete',
    106:'Num *', 107:'Num +', 109:'Num -', 110:'Num .', 111:'Num /',
    186:';', 187:'=', 188:',', 189:'-', 190:'.', 191:'/', 192:'` / Ё',
    219:'[', 220:'\\', 221:']', 222:"'",
}
KEY_NAMES.update({k:chr(k) for k in range(48,58)})
KEY_NAMES.update({k:chr(k) for k in range(65,91)})
KEY_NAMES.update({96+k:f'Num {k}' for k in range(10)})
KEY_NAMES.update({112+k:f'F{k+1}' for k in range(24)})
MODIFIERS = ('CTRL','ALT','SHIFT')
MOD_LABELS = {'CTRL':'Ctrl','ALT':'Alt','SHIFT':'Shift'}
MOUSE_NAMES = {'middle':'Средняя кнопка', 'x1':'Мышь 4', 'x2':'Мышь 5'}


def normalize(binding):
    if binding is None:
        return None
    if not isinstance(binding,dict):
        raise ValueError('Некорректное назначение клавиши.')
    mods=binding.get('modifiers',[])
    if not isinstance(mods,list) or any(m not in MODIFIERS for m in mods):
        raise ValueError('Неизвестный модификатор клавиши.')
    mods=[m for m in MODIFIERS if m in mods]
    device=binding.get('device')
    if device=='keyboard':
        code=binding.get('vk')
        if code==119:
            raise ValueError('F8 зарезервирована для остановки. Измени назначение F8 в профиле.')
        if type(code) is not int or code not in KEY_NAMES:
            raise ValueError('Неизвестная клавиша в профиле.')
        return {'device':device,'vk':code,'modifiers':mods}
    if device=='mouse' and binding.get('button') in MOUSE_NAMES:
        return {'device':device,'button':binding['button'],'modifiers':mods}
    raise ValueError('Неизвестная кнопка в профиле.')


def label(binding):
    if not binding:
        return '—'
    key=KEY_NAMES[binding['vk']] if binding['device']=='keyboard' else MOUSE_NAMES[binding['button']]
    return ' + '.join([MOD_LABELS[m] for m in binding['modifiers']]+[key])


def load_bindings(path,spec):
    if not path.exists():
        return {},{}
    doc=json.loads(path.read_text(encoding='utf-8-sig'))
    if doc.get('schema')!='AHelperW.Bindings' or doc.get('version')!=1 or doc.get('specID')!=spec:
        raise ValueError('Файл назначений имеет другой формат или специализацию.')
    bindings=doc.get('bindings',{})
    if not isinstance(bindings,dict):
        raise ValueError('Некорректный список назначений.')
    bindings={str(k):normalize(v) for k,v in bindings.items()}
    seen={}
    for key,binding in bindings.items():
        if binding:
            signature=json.dumps(binding,sort_keys=True)
            if signature in seen:
                raise ValueError('В сохранённом профиле повторяется клавиша '+label(binding))
            seen[signature]=key
    return doc,bindings


class BindingEditor(tk.Toplevel):
    def __init__(self,parent,reader,root,spell_id=None):
        super().__init__(parent)
        self.withdraw()
        self.reader=reader
        self.spec=reader.cfg['specID']
        self.path=Path(root)/'bindings'/f'spec-{self.spec}.json'
        self.document={}
        self.bindings={}
        self.aliases={}
        self.items={}
        self.notes={}
        self.dirty=False
        self.armed=False
        self.selected=None
        for _,name,kind,spec in reader.entries:
            if kind=='spell':
                key=str(spec['spellID'])
                self.items[key]=name.split(' ',1)[-1]
                self.notes[key]=''
        for alias_name,alias in reader.cfg.get('aliases',{}).items():
            source=str(alias.get('bindingSpellID',alias.get('displaySpellID','')))
            spell=alias.get('spellID')
            if source in self.items and type(spell) is int and str(spell)!=source:
                self.aliases[str(spell)]=int(source)
                self.notes[source]='Общая клавиша: '+('Героический удар' if alias_name=='heroic_strike' else alias.get('label',alias_name))
                if str(spell) in self.items:
                    self.items.pop(str(spell))
                    self.notes.pop(str(spell),None)
        if spell_id is not None:
            spell_id=str(self.aliases.get(str(spell_id),spell_id))
        try:
            self.document,self.bindings=load_bindings(self.path,self.spec)
        except Exception:
            self.destroy()
            raise
        self.title('AHelperW — назначение клавиш')
        compact=spell_id in self.items
        self.geometry('850x340' if compact else '900x690')
        self.minsize(810,320 if compact else 580)
        self.transient(parent)
        title={71:'Воин · Оружие',72:'Воин · Неистовство'}.get(self.spec,'Способности текущей специализации')
        ttk.Label(self,text=title,font=('Segoe UI',15,'bold')).pack(anchor='w',padx=16,pady=(16,4))
        ttk.Label(self,text='Выбери способность → «Записать клавишу» → нажми сочетание → «Сохранить».').pack(anchor='w',padx=16)
        ttk.Label(self,text='Укажи сочетания, уже назначенные в WoW. Баффы и дебаффы отдельно не назначаются.').pack(anchor='w',padx=16,pady=(3,10))
        area=ttk.Frame(self)
        self.area=area
        if not compact:
            area.pack(fill='both',expand=True,padx=16)
        self.table=ttk.Treeview(area,columns=('key','note'),show='tree headings',selectmode='browse',height=14)
        self.table.heading('#0',text='Способность'); self.table.column('#0',width=290,minwidth=180)
        self.table.heading('key',text='Клавиша'); self.table.column('key',width=160,minwidth=110)
        self.table.heading('note',text='Примечание'); self.table.column('note',width=300,minwidth=160)
        scroll=ttk.Scrollbar(area,orient='vertical',command=self.table.yview)
        self.table.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right',fill='y'); self.table.pack(fill='both',expand=True)
        for key,name in self.items.items():
            self.table.insert('','end',iid=key,text=name,values=(label(self.bindings.get(key)),self.notes[key]))
        self.table.bind('<<TreeviewSelect>>',self.select)
        self.table.bind('<Double-1>',lambda e:self.arm())
        self.selection_text=ttk.Label(self,text='Выбери способность',font=('Segoe UI',11,'bold'))
        self.selection_text.pack(anchor='w',padx=16,pady=(12,5))
        controls=ttk.Frame(self); controls.pack(fill='x',padx=16)
        self.key_text=tk.StringVar(value='—')
        self.capture=ttk.Entry(controls,textvariable=self.key_text,state='readonly',width=26)
        self.capture.pack(side='left',padx=(0,8))
        self.capture.bind('<KeyPress>',self.key_pressed)
        self.capture.bind('<FocusOut>',self.disarm)
        ttk.Button(controls,text='Записать клавишу',command=self.arm).pack(side='left')
        ttk.Button(controls,text='Очистить',command=lambda:self.assign(None)).pack(side='left',padx=8)
        mouse=ttk.Frame(self); mouse.pack(fill='x',padx=16,pady=10)
        ttk.Label(mouse,text='Кнопка мыши:').pack(side='left')
        self.mouse_key=tk.StringVar(value='Мышь 4')
        ttk.Combobox(mouse,textvariable=self.mouse_key,values=list(MOUSE_NAMES.values()),state='readonly',width=17).pack(side='left',padx=8)
        self.mouse_mods={m:tk.BooleanVar(value=False) for m in MODIFIERS}
        for m in MODIFIERS:
            ttk.Checkbutton(mouse,text=MOD_LABELS[m],variable=self.mouse_mods[m]).pack(side='left',padx=3)
        ttk.Button(mouse,text='Назначить мышь',command=self.assign_mouse).pack(side='left',padx=8)
        self.status=ttk.Label(self,text='',wraplength=820)
        self.status.pack(fill='x',padx=16,pady=4)
        footer=ttk.Frame(self); footer.pack(fill='x',padx=16,pady=(8,16))
        self.count=ttk.Label(footer,text=''); self.count.pack(side='left')
        ttk.Button(footer,text='Сохранить',command=self.save).pack(side='right')
        ttk.Button(footer,text='Закрыть',command=self.close).pack(side='right',padx=8)
        self.protocol('WM_DELETE_WINDOW',self.close)
        self.refresh_count()
        if self.items:
            self.select_spell(spell_id if compact else next(iter(self.items)))
        self.deiconify()

    def select_spell(self,spell_id):
        spell_id=str(self.aliases.get(str(spell_id),spell_id))
        if spell_id in self.items:
            self.table.selection_set(spell_id)
            self.table.focus(spell_id)
            self.table.see(spell_id)
            self.select()

    def show_all(self):
        if not self.area.winfo_manager():
            self.area.pack(fill='both',expand=True,padx=16,before=self.selection_text)
            self.geometry('900x690')
            self.minsize(810,580)

    def select(self,event=None):
        self.disarm()
        selected=self.table.selection()
        self.selected=selected[0] if selected else None
        if self.selected:
            note=self.notes[self.selected]
            self.selection_text.config(text=self.items[self.selected]+(' · '+note if note else ''))
            self.key_text.set(label(self.bindings.get(self.selected)))

    def arm(self):
        if not self.selected:
            return
        self.armed=True
        self.key_text.set('Нажми сочетание…')
        self.status.config(text='Запись активна только в этом поле. Esc — отменить. Поддерживаются Ctrl, Alt и Shift.')
        self.capture.focus_set()

    def disarm(self,event=None):
        if self.armed:
            self.armed=False
            self.key_text.set(label(self.bindings.get(self.selected)))

    def key_pressed(self,event):
        if not self.armed:
            return
        vk=event.keycode
        if vk==27:
            self.disarm(); self.status.config(text='Запись отменена.'); return 'break'
        if vk in (16,17,18,160,161,162,163,164,165):
            return 'break'
        if vk==119:
            self.status.config(text='F8 зарезервирована для остановки исполнения.'); return 'break'
        if any(ctypes.windll.user32.GetKeyState(k)&0x8000 for k in (91,92)):
            self.status.config(text='Сочетания с Win не поддерживаются.'); return 'break'
        if vk not in KEY_NAMES:
            self.status.config(text='Эта клавиша не поддерживается. Выбери другую.'); return 'break'
        mods=[m for m,k in [('CTRL',17),('ALT',18),('SHIFT',16)] if ctypes.windll.user32.GetKeyState(k)&0x8000]
        self.disarm()
        self.assign({'device':'keyboard','vk':vk,'modifiers':mods})
        return 'break'

    def assign_mouse(self):
        button=next(k for k,v in MOUSE_NAMES.items() if v==self.mouse_key.get())
        self.assign({'device':'mouse','button':button,'modifiers':[m for m in MODIFIERS if self.mouse_mods[m].get()]})

    def assign(self,binding):
        self.disarm()
        if not self.selected:
            return
        binding=normalize(binding)
        for key,other in self.bindings.items():
            if key!=self.selected and binding is not None and other==binding:
                name=self.items.get(key,'способность вне текущего HUD')
                self.status.config(text='Сочетание уже назначено: '+name+'. Сначала освободи его.')
                return
        if self.bindings.get(self.selected)!=binding:
            self.bindings[self.selected]=binding
            self.dirty=True
        self.table.set(self.selected,'key',label(binding))
        self.key_text.set(label(binding))
        self.status.config(text='Назначение изменено. Нажми «Сохранить».')
        self.refresh_count()

    def refresh_count(self):
        n=sum(bool(self.bindings.get(k)) for k in self.items)
        self.count.config(text=f'Назначено {n} из {len(self.items)}'+(' · не сохранено' if self.dirty else ''))

    def save(self):
        self.disarm()
        doc=dict(self.document)
        doc.update(schema='AHelperW.Bindings',version=1,specID=self.spec,
                   keyFormat='windows-vk',bindings=self.bindings,aliases=self.aliases,
                   sourceProfileHash=self.reader.hash)
        try:
            self.path.parent.mkdir(parents=True,exist_ok=True)
            temp=self.path.with_suffix('.tmp')
            temp.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
            if self.path.exists():
                shutil.copy2(self.path,self.path.with_suffix('.json.bak'))
            os.replace(temp,self.path)
        except OSError as exc:
            messagebox.showerror('Назначение клавиш','Не удалось сохранить: '+str(exc),parent=self)
            return False
        self.document=doc
        self.dirty=False
        self.refresh_count()
        self.status.config(text='Назначения сохранены. При следующем открытии они загрузятся автоматически.')
        self.master.refresh_bindings()
        self.master.debug.event('bindings_saved',specID=self.spec,assigned=sum(bool(v) for v in self.bindings.values()))
        return True

    def close(self):
        self.disarm()
        if self.dirty:
            answer=messagebox.askyesnocancel('Назначение клавиш','Сохранить изменения?',parent=self)
            if answer is None or (answer and not self.save()):
                return False
        self.destroy()
        return True
