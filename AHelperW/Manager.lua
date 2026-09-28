local _, ns = ...

-- Менеджер наборов: три широкие колонки (способности/проки/дебаффы). В каждой:
-- добавленные строки (drag-n-drop, ✕), разделитель, и кандидаты этого же типа
-- (категории Cooldown Manager + дефолт AHelperW) с «+». Валидация типов и
-- авто-маршрутизация по флагам hasAura/selfAura из C_CooldownViewer.
-- Дроп из книги заклинаний — GetCursorInfo. Конфиг — вне боя.

local M = {}
ns.Manager = M

local COL_W, ROW_H = 298, 26
local COLS = {
  { key = "spells",  title = "Способности", color = { 0, 1, 0.53 },    x = 12 },
  { key = "procs",   title = "Проки",       color = { 1, 0.31, 0.85 }, x = 12 + COL_W + 12 },
  { key = "debuffs", title = "Дебаффы",     color = { 0.63, 0.42, 1 }, x = 12 + (COL_W + 12) * 2 },
}
local WIN_W = 12 + (COL_W + 12) * 3
local WIN_H = 500

local win, columns
local dragData, dragGhost

local function msg(text)
  print("|cff00ff88AHelperW|r: " .. text)
end

-- ---------------------------------------------------------------------------
-- Справочник Cooldown Manager: и мета по spellID, и список записей по категориям
-- ---------------------------------------------------------------------------
local cdmMeta, cdmEntries

local function ScanCDM()
  if cdmMeta then return end
  cdmMeta, cdmEntries = {}, {}
  pcall(function()
    local cats = {
      { Enum.CooldownViewerCategory.Essential,   "spell" },
      { Enum.CooldownViewerCategory.Utility,     "spell" },
      { Enum.CooldownViewerCategory.TrackedBuff, "buff" },
      { Enum.CooldownViewerCategory.TrackedBar,  "buff" },
    }
    local seen = {}
    for _, c in ipairs(cats) do
      local set = C_CooldownViewer.GetCooldownViewerCategorySet(c[1])
      for _, cdID in ipairs(set or {}) do
        local ok, ci = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cdID)
        if ok and ci and ci.spellID then
          local meta = {
            hasAura = ci.hasAura and true or false,
            selfAura = ci.selfAura and true or false,
            cat = c[2],
          }
          if not cdmMeta[ci.spellID] then cdmMeta[ci.spellID] = meta end
          for _, l in ipairs(ci.linkedSpellIDs or {}) do
            if not cdmMeta[l] then cdmMeta[l] = meta end
          end
          if not seen[ci.spellID] then
            seen[ci.spellID] = true
            cdmEntries[#cdmEntries + 1] = { id = ci.spellID, meta = meta }
          end
        end
      end
    end
  end)
end

local function CDMMeta()
  ScanCDM()
  return cdmMeta
end

-- вредное ли заклинание (кастуется во врага): отделяет дебаффы от групповых
-- бафов, которые CDM тоже помечает «не на себе» (напр. Ободряющий клич)
local function IsHarmful(id)
  local h
  pcall(function()
    if C_Spell and C_Spell.IsSpellHarmful then
      h = C_Spell.IsSpellHarmful(id)
    elseif IsHarmfulSpell then
      h = IsHarmfulSpell(id)
    end
  end)
  return h and true or false
end

function M.InvalidateCDM()
  cdmMeta, cdmEntries = nil, nil
end

-- ---------------------------------------------------------------------------
-- Валидация типа + авто-маршрутизация
-- ---------------------------------------------------------------------------
local function ValidateDrop(id, targetKey)
  local info = C_Spell.GetSpellInfo(id)
  if not info then
    return false, "клиент не знает spellID " .. id
  end
  local knows = false
  pcall(function()
    knows = (IsPlayerSpell and IsPlayerSpell(id)) and true or false
  end)
  if targetKey == "spells" then
    if not knows then
      return false, info.name .. " (" .. id .. ") — не способность твоего персонажа; ауры клади в Проки/Дебаффы"
    end
    return true
  end
  local meta = CDMMeta()[id]
  if meta then
    if not meta.hasAura then
      return false, info.name .. " — способность без отслеживаемой ауры; ей место в «Способности»"
    end
    if targetKey == "debuffs" and (meta.selfAura or not IsHarmful(id)) then
      return true, nil, "procs", info.name .. " — аура на себе/группе, кладу в «Проки»"
    elseif targetKey == "procs" and not meta.selfAura and IsHarmful(id) then
      return true, nil, "debuffs", info.name .. " — дот/дебафф на цели, кладу в «Дебаффы»"
    end
  elseif knows then
    msg("внимание: " .. info.name .. " — известная способность; проверь, что это ID ауры")
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Мутации наборов
-- ---------------------------------------------------------------------------
local function RemoveID(list, id)
  for i, v in ipairs(list) do
    if v == id then
      table.remove(list, i)
      return i
    end
  end
end

local function InsertAt(list, id, idx)
  for _, v in ipairs(list) do
    if v == id then return false end
  end
  idx = math.max(1, math.min(idx or (#list + 1), #list + 1))
  table.insert(list, idx, id)
  return true
end

local function AfterChange()
  ns.Rebuild()
  M.Refresh()
end

local function AddValidated(id, targetKey)
  local ok, err, redirect, note = ValidateDrop(id, targetKey)
  if not ok then
    msg("|cffff4040" .. err .. "|r")
    return
  end
  local custom = ns.EnsureCustom()
  if not custom then return end
  if redirect then
    msg(note)
    targetKey = redirect
  end
  if InsertAt(custom[targetKey], id) then
    AfterChange()
  else
    msg("уже в списке")
  end
end

-- ---------------------------------------------------------------------------
-- Drag-n-drop (только добавленные строки)
-- ---------------------------------------------------------------------------
local function EnsureGhost()
  if dragGhost then return end
  dragGhost = CreateFrame("Frame", nil, UIParent)
  dragGhost:SetSize(200, ROW_H)
  dragGhost:SetFrameStrata("TOOLTIP")
  dragGhost.bg = dragGhost:CreateTexture(nil, "BACKGROUND")
  dragGhost.bg:SetAllPoints()
  dragGhost.bg:SetColorTexture(0.1, 0.1, 0.12, 0.9)
  dragGhost.icon = dragGhost:CreateTexture(nil, "ARTWORK")
  dragGhost.icon:SetSize(20, 20)
  dragGhost.icon:SetPoint("LEFT", 3, 0)
  dragGhost.text = dragGhost:CreateFontString(nil, "OVERLAY")
  ns.SetFont(dragGhost.text, 12, "OUTLINE")
  dragGhost.text:SetPoint("LEFT", dragGhost.icon, "RIGHT", 6, 0)
  dragGhost:Hide()
end

local function StartDrag(data)
  EnsureGhost()
  dragData = data
  local info = C_Spell.GetSpellInfo(data.id)
  dragGhost.icon:SetTexture(info and info.iconID or 134400)
  dragGhost.text:SetText(info and info.name or data.id)
  dragGhost:Show()
  dragGhost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s + 14)
  end)
end

-- индекс вставки только среди ДОБАВЛЕННЫХ строк колонки
local function InsertIndexFor(col, count)
  local _, cy = GetCursorPosition()
  cy = cy / UIParent:GetEffectiveScale()
  local last = 0
  for s = 1, #col.rows do
    local row = col.rows[s]
    if row and row:IsShown() and row.itemType == "added" then
      last = row.listIndex
      local mid = (row:GetTop() + row:GetBottom()) / 2
      if cy > mid then return row.listIndex end
    end
  end
  return math.min(count + 1, last + 1)
end

local function HandleDropInto(targetKey, col)
  local data = dragData
  if not data then return end
  local ok, err, redirect, note = ValidateDrop(data.id, targetKey)
  if not ok then
    msg("|cffff4040" .. err .. "|r")
    return
  end
  local custom = ns.EnsureCustom()
  if not custom then return end
  if redirect then
    msg(note)
    targetKey = redirect
  end
  local list = custom[targetKey]
  local idx = redirect and (#list + 1) or InsertIndexFor(col, #list)
  if data.fromKey then
    local oldIdx = RemoveID(custom[data.fromKey], data.id)
    if data.fromKey == targetKey and oldIdx and oldIdx < idx then idx = idx - 1 end
  end
  if not InsertAt(list, data.id, idx) then
    msg("уже в списке")
    if data.fromKey then InsertAt(custom[data.fromKey], data.id) end
  end
  AfterChange()
end

local function StopDrag()
  if dragGhost then
    dragGhost:Hide()
    dragGhost:SetScript("OnUpdate", nil)
  end
  local data = dragData
  if not data then return end
  for _, col in ipairs(columns) do
    if col.frame:IsMouseOver() then
      HandleDropInto(col.key, col)
      dragData = nil
      return
    end
  end
  if data.fromKey then
    local custom = ns.EnsureCustom()
    if custom and RemoveID(custom[data.fromKey], data.id) then
      msg("убрано: " .. data.id)
      AfterChange()
    end
  end
  dragData = nil
end

local function TrySpellCursor(targetKey, col)
  local kind, _, _, spellID = GetCursorInfo()
  if kind == "spell" and spellID then
    ClearCursor()
    dragData = { id = spellID }
    HandleDropInto(targetKey, col)
    dragData = nil
    return true
  end
end

-- ---------------------------------------------------------------------------
-- Кандидаты для колонки: CDM своего типа + дефолт спека, минус уже добавленные
-- ---------------------------------------------------------------------------
local function ColumnCandidates(key, lists)
  ScanCDM()
  local have = {}
  for _, id in ipairs(lists[key] or {}) do have[id] = true end
  local out, seen = {}, {}
  local function push(id)
    if id and not have[id] and not seen[id] and C_Spell.GetSpellInfo(id) then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  for _, e in ipairs(cdmEntries or {}) do
    if key == "spells" then
      if e.meta.cat == "spell" then push(e.id) end
    elseif key == "procs" then
      -- ауры на себе + групповые бафы (CDM помечает их «не на себе», но они не вредные)
      if e.meta.hasAura and (e.meta.selfAura or not IsHarmful(e.id)) then push(e.id) end
    else
      if e.meta.hasAura and not e.meta.selfAura and IsHarmful(e.id) then push(e.id) end
    end
  end
  local _, _, _, data = ns.GetTrackList()
  if data then
    for _, id in ipairs(data[key] or {}) do push(id) end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Строки: itemType = "added" | "cand" | "divider"
-- ---------------------------------------------------------------------------
local function CreateRow(col)
  local r = CreateFrame("Button", nil, col.frame)
  r:SetSize(COL_W - 8, ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 4, 0)
  r.name = r:CreateFontString(nil, "OVERLAY")
  ns.SetFont(r.name, 12)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetPoint("RIGHT", r, "RIGHT", -26, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)

  r.action = CreateFrame("Button", nil, r)
  r.action:SetSize(18, 18)
  r.action:SetPoint("RIGHT", -4, 0)
  r.action.t = r.action:CreateFontString(nil, "OVERLAY")
  ns.SetFont(r.action.t, 13, "OUTLINE")
  r.action.t:SetPoint("CENTER")
  r.action:SetScript("OnEnter", function(self)
    self.t:SetTextColor(1, 1, 1)
  end)
  r.action:SetScript("OnLeave", function(self)
    if r.itemType == "added" then self.t:SetTextColor(0.5, 0.5, 0.55)
    else self.t:SetTextColor(0, 1, 0.53) end
  end)
  r.action:SetScript("OnClick", function()
    if not r.spellID then return end
    if r.itemType == "added" then
      local custom = ns.EnsureCustom()
      if custom and RemoveID(custom[col.key], r.spellID) then AfterChange() end
    elseif r.itemType == "cand" then
      AddValidated(r.spellID, col.key)
    end
  end)

  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", function()
    if r.itemType == "added" then
      StartDrag({ id = r.spellID, fromKey = col.key })
    end
  end)
  r:SetScript("OnDragStop", StopDrag)
  r:SetScript("OnClick", function()
    if r.itemType == "cand" then AddValidated(r.spellID, col.key) end
  end)
  r:SetScript("OnEnter", function(self)
    if not self.spellID then return end
    self.bg:SetColorTexture(0.16, 0.18, 0.21, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(self)
    self.bg:SetColorTexture(unpack(self.baseBg or { 0.11, 0.12, 0.14, 1 }))
    GameTooltip:Hide()
  end)
  r:SetScript("OnReceiveDrag", function() TrySpellCursor(col.key, col) end)
  return r
end

local function FillRow(r, item)
  r.itemType = item.type
  r.spellID = item.id
  r.listIndex = item.index
  if item.type == "divider" then
    r.baseBg = { 0, 0, 0, 0 }
    r.bg:SetColorTexture(0, 0, 0, 0)
    r.icon:SetTexture(nil)
    r.name:SetText("|cff6b7077— доступно для добавления —|r")
    r.action.t:SetText("")
    return
  end
  local info = C_Spell.GetSpellInfo(item.id)
  r.icon:SetTexture(info and info.iconID or 134400)
  if item.type == "added" then
    r.baseBg = { 0.11, 0.12, 0.14, 1 }
    r.name:SetText(info and info.name or ("|cffff4040" .. item.id .. "|r"))
    r.name:SetTextColor(0.91, 0.9, 0.88)
    r.icon:SetDesaturated(false)
    r.action.t:SetText("x")
    r.action.t:SetTextColor(0.5, 0.5, 0.55)
  else
    r.baseBg = { 0.08, 0.085, 0.1, 1 }
    r.name:SetText(info and info.name or tostring(item.id))
    r.name:SetTextColor(0.55, 0.57, 0.6)
    r.icon:SetDesaturated(true)
    r.action.t:SetText("+")
    r.action.t:SetTextColor(0, 1, 0.53)
  end
  r.bg:SetColorTexture(unpack(r.baseBg))
end

-- ---------------------------------------------------------------------------
-- Окно
-- ---------------------------------------------------------------------------
local function BuildWindow()
  win = CreateFrame("Frame", "AHelperWManager", UIParent)
  win:SetSize(WIN_W, WIN_H)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "AHelperWManager")

  win.bg = win:CreateTexture(nil, "BACKGROUND")
  win.bg:SetAllPoints()
  win.bg:SetColorTexture(0.045, 0.05, 0.06, 0.97)

  win.title = win:CreateFontString(nil, "OVERLAY")
  ns.SetFont(win.title, 15, "OUTLINE")
  win.title:SetPoint("TOPLEFT", 12, -10)
  win.title:SetText("|cff00ff88AHelperW|r — наборы текущего спека")

  win.hint = win:CreateFontString(nil, "OVERLAY")
  ns.SetFont(win.hint, 11)
  win.hint:SetPoint("TOPLEFT", 12, -32)
  win.hint:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, -32)
  win.hint:SetJustifyH("LEFT")
  win.hint:SetWordWrap(false)
  win.hint:SetTextColor(0.55, 0.57, 0.6)
  win.hint:SetText("Перетаскивай строки — порядок квадратов · «+» — добавить · «x» — убрать · заклинание из книги бросай в колонку")

  win.close = CreateFrame("Button", nil, win)
  win.close:SetSize(22, 22)
  win.close:SetPoint("TOPRIGHT", -8, -8)
  win.close.t = win.close:CreateFontString(nil, "OVERLAY")
  ns.SetFont(win.close.t, 15, "OUTLINE")
  win.close.t:SetPoint("CENTER")
  win.close.t:SetText("X")
  win.close:SetScript("OnClick", function() win:Hide() end)

  columns = {}
  for i, def in ipairs(COLS) do
    local f = CreateFrame("Frame", nil, win)
    f:SetSize(COL_W, WIN_H - 110)
    f:SetPoint("TOPLEFT", def.x, -52)
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.08, 0.085, 0.1, 1)
    f.header = f:CreateFontString(nil, "OVERLAY")
    ns.SetFont(f.header, 13, "OUTLINE")
    f.header:SetPoint("TOPLEFT", 6, -6)
    f.header:SetText(def.title)
    f.header:SetTextColor(def.color[1], def.color[2], def.color[3])
    f:SetScript("OnReceiveDrag", function() TrySpellCursor(def.key, columns[i]) end)
    f:SetScript("OnMouseUp", function() TrySpellCursor(def.key, columns[i]) end)
    f:SetClipsChildren(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
      columns[i].offset = math.max(0, (columns[i].offset or 0) - delta)
      M.Refresh()
    end)
    f.more = f:CreateFontString(nil, "OVERLAY")
    ns.SetFont(f.more, 11, "OUTLINE")
    f.more:SetPoint("BOTTOM", f, "BOTTOM", 0, 4)
    f.more:SetTextColor(0.55, 0.57, 0.6)
    columns[i] = { key = def.key, frame = f, rows = {}, offset = 0 }
  end

  local reset = CreateFrame("Button", nil, win)
  reset:SetSize(190, 24)
  reset:SetPoint("BOTTOMLEFT", 12, 10)
  reset.bg = reset:CreateTexture(nil, "BACKGROUND")
  reset.bg:SetAllPoints()
  reset.bg:SetColorTexture(0.13, 0.14, 0.17, 1)
  reset.t = reset:CreateFontString(nil, "OVERLAY")
  ns.SetFont(reset.t, 12)
  reset.t:SetPoint("CENTER")
  reset.t:SetText("Сбросить к дефолту спека")
  reset:SetScript("OnClick", function()
    local _, _, _, _, key = ns.GetTrackList()
    if key and ns.db.custom then ns.db.custom[key] = nil end
    AfterChange()
    msg("набор спека сброшен к дефолту")
  end)

  local icons = CreateFrame("Button", nil, win)
  icons:SetSize(210, 24)
  icons:SetPoint("BOTTOMLEFT", 212, 10)
  icons.bg = icons:CreateTexture(nil, "BACKGROUND")
  icons.bg:SetAllPoints()
  icons.bg:SetColorTexture(0.13, 0.14, 0.17, 1)
  icons.t = icons:CreateFontString(nil, "OVERLAY")
  ns.SetFont(icons.t, 12)
  icons.t:SetPoint("CENTER")
  icons:SetScript("OnClick", function()
    ns.db.style = (ns.db.style == "mix") and "color" or "mix"
    ns.ResetProcContainers()
    AfterChange()
  end)
  win.iconsBtn = icons

  local compact = CreateFrame("Button", nil, win)
  compact:SetSize(210, 24)
  compact:SetPoint("BOTTOMLEFT", 432, 10)
  compact.bg = compact:CreateTexture(nil, "BACKGROUND")
  compact.bg:SetAllPoints()
  compact.bg:SetColorTexture(0.13, 0.14, 0.17, 1)
  compact.t = compact:CreateFontString(nil, "OVERLAY")
  ns.SetFont(compact.t, 12)
  compact.t:SetPoint("CENTER")
  compact:SetScript("OnClick", function()
    if ns.SetCompact(not ns.db.compact) then M.Refresh() end
  end)
  win.compactBtn = compact

  win:SetScript("OnShow", function() M.Refresh() end)
end

function M.Refresh()
  if not win or not win:IsShown() then return end
  local lists = {}
  local specKey
  lists.spells, lists.procs, lists.debuffs, _, specKey = ns.GetTrackList()
  if specKey ~= M.lastSpecKey then
    M.lastSpecKey = specKey
    M.InvalidateCDM()
    for _, col in ipairs(columns) do col.offset = 0 end
  end

  for _, col in ipairs(columns) do
    local added = lists[col.key] or {}
    local cands = ColumnCandidates(col.key, lists)

    -- комбинированный список: добавленные, разделитель, кандидаты
    local combined = {}
    for i, id in ipairs(added) do
      combined[#combined + 1] = { type = "added", id = id, index = i }
    end
    if #cands > 0 then
      combined[#combined + 1] = { type = "divider" }
      for _, id in ipairs(cands) do
        combined[#combined + 1] = { type = "cand", id = id }
      end
    end

    local maxVis = math.floor((col.frame:GetHeight() - 44) / (ROW_H + 3))
    col.offset = math.max(0, math.min(col.offset or 0, #combined - maxVis))
    for s = 1, maxVis do
      local item = combined[col.offset + s]
      local r = col.rows[s]
      if item then
        if not r then
          r = CreateRow(col)
          col.rows[s] = r
        end
        FillRow(r, item)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 4, -(26 + (s - 1) * (ROW_H + 3)))
        r:Show()
      elseif r then
        r:Hide()
      end
    end
    for s = maxVis + 1, #col.rows do col.rows[s]:Hide() end

    local below = #combined - col.offset - maxVis
    local parts = {}
    if col.offset > 0 then parts[#parts + 1] = "^ " .. col.offset end
    if below > 0 then parts[#parts + 1] = "v " .. below end
    col.frame.more:SetText(table.concat(parts, "  "))
  end

  win.iconsBtn.t:SetText("Иконки в квадратах: " ..
    (ns.db.style == "mix" and "|cff00ff88вкл|r" or "|cff8b9099выкл|r"))
  win.compactBtn.t:SetText("Вид: " .. (ns.db.compact and "|cff00ff88компактный|r" or "полный"))
end

function M.Toggle()
  if InCombatLockdown() then
    msg("менеджер недоступен в бою")
    return
  end
  if not win then BuildWindow() end
  win:SetShown(not win:IsShown())
end

-- ---------------------------------------------------------------------------
-- Кнопка у миникарты: перетаскивается по ободу, клик открывает настройки.
-- ---------------------------------------------------------------------------
function ns.InitMinimapButton()
  local btn = CreateFrame("Button", "AHelperWMinimapButton", Minimap)
  btn:SetSize(24, 24)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)

  btn.square = btn:CreateTexture(nil, "ARTWORK")
  btn.square:SetSize(12, 12)
  btn.square:SetPoint("CENTER")
  btn.square:SetColorTexture(0, 1, 0.53, 1)
  btn.ring = btn:CreateTexture(nil, "OVERLAY")
  btn.ring:SetAllPoints()
  btn.ring:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
  btn.ring:SetTexCoord(0, 0.6, 0, 0.6)

  local function Position()
    local angle = math.rad(ns.db.minimapAngle or 215)
    local r = Minimap:GetWidth() / 2 + 6
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
  end

  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = UIParent:GetEffectiveScale()
      ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      Position()
    end)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnClick", function() ns.Settings.Toggle() end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("AHelperW")
    GameTooltip:AddLine("Клик — настройки вида и экспорт", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Перетащи — сдвинуть кнопку", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Position()
end
