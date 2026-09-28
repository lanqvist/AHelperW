local _, ns = ...

local R = {}
ns.Resources = R

local row, hpBar, hpText, powerBar, powerText, hybrid, runeRow
local targetRow, targetBar, gcdFrame, gcdCooldown
local rageArea
local runes = {}

local function IsSecretV(v)
  return issecretvalue and issecretvalue(v)
end

local function MakeFlash(parent)
  local flash = parent:CreateTexture(nil, "OVERLAY")
  flash:SetAllPoints()
  flash:SetColorTexture(1, 1, 1, 1)
  flash:SetAlpha(0)
  local ag = flash:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0.8); a:SetToAlpha(0); a:SetDuration(0.22); a:SetSmoothing("OUT")
  return ag
end

local function EnsureBuilt()
  if row then return end
  row = CreateFrame("Frame", nil, ns.frame)

  -- Player HP keeps the validated absolute-number display. Target percentages below
  -- use a native NumericRuleFormatter when supported; Lua never scales a secret.
  hpBar = CreateFrame("StatusBar", nil, row)
  hpBar:SetPoint("LEFT", row, "LEFT", 0, 0)
  hpBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
  hpBar.bg = hpBar:CreateTexture(nil, "BACKGROUND")
  hpBar.bg:SetAllPoints()
  hpBar.bg:SetColorTexture(0.16, 0.16, 0.16, 1)

  hpText = hpBar:CreateFontString(nil, "OVERLAY")
  ns.SetFont(hpText, 26, "OUTLINE")
  hpText:SetPoint("CENTER", hpBar, "CENTER", 0, 0)
  -- Пульс при критическом ХП: мягкий, ≤2 Гц (не строб)
  local ag = hpText:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.55); a:SetDuration(0.5); a:SetSmoothing("IN_OUT")
  hpText.pulse = ag

  -- Мана — большие абсолюты, ей полоса как у ХП; энергия/ярость остаются цифрами
  powerBar = CreateFrame("StatusBar", nil, row)
  powerBar:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  powerBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
  powerBar.bg = powerBar:CreateTexture(nil, "BACKGROUND")
  powerBar.bg:SetAllPoints()
  powerBar.bg:SetColorTexture(0.16, 0.16, 0.16, 1)
  powerBar:Hide()

  powerText = row:CreateFontString(nil, "OVERLAY")
  ns.SetFont(powerText, 24)
  powerText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  rageArea = CreateFrame("Frame", nil, row)
  rageArea:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  -- Гибрид: цифра в квадрате (альтернативные ресурсы)
  hybrid = CreateFrame("Frame", nil, row)
  hybrid:SetPoint("LEFT", hpBar, "RIGHT", 8, 0)
  hybrid.bg = hybrid:CreateTexture(nil, "ARTWORK")
  hybrid.bg:SetAllPoints()
  hybrid.text = hybrid:CreateFontString(nil, "OVERLAY")
  hybrid.text:SetPoint("CENTER")
  hybrid.flashAnim = MakeFlash(hybrid)

  -- Руны ДК: 6 мини-квадратов, каждая руна зелёная/тёмная
  runeRow = CreateFrame("Frame", nil, row)
  runeRow:SetPoint("LEFT", hpBar, "RIGHT", 8, 0)

  -- Дополнительные входы APL Arms: доля здоровья цели и собственный GCD.
  -- Секретный процент передаётся StatusBar напрямую, без чтения в Lua.
  targetRow = CreateFrame("Frame", nil, ns.frame)
  targetBar = CreateFrame("StatusBar", nil, targetRow)
  targetBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
  targetBar:SetMinMaxValues(0, 1)
  targetBar:SetStatusBarColor(1, 0.32, 0.25)
  targetBar.bg = targetBar:CreateTexture(nil, "BACKGROUND")
  targetBar.bg:SetAllPoints()
  targetBar.bg:SetColorTexture(0.16, 0.16, 0.16, 1)
  targetBar.label = targetBar:CreateFontString(nil, "OVERLAY")
  targetBar.label:SetPoint("CENTER")
  ns.SetFont(targetBar.label, 10, "OUTLINE")
  targetBar.label:SetText("ЦЕЛЬ")
  targetBar.percent = targetBar:CreateFontString(nil, "OVERLAY")
  ns.SetFont(targetBar.percent, 10, "OUTLINE")
  targetBar.percent:SetPoint("RIGHT", -2, 0)
  targetBar.label:ClearAllPoints()
  targetBar.label:SetPoint("LEFT", 3, 0)
  targetBar.labels = {}

  for _, fraction in ipairs({ 0.2, 0.35 }) do
    local mark = targetBar:CreateTexture(nil, "OVERLAY")
    mark:SetColorTexture(1, 1, 1, 0.95)
    mark:SetWidth(ns.Round(2))
    targetBar["mark" .. (fraction == 0.2 and "20" or "35")] = mark
    local label = targetRow:CreateFontString(nil, "OVERLAY")
    ns.SetFont(label, 9, "OUTLINE")
    label:SetText(fraction == 0.2 and "20" or "35")
    targetBar.labels[#targetBar.labels + 1] = label
  end

  gcdFrame = CreateFrame("Frame", nil, targetRow)
  gcdFrame.bg = gcdFrame:CreateTexture(nil, "BACKGROUND")
  gcdFrame.bg:SetAllPoints()
  gcdFrame.bg:SetColorTexture(0.16, 0.16, 0.16, 1)
  gcdFrame.label = gcdFrame:CreateFontString(nil, "OVERLAY")
  ns.SetFont(gcdFrame.label, 10, "OUTLINE")
  gcdFrame.label:SetPoint("TOP", 0, -2)
  gcdFrame.label:SetText("GCD")
  gcdCooldown = CreateFrame("Cooldown", nil, gcdFrame, "CooldownFrameTemplate")
  gcdCooldown:SetAllPoints()
  gcdCooldown:SetDrawEdge(false)
  gcdCooldown:SetDrawSwipe(false)
  gcdCooldown:SetDrawBling(false)
  gcdCooldown:SetHideCountdownNumbers(false)
  ns.ConfigureCountdown(gcdCooldown)
  targetRow:Hide()
  R.regions = { playerHealth = hpBar, rage = rageArea, targetHealth = targetBar, targetHealthPercent = targetBar.percent, gcd = gcdFrame }
end

-- Построение под спек. Возвращает w, h строки ресурсов.
function R.Build(specData)
  EnsureBuilt()
  local layout = ns.HUDLayout()
  local _, specID = ns.GetSpecData()
  R.compactArms = layout.compact and specID == 71
  local size = ns.Round(ns.db.size)
  local mini = ns.Round(size * 0.4)
  local miniGap = ns.Round(3)

  hybrid:SetSize(size, size)
  ns.SetFont(hybrid.text, math.floor(size * 0.5))
  hybrid:Hide()
  runeRow:Hide()

  hpBar:SetSize(ns.Round(size * 3.4), ns.Round(size * 0.6))
  ns.SetFont(hpText, math.floor(size * 0.36), "OUTLINE")
  powerBar:SetSize(ns.Round(size * 2.4), ns.Round(size * 0.6))
  rageArea:SetSize(ns.Round(size * 2.4), size)
  rageArea:ClearAllPoints()
  rageArea:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  targetBar.percent:SetWidth(ns.Round(size * 1.5))
  targetBar.percent:SetJustifyH("RIGHT")

  R.secondary = specData and specData.secondary or nil

  hybrid.prev = nil -- иначе после смены спека вспышка «максимум» срабатывает ложно
  R.lastPowerMode = nil -- перепривязать якоря/шрифт ресурса после ребилда

  if R.secondary == "RUNES" then
    runeRow:SetSize(6 * mini + 5 * miniGap, mini)
    for i = 1, 6 do
      local r = runes[i]
      if not r then
        r = runeRow:CreateTexture(nil, "ARTWORK")
        runes[i] = r
      end
      r:SetSize(mini, mini)
      r:ClearAllPoints()
      r:SetPoint("LEFT", runeRow, "LEFT", (i - 1) * (mini + miniGap), 0)
      r:Show()
    end
    runeRow:Show()
  elseif R.secondary then
    hybrid:Show()
  end

  -- Ширина строки: полоса ХП → квадрат/руны ресурса → мана-полоса или цифра
  local gapE = ns.Round(8)
  local secW = 0
  if R.secondary == "RUNES" then
    secW = 6 * mini + 5 * miniGap + gapE
  elseif R.secondary then
    secW = size + gapE
  end
  local h = size
  local w = ns.Round(size * 3.4) + gapE + secW + ns.Round(size * 2.4)
  row:SetSize(w, h)
  row:ClearAllPoints()
  row:SetPoint("TOP", ns.frame, "TOP", 0, -(layout.pad + (ns.gridH or 0) + layout.sectionGap))

  R.showArmsInputs = specID == 71
  gcdCooldown:SetDrawSwipe(not ns.db.stable)
  if R.showArmsInputs then
    local extraGap = ns.Round(5)
    targetRow:SetSize(w, size)
    targetRow:ClearAllPoints()
    targetRow:SetPoint("TOP", row, "BOTTOM", 0, -extraGap)
    targetBar:SetSize(ns.Round(size * 3.4), ns.Round(size * 0.55))
    targetBar:ClearAllPoints()
    targetBar:SetPoint("TOPLEFT", targetRow, "TOPLEFT", 0, -1)
    targetBar.mark20:ClearAllPoints()
    targetBar.mark20:SetPoint("TOP", targetBar, "TOPLEFT", ns.Round(size * 3.4 * 0.2), 0)
    targetBar.mark20:SetPoint("BOTTOM", targetBar, "BOTTOMLEFT", ns.Round(size * 3.4 * 0.2), 0)
    targetBar.mark35:ClearAllPoints()
    targetBar.mark35:SetPoint("TOP", targetBar, "TOPLEFT", ns.Round(size * 3.4 * 0.35), 0)
    targetBar.mark35:SetPoint("BOTTOM", targetBar, "BOTTOMLEFT", ns.Round(size * 3.4 * 0.35), 0)
    for i, fraction in ipairs({ 0.2, 0.35 }) do
      local label = targetBar.labels[i]
      label:ClearAllPoints()
      label:SetPoint("TOP", targetBar, "BOTTOMLEFT", ns.Round(size * 3.4 * fraction), -1)
    end
    gcdFrame:SetSize(size, size)
    gcdFrame:ClearAllPoints()
    gcdFrame:SetPoint("RIGHT", targetRow, "RIGHT", 0, 0)
    targetRow:Show()
    targetBar.label:SetText("ЦЕЛЬ")
    if R.compactArms then
      local compactGap = ns.Round(4)
      local hpW, rageW, targetW = ns.Round(size * 2.4), ns.Round(size * 1.4), ns.Round(size * 2.1)
      w = hpW + rageW + targetW + size + compactGap * 3
      row:SetSize(w, size)
      hpBar:SetWidth(hpW)
      rageArea:SetSize(rageW, size)
      rageArea:ClearAllPoints()
      rageArea:SetPoint("LEFT", row, "LEFT", hpW + compactGap, 0)
      targetRow:ClearAllPoints()
      targetRow:SetPoint("TOPLEFT", row, "TOPLEFT", hpW + rageW + compactGap * 2, 0)
      targetRow:SetSize(targetW + compactGap + size, size)
      targetBar:SetWidth(targetW)
      targetBar.label:SetText("Ц")
      for i, fraction in ipairs({ 0.2, 0.35 }) do
        local mark = targetBar[i == 1 and "mark20" or "mark35"]
        mark:ClearAllPoints()
        mark:SetPoint("BOTTOM", targetBar, "BOTTOMLEFT", ns.Round(targetW * fraction), 0)
        -- The narrower bar puts the 35% marker beneath the percentage's OCR
        -- rectangle. Keep compact markers at the bottom, below the digits.
        mark:SetHeight(ns.Round(3))
        targetBar.labels[i]:ClearAllPoints()
        targetBar.labels[i]:SetPoint("TOP", targetBar, "BOTTOMLEFT", ns.Round(targetW * fraction), -1)
      end
      R.RefreshGCD()
      return w, size
    end
    R.RefreshGCD()
    return w, h + extraGap + size
  end
  targetRow:Hide()
  return w, h
end

function R.RefreshGCD(updateTimer)
  if not gcdCooldown or not R.showArmsInputs then return end
  local ok, cd = pcall(C_Spell.GetSpellCooldown, 61304)
  if ok and cd and cd.isActive then
    gcdFrame.bg:SetColorTexture(0.65, 0.12, 0.12, 1)
    gcdFrame.label:SetTextColor(1, 1, 1)
    if updateTimer ~= false then
      pcall(gcdCooldown.SetCooldown, gcdCooldown, cd.startTime, cd.duration, cd.modRate)
    end
  elseif ok and cd then
    gcdFrame.bg:SetColorTexture(0, 1, 0.53, 1)
    gcdFrame.label:SetTextColor(0, 0, 0)
    if updateTimer ~= false then gcdCooldown:Clear() end
  else
    gcdFrame.bg:SetColorTexture(0.16, 0.16, 0.16, 1)
    gcdFrame.label:SetTextColor(1, 1, 1)
    if updateTimer ~= false then gcdCooldown:Clear() end
  end
end

local healthPercentCurve
local function UpdateTarget()
  if not R.showArmsInputs or not targetBar then return end
  local exists = UnitExists("target")
  targetBar:SetAlpha(exists and 1 or 0.35)
  if exists then
    pcall(targetBar.SetValue, targetBar, UnitHealthPercent("target"))
    local rendered = pcall(function()
      if not healthPercentCurve then
        local curve = C_CurveUtil.CreateCurve()
        curve:AddPoint(0, 0)
        curve:AddPoint(1, 100)
        healthPercentCurve = curve
      end
      -- Scale inside the engine, then format directly into the font string.
      targetBar.percent:SetFormattedText("%.1f%%", UnitHealthPercent("target", true, healthPercentCurve))
    end)
    if not rendered then targetBar.percent:SetText("?") end
  else
    targetBar:SetValue(0)
    targetBar.percent:SetText("—")
  end
end

local function UpdateHealth(pal)
  -- В бою (Secret Values) число выводится «сквозняком», а пороги/цвет недоступны → белый.
  -- TODO: перевести окраску на ColorCurve (C_CurveUtil), когда проверим API в игре.
  -- Шкала бара: максимум читаем вне боя; если секретен — оставляем прежнюю шкалу
  local maxv = UnitHealthMax("player")
  if not IsSecretV(maxv) and type(maxv) == "number" and maxv > 0 then
    hpBar:SetMinMaxValues(0, maxv)
  end
  -- Секреты текут в движковые приёмники без преобразований
  pcall(hpBar.SetValue, hpBar, UnitHealth("player"))
  pcall(hpText.SetText, hpText, UnitHealth("player"))

  -- Пороговая окраска работает только если значения читаемы (на живом 12.1 они
  -- секретны всегда — блок оставлен на случай смягчения политики Blizzard)
  local colored = pcall(function()
    local p = UnitHealth("player") / UnitHealthMax("player") * 100
    if p < 30 then
      hpBar:SetStatusBarColor(pal.hpLow[1], pal.hpLow[2], pal.hpLow[3])
      if not hpText.pulse:IsPlaying() then hpText.pulse:Play() end
    else
      hpText.pulse:Stop()
      if p < 70 then hpBar:SetStatusBarColor(pal.hpMid[1], pal.hpMid[2], pal.hpMid[3])
      else hpBar:SetStatusBarColor(pal.hpBar[1], pal.hpBar[2], pal.hpBar[3]) end
    end
  end)
  if not colored then
    hpText.pulse:Stop()
    hpBar:SetStatusBarColor(pal.hpBar[1], pal.hpBar[2], pal.hpBar[3])
  end
  hpText:SetTextColor(pal.hpHigh[1], pal.hpHigh[2], pal.hpHigh[3])
end

local function UpdatePower(pal)
  local isMana = (UnitPowerType("player") == Enum.PowerType.Mana)

  if R.lastPowerMode ~= isMana then
    R.lastPowerMode = isMana
    powerText:ClearAllPoints()
    if isMana then
      powerBar:Show()
      -- текст на самой полосе, иначе фрейм полосы рисуется поверх и закрывает цифру
      powerText:SetParent(powerBar)
      powerText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)
      ns.SetFont(powerText, math.floor(ns.db.size * 0.36), "OUTLINE")
    else
      powerBar:Hide()
      powerText:SetParent(row)
      powerText:SetPoint("RIGHT", R.compactArms and rageArea or row, "RIGHT", 0, 0)
      ns.SetFont(powerText, math.floor(ns.db.size * 0.63))
    end
  end

  if isMana then
    -- та же схема, что у ХП: шкала по читаемому вне боя максимуму, секреты — в приёмники
    local maxv = UnitPowerMax("player")
    if not IsSecretV(maxv) and type(maxv) == "number" and maxv > 0 then
      powerBar:SetMinMaxValues(0, maxv)
    end
    powerBar:SetStatusBarColor(pal.manaBar[1], pal.manaBar[2], pal.manaBar[3])
    pcall(powerBar.SetValue, powerBar, UnitPower("player"))
    pcall(powerText.SetText, powerText, UnitPower("player"))
  else
    local wrote = pcall(powerText.SetFormattedText, powerText, "%d", UnitPower("player"))
    if not wrote then
      pcall(powerText.SetText, powerText, UnitPower("player"))
    end
  end
  powerText:SetTextColor(pal.power[1], pal.power[2], pal.power[3])
end

local function UpdateSecondary(pal)
  if R.secondary == "RUNES" then
    for i = 1, 6 do
      local _, _, runeReady = GetRuneCooldown(i)
      local c = runeReady and pal.ready or pal.pipOff
      runes[i]:SetColorTexture(c[1], c[2], c[3], 1)
    end
    return
  end
  if not R.secondary then return end

  -- Вторичные ресурсы никогда не секретны — обычная логика разрешена и в бою
  local cur = UnitPower("player", R.secondary) or 0
  local max = UnitPowerMax("player", R.secondary) or 0
  hybrid.text:SetText(cur)
  local bg, tc
  if max > 0 and cur >= max then
    bg, tc = pal.ready, pal.textOnBright
    if not ns.db.stable and hybrid.prev ~= nil and hybrid.prev ~= cur then
      hybrid.flashAnim:Stop(); hybrid.flashAnim:Play()
    end
  elseif cur > 0 then
    bg, tc = pal.pipMid, pal.textOnBright
  else
    bg, tc = pal.pipOff, pal.textOnDark
  end
  hybrid.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
  hybrid.text:SetTextColor(tc[1], tc[2], tc[3])
  hybrid.prev = cur
end

function R.Update()
  if not row or not row:IsVisible() then return end
  local pal = ns.Palette()
  UpdateHealth(pal)
  UpdatePower(pal)
  UpdateSecondary(pal)
  UpdateTarget()
  R.RefreshGCD(false)
end

function R.SetShown(shown)
  if row then row:SetShown(shown) end
  if targetRow then targetRow:SetShown(shown and R.showArmsInputs) end
end
