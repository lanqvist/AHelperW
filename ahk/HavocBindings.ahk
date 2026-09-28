#Requires AutoHotkey v2.0
#SingleInstance Force

; Standalone binding editor. IDs identify spells, never HUD positions.
class HavocBindings {
    __New() {
        this.path := A_ScriptDir "\profiles\havoc.ini"
        this.items := [
            [162243, "Укус демона", "Базовая атака"],
            [162794, "Удар Хаоса / Аннигиляция", "Расход гнева; одна клавиша"],
            [188499, "Танец клинков / Смертоносный взмах", "Одна клавиша для обеих форм"],
            [198013, "Пронзающий взгляд", "Кулдаун"],
            [232893, "Клинок Скверны", "Талант"],
            [258920, "Обжигающий жар", "Способность"],
            [195072, "Рывок Скверны", "Перемещение"],
            [258860, "Разрыв сущности", "Талант"],
            [370965, "Охота", "Талант"],
            [198793, "Коварное отступление", "Перемещение"],
            [191427, "Метаморфоза", "Требует выбора места"],
            [198589, "Затуманивание", "Защита"],
            [185123, "Бросок боевого клинка", "Способность"],
            [183752, "Прерывание", "Контроль"]
        ]
        this.bindings := Map()
        this.selected := 0
        this.dirty := false
        this.loading := false
        this.Load()
        this.win := Gui(, "AHelperW · Havoc · назначение клавиш")
        this.win.SetFont("s10", "Segoe UI")
        this.win.AddText("xm w720", "Охотник на демонов · Истребление (577)")
        this.win.AddText("xm w720", "Выбери способность → нажми сочетание в поле → Назначить → Сохранить.")
        this.list := this.win.AddListView("xm w720 r15 -Multi", ["Способность", "Клавиша", "Примечание", "Spell ID"])
        this.list.OnEvent("ItemSelect", ObjBindMethod(this, "Select"))
        this.label := this.win.AddText("xm w720", "Выбери строку списка")
        this.key := this.win.AddHotkey("xm w240")
        this.key.OnEvent("Change", ObjBindMethod(this, "KeyChanged"))
        this.win.AddButton("x+12 w130", "Назначить").OnEvent("Click", ObjBindMethod(this, "Assign"))
        this.win.AddButton("x+8 w130", "Очистить").OnEvent("Click", ObjBindMethod(this, "Clear"))
        this.win.AddText("xm w720", "Поддерживаются клавиши с Ctrl / Alt / Shift. Пустая клавиша = не назначена.")
        this.status := this.win.AddText("xm w720 r2", "Профиль: " this.path)
        this.win.AddButton("xm w150", "Сохранить профиль").OnEvent("Click", ObjBindMethod(this, "Save"))
        this.win.AddButton("x+10 w150", "Открыть папку").OnEvent("Click", (*) => this.OpenFolder())
        this.win.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.win.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.Refresh()
        this.win.Show()
    }

    Load() {
        if FileExist(this.path) && IniRead(this.path, "profile", "specId", "577") != "577"
            throw Error("Файл профиля предназначен для другого спека: " this.path)
        for item in this.items
            this.bindings[item[1]] := IniRead(this.path, "bindings", String(item[1]), "")
    }

    Refresh() {
        this.loading := true
        this.list.Delete()
        for item in this.items
            this.list.Add(, item[2], this.bindings[item[1]], item[3], item[1])
        for i, width in [285, 100, 240, 75]
            this.list.ModifyCol(i, width)
        if this.selected
            this.list.Modify(this.selected, "Select Focus Vis")
        this.loading := false
    }

    Select(ctrl, row, selected) {
        if !selected || this.loading
            return
        this.selected := row
        this.label.Text := this.items[row][2]
        this.key.Value := this.bindings[this.items[row][1]]
    }

    KeyChanged(*) {
        this.status.Text := "Нажми «Назначить», чтобы применить сочетание к выбранной строке."
    }

    Assign(*) {
        if !this.selected {
            this.status.Text := "Сначала выбери способность."
            return false
        }
        id := this.items[this.selected][1]
        value := this.key.Value
        for item in this.items {
            if item[1] != id && value != "" && StrLower(this.bindings[item[1]]) = StrLower(value) {
                this.status.Text := "Клавиша уже назначена: " item[2] ". Сначала очисти её назначение."
                return false
            }
        }
        this.bindings[id] := value
        this.dirty := true
        this.Refresh()
        this.status.Text := "Назначение изменено. Сохрани профиль."
        return true
    }

    Clear(*) {
        if !this.selected
            return
        this.key.Value := ""
        this.Assign()
    }

    Save(*) {
        ; Do not silently discard a captured but unapplied key.
        if this.selected && this.key.Value != this.bindings[this.items[this.selected][1]] {
            if !this.Assign()
                return
        }
        temp := this.path ".tmp"
        try {
            DirCreate(A_ScriptDir "\profiles")
            ; Preserve metadata/unknown bindings from a future profile version.
            if FileExist(this.path)
                FileCopy(this.path, temp, true)
            else if FileExist(temp)
                FileDelete(temp)
            IniWrite("1", temp, "profile", "schemaVersion")
            IniWrite("577", temp, "profile", "specId")
            IniWrite("Havoc", temp, "profile", "name")
            IniWrite("AHK-v2", temp, "profile", "keyFormat")
            for id, value in this.bindings
                IniWrite(value, temp, "bindings", String(id))
            FileMove(temp, this.path, true)
            this.dirty := false
            this.status.Text := "Сохранено: " this.path
        } catch as err {
            MsgBox("Не удалось сохранить профиль:`n" err.Message, "AHelperW", "Iconx")
        }
    }

    OpenFolder() {
        DirCreate(A_ScriptDir "\profiles")
        Run(A_ScriptDir "\profiles")
    }

    Close(*) {
        pending := this.selected && this.key.Value != this.bindings[this.items[this.selected][1]]
        if this.dirty || pending {
            answer := MsgBox("Сохранить изменения профиля?", "AHelperW", "YesNoCancel")
            if answer = "Cancel"
                return
            if answer = "Yes" {
                this.Save()
                if this.dirty || (this.selected && this.key.Value != this.bindings[this.items[this.selected][1]])
                    return
            }
        }
        ExitApp()
    }
}

editor := HavocBindings()
