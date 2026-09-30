local _, ns = ...
local C = { cells = {}, forecasts = {}, active = false }
ns.CombatContext = C
local frame, started, lastSpell, lastAt
-- Target changes for the reader's health-based TTD: PLAYER_TARGET_CHANGED is
-- public. Four colours cycle per change, so a reader sampling every frame sees
-- each switch; health samples captured before it belong to the old target.
-- No dark entry: a tooltip over the HUD dims every colour to ~18%, and a dark
-- "no target" would then match (white -> 47,47,48); dimmed pixels must be unknown.
local targetGeneration = 0
C.targetGenerationColors = {
  g0 = { 0, 1, 0.53 }, g1 = { 1, 0.15, 0.15 }, g2 = { 0.25, 0.45, 1 }, g3 = { 1, 1, 1 },
  none = { 0.75, 0, 0.75 }, unknown = { 0.48, 0.35, 0 },
}
local dirtyCasts = true
local read = ns.ReadValue
local function secret(v) return issecretvalue and issecretvalue(v) end

-- Additional profile observations; old recharge-only profiles keep their layout.
local function Telemetry(profile)
  local entries = {}
  for _, entry in ipairs(profile.rechargeTelemetry or {}) do entries[#entries + 1] = entry end
  for _, entry in ipairs(profile.cooldownTelemetry or {}) do entries[#entries + 1] = entry end
  return entries
end

local function SetCell(cell, text, state)
  cell.value:SetText(text)
  local p = ns.Palette()
  local color = p[state or "procoff"] or p.procoff
  cell.bg:SetColorTexture(color[1], color[2], color[3], 1)
  local tc = state == "ready" and p.textOnBright or { 1, 1, 1 }
  cell.value:SetTextColor(tc[1], tc[2], tc[3])
end

local function PaintTargetFlag()
  local flag = C.cells.ttd and C.cells.ttd.targetFlag
  if not flag then return end
  local target = read(UnitExists, "target")
  local color = target == true and C.targetGenerationColors["g" .. targetGeneration]
    or target == false and C.targetGenerationColors.none or C.targetGenerationColors.unknown
  flag:SetColorTexture(color[1], color[2], color[3], 1)
end

local function Cell(key, title, tip)
  local c = CreateFrame("Button", nil, frame)
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetAllPoints()
  c.title = c:CreateFontString(nil, "OVERLAY")
  ns.SetFont(c.title, 8, "OUTLINE")
  c.title:SetPoint("TOPLEFT", 3, -2)
  c.title:SetJustifyH("LEFT")
  c.title:SetWordWrap(false)
  c.title:SetText(title)
  c.fullTitle = title
  c.value = c:CreateFontString(nil, "OVERLAY")
  ns.SetFont(c.value, 12, "OUTLINE")
  c.value:SetPoint("BOTTOMLEFT", 3, 3)
  c.value:SetJustifyH("LEFT")
  c.value:SetWordWrap(false)
  c.tip, c.defaultTip = tip, tip
  c:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    if self.itemID then GameTooltip:AddLine("itemID: " .. self.itemID, 1, 1, 1) end
    if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  SetCell(c, "?", "unknown")
  C.cells[key] = c
  return c
end

local function Cooldown(c)
  local cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate")
  cd:SetSize(24, 24)
  cd:SetPoint("BOTTOMRIGHT", -2, 2)
  cd:SetDrawSwipe(false)
  cd:SetDrawEdge(false)
  cd:SetDrawBling(false)
  cd:SetHideCountdownNumbers(false)
  ns.ConfigureCountdown(cd)
  local fs = cd:GetCountdownFontString()
  if fs then ns.SetFont(fs, 11, "OUTLINE") end
  c.cooldown = cd
end

local function EnsureBuilt()
  if frame then return end
  frame = CreateFrame("Frame", nil, ns.frame)
  Cell("targets", "ЦЕЛИ:~АВТО", "Автооценка видимых живых врагов в дистанции Смертельного удара. Не точный радиус AoE; может учитывать соседних неагрессивных врагов. ЛКМ: ручной выбор 1/2/3+. ПКМ: вернуть авто. ? — нет достоверного наблюдения или идёт стабилизация.")
  C.cells.targets.statusFlag = C.cells.targets:CreateTexture(nil, "OVERLAY")
  C.cells.targets.statusFlag:SetSize(9, 9)
  C.cells.targets.statusFlag:SetPoint("TOPRIGHT", -2, -2)
  C.cells.targets:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  C.cells.targets:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.db.targetMode = "auto"; ns.TargetCount.Reset()
    else ns.db.targetMode = "manual"; C.targets = (C.targets or 0) % 3 + 1 end
    C.Update()
  end)
  Cell("time", "БОЙ, С", "Время от входа в бой. После /reload в бою неизвестно.")
  C.cells.time.inputFlag = C.cells.time:CreateTexture(nil, "OVERLAY")
  C.cells.time.inputFlag:SetSize(9, 9)
  C.cells.time.inputFlag:SetPoint("TOPRIGHT", -2, -2)
  Cell("speed", "СКОРОСТЬ", "Текущая скорость, ярдов/с. Не является расстоянием до цели или прогнозом движения.")
  Cell("range", "ДИСТАНЦИЯ", "Доступность цели для Смертельного удара. Ничего не сообщает о линии видимости и направлении взгляда.")
  Cell("haste", "СКОРОСТЬ %", "Текущий процент haste. Базовый GCD Arms = max(0.75, 1.5 / (1 + haste / 100)).")
  Cell("maxrage", "МАКС. ЯРОСТЬ", "Максимум ярости; текущее значение показано выше.")
  Cell("ttd", "TTD: ОЦЕНКА", "Ручной прогноз смерти текущей цели: /ahw ttd 60. Сбрасывается при смене цели. ? — прогноз не задан. Цветной квадрат справа меняет цвет при каждой смене цели (пурпурный — нет цели): по нему ридер оценивает TTD из процента здоровья.")
  C.cells.ttd.targetFlag = C.cells.ttd:CreateTexture(nil, "OVERLAY")
  C.cells.ttd.targetFlag:SetSize(9, 9)
  C.cells.ttd.targetFlag:SetPoint("TOPRIGHT", -2, -2)
  Cell("fight", "БОЙ: ОЦЕНКА", "Ручной прогноз оставшегося времени боя: /ahw fight 120. ? — прогноз не задан.")
  Cell("chargeRange", "РЫВОК", "Попадает ли цель в диапазон Рывка. Это не точное расстояние в ярдах.")
  for _, spec in ipairs({ { "trinket1", "ТРИНКЕТ 1", 13 }, { "trinket2", "ТРИНКЕТ 2", 14 }, { "potion", "ЗЕЛЬЕ" } }) do
    local c = Cell(spec[1], spec[2], "КД активного эффекта. ПАСС. — предмет без эффекта по нажатию. Зелье: /ahw potion itemID; 0 отключает.")
    c.slot = spec[3]
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("CENTER", 0, -3)
    c.icon:SetSize(20, 20)
    c.icon:SetAlpha(0.4)
    Cooldown(c)
  end
  local function AcceptPotion()
    local kind, id = GetCursorInfo()
    if kind == "item" and type(id) == "number" then
      ns.db.potionID = id
      ClearCursor()
      C.RefreshItems()
      C.Update()
    end
  end
  C.cells.potion.tip = "Перетащи зелье из сумки сюда или используй /ahw potion itemID. Отображается КД активного эффекта. /ahw potion 0 очищает слот."
  C.cells.potion:SetScript("OnReceiveDrag", AcceptPotion)
  C.cells.potion:SetScript("OnClick", AcceptPotion)
  Cell("targetCast", "КАСТ ЦЕЛИ", "Название и остаток каста/канала. Красный прямоугольник справа: прерывание запрещено. ? на его месте: неизвестно.")
  Cell("playerCast", "МОЙ КАСТ / КАНАЛ", "Каст или канал игрока; Вихрь клинков дополнительно отображается отдельной аурой.")
  for _, key in ipairs({ "targetCast", "playerCast" }) do
    local c = C.cells[key]
    Cooldown(c)
    c.shield = c:CreateTexture(nil, "OVERLAY")
    c.shield:SetSize(11, 9)
    c.shield:SetPoint("TOPRIGHT", -2, -2)
    c.shield:SetColorTexture(1, 0.15, 0.15, 1)
    c.shield:SetDrawLayer("OVERLAY", 2)
    c.shield:Hide()
    c.interruptFlag = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.interruptFlag:SetAllPoints(c.shield)
    c.interruptFlag:SetColorTexture(0, 1, 0.53, 1)
    c.interruptFlag:Hide()
    c.unknownShield = c:CreateFontString(nil, "OVERLAY")
    ns.SetFont(c.unknownShield, 9)
    c.unknownShield:SetPoint("TOPRIGHT", -2, -1)
    c.unknownShield:SetText("?")
    c.timerUnknown = c:CreateFontString(nil, "OVERLAY")
    ns.SetFont(c.timerUnknown, 11, "OUTLINE")
    c.timerUnknown:SetPoint("BOTTOMRIGHT", -4, 4)
    c.timerUnknown:SetText("?")
    c.timerUnknown:Hide()
  end
  Cell("last", "ПРИМЕНЕНО: ID", "Последний UNIT_SPELLCAST_SUCCEEDED игрока: ID применённой способности. Отправка клавиши сама по себе не является применением.")
  for _, profile in pairs(ns.specProfiles) do
    for _, entry in ipairs(Telemetry(profile)) do
      if not C.cells[entry.key] then
        Cell(entry.key, entry.title, "Нативные данные восстановления, секунды. Числа передаются движку; отсутствующие данные показываются как ?.")
      end
    end
  end
  C.cells.last.age = C.cells.last:CreateFontString(nil, "OVERLAY")
  ns.SetFont(C.cells.last.age, 9, "OUTLINE")
  C.cells.last.age:SetPoint("TOPRIGHT", -3, -2)
  C.footer = frame:CreateFontString(nil, "OVERLAY")
  ns.SetFont(C.footer, 9, "OUTLINE")
  C.footer:SetPoint("BOTTOMLEFT", 0, 0)
  C.footer:SetJustifyH("LEFT")
  C.footer:SetWordWrap(false)
end

function C.Build(width, resourceHeight)
  EnsureBuilt()
  C.profile = ns.GetAPLProfile()
  C.active = C.profile ~= nil and ns.db.context ~= false
  frame:SetShown(C.active)
  if not C.active then return resourceHeight end
  local layout = ns.HUDLayout()
  local gap, size = ns.Round(layout.compact and 2 or 4), ns.Round(ns.db.size)
  local smallH = layout.compact and ns.Round(26) or size
  -- Room for the 8-row cast journal (y 12..24) above the OCR digits: compact
  -- digits use the bottom 17 of 42; the full layout reads the bottom half.
  local lastH = layout.compact and ns.Round(42) or size + ns.Round(10)
  local footerH = ns.Round(layout.compact and 10 or 16)
  local cellW = (width - gap * 5) / 6
  local height = smallH * 2 + lastH + gap * 3 + footerH
  local telemetry = Telemetry(C.profile)
  local telemetryRows = math.ceil(#telemetry / 6)
  height = height + telemetryRows * (smallH + gap)
  frame:ClearAllPoints()
  frame:SetPoint("TOP", ns.frame, "TOP", 0, -(layout.pad + layout.sectionGap + ns.gridH + resourceHeight + gap))
  frame:SetSize(width, height)
  local order = { "targets", "time", "speed", "range", "haste", "maxrage", "ttd", "fight", "chargeRange", "trinket1", "trinket2", "potion", "targetCast", "playerCast", "last" }
  local shortTitles = { targets = "ЦЕЛИ", time = "БОЙ", speed = "СКОР.", range = "РАДИУС", haste = "HASTE", maxrage = "MAX ЯР.",
    ttd = "TTD", fight = "ОСТ.", chargeRange = "РЫВОК", trinket1 = "АКС. 1", trinket2 = "АКС. 2", potion = "ЗЕЛЬЕ",
    targetCast = "КАСТ ЦЕЛИ", playerCast = "МОЙ КАСТ", last = "ПРИМЕНЕНО" }
  for i, key in ipairs(order) do
    local c = C.cells[key]
    local rowIndex = i <= 12 and math.floor((i - 1) / 6) or 2
    local col = i <= 12 and (i - 1) % 6 or (i - 13) * 2
    local w = i <= 12 and cellW or cellW * 2 + gap
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (cellW + gap), -rowIndex * (smallH + gap))
    c:SetSize(w, i <= 12 and smallH or lastH)
    c.title:SetText(layout.compact and shortTitles[key] or c.fullTitle)
    local profileCell = (C.profile.contextCells or {})[key]
    if profileCell and profileCell.title then c.title:SetText(profileCell.title) end
    if profileCell and profileCell.tip then c.tip, c.profileTip = profileCell.tip, true
    elseif c.profileTip then c.tip, c.profileTip = c.defaultTip, nil end
    ns.SetFont(c.title, layout.compact and 7 or 8, "OUTLINE")
    c.title:SetWidth(w - 6 - ((key == "targets" or key == "ttd") and 11 or 0))
    c.value:ClearAllPoints()
    c.value:SetPoint("BOTTOMLEFT", layout.compact and 2 or 3, 3)
    c.value:SetWidth(w - (c.cooldown and 28 or (layout.compact and 4 or 6)))
    if c.cooldown and i <= 12 then c.value:SetWidth(w - (layout.compact and 4 or 6)) end
    -- Five decimal characters (100.0) must fit without inspecting secret text.
    if i <= 12 then
      -- Compact has shorter labels, but keeps the full-layout numeric font.
      local fullWidth = ((ns.db.perRow * size + (ns.db.perRow - 1) * ns.Round(ns.db.gap)) - ns.Round(4) * 5) / 6
      ns.SetFont(c.value, math.min(11, math.floor(((layout.compact and fullWidth or w) - 6) / 3.2)), "OUTLINE")
    end
    if c.icon then c.icon:SetShown(not layout.compact) end
  end
  for _, profile in pairs(ns.specProfiles) do
    for _, entry in ipairs(Telemetry(profile)) do C.cells[entry.key]:Hide() end
  end
  for i, entry in ipairs(telemetry) do
    local c = C.cells[entry.key]
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", ((i - 1) % 6) * (cellW + gap),
      -(smallH * 2 + lastH + gap * 3 + math.floor((i - 1) / 6) * (smallH + gap)))
    c:SetSize(cellW, smallH)
    c.title:SetWidth(cellW - 6)
    c.value:SetWidth(cellW - 6)
    ns.SetFont(c.value, 11, "OUTLINE")
    c:Show()
  end
  ns.ComboHistory.Build(frame, cellW * 5 + gap * 4, smallH, C.profile.comboHistory == true)
  if C.profile.comboHistory then
    ns.ComboHistory.frame:ClearAllPoints()
    ns.ComboHistory.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", cellW + gap,
      -(smallH * 2 + lastH + gap * 3))
  end
  C.footer:SetWidth(width)
  ns.SetFont(C.footer, layout.compact and 7 or 9, "OUTLINE")
  ns.CastReceipt.Build(C.cells.last, C.cells.last:GetWidth())
  C.footer:SetText("ЦЕЛИ: автооценка · ? неизвестно · TTD/БОЙ — ручной прогноз")
  dirtyCasts = true
  C.RefreshItems()
  C.Update()
  return resourceHeight + gap + height
end

function C.RefreshItems()
  if not frame or not C.active then return end
  for _, key in ipairs({ "trinket1", "trinket2", "potion" }) do
    local c = C.cells[key]
    if c.slot then c.itemID = read(GetInventoryItemID, "player", c.slot)
    else c.itemID = ns.db.potionID end
    c.start, c.duration, c.enabled, c.loaded, c.useSpell = nil, nil, nil, nil, nil
    c.cooldown:Clear()
    c.icon:Hide()
    if c.itemID then
      c.loaded = read(C_Item.IsItemDataCachedByID, c.itemID)
      if not c.loaded then pcall(C_Item.RequestLoadItemDataByID, c.itemID) end
      local ok, _, spell = pcall(C_Item.GetItemSpell, c.itemID)
      if ok and not secret(spell) then c.useSpell = spell end
      local texture = read(C_Item.GetItemIconByID, c.itemID)
      if texture then c.icon:SetTexture(texture); c.icon:SetShown(not ns.db.compact) end
      local okCD, start, duration, enabled
      if c.slot then okCD, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", c.slot)
      else okCD, start, duration, enabled = pcall(C_Item.GetItemCooldown, c.itemID) end
      if okCD then
        pcall(c.cooldown.SetCooldown, c.cooldown, start, duration)
        if not secret(start) then c.start = start end
        if not secret(duration) then c.duration = duration end
        if not secret(enabled) then c.enabled = enabled end
      end
    end
  end
end

local function UpdateItem(c, key)
  if not c.itemID then SetCell(c, key == "potion" and (ns.db.compact and "ВЫБ." or "ВЫБЕРИ") or "ПУСТО"); return end
  if not c.loaded then SetCell(c, "?", "unknown"); return end
  if not c.useSpell then SetCell(c, "ПАСС."); return end
  if key == "potion" then
    local count = read(C_Item.GetItemCount, c.itemID)
    if count == 0 then SetCell(c, "НЕТ"); return end
    if count == nil then SetCell(c, "?", "unknown"); return end
  end
  if c.enabled == false or c.enabled == 0 then SetCell(c, "БЛОК", "unusable"); return end
  if c.start == nil or c.duration == nil or c.enabled == nil then SetCell(c, "?", "unknown"); return end
  if c.duration > 0 and c.start + c.duration > GetTime() then SetCell(c, "", "cd")
  else SetCell(c, "ГОТОВ", "ready") end
end

local function UpdateCast(c, unit)
  local ok, name, _, _, _, _, _, _, noInterrupt, _, id = pcall(UnitCastingInfo, unit)
  local channel = false
  if ok and not secret(name) and name == nil then
    ok, name, _, _, _, _, _, noInterrupt, _, _, _, id = pcall(UnitChannelInfo, unit)
    channel = true
  end
  if not ok then
    c.interruptFlag:Hide()
    SetCell(c, "?", "unknown"); c.cooldown:Clear()
    c.shield:Hide(); c.unknownShield:Show(); c.timerUnknown:Show()
    return
  end
  local empty = not secret(name) and name == nil
  if empty then
    c.interruptFlag:Hide()
    SetCell(c, "—")
    c.shield:Hide(); c.unknownShield:Hide(); c.timerUnknown:Hide(); c.cooldown:Clear(); c.castID = nil
    return
  end
  SetCell(c, "", "nores")
  c.interruptFlag:Show()
  c.interruptFlag:SetColorTexture(0, 1, 0.53, 1)
  if not pcall(c.value.SetText, c.value, name) then c.value:SetText("?") end
  if not secret(noInterrupt) and noInterrupt == nil then
    c.interruptFlag:SetColorTexture(0.48, 0.35, 0, 1)
    c.shield:Hide(); c.unknownShield:Show()
  else
    c.unknownShield:Hide()
    pcall(c.shield.SetShown, c.shield, noInterrupt)
  end
  if secret(id) then id = nil end
  if dirtyCasts or id ~= c.castID or channel ~= c.channel then
    c.castID, c.channel = id, channel
    local getDuration = channel and UnitChannelDuration or UnitCastingDuration
    local okDuration = pcall(function() c.cooldown:SetCooldownFromDurationObject(getDuration(unit)) end)
    c.timerUnknown:SetShown(not okDuration)
    if not okDuration then c.cooldown:Clear() end
  end
end

-- Seconds until the next rune is ready. Rune values are computed only when the
-- client exposes them as plain numbers; any secret or partial answer is "?".
local function UpdateRuneNext(cell)
  local best, pending = nil, false
  for i = 1, 6 do
    local ok, start, duration, ready = pcall(GetRuneCooldown, i)
    if not ok or secret(start) or secret(duration) or secret(ready) then SetCell(cell, "?", "unknown"); return end
    if ready == false then
      pending = true
      if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0 then
        local left = start + duration - GetTime()
        if left > 0 and (not best or left < best) then best = left end
      end
    elseif ready ~= true then SetCell(cell, "?", "unknown"); return end
  end
  if not pending then SetCell(cell, "—")
  elseif best then SetCell(cell, string.format("%.1f", best), "nores")
  else SetCell(cell, "?", "unknown") end
end

local function Number(cell, fn, kind, ...)
  SetCell(cell, "?", "unknown")
  local ok, value = pcall(fn, ...)
  if ok and (secret(value) or value ~= nil) then
    SetCell(cell, "")
    ns.DisplayNumber(cell.value, value, kind)
  end
end

local function BaseCooldown(cell, entry)
  SetCell(cell, "?", "unknown")
  local ok, info = pcall(C_Spell.GetSpellCooldown, entry.spellID)
  if not ok or secret(info) or type(info) ~= "table" then return end
  if secret(info.isActive) or secret(info.isOnGCD) then return end
  if info.isActive == false or info.isOnGCD == true then
    SetCell(cell, "0", "ready")
    return
  end
  if info.isActive ~= true or type(C_Spell.GetSpellCooldownDuration) ~= "function" then return end
  local got, duration = pcall(C_Spell.GetSpellCooldownDuration, entry.spellID, true)
  if not got or secret(duration) or not duration then return end
  -- GetRemainingDuration can return a secret; it goes straight to the renderer.
  local rendered = pcall(function()
    local remaining = duration:GetRemainingDuration()
    SetCell(cell, "", "cd")
    if not ns.DisplayNumber(cell.value, remaining, "decimal") then error("renderer unavailable") end
  end)
  if not rendered then SetCell(cell, "?", "unknown") end
end

function C.Update()
  if not C.active or not frame:IsVisible() then return end
  local autoTargets = ns.db.targetMode ~= "manual"
  local targets = C.targets
  if autoTargets then targets = ns.TargetCount.Update() end
  local targetStatus = autoTargets and (ns.TargetCount.reason or "waiting") or "manual"
  C.cells.targets.statusFlag:SetColorTexture(unpack(ns.TargetCount.statusColors[targetStatus] or ns.TargetCount.statusColors.waiting))
  C.cells.targets.title:SetText(ns.db.compact and (autoTargets and "Ц:АВТ" or "Ц:РУЧ") or (autoTargets and "ЦЕЛИ:~АВТО" or "ЦЕЛИ:РУЧН."))
  local lower = autoTargets and not targets and targetStatus == "stabilizing" and ns.TargetCount.lower
  -- "N+" while stabilizing is a lower bound, kept in the unknown colour so it
  -- is never read as an exact count; the reader needs the stabilizing flag.
  local text = targets and (not autoTargets and targets == 3 and "3+" or tostring(targets))
    or (lower and lower >= 2 and (lower .. "+")) or "?"
  SetCell(C.cells.targets, text, targets and "nores" or "unknown")
  local fighting = read(UnitAffectingCombat, "player")
  SetCell(C.cells.time, started and string.format("%.1f", GetTime() - started) or (fighting and "?" or "0"), fighting and "nores" or "procoff")
  local inputOK, focus = pcall(function() return GetCurrentKeyBoardFocus() end)
  local playerDead = read(UnitIsDeadOrGhost, "player")
  local menuOpen = GameMenuFrame and GameMenuFrame:IsShown()
  if not inputOK or secret(focus) or playerDead == nil then
    C.cells.time.inputFlag:SetColorTexture(0.48, 0.35, 0, 1)
  elseif focus or menuOpen or playerDead then
    C.cells.time.inputFlag:SetColorTexture(1, 0.15, 0.15, 1)
  else
    C.cells.time.inputFlag:SetColorTexture(0, 1, 0.53, 1)
  end
  Number(C.cells.speed, GetUnitSpeed, "decimal", "player")
  Number(C.cells.haste, UnitSpellHaste, "decimal", "player")
  Number(C.cells.maxrage, UnitPowerMax, "integer", "player", C.profile.powerType)
  for _, entry in ipairs(C.profile.rechargeTelemetry or {}) do
    Number(C.cells[entry.key], function()
      local charges = C_Spell.GetSpellCharges(entry.spellID)
      if charges then return charges.cooldownDuration end
    end, "decimal")
  end
  for _, entry in ipairs(C.profile.cooldownTelemetry or {}) do
    BaseCooldown(C.cells[entry.key], entry)
  end
  local target = read(UnitExists, "target")
  local attack = read(UnitCanAttack, "player", "target")
  local dead = read(UnitIsDeadOrGhost, "target")
  local rangeEntries = { { "range", C.profile.referenceSpellID } }
  local aux = (C.profile.contextCells or {}).chargeRange or {}
  if aux.source == "range" then rangeEntries[#rangeEntries + 1] = { "chargeRange", aux.spellID }
  elseif aux.source == "powerRegen" then
    Number(C.cells.chargeRange, function() local _, active = GetPowerRegen(); return active end, "decimal")
  elseif aux.source == "runeNext" then UpdateRuneNext(C.cells.chargeRange)
  else SetCell(C.cells.chargeRange, "—") end
  for _, entry in ipairs(rangeEntries) do
    local value
    if entry[1] == "range" then value = ns.MeleeInRange("target", C.profile)
    else value = read(C_Spell.IsSpellInRange, entry[2], "target") end
    if target == false then SetCell(C.cells[entry[1]], "НЕТ ЦЕЛИ")
    elseif dead == true or attack == false then SetCell(C.cells[entry[1]], "НЕЛЬЗЯ", "unusable")
    elseif target == nil or attack == nil or dead == nil then SetCell(C.cells[entry[1]], "?", "unknown")
    elseif value == true then SetCell(C.cells[entry[1]], "ДА", "ready")
    elseif value == false then SetCell(C.cells[entry[1]], "ВНЕ", "cd")
    else SetCell(C.cells[entry[1]], "?", "unknown") end
  end
  PaintTargetFlag()
  for _, key in ipairs({ "ttd", "fight" }) do
    local estimate = C.forecasts[key]
    local remaining = estimate and (estimate.deadline and estimate.deadline - GetTime() or estimate.seconds)
    -- Expired forecasts become unknown, not a permanent execute/end-of-fight signal.
    if remaining and remaining <= 0 then C.forecasts[key] = nil; remaining = nil end
    SetCell(C.cells[key], remaining and ("~" .. math.ceil(remaining)) or "?", remaining and "nores" or "unknown")
  end
  for _, key in ipairs({ "trinket1", "trinket2", "potion" }) do UpdateItem(C.cells[key], key) end
  UpdateCast(C.cells.targetCast, "target")
  UpdateCast(C.cells.playerCast, "player")
  dirtyCasts = false
  if lastAt then
    SetCell(C.cells.last, "")
    ns.DisplayNumber(C.cells.last.value, lastSpell)
  C.cells.last.age:SetFormattedText("%.1fс", GetTime() - lastAt)
  else SetCell(C.cells.last, "—"); C.cells.last.age:SetText("") end
  local auto = read(C_Spell.IsCurrentSpell, 6603)
  if ns.db.compact then
    C.footer:SetText("АА: " .. (auto == nil and "?" or (auto and "ДА" or "НЕТ")) .. (autoTargets and " · ЦЕЛИ ≈" or " · ЦЕЛИ РУЧ.") .. " · TTD: ПРОГНОЗ")
  else
    C.footer:SetText("АВТОАТАКА: " .. (auto == nil and "?" or (auto and "ДА" or "НЕТ")) .. (autoTargets and " · ЦЕЛИ ≈ ближние" or " · ЦЕЛИ вручную") .. " · TTD/БОЙ — прогноз")
  end
end

function C.SetForecast(key, seconds)
  C.forecasts[key] = seconds and { seconds = seconds, deadline = read(UnitAffectingCombat, "player") and GetTime() + seconds or nil } or nil
  C.Update()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "SPELL_UPDATE_COOLDOWN" }) do events:RegisterEvent(event) end
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do events:RegisterUnitEvent(event, "player", "target") end
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "PLAYER_REGEN_DISABLED" then
    started = GetTime()
    for _, v in pairs(C.forecasts) do v.deadline = started + v.seconds end
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
    started, lastAt, lastSpell, C.targets = nil, nil, nil, nil
    wipe(C.forecasts)
    if event == "PLAYER_ENTERING_WORLD" then targetGeneration = (targetGeneration + 1) % 4; PaintTargetFlag() end
  elseif event == "PLAYER_TARGET_CHANGED" then
    C.forecasts.ttd = nil
    dirtyCasts = true
    targetGeneration = (targetGeneration + 1) % 4
    PaintTargetFlag()
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    lastSpell, lastAt = spellID, GetTime()
  elseif event:find("^UNIT_SPELLCAST") then
    dirtyCasts = true
  elseif ns.db then
    C.RefreshItems()
  end
end)
