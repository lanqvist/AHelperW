-- Timing of the nameplate target estimate. Mocks only; no secure rendering.
local now = 0
local inRange = {}
function GetTime() return now end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function UnitExists(unit) return inRange[unit] ~= nil end
function UnitCanAttack() return true end
function UnitIsDeadOrGhost() return false end
C_Spell = { IsSpellInRange = function(_, unit) return inRange[unit] end }
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
local ns = { ReadValue = function(fn, ...) return fn(...) end, GetMeleeReference = function() return 23881 end,
  MeleeInRange = function(unit) return C_Spell.IsSpellInRange(23881, unit) end }
assert(loadfile("AHelperW/TargetCount.lua"))("AHelperW", ns)
local T = ns.TargetCount
T.Reset()
local function set(n) wipe(inRange); for i = 1, n do inRange["nameplate" .. i] = true end end
local function tick(t) now = t; T.nextScan = 0; return T.Update() end

-- Pull: enemies enter melee one by one every 0.15 s.
set(1); assert(tick(1.00) == nil and T.reason == "stabilizing")
set(2); assert(tick(1.15) == nil)
set(3); assert(tick(1.30) == nil)
set(5); assert(tick(1.35) == nil)
-- 0.4 s from the first enemy, not from the last increase.
assert(T.lower == 1, "lower bound on a pull is the first count")
assert(tick(1.41) == 5 and T.reason == "estimate", "rising count must not restart stabilization")
assert(T.lower == nil, "a published estimate clears the lower bound")

-- A decrease keeps the longer window, measured from the drop.
set(3); assert(tick(2.00) == nil and T.delay == 0.8 and T.lower == 3)
assert(tick(2.50) == nil)
assert(tick(2.81) == 3)

-- A rise after a published count uses a fresh 0.4 s window.
set(4); assert(tick(3.00) == nil)
assert(tick(3.41) == 4)

-- A rise inside a decrease window restarts as before (no shortcut).
set(2); tick(4.00)
set(3); tick(4.10)
assert(T.pendingAt == 4.10 and tick(4.40) == nil and tick(4.51) == 3)

-- Flicker 5 -> 4 -> 5: the bound keeps the smallest count since the last estimate.
set(5); tick(6.00); assert(tick(6.41) == 5)
set(4); assert(tick(7.00) == nil and T.lower == 4)
set(5); assert(tick(7.20) == nil and T.lower == 4)
assert(tick(7.61) == 5 and T.lower == nil)
-- An unresolved observation clears the bound instead of keeping a stale one.
set(3); tick(8.00); assert(T.lower == 3)
set(0); assert(tick(8.20) == nil and T.lower == nil)
