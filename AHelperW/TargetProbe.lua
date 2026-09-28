local _, ns = ...

-- Diagnostic only: retains public answers, never stores or branches on secrets.
-- Does not supply active_enemies to the HUD or reader.
local P = {}
ns.TargetProbe = P
local tokens = {}
local ticker, reportFrame
local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, event, unit)
  if issecretvalue and issecretvalue(unit) then return end
  if type(unit) ~= "string" then return end
  if event == "NAME_PLATE_UNIT_ADDED" then tokens[unit] = true
  else tokens[unit] = nil end
end)

local function query(fn, ...)
  if type(fn) ~= "function" then return "missing" end
  local ok, value = pcall(fn, ...)
  if not ok then return "error" end
  if issecretvalue and issecretvalue(value) then return "secret" end
  if value == nil then return "nil" end
  if value == true then return "yes" end
  if value == false then return "no" end
  return "unexpected"
end

local function unitRow(unit)
  return {
    unit = unit,
    exists = query(UnitExists, unit),
    hostile = query(UnitCanAttack, "player", unit),
    dead = query(UnitIsDeadOrGhost, unit),
    combat = query(UnitAffectingCombat, unit),
    mortalStrike = query(C_Spell and C_Spell.IsSpellInRange, 12294, unit),
    cleave = query(C_Spell and C_Spell.IsSpellInRange, 845, unit),
    target = query(UnitIsUnit, unit, "target"),
  }
end

local function msg(text)
  print("|cff00ff88AHelperW|r: " .. text)
end

local function sample()
  local recording = ns.db.targetProbe
  if not recording or #recording.samples >= 31 then return end
  -- Include slots present before the command, plus event-discovered tokens.
  local candidates = {}
  for i = 1, 40 do candidates["nameplate" .. i] = true end
  for unit in pairs(tokens) do candidates[unit] = true end
  local units = {}
  for unit in pairs(candidates) do units[#units + 1] = unit end
  table.sort(units)
  local snap = {
    seconds = math.floor(GetTime() - recording.startedAt + 0.5),
    playerCombat = query(UnitAffectingCombat, "player"),
    lockdown = query(InCombatLockdown),
    target = unitRow("target"), rows = {}, absent = 0,
    visibleHostile = 0, meleeConfirmed = 0, unresolved = 0,
  }
  for _, unit in ipairs(units) do
    local exists = query(UnitExists, unit)
    if exists == "no" then snap.absent = snap.absent + 1
    else
      local row = unitRow(unit)
      snap.rows[#snap.rows + 1] = row
      if row.exists == "yes" and row.hostile == "yes" and row.dead == "no" then
        snap.visibleHostile = snap.visibleHostile + 1
        if row.mortalStrike == "yes" then snap.meleeConfirmed = snap.meleeConfirmed + 1
        elseif row.mortalStrike ~= "no" then snap.unresolved = snap.unresolved + 1 end
      elseif row.exists ~= "no" and row.hostile ~= "no" and row.dead ~= "yes" then
        snap.unresolved = snap.unresolved + 1
      end
    end
  end
  recording.samples[#recording.samples + 1] = snap
end

function P.Stop()
  if ticker then ticker:Cancel(); ticker = nil end
  local recording = ns.db.targetProbe
  if not recording or recording.finished then return end
  recording.finished = true
  local fighting, maximum, unresolved = 0, 0, 0
  for _, s in ipairs(recording.samples) do
    if s.playerCombat == "yes" then fighting = fighting + 1 end
    maximum = math.max(maximum, s.meleeConfirmed)
    unresolved = math.max(unresolved, s.unresolved)
  end
  msg("Диагностика целей завершена: снимков " .. #recording.samples .. ", в бою " .. fighting
    .. ", максимум подтверждённых ближних неймплейтов " .. maximum
    .. ", максимум неопределённых " .. unresolved .. ". Это не точное число целей в AoE.")
  msg("/ahw targetprobe report — скопировать отчёт; /reload — сохранить его на диск.")
end

function P.Start()
  if ticker then ticker:Cancel(); ticker = nil end
  local version, build = GetBuildInfo()
  ns.db.targetProbe = { version = 1, client = version, build = build,
    startedAt = GetTime(), samples = {}, finished = false }
  sample()
  ticker = C_Timer.NewTicker(1, function()
    sample()
    if #ns.db.targetProbe.samples >= 31 then P.Stop() end
  end)
  msg("Запись целей на 30 секунд. Начни вне боя, атакуй группу манекенов, отойди и вернись.")
end

local function rowText(r)
  return r.unit .. " exists=" .. r.exists .. " hostile=" .. r.hostile .. " dead=" .. r.dead
    .. " combat=" .. r.combat .. " MS=" .. r.mortalStrike .. " Cleave=" .. r.cleave .. " target=" .. r.target
end

function P.Report()
  local recording = ns.db.targetProbe
  if not recording then msg("Сначала /ahw targetprobe start"); return end
  local lines = { "AHelperW TargetProbe v1; client=" .. recording.client .. "; build=" .. recording.build,
    "yes/no=public boolean; nil=no answer; secret=restricted; error=API failure; missing=API unavailable",
    "MS=Mortal Strike range, NOT exact AoE range. Rows describe nameplates, NOT all nearby enemies." }
  for _, s in ipairs(recording.samples) do
    lines[#lines + 1] = "t=" .. s.seconds .. " combat=" .. s.playerCombat .. " lockdown=" .. s.lockdown
      .. " hostile=" .. s.visibleHostile .. " melee=" .. s.meleeConfirmed .. " unresolved=" .. s.unresolved
    lines[#lines + 1] = rowText(s.target)
    for _, row in ipairs(s.rows) do lines[#lines + 1] = rowText(row) end
  end
  if not reportFrame then
    reportFrame = CreateFrame("Frame", "AHelperWTargetProbeReport", UIParent, "BackdropTemplate")
    reportFrame:SetSize(680, 440); reportFrame:SetPoint("CENTER"); reportFrame:SetFrameStrata("DIALOG")
    reportFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    reportFrame:SetBackdropColor(0, 0, 0, 0.95)
    reportFrame:EnableMouse(true)
    local title = reportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -12); title:SetText("Диагностика целей — Ctrl+A, Ctrl+C")
    local close = CreateFrame("Button", nil, reportFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    local scroll = CreateFrame("ScrollFrame", nil, reportFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -38); scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(625); edit:SetHeight(370); edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() reportFrame:Hide() end)
    scroll:SetScrollChild(edit)
    reportFrame.edit = edit
    table.insert(UISpecialFrames, "AHelperWTargetProbeReport")
  end
  reportFrame.edit:SetText(table.concat(lines, "\n"))
  reportFrame:Show(); reportFrame.edit:SetFocus(); reportFrame.edit:HighlightText()
end
