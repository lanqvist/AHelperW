local _, ns = ...
local window, edit
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
  local screenW, screenH = GetPhysicalScreenSize()
  local scale = region:GetEffectiveScale()
  local sx = screenW / (UIParent:GetWidth() * UIParent:GetEffectiveScale()) * scale
  local sy = screenH / (UIParent:GetHeight() * UIParent:GetEffectiveScale()) * scale
  return { x = math.floor(x * sx + 0.5), y = math.floor(screenH - (bottom + height) * sy + 0.5),
    width = math.floor(width * sx + 0.5), height = math.floor(height * sy + 0.5) }
end

function ns.MakeHUDExport()
  if InCombatLockdown() then return nil, "Экспорт доступен вне боя." end
  local version, build, _, interface = GetBuildInfo()
  local _, spec = ns.GetSpecData()
  if spec ~= 71 then return nil, "Схема APL-экспорта сейчас предназначена для Arms." end
  local _, race = UnitRace("player")
  local configID = ns.ReadValue(C_ClassTalents.GetActiveConfigID)
  local talents = configID and ns.ReadValue(C_Traits.GenerateImportString, configID)
  local screenW, screenH = GetPhysicalScreenSize()
  local layout = ns.HUDLayout()
  local result = {
    schema = "AHelperW.HUD", version = 1, static = true,
    client = { version = version, build = build, interface = interface },
    specID = spec, race = race, talents = talents or "unknown",
    apl = { sourceCommit = "4c7c73621e596419b5bd6faa5d68940a9c640379", assumedBuild = "69933", heroTree = "slayer", talentsVerified = false },
    screen = { width = screenW, height = screenH, origin = "top-left", units = "physical-pixels" },
    display = { palette = ns.db.palette, preview = ns.db.preview, cdText = ns.db.cdText, scale = ns.db.scale, dock = ns.db.dock,
      size = ns.db.size, gap = layout.gap, perRow = layout.perRow, compact = layout.compact, stable = ns.db.stable, colors = ns.Palette(), timerLayout = "split-v1", chargeText = "white-on-black", stateLabelLayout = "bottom-center-v1",
      gcdColors = { ready = {0, 1, 0.53}, cd = {0.65, 0.12, 0.12}, unknown = {0.16, 0.16, 0.16} } },
    squares = Array(), context = {}, contextNumbers = {}, contextSamples = {}, resources = {}, equipment = Array(),
    aliases = { heroic_strike = { spellID = 1269383, displaySpellID = 1464, procID = 1269391, sharesBindingWith = "slam" } },
    unknownInputs = { "target_if:min:target.health.pct across all enemies", "exact movement.distance", "line_of_sight", "future raid events", "unconfigured trinket metadata" },
    manualInputs = { target_time_to_die = "ttd", fight_remains = "fight" },
    targetCounting = { mode = ns.db.targetMode or "auto", method = "visible-hostile-nameplates", referenceSpellID = 12294, estimated = true, unknownIsZero = false },
    notes = "Static geometry/config only. Re-export after moving, scaling, changing preview, equipment, talents or tracked spells. No live combat data. Unknown is never zero/ready."
  }
  for i, sq in ipairs(ns.squares) do
    if sq.spellID and sq:IsShown() then
      local rect = Rect(sq)
      local castIDs = Array()
      if sq.kind == "spell" then
        castIDs[1] = sq.spellID
        local override = C_Spell.GetOverrideSpell and ns.ReadValue(C_Spell.GetOverrideSpell, sq.spellID)
        if type(override) == "number" and override > 0 and override ~= sq.spellID then castIDs[#castIDs + 1] = override end
      end
      result.squares[#result.squares + 1] = { index = i, kind = sq.kind, spellID = sq.spellID, rect = rect, castSpellIDs = castIDs,
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
  result.context.autoAttack = Rect(ns.CombatContext.footer)
  result.castReceipt = { version = 1, rect = Rect(ns.CastReceipt.frame), rows = 4, columns = 56,
    source = "public UNIT_SPELLCAST_SUCCEEDED; matching event does not prove which input caused it" }
  for key, r in pairs(ns.Resources.regions or {}) do result.resources[key] = Rect(r) end
  for slot = 1, 19 do
    local id = ns.ReadValue(GetInventoryItemID, "player", slot)
    if id then
      local link = ns.ReadValue(GetInventoryItemLink, "player", slot)
      local _, useSpell = C_Item.GetItemSpell(id)
      result.equipment[#result.equipment + 1] = { slot = slot, itemID = id, link = link, useSpellID = useSpell,
        itemLevel = link and ns.ReadValue(C_Item.GetDetailedItemLevelInfo, link) or nil,
        aplMetadata = ns.db.trinketMetadata and ns.db.trinketMetadata[id] or nil }
    end
  end
  result.potionID = ns.db.potionID
  local text = JSON(result)
  ns.db.lastHUDExport = text
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
