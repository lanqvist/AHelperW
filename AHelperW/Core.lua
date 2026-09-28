local ADDON_NAME, ns = ...

local DEFAULTS = {
  locked = true,
  pos = nil,
  dock = "left", -- Existing manual position stays in pos; dock off restores it.
  scale = 1,
  plateAlpha = 0.9,
  palette = "default",
  cdText = false,
  auraTimers = false,
  preview = false,
  context = true,
  compact = false,
  targetMode = "auto",
  stable = true,
  size = 38,
  gap = 4,
  perRow = 8,
  almost = 1.5,
  style = "color",
  minimapAngle = 215,
}

local function InitDB()
  AHelperWDB = AHelperWDB or {}
  for k, v in pairs(DEFAULTS) do
    if AHelperWDB[k] == nil then AHelperWDB[k] = v end
  end
  ns.db = AHelperWDB
end

local function Rebuild()
  -- конфиг AuraContainer'ов в бою запрещён (кнопки forbidden) — откладываем
  if InCombatLockdown() then
    ns.pendingRebuild = true
    return
  end
  ns.pixelMult = ns.PixelMult()
  ns.ExpandArmsHUD()
  local spells, procs, debuffs, specData = ns.GetTrackList()
  local gw, gh = ns.BuildSquares(spells, procs, debuffs, specData and specData.stackLinks)
  ns.gridH = gh
  local rw, rh = ns.Resources.Build(specData)
  ns.Resources.SetShown(true)
  rh = ns.CombatContext.Build(math.max(gw, rw), rh)
  ns.LayoutFrame(gw, gh, rw, rh)
  ns.frame:SetShown(specData ~= nil or #spells > 0 or #procs > 0 or #debuffs > 0)
  ns.RefreshCooldownWidgets()
  ns.Resources.RefreshGCD()
  ns.RefreshTargetContainers()
  ns.RefreshPreview()
end
ns.Rebuild = Rebuild

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    InitDB()
    ns.CreateMainFrame()
    ns.ApplyScale()
    ns.InitMinimapButton()
    Rebuild()

    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("UI_SCALE_CHANGED")
    ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    ev:RegisterEvent("SPELL_UPDATE_CHARGES")
    ev:RegisterEvent("SPELL_UPDATE_USABLE")
    ev:RegisterUnitEvent("UNIT_HEALTH", "player")
    ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    ev:RegisterEvent("RUNE_POWER_UPDATE")

    -- SPELL_UPDATE_COOLDOWN не стреляет при ОКОНЧАНИИ кулдауна —
    -- перекраска в «готово» требует тикера
    C_Timer.NewTicker(0.1, function()
      ns.UpdateSquares()
      ns.Resources.Update()
      ns.CombatContext.Update()
    end)
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD"
      or event == "TRAIT_CONFIG_UPDATED" or event == "SPELLS_CHANGED"
      or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
    Rebuild()
  elseif event == "PLAYER_TARGET_CHANGED" then
    ns.RefreshTargetContainers()
    ns.Resources.Update()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.pendingRebuild then
      ns.pendingRebuild = nil
      Rebuild()
    end
  elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
    ns.RefreshCooldownWidgets()
    ns.Resources.RefreshGCD()
    ns.UpdateSquares()
  elseif event == "SPELL_UPDATE_USABLE" then
    ns.UpdateSquares()
  else
    ns.Resources.Update()
  end
end)
