local _, ns = ...

local function msg(text)
  print("|cff00ff88AHelperW|r: " .. text)
end

SLASH_AHELPERW1 = "/ahw"
SlashCmdList.AHELPERW = function(input)
  local cmd, arg = input:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  arg = (arg or ""):match("^%s*(.-)%s*$"):lower()

  if cmd == "export" then
    ns.ShowHUDExport()
  elseif cmd == "targetprobe" then
    if arg == "start" then ns.TargetProbe.Start()
    elseif arg == "stop" then ns.TargetProbe.Stop()
    elseif arg == "report" then ns.TargetProbe.Report()
    else msg("/ahw targetprobe start|stop|report — диагностика целей на 30 секунд") end
  elseif cmd == "spelldebug" then
    local id = tonumber(arg)
    if not id or id <= 0 or id ~= math.floor(id) then
      msg("/ahw spelldebug ID — состояние способности и доступность API"); return
    end
    ns.PrintSpellDebug(id)
  elseif cmd == "timerdebug" then
    msg("таймеры способностей: " .. (ns.db.cdText and "включены" or "выключены"))
    for _, sq in ipairs(ns.squares) do
      if sq.spellID and sq.kind == "spell" then
        local status = ns.cooldownStatus[sq.spellID] or {}
        print(sq.spellID .. ": " .. (status.path or "не привязан") .. " / " .. (status.status or "?")
          .. (status.error and (" — " .. status.error) or "")
          .. (status.durationError and (" — " .. status.durationError) or ""))
      end
    end
  elseif cmd == "dock" then
    if arg ~= "left" and arg ~= "right" and arg ~= "off" then
      msg("/ahw dock left|right|off — край экрана или сохранённая свободная позиция"); return
    end
    ns.SetDock(arg == "off" and "free" or arg)
    msg("позиция изменена; обнови координаты через /ahw export")
  elseif cmd == "compact" then
    if arg ~= "on" and arg ~= "off" then msg("/ahw compact on|off — компактный / полный вид"); return end
    ns.SetCompact(arg == "on")
  elseif cmd == "context" then
    if arg ~= "on" and arg ~= "off" then msg("/ahw context on|off"); return end
    ns.db.context = arg == "on"
    ns.Rebuild()
  elseif cmd == "stable" then
    if arg ~= "on" and arg ~= "off" then msg("/ahw stable on|off — постоянные цвета без вспышек"); return end
    ns.db.stable = arg == "on"
    for _, sq in ipairs(ns.squares) do sq.flashAnim:Stop() end
    ns.Rebuild()
  elseif cmd == "targets" then
    if arg == "auto" then
      ns.db.targetMode = "auto"; ns.TargetCount.Reset(); ns.CombatContext.Update()
      msg("Автооценка ближайших видимых врагов включена; это не точное количество целей в AoE."); return
    end
    local value = tonumber(arg)
    if arg ~= "unknown" and (not value or value < 1 or value % 1 ~= 0) then
      msg("/ahw targets auto|1|2|3|unknown"); return
    end
    ns.db.targetMode = "manual"
    ns.CombatContext.targets = value and math.min(value, 3) or nil
    ns.CombatContext.Update()
  elseif cmd == "ttd" or cmd == "fight" then
    local value = tonumber(arg)
    if arg ~= "unknown" and (not value or value <= 0 or value > 7200) then
      msg("/ahw " .. cmd .. " <секунды 1–7200>|unknown — ручной прогноз"); return
    end
    ns.CombatContext.SetForecast(cmd, value)
  elseif cmd == "potion" then
    local id = tonumber(arg)
    if not id or id < 0 or id % 1 ~= 0 then msg("/ahw potion <itemID>; 0 — убрать"); return end
    ns.db.potionID = id > 0 and id or nil
    ns.CombatContext.RefreshItems()
    ns.CombatContext.Update()
    msg(id > 0 and ("предмет для слота зелья: " .. id) or "слот зелья очищен")
  elseif cmd == "trinket" then
    local slot, kind, cooldown, duration, stat = arg:match("^(%d)%s+(%a+)%s+(%d+)%s+(%d+)%s*(%a*)$")
    slot, cooldown, duration = tonumber(slot), tonumber(cooldown), tonumber(duration)
    if (slot ~= 1 and slot ~= 2) or (kind ~= "buff" and kind ~= "damage")
        or cooldown <= 0 or cooldown > 3600 or duration > 3600
        or (kind == "buff" and duration <= 0) or (stat ~= "" and stat ~= "strength") then
      msg("/ahw trinket 1|2 buff|damage КД_сек длительность_баффа [strength]")
      return
    end
    local id = ns.ReadValue(GetInventoryItemID, "player", slot + 12)
    if not id then msg("слот тринкета пуст или недоступен"); return end
    ns.db.trinketMetadata = ns.db.trinketMetadata or {}
    ns.db.trinketMetadata[id] = { hasUseBuff = kind == "buff", cooldownDuration = cooldown, buffDuration = duration, strength = stat == "strength", source = "manual" }
    msg("параметры APL сохранены для itemID " .. id .. "; попадут в /ahw export")
  elseif cmd == "preview" then
    if arg ~= "on" and arg ~= "off" then
      msg("/ahw preview on|off — иконки, номера и список квадратов")
      return
    end
    if InCombatLockdown() then
      msg("переключать превью нужно вне боя")
      return
    end
    ns.db.preview = arg == "on"
    ns.ResetProcContainers()
    ns.Rebuild()
    msg("превью: " .. (ns.db.preview and "вкл" or "выкл"))
  elseif cmd == "armsapl" then
    if InCombatLockdown() then
      msg("добавление набора APL доступно вне боя")
      return
    end
    local _, specID = ns.GetSpecData()
    if specID ~= 71 then
      msg("этот набор предназначен для Arms / Slayer, спек 71")
      return
    end
    local _, build = GetBuildInfo()
    if tostring(build) ~= "69933" then
      msg("набор сверялся со сборкой 69933; текущая сборка требует повторной сверки")
      return
    end
    local preset = ns.armsAplPreset
    local custom = ns.EnsureCustom()
    if not custom or not preset then return end
    local count = 0
    local missing = {}
    for _, kind in ipairs({ "spells", "procs", "debuffs" }) do
      local present = {}
      for _, id in ipairs(custom[kind]) do present[id] = true end
      for _, id in ipairs(preset[kind]) do
        if not present[id] then
          if C_Spell.GetSpellInfo(id) then
            table.insert(custom[kind], id)
            present[id] = true
            count = count + 1
          else
            missing[#missing + 1] = tostring(id)
          end
        end
      end
    end
    ns.db.cdText = true
    ns.db.auraTimers = true
    ns.Rebuild()
    ns.ApplyCdTextOption()
    msg("добавлено индикаторов Arms/Slayer: " .. count .. "; таймеры КД и баффов включены")
    msg("набор для присланного билда 69933; активные таланты автоматически не сверяются")
    if #missing > 0 then msg("клиент не знает ID: " .. table.concat(missing, ", ")) end
  elseif cmd == "auratimers" then
    if arg ~= "on" and arg ~= "off" then
      msg("/ahw auratimers on|off — время действия баффов")
      return
    end
    ns.db.auraTimers = arg == "on"
    ns.Rebuild()
    msg("таймеры баффов: " .. (ns.db.auraTimers and "вкл" or "выкл"))
  elseif cmd == "unlock" then
    ns.db.locked = false
    ns.ApplyLock()
    msg("окно разблокировано — перетаскивай мышью")
  elseif cmd == "lock" then
    ns.db.locked = true
    ns.ApplyLock()
    msg("окно закреплено")
  elseif cmd == "scale" then
    local v = tonumber(arg)
    if v and v >= 0.5 and v <= 3 then
      ns.db.scale = v
      ns.ApplyScale()
      msg("масштаб: " .. v)
    else
      msg("масштаб от 0.5 до 3, например: /ahw scale 1.5")
    end
  elseif cmd == "alpha" then
    local v = tonumber(arg)
    if v and v >= 0 and v <= 1 then
      ns.db.plateAlpha = v
      ns.ApplyPlateAlpha()
      msg("прозрачность подложки: " .. v)
    else
      msg("прозрачность от 0 до 1, например: /ahw alpha 0.9")
    end
  elseif cmd == "palette" then
    if ns.palettes[arg] then
      ns.db.palette = arg
      -- прок-контейнеры сконфигурированы старыми цветами — пересоздать
      if ns.ResetProcContainers then ns.ResetProcContainers() end
      ns.Rebuild()
      msg("палитра: " .. arg)
    else
      msg("палитры: default, cvd")
    end
  elseif cmd == "cdtext" then
    ns.db.cdText = (arg == "on")
    ns.ApplyCdTextOption()
    msg("секунды на кулдаунах: " .. (ns.db.cdText and "вкл" or "выкл"))
  elseif cmd == "reset" then
    ns.db.pos = nil
    ns.SetDock("left")
    msg("окно у левого края; обнови координаты через /ahw export")
  elseif cmd == "add" or cmd == "del" or cmd == "addproc" or cmd == "delproc"
      or cmd == "adddebuff" or cmd == "deldebuff" then
    local id = tonumber(arg)
    if not id then
      msg("нужен spellID: /ahw " .. cmd .. " 190319 (ID — в адресе заклинания на wowhead)")
      return
    end
    local c = ns.EnsureCustom()
    if not c then
      msg("спек не определён")
      return
    end
    local list, label
    if cmd == "add" or cmd == "del" then
      list, label = c.spells, "способность"
    elseif cmd == "addproc" or cmd == "delproc" then
      list, label = c.procs, "прок"
    else
      list, label = c.debuffs, "дебафф"
    end
    if cmd:sub(1, 3) == "add" then
      for _, v in ipairs(list) do
        if v == id then
          msg("уже в списке")
          return
        end
      end
      if not C_Spell.GetSpellInfo(id) then
        msg("клиент не знает spellID " .. id)
        return
      end
      table.insert(list, id)
      msg(label .. " добавлен(а): " .. id)
    else
      local removed = false
      for i, v in ipairs(list) do
        if v == id then
          table.remove(list, i)
          removed = true
          break
        end
      end
      if not removed then
        msg("нет в списке: " .. id)
        return
      end
      msg("убрано: " .. id)
    end
    ns.Rebuild()
  elseif cmd == "spells" then
    local spells, procs, debuffs, _, key = ns.GetTrackList()
    local custom = ns.db.custom and key and ns.db.custom[key]
    msg("набор " .. tostring(key) .. (custom and " (свой)" or " (дефолт спека)") .. ":")
    for _, id in ipairs(spells) do
      local info = C_Spell.GetSpellInfo(id)
      print(("  %d — %s"):format(id, info and info.name or "|cffff4040нет в клиенте|r"))
    end
    for _, id in ipairs(procs) do
      local info = C_Spell.GetSpellInfo(id)
      print(("  %d — %s |cffff4fd8(прок)|r"):format(id, info and info.name or "|cffff4040нет в клиенте|r"))
    end
    for _, id in ipairs(debuffs) do
      local info = C_Spell.GetSpellInfo(id)
      print(("  %d — %s |cffa06bff(дебафф)|r"):format(id, info and info.name or "|cffff4040нет в клиенте|r"))
    end
  elseif cmd == "config" then
    ns.Settings.Toggle()
  elseif cmd == "editor" then
    ns.Manager.Toggle()
  elseif cmd == "icons" then
    ns.db.style = (arg == "on") and "mix" or "color"
    ns.ResetProcContainers()
    ns.Rebuild()
    msg("иконки в квадратах: " .. (ns.db.style == "mix" and "вкл" or "выкл"))
  elseif cmd == "procdebug" then
    msg("интринсик AuraContainer: " .. (ns.HasAuraContainer() and "|cff00ff88есть|r" or "|cffff4040НЕТ|r"))
    msg("C_UnitAuras.GetPlayerAuraBySpellID: " ..
      ((C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) and "|cff00ff88есть|r" or "|cffff4040НЕТ|r"))
    local _, procs, debuffs = ns.GetTrackList()
    if #procs == 0 and #debuffs == 0 then
      msg("у спека нет проков/дебаффов в наборе")
      return
    end
    for _, id in ipairs(debuffs) do
      local info = C_Spell.GetSpellInfo(id)
      print(("  %d %s (дебафф на цели) — движок: %s"):format(
        id, info and info.name or "?", tostring(ns.procStatus[id] or "не подключался")))
    end
    for _, id in ipairs(procs) do
      local info = C_Spell.GetSpellInfo(id)
      local aura
      if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, res = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if ok then aura = res end
      end
      local detail = ""
      if aura then
        -- вне рестрикций поля читаемы: диагностика, где лежит число стаков
        pcall(function()
          detail = (" [applications=%s charges=%s]"):format(
            tostring(aura.applications), tostring(aura.charges))
        end)
      end
      print(("  %d %s — движок: %s, аура сейчас: %s%s"):format(
        id,
        info and info.name or "|cffff4040нет в клиенте|r",
        tostring(ns.procStatus[id] or "не подключался"),
        aura and "|cffff4fd8ВИСИТ|r" or "нет",
        detail))
    end
    msg("тест: получи прок ВНЕ боя и повтори /ahw procdebug — «ВИСИТ» подтверждает ID ауры")
  elseif cmd == "procmethods" then
    -- интроспекция реального API AuraContainer в живом клиенте
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, UIParent)
    if not ok or not c then
      msg("не удалось создать AuraContainer: " .. tostring(c))
      return
    end
    c:Hide()
    local found = {}
    local function collect(src, label)
      if type(src) ~= "table" then return end
      for k, v in pairs(src) do
        if type(v) == "function" and type(k) == "string"
          and (k:find("ura") or k:find("Group") or k:find("Unit") or k:find("Filter")
               or k:find("Spell") or k:find("Candidate") or k:find("Frame")) then
          found[k] = label
        end
      end
    end
    local mt = getmetatable(c)
    if mt and type(mt.__index) == "table" then collect(mt.__index, "mt") end
    collect(rawget(_G, "AuraContainerMixin"), "mixin")
    -- прямые пробы вероятных имён (если __index — функция)
    local candidates = { "AddAuraGroup", "AddGroup", "AddAuraFrame", "SetAuraGroup",
      "ConfigureAuraGroup", "CreateAuraGroup", "SetUnit", "SetAuraFilter", "SetFilter",
      "SetCandidateFilters", "SetSpellFilter", "GetAuraGroupFrame", "SetMaxFrameCount",
      "SetInitializeFrameCallback", "SetTemplateNames", "Configure", "SetFilterString" }
    for _, k in ipairs(candidates) do
      local okG, v = pcall(function() return c[k] end)
      if okG and type(v) == "function" and not found[k] then found[k] = "probe" end
    end
    local names = {}
    for k in pairs(found) do names[#names + 1] = k end
    table.sort(names)
    msg("методы AuraContainer, похожие на конфиг (" .. #names .. "):")
    for _, n in ipairs(names) do
      print("  |cff00ff88" .. n .. "|r (" .. found[n] .. ")")
    end
    if rawget(_G, "AuraButtonMixin") then
      local bfound = {}
      for k, v in pairs(AuraButtonMixin) do
        if type(v) == "function" and (k:find("Set") or k:find("Application")) then
          bfound[#bfound + 1] = k
        end
      end
      table.sort(bfound)
      msg("методы AuraButtonMixin: " .. table.concat(bfound, ", "))
    end
  elseif cmd == "procapi" then
    -- спросить встроенную документацию клиента о виджет-API аур
    pcall(function() C_AddOns.LoadAddOn("Blizzard_APIDocumentation") end)
    pcall(function() C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated") end)
    local doc = rawget(_G, "APIDocumentation")
    if not doc then
      msg("APIDocumentation недоступна (нет Blizzard_APIDocumentation)")
      return
    end
    local detailed = arg ~= ""
    local terms = detailed and { arg } or { "AuraContainer", "AuraButton", "AuraGroup", "ApplicationCount" }
    for _, term in ipairs(terms) do
      msg("поиск: " .. term)
      local ok, matches = pcall(function() return doc:FindAllAPIMatches(term) end)
      if ok and matches then
        local shown = 0
        for _, list in pairs(matches) do
          if type(list) == "table" then
            for _, api in ipairs(list) do
              if detailed then
                local okD, lines = pcall(function() return api:GetDetailedOutputLines() end)
                if okD and lines then
                  for _, l in ipairs(lines) do
                    if shown < 120 then print("  " .. l) end
                    shown = shown + 1
                  end
                end
              else
                local okL, line = pcall(function() return api:GetSingleOutputLine() end)
                if okL and line and shown < 40 then
                  print("  " .. line)
                  shown = shown + 1
                end
              end
            end
          end
        end
        if shown == 0 then print("  (ничего)") end
      else
        print("  (поиск не сработал)")
      end
    end
  elseif cmd == "default" then
    local _, _, _, _, key = ns.GetTrackList()
    if key and ns.db.custom then ns.db.custom[key] = nil end
    ns.Rebuild()
    msg("набор спека сброшен к дефолту")
  else
    msg("команды:")
    print("  /ahw unlock — разблокировать и перетащить")
    print("  /ahw lock — закрепить")
    print("  /ahw dock left|right|off — у края / вернуть свободную позицию")
    print("  /ahw scale <0.5-3> — масштаб")
    print("  /ahw alpha <0-1> — прозрачность подложки")
    print("  /ahw palette default|cvd — палитра (cvd — для дальтоников)")
    print("  /ahw cdtext on|off — секунды на кулдаунах (при <10 сек)")
    print("  /ahw auratimers on|off — время действия баффов")
    print("  /ahw armsapl — дополнить набор под Arms/Slayer, сборка 69933")
    print("  /ahw preview on|off — иконки, номера и список квадратов")
    print("  /ahw context on|off — дополнительный контекст Arms")
    print("  /ahw compact on|off — компактный / полный вид; после смены обнови экспорт")
    print("  /ahw stable on|off — постоянные цвета без вспышек (по умолчанию on)")
    print("  /ahw targets 1|2|3|unknown — ручной режим целей")
    print("  /ahw ttd|fight <секунды>|unknown — ручные прогнозы")
    print("  /ahw potion <itemID> — отслеживать выбранное зелье")
    print("  /ahw trinket 1|2 buff|damage КД_сек бафф_сек [strength] — параметры предмета для APL")
    print("  /ahw export — экспорт схемы HUD и текущего профиля вне боя")
    print("  /ahw timerdebug — диагностика привязки таймеров КД")
    print("  /ahw reset — сбросить позицию")
    print("  /ahw spells — показать набор текущего спека")
    print("  /ahw add|del <spellID> — добавить/убрать способность")
    print("  /ahw addproc|delproc <spellID> — добавить/убрать прок (ID ауры)")
    print("  /ahw adddebuff|deldebuff <spellID> — добавить/убрать свой дебафф на цели")
    print("  /ahw config — настройки вида и экспорт; также кнопка у миникарты")
    print("  /ahw editor — ручной редактор наборов для диагностики")
    print("  /ahw icons on|off — иконки внутри квадратов")
    print("  /ahw default — вернуть дефолтный набор спека")
  end
end
