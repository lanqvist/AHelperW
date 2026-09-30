local _, ns = ...
local window, edit
-- Static item metadata, not a guess from an empty off-hand slot. GetItemInfoInstant
-- returns equipLoc fourth; missing/secret metadata is omitted from the export.
local function EquipLoc(item)
  if not C_Item or type(C_Item.GetItemInfoInstant) ~= "function" then return nil end
  local ok, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, item)
  if not ok or (issecretvalue and issecretvalue(loc)) or type(loc) ~= "string" or loc == "" then return nil end
  return loc
end
local function Array() return setmetatable({}, { __jsonArray = true }) end
local function quote(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return string.format('\\u%04x', string.byte(c))
  end) .. '"'
end
local function JSON(value)
  if issecretvalue and issecretvalue(value) then return 'null' end
  local t = type(value)
  if t == 'nil' then return 'null' end
  if t == 'string' then return quote(value) end
  if t == 'boolean' then return value and 'true' or 'false' end
  if t == 'number' then return tostring(value) end
  if t ~= 'table' then return 'null' end
  local entries = {}
  if #value > 0 or (getmetatable(value) and getmetatable(value).__jsonArray) then
    for _, v in ipairs(value) do entries[#entries + 1] = JSON(v) end
    return '[' .. table.concat(entries, ',') .. ']'
  end
  local keys = {}
  for k in pairs(value) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do entries[#entries + 1] = quote(tostring(k)) .. ':' .. JSON(value[k]) end
  return '{' .. table.concat(entries, ',') .. '}'
end

local function Rect(region, includeHidden)
  if not region or (not includeHidden and not region:IsVisible()) then return nil end
  local x, bottom, width, height = region:GetRect()
  if not x then return nil end
  if issecretvalue and (issecretvalue(x) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height)) then
    -- A region sized by secret content cannot be measured; never do math on it.
    ns.exportSecretRegion = true
    return nil
  end
  local screenW, screenH = GetPhysicalScreenSize()
  local scale = region:GetEffectiveScale()
  local sx = screenW / (UIParent:GetWidth() * UIParent:GetEffectiveScale()) * scale
  local sy = screenH / (UIParent:GetHeight() * UIParent:GetEffectiveScale()) * scale
  return { x = math.floor(x * sx + 0.5), y = math.floor(screenH - (bottom + height) * sy + 0.5),
    width = math.floor(width * sx + 0.5), height = math.floor(height * sy + 0.5) }
end

-- Everything that moves or resizes HUD elements. A stored export whose key
-- differs from the current one describes an older layout.
function ns.HUDLayoutKey()
  local db, pos = ns.db, ns.db.pos or {}
  local w, h = GetPhysicalScreenSize()
  return table.concat({ tostring(db.compact), tostring(db.perRow), tostring(db.size), tostring(db.gap),
    tostring(db.scale), tostring(db.dock), tostring(pos.point), tostring(pos.relPoint), tostring(pos.x), tostring(pos.y),
    tostring(db.style), tostring(db.preview), tostring(db.context), tostring(UIParent:GetEffectiveScale()), w .. "x" .. h }, "|")
end

-- Keep the latest export per specialization. WoW writes SavedVariables on
-- /reload, logout or exit; the reader then picks the newest one up.
function ns.StoreHUDExport(spec, text)
  ns.db.hudExports = ns.db.hudExports or {}
  local key = ns.HUDLayoutKey()
  ns.db.hudExports[spec] = { text = text, at = time(), layout = key }
  for _, item in pairs(ns.db.hudExports) do item.stale = item.layout ~= key or nil end
end

-- Export while the HUD is on screen (a few seconds after a rebuild or layout
-- change); the stored copy reaches disk on /reload or logout. At PLAYER_LOGOUT
-- the UI may already be hidden, so that attempt alone is not enough.
local autoPending, autoTries = false, 0
function ns.ScheduleAutoExport(delay)
  if autoPending or not C_Timer or not C_Timer.After then return end
  autoPending = true
  C_Timer.After(delay or 2, function()
    autoPending = false
    if not ns.db or not ns.GetAPLProfile() then return end
    if InCombatLockdown() then ns.autoExportAfterCombat = true; return end
    local ok, text, err = pcall(ns.MakeHUDExport)
    if not ok then text, err = nil, tostring(text) end
    ns.db.autoExportStatus = { at = time(), ok = text ~= nil, error = err }
    if text then autoTries = 0
    else
      autoTries = autoTries + 1
      if autoTries <= 12 then ns.ScheduleAutoExport(5) end
    end
  end)
end

function ns.MakeHUDExport()
  if InCombatLockdown() then return nil, "Экспорт доступен вне боя." end
  local version, build, _, interface = GetBuildInfo()
  local _, spec = ns.GetSpecData()
  local profile = ns.GetAPLProfile()
  if not profile then return nil, "Для текущей специализации пакет экспорта APL не подключён." end
  ns.exportSecretRegion = nil
  local _, race = UnitRace("player")
  local configID = ns.ReadValue(C_ClassTalents.GetActiveConfigID)
  local talents = configID and ns.ReadValue(C_Traits.GenerateImportString, configID)
  local screenW, screenH = GetPhysicalScreenSize()
  local layout = ns.HUDLayout()
  -- Single-tree profiles keep their static tree; with several trees the export
  -- names the client's active subtree (the reader re-checks it from talents).
  local hero, heroID = ns.GetActiveHeroTree(profile)
  local result = {
    schema = "AHelperW.HUD", version = 1, static = true,
    client = { version = version, build = build, interface = interface },
    specID = spec, race = race, talents = talents or "unknown",
    apl = { profileID = profile.id, sourceCommit = "4c7c73621e596419b5bd6faa5d68940a9c640379", assumedBuild = "69933", heroTree = profile.heroTree or (hero and hero.key), heroTreeID = not profile.heroTree and heroID or nil, talentsVerified = false },
    screen = { width = screenW, height = screenH, origin = "top-left", units = "physical-pixels" },
    display = { palette = ns.db.palette, preview = ns.db.preview, cdText = ns.db.cdText, scale = ns.db.scale, dock = ns.db.dock,
      size = ns.db.size, gap = layout.gap, perRow = layout.perRow, compact = layout.compact, stable = ns.db.stable, colors = ns.Palette(), timerLayout = "split-v1", chargeText = "white-on-black", stateLabelLayout = "bottom-center-v1",
      gcdColors = { ready = {0, 1, 0.53}, cd = {0.65, 0.12, 0.12}, unknown = {0.16, 0.16, 0.16} } },
    squares = Array(), context = {}, contextNumbers = {}, contextSamples = {}, resources = {}, equipment = Array(),
    aliases = profile.aliases, cooldownTelemetry = profile.cooldownTelemetry,
    spellKnowledge = Array(),
    unknownInputs = { "target_if:min:target.health.pct across all enemies", "exact movement.distance", "line_of_sight", "future raid events", "unconfigured trinket metadata" },
    manualInputs = { target_time_to_die = "ttd", fight_remains = "fight" },
    targetCounting = { mode = ns.db.targetMode or "auto", method = "visible-hostile-nameplates", referenceSpellID = profile.referenceSpellID, estimated = true, unknownIsZero = false },
    notes = "Static geometry/config only. Re-export after moving, scaling, changing preview, equipment, talents or tracked spells. No live combat data. Unknown is never zero/ready."
  }
  -- Hidden configured actions remain diagnosable in the static export.
  for _, spellID in ipairs(ns.GetTrackList()) do
    local knowledge = ns.GetSpellKnowledge(spellID, profile)
    knowledge.infoAvailable = C_Spell.GetSpellInfo(spellID) ~= nil
    result.spellKnowledge[#result.spellKnowledge + 1] = knowledge
  end
  for i, sq in ipairs(ns.squares) do
    if sq.spellID and sq:IsShown() then
      local rect = Rect(sq)
      local castIDs = Array()
      if sq.kind == "spell" then
        castIDs[1] = sq.spellID
        local override = C_Spell.GetOverrideSpell and ns.ReadValue(C_Spell.GetOverrideSpell, sq.spellID)
        if type(override) == "number" and override > 0 and override ~= sq.spellID then castIDs[#castIDs + 1] = override end
      end
      local info = C_Spell.GetSpellInfo(sq.spellID)
      result.squares[#result.squares + 1] = { index = i, kind = sq.kind, spellID = sq.spellID, name = info and info.name, rect = rect, castSpellIDs = castIDs,
        charges = sq.chargesUnknownMax and "unknown-max" or sq.multiCharge or false,
        maxCharges = sq.maxCharges, stackAuraID = sq.stackAuraID,
        baseCooldownMs = sq.kind == "spell" and ns.ReadValue(GetSpellBaseCooldown, sq.spellID) or nil,
        colorSample = rect and { x = rect.x + math.max(2, math.floor(rect.width * 0.1)), y = rect.y + math.floor(rect.height * 0.8) },
        timerRegion = rect and { x = rect.x + 2, y = rect.y + math.floor(rect.height * 0.13), width = rect.width - 4, height = math.floor(rect.height * 0.44) },
        stackRegion = rect and { x = rect.x + math.floor(rect.width * 0.6), y = rect.y + math.floor(rect.height * 0.7), width = math.floor(rect.width * 0.4), height = math.floor(rect.height * 0.3) } }
    end
  end
  for key, c in pairs(ns.CombatContext.cells) do
    local rect = Rect(c)
    result.context[key] = rect
    if rect and layout.compact then
      local textHeight = (key == "last" or key == "targetCast" or key == "playerCast") and 17 or 16
      local pixels = math.ceil(textHeight * rect.height / c:GetHeight())
      result.contextNumbers[key] = { x = rect.x, y = rect.y + rect.height - pixels, width = rect.width, height = pixels }
      -- Five-pixel sample fits the bottom padding, away from text and cooldowns.
      result.contextSamples[key] = { x = rect.x + 2, y = rect.y + rect.height - 3 }
    end
  end
  result.context.inputAllowed = Rect(ns.CombatContext.cells.time.inputFlag, true)
  result.context.targetCountStatus = Rect(ns.CombatContext.cells.targets.statusFlag, true)
  result.targetCounting.statusColors = ns.TargetCount.statusColors
  result.context.targetInterrupt = Rect(ns.CombatContext.cells.targetCast.interruptFlag, true)
  result.context.targetGeneration = Rect(ns.CombatContext.cells.ttd.targetFlag, true)
  result.targetGeneration = { version = 1, colors = ns.CombatContext.targetGenerationColors,
    source = "PLAYER_TARGET_CHANGED counter mod 4; none = no target, unknown = unreadable" }
  result.context.autoAttack = Rect(ns.CombatContext.footer)
  result.castReceipt = { version = 2, rect = Rect(ns.CastReceipt.frame), rows = ns.CastReceipt.ROWS, columns = 56,
    source = "public UNIT_SPELLCAST_SUCCEEDED; matching event does not prove which input caused it" }
  if profile.comboHistory then
    result.comboHistory = { version = 1, diagnosticOnly = true, markers = Array(),
      colors = { active = { 0, 1, 0.53 }, inactive = { 0.16, 0.16, 0.16 }, unknown = { 0.48, 0.35, 0 } } }
    for _, marker in ipairs(ns.ComboHistory.markers) do
      result.comboHistory.markers[#result.comboHistory.markers + 1] = {
        action = marker.action, auraID = marker.auraID, configured = marker.configured, rect = Rect(marker.frame) }
    end
  end
  for key, r in pairs(ns.Resources.regions or {}) do result.resources[key] = Rect(r) end
  -- Death Knight runes: one colour sample per rune (display colours ready / cd /
  -- unknown). Written only when every rune square is measurable.
  if ns.Resources.runeTextures then
    local rects, measured = Array(), 0
    for i = 1, 6 do
      local rect = Rect(ns.Resources.runeTextures[i])
      if rect then rects[i], measured = rect, measured + 1 end
    end
    if measured == 6 then
      result.runes = { version = 1, count = 6, rects = rects, source = "GetRuneCooldown isRuneReady",
        states = { ready = "ready", recharging = "cd", unreadable = "unknown" } }
    end
  end
  result.resourceMeta = { [profile.primary] = { powerType = profile.powerType,
    max = ns.ReadValue(UnitPowerMax, "player", profile.powerType) } }
  if profile.secondary then
    result.resourceMeta[profile.secondary] = { powerType = profile.secondaryType,
      max = ns.ReadValue(UnitPowerMax, "player", profile.secondaryType) }
  end
  -- Context cells whose meaning depends on the profile are exported by name.
  for cellKey, cell in pairs(profile.contextCells or {}) do
    if cell.export then
      for _, section in ipairs({ "context", "contextNumbers", "contextSamples" }) do
        result[section][cell.export] = result[section][cellKey]
        result[section][cellKey] = nil
      end
    end
  end
  for slot = 1, 19 do
    local id = ns.ReadValue(GetInventoryItemID, "player", slot)
    if id then
      local link = ns.ReadValue(GetInventoryItemLink, "player", slot)
      local _, useSpell = C_Item.GetItemSpell(id)
      result.equipment[#result.equipment + 1] = { slot = slot, itemID = id, link = link, useSpellID = useSpell,
        equipLoc = EquipLoc(link or id),
        itemLevel = link and ns.ReadValue(C_Item.GetDetailedItemLevelInfo, link) or nil,
        aplMetadata = ns.db.trinketMetadata and ns.db.trinketMetadata[id] or nil }
    end
  end
  result.potionID = ns.db.potionID
  if #result.squares == 0 then
    return nil, "HUD скрыт: нет видимых квадратов для экспорта."
  end
  if ns.exportSecretRegion then
    return nil, "Часть HUD сейчас скрыта клиентом (secret-размеры). Сними цель и повтори экспорт."
  end
  local text = JSON(result)
  ns.db.lastHUDExport = text
  ns.StoreHUDExport(spec, text)
  return text
end

function ns.ShowHUDExport()
  local text, err = ns.MakeHUDExport()
  if not text then print("AHelperW: " .. err); return end
  if not window then
    window = CreateFrame("Frame", "AHelperWExportWindow", UIParent, "BackdropTemplate")
    window:SetSize(660, 430)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]] })
    window:SetBackdropColor(0.03, 0.03, 0.03, 1)
    local title = window:CreateFontString(nil, "OVERLAY")
    ns.SetFont(title, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Экспорт HUD · Ctrl+C — скопировать · Esc — закрыть")
    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -48)
    scroll:SetPoint("BOTTOMRIGHT", -34, 20)
    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetWidth(600)
    edit:SetMaxLetters(0)
    ns.SetFont(edit, 11)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); window:Hide() end)
    scroll:SetScrollChild(edit)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    table.insert(UISpecialFrames, "AHelperWExportWindow")
  end
  window:Show()
  edit:SetText(text)
  edit:SetFocus()
  edit:HighlightText()
end
