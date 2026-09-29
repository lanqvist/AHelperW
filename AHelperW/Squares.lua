local _, ns = ...

-- Midnight Secret Values: числовые поля кулдаунов в бою секретны (арифметика/сравнения = ошибка Lua).
-- Булевы isActive/isOnGCD/isEnabled — NeverSecret, на них и строим состояние.
local function num(v)
  -- проверка секретности строго ДО любого сравнения: сравнение секрета = Lua-ошибка
  if issecretvalue and issecretvalue(v) then return nil end
  if v == nil then return nil end
  return v
end
ns.SafeNumber = num
local function EffectiveSpell(id)
  return ns.ReadValue(C_Spell.GetOverrideSpell, id) or id
end

local squares = {}
ns.squares = squares

-- Availability states; "engine" renders secret usability flags natively.
-- baseID: the square's own spell; its range proxy also covers an override (Graveyard
-- for Epidemic, Blightfall for Dark Transformation stayed unknown in game).
local function GetSpellState(spellID, baseID)
  local cd = C_Spell.GetSpellCooldown(spellID)
  if not cd then return "unknown" end

  local active = cd.isActive
  if active == nil then
    -- фолбэк для клиентов без isActive: числовая проверка (вне рестрикций)
    local st, du = num(cd.startTime), num(cd.duration)
    if not st or not du then return "unknown" end
    active = du > 0 and (st + du - GetTime()) > 0
  end

  if not active or cd.isOnGCD then
    local hasRange = ns.ReadValue(C_Spell.SpellHasRange, spellID)
    if hasRange == nil then return "unknown" end
    if hasRange then
      local inRange = ns.ReadValue(C_Spell.IsSpellInRange, spellID, "target")
      -- Cleave's frontal area can have a range but no valid unit range check.
      -- A positive Mortal Strike check proves the target is close enough;
      -- a negative/nil check does NOT prove Cleave is out of range.
      -- Same for Frostscythe (cone) and Glacial Advance (line): nil in game, Obliterate's was not.
      local proxy = inRange == nil and (ns.rangeProxies[spellID] or (baseID and ns.rangeProxies[baseID]))
      if proxy then
        local near = proxy == true and ns.MeleeInRange("target") or (proxy ~= true and ns.ReadValue(C_Spell.IsSpellInRange, proxy, "target"))
        if near == true then
          inRange = true
        end
      end
      if inRange == false then return "outofrange" end
      if inRange == nil then return "unknown" end
    end
    -- откачено (или только GCD) — проверяем ресурс
    local okCall, usable, noPower = pcall(C_Spell.IsSpellUsable, spellID)
    if okCall then
      local secretUsable = issecretvalue and issecretvalue(usable)
      local secretPower = issecretvalue and issecretvalue(noPower)
      if (not secretUsable and type(usable) ~= "boolean") or (not secretPower and type(noPower) ~= "boolean") then return "unknown" end
      if secretUsable or secretPower then
        return "engine", usable, noPower
      end
      -- usable/noPower могут быть секретами: ветвление в pcall
      local okBranch, res = pcall(function()
        if noPower then return "nores" end
        if not usable then return "unusable" end
        return "ready"
      end)
      if okBranch then return res end
    end
    return "unknown"
  end

  -- реальный кулдаун; «вот-вот» — только когда числа читаемы (вне боя)
  local st, du = num(cd.startTime), num(cd.duration)
  if st and du and du > 0 then
    local rem = st + du - GetTime()
    if rem > 0 and rem <= ns.db.almost then return "almost" end
  end
  return "cd"
end

function ns.PrintSpellDebug(id)
  local function describe(value)
    if issecretvalue and issecretvalue(value) then return "secret" end
    return tostring(value)
  end
  local function query(label, fn, ...)
    if type(fn) ~= "function" then print(label .. ": missing API"); return end
    local ok, a, b = pcall(fn, ...)
    if not ok then print(label .. ": API error"); return end
    print(label .. ": " .. describe(a) .. ", " .. describe(b))
  end
  local effective = EffectiveSpell(id)
  print("AHelperW spell: " .. id .. " -> " .. effective)
  query("state", GetSpellState, effective)
  query("hasRange", C_Spell.SpellHasRange, effective)
  query("inRange", C_Spell.IsSpellInRange, effective, "target")
  query("melee reference", C_Spell.IsSpellInRange, 12294, "target")
  query("usable / noPower", C_Spell.IsSpellUsable, effective)
end

local function CreateSquare(parent)
  local size = ns.Round(ns.db.size)
  local sq = CreateFrame("Frame", nil, parent)
  sq:SetSize(size, size)

  sq.bg = sq:CreateTexture(nil, "ARTWORK")
  sq.bg:SetAllPoints()
  -- Secret booleans can drive native visibility without a Lua branch.
  sq.usableFill = sq:CreateTexture(nil, "ARTWORK", nil, 1)
  sq.usableFill:SetAllPoints(); sq.usableFill:Hide()
  sq.noPowerFill = sq:CreateTexture(nil, "ARTWORK", nil, 1)
  sq.noPowerFill:SetAllPoints(); sq.noPowerFill:Hide()

  -- режим «цвет + иконка»: полупрозрачная мини-иконка в центре, контраст цвета — главный
  sq.iconTex = sq:CreateTexture(nil, "ARTWORK", nil, 2)
  sq.iconTex:SetAlpha(0.55)
  sq.iconTex:Hide()

  sq.chargePlate = sq:CreateTexture(nil, "ARTWORK", nil, 3)
  sq.chargePlate:SetColorTexture(0, 0, 0, 1)
  sq.chargePlate:SetPoint("BOTTOMRIGHT", 0, 0)
  sq.chargePlate:Hide()
  sq.charges = sq:CreateFontString(nil, "OVERLAY")
  ns.SetFont(sq.charges, math.floor(size * 0.3), "")
  sq.charges:SetPoint("BOTTOMRIGHT", -2, 2)
  sq.stateLabel = sq:CreateFontString(nil, "OVERLAY")
  -- Bottom centre is separate from the timer, charge box and colour sample.
  sq.stateLabel:SetJustifyH("CENTER")
  sq.stateLabel:SetWordWrap(false)

  -- Numbered badge for the optional visual legend. Keep it above the
  -- engine-owned AuraButton; a FontString directly on sq gets covered.
  sq.previewBadge = CreateFrame("Frame", nil, sq)
  sq.previewBadge:SetSize(20, 16)
  sq.previewBadge:SetPoint("TOPLEFT", 0, 0)
  sq.previewBadge:SetFrameLevel(sq:GetFrameLevel() + 5)
  local badgeBg = sq.previewBadge:CreateTexture(nil, "BACKGROUND")
  badgeBg:SetAllPoints()
  badgeBg:SetColorTexture(0, 0, 0, 0.9)
  sq.previewNumber = sq.previewBadge:CreateFontString(nil, "OVERLAY")
  ns.SetFont(sq.previewNumber, 10, "OUTLINE")
  sq.previewNumber:SetPoint("CENTER", 0, 0)
  sq.previewBadge:Hide()

  -- Штатный Cooldown-виджет: единственный санкционированный способ показать секунды в бою
  sq.cool = CreateFrame("Cooldown", nil, sq, "CooldownFrameTemplate")
  sq.cool:SetAllPoints()
  sq.cool:SetDrawSwipe(false)
  sq.cool:SetDrawEdge(false)
  sq.cool:SetDrawBling(false)
  sq.cool:SetHideCountdownNumbers(not ns.db.cdText)
  ns.ConfigureCountdown(sq.cool)
  ns.LayoutSquareCountdown(sq.cool, size)

  sq.flash = sq:CreateTexture(nil, "OVERLAY")
  sq.flash:SetAllPoints()
  sq.flash:SetColorTexture(1, 1, 1, 1)
  sq.flash:SetAlpha(0)
  local ag = sq.flash:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0.8)
  a:SetToAlpha(0)
  a:SetDuration(0.22)
  a:SetSmoothing("OUT")
  sq.flashAnim = ag

  -- Мышь включается только в unlock-режиме: тултип + проброс перетаскивания родителю
  sq:EnableMouse(false)
  sq:RegisterForDrag("LeftButton")
  sq:SetScript("OnDragStart", function()
    if not ns.db.locked then ns.frame:StartMoving() end
  end)
  sq:SetScript("OnDragStop", function()
    ns.frame:StopMovingOrSizing()
    ns.SavePosition(ns.frame)
  end)
  sq:SetScript("OnEnter", function(self)
    if ns.db.locked or not self.spellID then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
    GameTooltip:Show()
  end)
  sq:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return sq
end

function ns.ApplySquareMouse()
  for _, sq in ipairs(squares) do
    sq:EnableMouse(not ns.db.locked)
  end
end

-- Проки. В бою читать ауры НЕЛЬЗЯ (GetPlayerAuraBySpellID → nil при рестрикциях,
-- неотличимо от «бафа нет») — единственный рабочий путь: интринсик AuraContainer
-- с candidateFilters по spellID. Движок сам показывает/прячет кнопку-квадрат
-- и сам рендерит стаки (SetApplicationCount). Конфиг — только вне боя,
-- в бою кнопки forbidden. См. docs/research-api.md.
-- ВАЖНО: блок объявлен ДО BuildSquares — place() зовёт эти локалы.
local procContainers = {} -- [auraSpellID] = AuraContainer
local hasAuraContainer

ns.procStatus = {} -- [auraSpellID] = "engine" | "create-fail" | "config-fail"

local function ProbeAuraContainer()
  if hasAuraContainer == nil then
    local ok, f = pcall(CreateFrame, "AuraContainer", nil, UIParent)
    hasAuraContainer = ok and f ~= nil
    if ok and f then f:Hide() end
  end
  return hasAuraContainer
end
function ns.HasAuraContainer() return ProbeAuraContainer() end

function ns.HideProcContainers()
  for _, e in pairs(procContainers) do
    e.container:Hide()
    e.attached = false
  end
end

-- Контейнеры цели не переоценивают ауры при снятии/смене цели сами (нет событий
-- от «пустого» юнита) — дёргаем их по PLAYER_TARGET_CHANGED
function ns.RefreshTargetContainers()
  local hasTarget = true
  pcall(function() hasTarget = UnitExists("target") and true or false end)
  for _, e in pairs(procContainers) do
    if e.unit == "target" and e.attached then
      if hasTarget then
        e.container:Show()
        pcall(e.container.UpdateAllAuras, e.container)
      else
        e.container:Hide()
      end
    end
  end
end

-- смена палитры: контейнеры сконфигурированы старыми цветами — пересоздать
function ns.ResetProcContainers()
  ns.HideProcContainers()
  wipe(procContainers)
end

-- Реальный API 12.1 (из Blizzard_AuraContainer, wow-ui-source live):
-- контейнер создаётся С ШАБЛОНОМ "CustomAuraContainerTemplate" (у голого интринсика
-- есть только SetUnit), includeSpellIDs — map {[id]=true}, а AddAuraSlot возвращает
-- одиночную кнопку, которую якорим вручную. Кнопка сама показывается/прячется по ауре.
-- unit "player" + HELPFUL|PLAYER — проки; unit "target" + HARMFUL|PLAYER — свои дебаффы
-- на цели (spellID-фильтр для вредных аур на враге разрешён движком).
-- counterOnly: невидимая кнопка, рисующая ТОЛЬКО счётчик стаков связанной ауры
-- в углу квадрата способности (кейс «стаки Вихря клинков как заряды Превосходства»)
local function AttachAuraSlot(sq, spellID, unit, filterStr, color, withDuration, counterOnly)
  -- Duration is part of the cached renderer configuration.
  local key = unit .. spellID .. (counterOnly and "c" or "") .. (withDuration and "t" or "")
  local entry = procContainers[key]
  if not entry then
    local pal = ns.Palette()
    local okC, c = pcall(CreateFrame, "AuraContainer", nil, ns.frame, "CustomAuraContainerTemplate")
    if not okC or not c then
      ns.procStatus[spellID] = "create-fail: " .. tostring(c)
      return false
    end
    local button
    local okSetup, setupErr = pcall(function()
      c:SetUnit(unit)
      button = c:AddAuraSlot("s" .. spellID, filterStr, {
        candidateFilters = { includeSpellIDs = { [spellID] = true } },
        initializeFrame = function(btn)
          local size = ns.Round(ns.db.size)
          btn:SetSize(size, size)
          if counterOnly then
            local fs = btn:CreateFontString(nil, "OVERLAY")
            ns.SetFont(fs, math.floor(size * 0.32), "OUTLINE")
            fs:SetPoint("BOTTOMRIGHT", -2, 2)
            fs:SetTextColor(1, 1, 1)
            local formatter = ns.GetNumberFormatter("stack")
            btn:SetApplicationCount(fs, formatter and { formatter = formatter } or nil)
            return
          end
          local tex = btn:CreateTexture(nil, "BACKGROUND")
          tex:SetAllPoints()
          tex:SetColorTexture(color[1], color[2], color[3], 1)
          local fs = btn:CreateFontString(nil, "OVERLAY")
          ns.SetFont(fs, math.floor(ns.db.size * 0.3))
          fs:SetPoint("BOTTOMRIGHT", -2, 2)
          fs:SetTextColor(pal.textOnBright[1], pal.textOnBright[2], pal.textOnBright[3])
          local formatter = ns.GetNumberFormatter("stack")
          btn:SetApplicationCount(fs, formatter and { formatter = formatter } or nil)
          if ns.db.style == "mix" or ns.db.preview then
            -- движок сам подставит настоящую иконку ауры (роль SetIcon)
            local ic = btn:CreateTexture(nil, "ARTWORK", nil, 2)
            local inset2 = ns.Round(size * 0.2)
            ic:SetPoint("TOPLEFT", inset2, -inset2)
            ic:SetPoint("BOTTOMRIGHT", -inset2, inset2)
            ic:SetAlpha(0.6)
            pcall(btn.SetIcon, btn, ic)
          end
          if withDuration then
            -- отсчёт через Cooldown-виджет: SetDurationText сам якорит текст
            -- (вылезал под квадрат), у виджета цифры всегда по центру
            local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
            cd:SetAllPoints()
            cd:SetDrawSwipe(false)
            cd:SetDrawEdge(false)
            cd:SetDrawBling(false)
            cd:SetHideCountdownNumbers(false)
            ns.ConfigureCountdown(cd)
            ns.LayoutSquareCountdown(cd, size)
            pcall(btn.SetDurationCooldown, btn, cd)
          end
        end,
      })
    end)
    if not okSetup or not button then
      c:Hide()
      ns.procStatus[spellID] = "config-fail: " .. tostring(setupErr)
      return false
    end
    entry = { container = c, button = button, unit = unit }
    procContainers[key] = entry
  end
  entry.attached = true
  ns.procStatus[spellID] = "engine"
  local c = entry.container
  c:ClearAllPoints()
  c:SetAllPoints(sq)
  pcall(c.SetFrameLevel, c, sq:GetFrameLevel() + 2)
  c:Show()
  pcall(function()
    entry.button:ClearAllPoints()
    entry.button:SetPoint("TOPLEFT", sq, "TOPLEFT", 0, 0)
  end)
  return true
end

-- Построение сетки: квадраты способностей + квадраты проков. Возвращает w, h сетки.
function ns.BuildSquares(spells, procs, debuffs, stackLinks)
  for _, sq in ipairs(squares) do
    sq:Hide()
    sq.spellID = nil
    sq.kind = nil
    sq.usableFill:Hide(); sq.noPowerFill:Hide()
    sq.chargePlate:Hide(); sq.charges:Hide()
    sq.stateLabel:SetText("")
    sq.procEngine = nil
  end
  ns.HideProcContainers()

  local layout = ns.HUDLayout()
  local pad = layout.pad
  local gap = layout.gap
  local size = ns.Round(ns.db.size)
  local perRow = layout.perRow

  local pal = ns.Palette()
  local shown = 0
  local function place(spellID, kind)
    -- рантайм-валидация: часть Midnight-ID не подтверждена, неизвестные скрываем;
    -- для проков/дебаффов IsPlayerSpell не проверяем — ID ауры не «известен» персонажу
    local info = C_Spell.GetSpellInfo(spellID)
    local known = true
    if kind == "spell" then
      pcall(function()
        if IsPlayerSpell and not IsPlayerSpell(spellID) then known = false end
      end)
    end
    if not (info and known) then return end
    shown = shown + 1
    local sq = squares[shown]
    if not sq then
      sq = CreateSquare(ns.frame)
      squares[shown] = sq
    end
    sq.spellID = spellID
    sq.kind = kind
    sq.prevState = nil
    -- многозарядность определяем ЗДЕСЬ (Build всегда вне боя, значения читаемы):
    -- в бою maxCharges оказался секретом, сравнивать его там нельзя
    sq.multiCharge = nil
    sq.maxCharges = nil
    sq.stackAuraID = kind == "spell" and stackLinks and stackLinks[spellID] or nil
    sq.chargesUnknownMax = nil
    local profile = ns.GetAPLProfile()
    sq.chargeSpellID = profile and profile.chargeSources and profile.chargeSources[spellID]
    if kind == "spell" then
      local chInfo = C_Spell.GetSpellCharges(spellID)
      if chInfo then
        local maxCharges = num(chInfo.maxCharges)
        sq.maxCharges = maxCharges
        sq.chargesUnknownMax = maxCharges == nil
        sq.multiCharge = maxCharges and maxCharges > 1 or nil
      end
    end
    sq:SetSize(size, size)
    -- Cover the complete exported counter rectangle despite pixel rounding.
    sq.chargePlate:SetSize(ns.Round(size * 0.42), ns.Round(size * 0.34))
    ns.SetFont(sq.charges, math.floor(size * 0.3), "")
    ns.SetFont(sq.stateLabel, math.floor(size * 0.2), "OUTLINE")
    sq.stateLabel:ClearAllPoints()
    sq.stateLabel:SetPoint("BOTTOM", sq, "BOTTOMLEFT", ns.Round(size * 0.44), ns.Round(2))
    sq.stateLabel:SetSize(ns.Round(size * 0.24), ns.Round(size * 0.28))
    ns.LayoutSquareCountdown(sq.cool, size)
    if (ns.db.style == "mix" or ns.db.preview) and info.iconID then
      local inset = ns.Round(size * 0.2)
      sq.iconTex:ClearAllPoints()
      sq.iconTex:SetPoint("TOPLEFT", inset, -inset)
      sq.iconTex:SetPoint("BOTTOMRIGHT", -inset, inset)
      sq.iconTex:SetTexture(info.iconID)
      sq.iconTex:Show()
    else
      sq.iconTex:Hide()
    end
    local col = (shown - 1) % perRow
    local row = math.floor((shown - 1) / perRow)
    sq:ClearAllPoints()
    sq:SetPoint("TOPLEFT", ns.frame, "TOPLEFT",
      pad + col * (size + gap), -(pad + row * (size + gap)))
    sq:Show()
    sq.previewNumber:SetText(shown)
    sq.previewBadge:SetShown(ns.db.preview)
    if kind ~= "spell" and ProbeAuraContainer() then
      if kind == "proc" then
        sq.procEngine = AttachAuraSlot(sq, spellID, "player", ns.externalAuras[spellID] and "HELPFUL" or "HELPFUL|PLAYER", pal.proc, ns.db.auraTimers) or nil
      else
        sq.procEngine = AttachAuraSlot(sq, spellID, "target", "HARMFUL|PLAYER", pal.debuff, true) or nil
      end
    elseif kind == "spell" and not (sq.multiCharge or sq.chargesUnknownMax)
      and stackLinks and stackLinks[spellID] and ProbeAuraContainer() then
      -- стаки связанной ауры в углу квадрата способности (движковый счётчик)
      AttachAuraSlot(sq, stackLinks[spellID], "player", "HELPFUL|PLAYER", nil, false, true)
    end
  end

  for _, id in ipairs(spells or {}) do place(id, "spell") end
  for _, id in ipairs(procs or {}) do place(id, "proc") end
  for _, id in ipairs(debuffs or {}) do place(id, "debuff") end

  ns.ApplySquareMouse()

  if shown == 0 then return 0, 0 end
  local cols = math.min(shown, perRow)
  local rows = math.ceil(shown / perRow)
  return cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap
end

-- Фолбэк, если интринсика нет: прямое чтение (работает только вне рестрикций)
local function GetProcAura(auraID)
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
    if ok then return aura end
  end
  return nil
end

local function UpdateProcSquare(sq, pal)
  if sq.procEngine then
    -- The engine owns visibility and all aura data in combat. Do not query it back.
    sq.bg:SetColorTexture(unpack(pal.procoff))
    sq.charges:Hide()
    sq.stateLabel:SetText("")
    return
  end
  local restricted = ns.ReadValue(C_Secrets and C_Secrets.ShouldAurasBeSecret)
  if restricted ~= false and (restricted == true or InCombatLockdown()) then
    sq.bg:SetColorTexture(unpack(pal.unknown))
    sq.charges:Hide()
    sq.stateLabel:SetText("?")
    return
  end
  if sq.kind == "debuff" then
    -- дебаффы читать нечем даже вне боя (API только для игрока) —
    -- подложка всегда тёмная, состояние рисует движковый AuraButton поверх
    local off = pal.unknown
    sq.bg:SetColorTexture(off[1], off[2], off[3], 1)
    sq.charges:Hide()
    sq.stateLabel:SetText("?")
    return
  end
  -- Прямое чтение работает вне рестрикций — красим подложку сами (проверка ID).
  -- В бою чтение вернёт nil (подложка тёмная), и боевое состояние рисует
  -- движковый AuraButton поверх — если интринсик реально работает.
  local aura = GetProcAura(sq.spellID)
  if issecretvalue and issecretvalue(aura) then
    sq.bg:SetColorTexture(unpack(pal.unknown))
    sq.charges:Hide(); sq.stateLabel:SetText("?")
    return
  end
  sq.stateLabel:SetText("")
  local state = aura and "proc" or "procoff"
  local c = pal[state]
  sq.bg:SetColorTexture(c[1], c[2], c[3], 1)

  if aura then
    -- стаки: >1 показываем; секрет сравнить нельзя — тогда показываем как есть
    local show = true
    local ok = pcall(function() show = aura.applications > 1 end)
    if not ok then show = true end
    if show then
      ns.DisplayNumber(sq.charges, aura.applications, "stack")
      local tc = pal.textOnBright
      sq.charges:SetTextColor(tc[1], tc[2], tc[3])
      sq.charges:Show()
    else
      sq.charges:Hide()
    end
  else
    sq.charges:Hide()
  end

  if not ns.db.stable and state == "proc" and sq.prevState == "procoff" then
    sq.flashAnim:Stop()
    sq.flashAnim:Play()
  end
  sq.prevState = state
end

function ns.UpdateSquares()
  local pal = ns.Palette()
  for _, sq in ipairs(squares) do
    if sq:IsShown() and sq.spellID then
      if sq.kind ~= "spell" then
        UpdateProcSquare(sq, pal)
      else
        local effectiveID = EffectiveSpell(sq.spellID)
        local state, usable, noPower = GetSpellState(effectiveID, sq.spellID)
        if sq.effectiveID ~= effectiveID then
          sq.effectiveID = effectiveID
          local info = C_Spell.GetSpellInfo(effectiveID)
          if info then sq.iconTex:SetTexture(info.iconID) end
        end
        local c = state == "engine" and pal.unusable or (pal[state] or pal.unknown)
        sq.bg:SetColorTexture(c[1], c[2], c[3], 1)
        if state == "engine" then
          sq.usableFill:SetColorTexture(unpack(pal.ready))
          sq.noPowerFill:SetColorTexture(unpack(pal.nores))
          local ok1 = pcall(sq.usableFill.SetShown, sq.usableFill, usable)
          local ok2 = pcall(sq.noPowerFill.SetShown, sq.noPowerFill, noPower)
          if not ok1 or not ok2 then
            sq.usableFill:Hide(); sq.noPowerFill:Hide()
            state = "unknown"
            sq.bg:SetColorTexture(unpack(pal.unknown))
          end
        else
          sq.usableFill:Hide(); sq.noPowerFill:Hide()
        end
        sq.stateLabel:SetText(state == "unknown" and "?" or (state == "unusable" and "×" or (state == "outofrange" and "Д" or "")))

        -- цифра зарядов — только у многозарядных (флаг вычислен при Build вне боя);
        -- у одноразрядных API тоже возвращает таблицу, но «1» там — бессмысленный шум
        local ch = (sq.multiCharge or sq.chargesUnknownMax) and C_Spell.GetSpellCharges(sq.chargeSpellID or effectiveID) or nil
        if ch then
          -- currentCharges может быть секретом — SetText принимает секреты как есть
          pcall(sq.charges.SetText, sq.charges, ch.currentCharges)
          sq.charges:SetTextColor(1, 1, 1)
          sq.chargePlate:Show()
          sq.charges:Show()
        else
          sq.charges:Hide()
          sq.chargePlate:Hide()
        end

        if not ns.db.stable and state == "ready" and sq.prevState and sq.prevState ~= "ready" and sq.prevState ~= "nores" then
          sq.flashAnim:Stop()
          sq.flashAnim:Play()
        end
        sq.prevState = state
      end
    end
  end
end

-- Перепривязка Cooldown-виджетов — только по событию SPELL_UPDATE_COOLDOWN
-- (SetCooldown каждый тик сбрасывал бы отсчёт)
ns.cooldownStatus = {}
local function BindSpellTimer(sq, spellID)
  local charged = sq.multiCharge or sq.chargesUnknownMax
  local getter
  if charged then getter = C_Spell.GetSpellChargeDuration
  else getter = C_Spell.GetSpellCooldownDuration end
  local path = charged and "charge-duration" or "cooldown-duration"
  local durationError
  if type(getter) == "function" and sq.cool.SetCooldownFromDurationObject then
    local ok, duration
    if charged then ok, duration = pcall(getter, spellID)
    else ok, duration = pcall(getter, spellID, true) end -- engine excludes GCD
    if ok and not (issecretvalue and issecretvalue(duration)) then
      if duration == nil then
        pcall(sq.cool.Clear, sq.cool)
        return { path = path, status = "no-duration" }
      end
      local bound, err = pcall(sq.cool.SetCooldownFromDurationObject, sq.cool, duration, true)
      if bound then return { path = path, status = "bound" } end
      durationError = tostring(err)
    elseif not ok then durationError = tostring(duration)
    else durationError = "duration-object-secret" end
  else
    durationError = "duration-api-unavailable"
  end

  -- Compatibility fallback only for readable values, never secret numeric times.
  local ok, info = pcall(charged and C_Spell.GetSpellCharges or C_Spell.GetSpellCooldown, spellID)
  if ok and info then
    if not charged and (info.isActive == false or info.isOnGCD) then
      pcall(sq.cool.Clear, sq.cool)
      return { path = "legacy", status = "clear", durationError = durationError }
    end
    local start, duration, rate
    if charged then
      start, duration, rate = num(info.cooldownStartTime), num(info.cooldownDuration), num(info.chargeModRate)
    else
      start, duration, rate = num(info.startTime), num(info.duration), num(info.modRate)
    end
    if start and duration then
      local bound, err = pcall(sq.cool.SetCooldown, sq.cool, start, duration, rate or 1)
      if bound then return { path = "legacy", status = "bound", durationError = durationError } end
      durationError = durationError .. "; " .. tostring(err)
    end
  end
  pcall(sq.cool.Clear, sq.cool)
  return { path = path, status = "unavailable", error = durationError }
end

function ns.RefreshCooldownWidgets()
  for _, sq in ipairs(squares) do
    if sq:IsShown() and sq.spellID and sq.kind == "spell" then
      local effectiveID = EffectiveSpell(sq.spellID)
      ns.cooldownStatus[sq.spellID] = BindSpellTimer(sq, sq.chargeSpellID or effectiveID)
    end
  end
  ns.db.timerDiagnostics = ns.cooldownStatus
end

function ns.ApplyCdTextOption()
  for _, sq in ipairs(squares) do
    sq.cool:SetHideCountdownNumbers(not ns.db.cdText)
  end
end
