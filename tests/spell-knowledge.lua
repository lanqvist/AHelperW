-- Public knowledge only; no game, UI or live inputs.
local ns = { armsAplPreset = {} }
Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, Runes = 5,
  RunicPower = 6, Chi = 12, HolyPower = 9 } }
local values, failed = {}, nil
local secret = {}
function IsPlayerSpell(id)
  if id == failed then error("API failure") end
  return values[id]
end
function ns.ReadValue(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok and value ~= secret then return value end
end
function ns.GetSpecData() return {}, 70 end
assert(loadfile("AHelperW/SpecProfiles.lua"))("AHelperW", ns)
local function check(base, grant, expected)
  values[24275], values[1241288] = base, grant
  local report = ns.GetSpellKnowledge(24275)
  assert(report.known == expected)
  assert(report.grantSpellID == 1241288)
  assert(report.status == (expected == true and "known" or (expected == false and "not-known" or "unknown")))
end
check(false, true, true)
check(true, false, true)
check(false, false, false)
check(false, nil, nil)
check(nil, false, nil)
check(secret, false, nil)
check(false, secret, nil)
check(nil, true, true)
failed = 1241288; check(false, false, nil); failed = nil
assert(ns.GetSpellKnowledge(24275, ns.specProfiles[71]).known == false,
  "Retribution granting spell must not leak into another specialization")
values[184575] = true
assert(ns.GetSpellKnowledge(184575).known == true)
values[184575] = false
assert(ns.GetSpellKnowledge(184575).known == false)
values[184575] = nil
assert(ns.GetSpellKnowledge(184575).known == nil)
