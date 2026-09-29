-- Behavioral checks in a Lua VM. UI mocks do not validate WoW secure rendering.
unpack = table.unpack or unpack
-- run.cjs sets SPEC_ID (and HERO_ID, the client's active hero subtree) per VM;
-- Arms (71) remains the default. Power types come from the spec profile.
local specID = SPEC_ID or 71
local heroID = HERO_ID
local now, combat, target = 100, false, true
local forbidden = { secret = true }
function issecretvalue(v) return type(v) == "table" and rawget(v, "secret") == true end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function GetTime() return now end
time = os.time
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
function UnitExists() return target end
function UnitCanAttack() return target end
function UnitIsDeadOrGhost() return false end
function GetUnitSpeed() return 0 end
function UnitSpellHaste() return 20 end
function UnitPowerMax() return 130 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetBuildInfo() return "12.1.0", "69933", "", 120100 end
function UnitRace() return "Night Elf", "NightElf" end
local classes = { [71] = "WARRIOR", [72] = "WARRIOR", [269] = "MONK", [251] = "DEATHKNIGHT", [252] = "DEATHKNIGHT" }
function UnitClass() return "Class", classes[specID] end
function GetPowerRegen() return 10, 12.5 end
-- Rune i: ready flag; recharging runes end at now + 8 + i (queued runes later).
local runeSecret = false
function GetRuneCooldown(i)
  if runeSecret then return forbidden, forbidden, forbidden end
  if i <= 2 then return 0, 0, true end
  return now - 2 + (i - 3) * 10, 10 + i - 3, false
end
function IsPlayerSpell() return true end
Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, Runes = 5, RunicPower = 6, Chi = 12 }, NumericRuleFormatRounding = { Nearest = 0 } }
UISpecialFrames = {}
C_SpecializationInfo = { GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return specID end }
C_ClassTalents = { GetActiveConfigID = function() return 1 end, GetActiveHeroTalentSpec = function() return heroID end }
C_Traits = { GenerateImportString = function() return "test-build" end }
local frames = {}
local methods = {}
local function noop() end
local function Frame(kind, parent)
  local f = { kind = kind, parent = parent, shown = true, scripts = {}, width = 40, height = 40 }
  setmetatable(f, { __index = function(_, k) return methods[k] or (k:match("^[A-Z]") and noop or nil) end })
  frames[#frames + 1] = f
  return f
end
function CreateFrame(kind, name, parent)
  if kind == "AuraContainer" then error("Mock intentionally omits secure aura engine") end
  return Frame(kind, parent)
end
function methods:CreateTexture() return Frame("Texture", self) end
function methods:CreateFontString() return Frame("FontString", self) end
function methods:CreateAnimationGroup() return Frame("AnimationGroup", self) end
function methods:CreateAnimation() return Frame("Animation", self) end
function methods:GetCountdownFontString() return Frame("FontString", self) end
function methods:SetText(v) self.text = v end
function methods:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetEffectiveScale() return 1 end
function methods:GetRect() return 10, 20, self.width, self.height end
function methods:GetFrameLevel() return 1 end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:SetCooldown(...) self.cooldownArgs = {...} end
function methods:SetCooldownFromDurationObject(v) assert(v, "missing duration"); self.durationObject = v end
function methods:Clear() self.cooldownArgs, self.durationObject = nil, nil end
function methods:SetColorTexture(...) self.color = {...} end
UIParent = Frame("Frame"); UIParent:SetSize(1920, 1080)
local ns = { db = { size = 38, gap = 4, perRow = 8, palette = "default", almost = 1.5 }, gridH = 120,
  Round = function(v) return v end, SetFont = noop, frame = Frame("Frame", UIParent), Resources = { regions = {} } }
local function loadAddon(name) assert(loadfile("AHelperW/" .. name .. ".lua"))("AHelperW", ns) end
loadAddon("Display"); loadAddon("Palette"); loadAddon("ClassData"); loadAddon("SpecProfiles"); loadAddon("Layout")
C_StringUtil = nil -- Native formatter absence must not break the addon.
local usable, noPower = true, false
local cd = { isActive = false, isOnGCD = false, startTime = 0, duration = 0 }
local charges, override
C_Spell = {
  GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = 1 } end,
  GetSpellCooldown = function() return cd end,
  IsSpellUsable = function() return usable, noPower end,
  GetSpellCharges = function() return charges end,
  GetOverrideSpell = function(id) return override or id end,
  IsSpellInRange = function() return target and true or nil end,
  SpellHasRange = function() return false end,
  IsCurrentSpell = function() return true end,
}
loadAddon("Squares")
ns.BuildSquares({1464}, {}, {})
ns.UpdateSquares()
assert(ns.squares[1].prevState == "ready")
C_Spell.SpellHasRange = function() return true end
target = false; ns.UpdateSquares(); assert(ns.squares[1].prevState == "unknown", "missing target/range must not be green")
target = true
local savedRangeAPI = C_Spell.IsSpellInRange
C_Spell.IsSpellInRange = function() return false end
ns.UpdateSquares(); assert(ns.squares[1].prevState == "outofrange")
C_Spell.IsSpellInRange = savedRangeAPI
C_Spell.SpellHasRange = function() return false end
usable = false; ns.UpdateSquares(); assert(ns.squares[1].prevState == "unusable", "unusable must not be green")
usable = forbidden; ns.UpdateSquares(); assert(ns.squares[1].prevState == "engine", "secret usability must render via native visibility")
assert(ns.squares[1].usableFill.shown == forbidden)
noPower = nil; ns.UpdateSquares(); assert(ns.squares[1].prevState == "unknown", "partial API result must not imply availability")
noPower = false
usable = true; noPower = true; ns.UpdateSquares(); assert(ns.squares[1].prevState == "nores")
noPower = false; cd = nil; ns.UpdateSquares(); assert(ns.squares[1].prevState == "unknown")
cd = { isActive = true, isOnGCD = true, startTime = 100, duration = 1.5 }
ns.UpdateSquares(); assert(ns.squares[1].prevState == "ready", "GCD is tracked separately")
override = 1269383; ns.UpdateSquares(); assert(ns.squares[1].effectiveID == 1269383)
charges = { maxCharges = 2, currentCharges = 1, cooldownStartTime = 99, cooldownDuration = 12, chargeModRate = 1 }
ns.BuildSquares({7384}, {}, {}); ns.RefreshCooldownWidgets()
assert(ns.squares[1].cool.cooldownArgs[2] == 12, "charge recharge must drive the timer")
charges.maxCharges = forbidden
ns.BuildSquares({7384}, {}, {}); ns.UpdateSquares()
assert(ns.squares[1].chargesUnknownMax and ns.squares[1].charges.text == 1, "unknown charge maximum must not hide available charges")
ns.db.custom = { [specID] = { spells = { 999 }, procs = {}, debuffs = {} } }
ns.ExpandArmsHUD()
assert(ns.db.custom[specID].spells[1] == 999, "migration must retain custom order")
if specID == 71 then
  local found = {}; for _, id in ipairs(ns.db.custom[71].spells) do found[id] = true end
  assert(found[100] and found[6552], "missing Arms actions")
  local count = #ns.db.custom[71].spells; ns.ExpandArmsHUD(); assert(#ns.db.custom[71].spells == count)
else
  assert(#ns.db.custom[specID].spells == 1 and ns.db.armsHudVersion == nil, "Arms migration must not touch other specs")
end

local itemIDs, enabled = {}, 1
function GetInventoryItemID(_, slot) return itemIDs[slot] end
function GetInventoryItemLink(_, slot) return itemIDs[slot] and "item:test" end
function GetInventoryItemCooldown() return 0, 0, enabled end
C_Item = { IsItemDataCachedByID = function() return true end, RequestLoadItemDataByID = noop,
  GetItemSpell = function() return "Use", 123 end, GetItemIconByID = function() return 1 end,
  GetItemCooldown = function() return 0, 0, true end, GetItemCount = function() return 1 end }
local casting, channeling
function UnitCastingInfo(unit)
  if casting == unit then return "Cast", "Cast", 1, 100, 200, false, "guid", forbidden, 123, 7 end
end
function UnitChannelInfo(unit)
  if channeling == unit then return "Channel", "Channel", 1, 100, 200, false, true, 456, false, 0, 8 end
end
function UnitCastingDuration() return forbidden end
function UnitChannelDuration() return forbidden end
loadAddon("TargetCount"); loadAddon("CastReceipt"); loadAddon("ComboHistory")
loadAddon("CombatContext")
local events = frames[#frames]
local function event(name, ...) events.scripts.OnEvent(events, name, ...) end
local C = ns.CombatContext
ns.db.potionID = 9999
local height = C.Build(344, 80)
assert(height > 80 and C.active)
assert(C.footer.text:find("АВТОАТАКА: ДА", 1, true))
assert(C.cells.trinket1.itemID == nil, "empty trinket must not inherit potion")
assert(C.cells.potion.itemID == 9999)
-- While stabilizing the cell shows "?" or a lower bound "N+", never a bare count.
local function notExact(text) return text == "?" or text:match("^%d+%+$") ~= nil end
assert(notExact(C.cells.targets.value.text), "targets must not default to one")
assert(C.cells.targets.bg.color[1] == ns.Palette().unknown[1], "a lower bound must keep the unknown colour")
assert(ns.TargetCount.reason == "stabilizing", "new auto estimate must wait for stabilization")
C.cells.targets.scripts.OnClick(nil, "LeftButton")
assert(C.targets == 1 and ns.db.targetMode == "manual" and C.cells.targets.value.text == "1")
C.cells.targets.scripts.OnClick(nil, "RightButton")
-- Right click returns to auto; the manual choice is kept only for the next manual click.
assert(ns.db.targetMode == "auto" and ns.TargetCount.reason == "stabilizing")
assert(notExact(C.cells.targets.value.text) and C.cells.targets.value.text ~= "1+", "auto mode must not show the stale manual count")
C.SetForecast("ttd", 30); now = 110; C.Update()
assert(C.cells.ttd.value.text == "~30", "pre-pull forecast must not tick")
combat = true; event("PLAYER_REGEN_DISABLED"); now = 125; C.Update()
assert(C.cells.ttd.value.text == "~15")
now = 141; C.Update(); assert(C.cells.ttd.value.text == "?", "expired forecast must not stay zero")
C.SetForecast("ttd", 20); C.SetForecast("fight", 60); event("PLAYER_TARGET_CHANGED")
assert(C.forecasts.ttd == nil and C.forecasts.fight ~= nil)
local rangeIDs = {}
C_Spell.IsSpellInRange = function(id, unit) if unit == "target" then rangeIDs[id] = true end; return target and true or nil end
C.Update(); C_Spell.IsSpellInRange = savedRangeAPI
local profile = ns.specProfiles[specID]
local aux = profile.contextCells.chargeRange
assert(rangeIDs[profile.referenceSpellID] and C.cells.range.value.text == "ДА", "range must use the spec melee reference")
if aux.source == "range" then
  assert(rangeIDs[aux.spellID] and C.cells.chargeRange.value.text == "ДА", "Charge range cell")
elseif aux.source == "powerRegen" then
  assert(C.cells.chargeRange.value.text == "12.5", "energy regeneration cell")
elseif aux.source == "runeNext" then
  -- Rune 3 recharges from now-2 for 10 s; queued runes end later.
  assert(C.cells.chargeRange.value.text == "8.0" and C.cells.chargeRange.bg.color[1] == ns.Palette().nores[1], "next rune countdown")
  runeSecret = true; C.Update()
  assert(C.cells.chargeRange.value.text == "?" and C.cells.chargeRange.bg.color[1] == ns.Palette().unknown[1], "secret runes must be unknown")
  runeSecret = false; C.Update()
end
if aux.title then assert(C.cells.chargeRange.title.text == aux.title, "profile cell title") end
-- Presets for /ahw apl: several hero trees need a known, supported active tree.
local trees = 0
for _ in pairs(profile.heroTrees) do trees = trees + 1 end
local preset, why = ns.GetAPLPreset(profile)
if trees == 1 then
  assert(preset == profile.preset and preset, "single-tree profile keeps its preset")
else
  assert(preset or why, "preset or refusal")
  local saved = heroID
  heroID = nil; assert(not ns.GetAPLPreset(profile) and select(2, ns.GetAPLPreset(profile)):find("не определена", 1, true))
  heroID = 999; assert(not ns.GetAPLPreset(profile) and select(2, ns.GetAPLPreset(profile)):find("не поддержана", 1, true))
  heroID = saved
end
casting = "target"; C.Update()
assert(C.cells.targetCast.value.text == "Cast")
assert(C.cells.targetCast.shield.shown == forbidden, "secret interrupt state must flow into native display")
assert(C.cells.targetCast.cooldown.durationObject == forbidden)
local savedDurationAPI = UnitCastingDuration; UnitCastingDuration = nil
event("UNIT_SPELLCAST_DELAYED"); C.Update()
assert(C.cells.targetCast.timerUnknown.shown == true, "missing duration API must be visible")
UnitCastingDuration = savedDurationAPI
casting = nil; channeling = "player"; event("UNIT_SPELLCAST_CHANNEL_START"); C.Update()
assert(C.cells.playerCast.value.text == "Channel" and C.cells.playerCast.shield.shown == true, "channel tuple mapping")
assert(C.cells.targetCast.value.text == "—", "stopped cast must clear")
itemIDs[13] = 1000; enabled = 0; C.RefreshItems(); C.Update()
assert(C.cells.trinket1.value.text == "БЛОК", "disabled item must not report ready")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 12294); C.Update()
assert(C.cells.last.value.text == 12294)
target = false; C.Update(); assert(C.cells.range.value.text == "НЕТ ЦЕЛИ")
event("PLAYER_REGEN_ENABLED"); combat = false; C.Update()
assert(C.cells.last.value.text == "—" and C.forecasts.fight == nil)
assert(C.targets == nil, "manual target count must reset after combat")
loadAddon("Export")
HUD_EXPORT = assert(ns.MakeHUDExport())
local stored = ns.db.hudExports[specID]
assert(stored and stored.text == HUD_EXPORT and stored.at and not stored.stale, "export must be stored per spec")
local savedScale = ns.db.scale; ns.db.scale = (savedScale or 1) + 1
ns.StoreHUDExport(999, "{}")
assert(ns.db.hudExports[specID].stale and not ns.db.hudExports[999].stale, "a layout change marks older exports stale")
ns.db.scale = savedScale; ns.db.hudExports[999] = nil
C.cells.targets.GetRect = function() return forbidden, 1, 1, 1 end
local refused, why = ns.MakeHUDExport()
assert(refused == nil and why:find("secret", 1, true), "secret geometry must refuse the export, not error")
C.cells.targets.GetRect = nil
assert(ns.MakeHUDExport(), "export recovers once geometry is readable again")
assert(HUD_EXPORT:find('"static":true', 1, true))
combat = true; assert(ns.MakeHUDExport() == nil, "combat export must be rejected")
combat = false; target = true; usable = true; noPower = false
function UnitHealth() return 770280 end
function UnitHealthMax() return 770280 end
function UnitHealthPercent() return 0.93 end
function UnitPower() return 71 end
function UnitPowerType() return profile.powerType end
Enum.PowerType.Mana = 0
local ticker
local afterFns = {}
C_Timer = { NewTicker = function(_, fn) ticker = fn end, After = function(_, fn) afterFns[#afterFns + 1] = fn end }
ns.CreateMainFrame = function() return ns.frame end
ns.PixelMult = function() return 1 end
ns.ApplyScale, ns.InitMinimapButton, ns.RefreshPreview = noop, noop, noop
local finalResourceHeight
ns.LayoutFrame = function(_, _, _, h) finalResourceHeight = h end
loadAddon("Resources")
loadAddon("Core")
local core = frames[#frames]
core.scripts.OnEvent(core, "PLAYER_LOGIN")
assert(ns.db.stable and ns.db.context)
assert(finalResourceHeight > 150 and ticker, "context must contribute to Core layout and ticker")
ns.db.hudExports = nil
assert(#afterFns >= 1, "a rebuild must schedule an automatic export")
afterFns[1]()
assert(ns.db.autoExportStatus and ns.db.hudExports and ns.db.hudExports[specID], "scheduled export must be stored for the spec")
-- This export includes the resource row built by Core (runes, runic power, ...).
HUD_EXPORT_FULL = ns.db.hudExports[specID].text
local frameCount = #frames
ticker(); ticker()
assert(#frames == frameCount, "polling must not allocate frames")
if ns.Resources.runeTextures then
  local pal = ns.Palette()
  assert(ns.Resources.runeTextures[1].color[1] == pal.ready[1] and ns.Resources.runeTextures[3].color[1] == pal.cd[1], "rune colours")
  runeSecret = true; ticker()
  assert(ns.Resources.runeTextures[1].color[1] == pal.unknown[1], "a secret rune state must be unknown, not spent")
  runeSecret = false; ticker()
end
assert(ns.Resources.regions.targetHealth.percent.text == "?", "missing formatter must not display 0.93 as 0.93 percent")
-- The export measures a plain frame: the text itself is sized by a secret value in game.
assert(ns.Resources.regions.targetHealthPercent == ns.Resources.regions.targetHealth.percentArea
  and ns.Resources.regions.targetHealthPercent.kind == "Frame", "target percent must export its proxy frame")
SlashCmdList = {}
loadAddon("Options")
SlashCmdList.AHELPERW("trinket 1 buff 120 20 strength")
assert(ns.db.trinketMetadata[1000].buffDuration == 20)
assert(ns.db.trinketMetadata[1000].strength == true)
SlashCmdList.AHELPERW("trinket invalid")
-- Check formatting recipes with a minimal native-formatter stand-in.
C_StringUtil = { CreateNumericRuleFormatter = function()
  local f = { rules = {} }
  function f:AddBreakpoint(rule) self.rules[#self.rules + 1] = rule end
  function f:FormatNumber(value)
    local rule
    for _, r in ipairs(self.rules) do if value >= r.threshold then rule = r end end
    assert(rule)
    if rule.min then value = math.max(rule.min, value) end
    if rule.components then value = value / rule.components[1].div end
    return string.format(rule.format, value)
  end
  return f
end }
local fresh = {}
assert(loadfile("AHelperW/Display.lua"))("AHelperW", fresh)
assert(fresh.GetNumberFormatter("percent"):FormatNumber(0.93) == "93.0%")
assert(fresh.GetNumberFormatter("stack"):FormatNumber(0) == "1")
assert(fresh.GetNumberFormatter("timer"):FormatNumber(1.25) ~= "1", "GCD timer must retain fractional precision")
print("HUD state, casts, forecasts, equipment, migration and export checks passed")
