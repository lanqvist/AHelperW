-- Behavioral checks in a Lua VM. UI mocks do not validate WoW secure rendering.
unpack = table.unpack or unpack
local now, combat, target = 100, false, true
local forbidden = { secret = true }
function issecretvalue(v) return type(v) == "table" and rawget(v, "secret") == true end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function GetTime() return now end
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
function UnitClass() return "Warrior", "WARRIOR" end
function IsPlayerSpell() return true end
Enum = { PowerType = { Rage = 1 }, NumericRuleFormatRounding = { Nearest = 0 } }
UISpecialFrames = {}
C_SpecializationInfo = { GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return 71 end }
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
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
loadAddon("Display"); loadAddon("Palette"); loadAddon("ClassData")
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
ns.db.custom = { [71] = { spells = { 999 }, procs = {}, debuffs = {} } }
ns.ExpandArmsHUD()
assert(ns.db.custom[71].spells[1] == 999, "migration must retain custom order")
local found = {}; for _, id in ipairs(ns.db.custom[71].spells) do found[id] = true end
assert(found[100] and found[6552], "missing Arms actions")
local count = #ns.db.custom[71].spells; ns.ExpandArmsHUD(); assert(#ns.db.custom[71].spells == count)

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
assert(C.cells.targets.value.text == "?", "targets must not default to one")
C.cells.targets.scripts.OnClick(nil, "LeftButton")
assert(C.targets == 1)
C.cells.targets.scripts.OnClick(nil, "RightButton")
assert(C.targets == nil)
C.SetForecast("ttd", 30); now = 110; C.Update()
assert(C.cells.ttd.value.text == "~30", "pre-pull forecast must not tick")
combat = true; event("PLAYER_REGEN_DISABLED"); now = 125; C.Update()
assert(C.cells.ttd.value.text == "~15")
now = 141; C.Update(); assert(C.cells.ttd.value.text == "?", "expired forecast must not stay zero")
C.SetForecast("ttd", 20); C.SetForecast("fight", 60); event("PLAYER_TARGET_CHANGED")
assert(C.forecasts.ttd == nil and C.forecasts.fight ~= nil)
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
loadAddon("Export")
HUD_EXPORT = assert(ns.MakeHUDExport())
assert(HUD_EXPORT:find('"static":true', 1, true))
combat = true; assert(ns.MakeHUDExport() == nil, "combat export must be rejected")
combat = false; target = true; usable = true; noPower = false
function UnitHealth() return 770280 end
function UnitHealthMax() return 770280 end
function UnitHealthPercent() return 0.93 end
function UnitPower() return 71 end
function UnitPowerType() return 1 end
Enum.PowerType.Mana = 0
local ticker
C_Timer = { NewTicker = function(_, fn) ticker = fn end }
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
local frameCount = #frames
ticker(); ticker()
assert(#frames == frameCount, "polling must not allocate frames")
assert(ns.Resources.regions.targetHealthPercent.text == "?", "missing formatter must not display 0.93 as 0.93 percent")
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
