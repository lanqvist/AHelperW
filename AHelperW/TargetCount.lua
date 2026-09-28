local _, ns = ...
local T = { tokens = {}, nextScan = 0 }
ns.TargetCount = T
local read = ns.ReadValue
-- Fixed diagnostic colors, independent of the user's HUD palette.
T.statusColors = {
  estimate = { 0, 1, 0.53 }, manual = { 0.6, 0.4, 1 },
  stabilizing = { 1, 0.8, 0 }, no_nameplates = { 0.16, 0.16, 0.16 },
  no_melee_observation = { 0.9, 0.3, 0 }, range_unknown = { 0, 0.8, 1 },
  unit_unknown = { 0.75, 0, 0.75 }, waiting = { 0.48, 0.35, 0 },
}

function T.Reset()
  T.nextScan, T.count, T.pending, T.pendingAt, T.lower = 0, nil, nil, nil, nil
  T.reason = "waiting"
end

local function scan()
  local reference = ns.GetMeleeReference()
  local candidates = {}
  for i = 1, 40 do candidates["nameplate" .. i] = true end
  for unit in pairs(T.tokens) do candidates[unit] = true end
  local count, visible, unresolved, unknownUnit, unknownRange = 0, 0, 0, 0, 0
  for unit in pairs(candidates) do
    local exists = read(UnitExists, unit)
    if exists == true then
      visible = visible + 1
      local hostile = read(UnitCanAttack, "player", unit)
      local dead = read(UnitIsDeadOrGhost, unit)
      if hostile == true and dead == false then
        local range = reference and read(C_Spell.IsSpellInRange, reference, unit)
        if range == true then count = count + 1
        elseif range == nil then unresolved = unresolved + 1; unknownRange = unknownRange + 1 end
      elseif hostile ~= false and dead ~= true then unresolved = unresolved + 1; unknownUnit = unknownUnit + 1 end
    elseif exists == nil then unresolved = unresolved + 1; unknownUnit = unknownUnit + 1 end
  end
  return count, visible, unresolved, unknownUnit, unknownRange
end

function T.Update()
  local now = GetTime()
  if now < T.nextScan then return T.count end
  T.nextScan = now + 0.2
  local count, visible, unresolved, unknownUnit, unknownRange = scan()
  T.visible, T.unresolved, T.observed = visible, unresolved, count
  -- No visible nearby candidates is not proof that zero enemies exist.
  if unresolved > 0 or count == 0 then
    T.count, T.pending, T.pendingAt, T.lower = nil, nil, nil, nil
    T.reason = unknownUnit > 0 and "unit_unknown" or (unknownRange > 0 and "range_unknown"
      or (visible == 0 and "no_nameplates" or "no_melee_observation"))
    return nil
  end
  -- Enemies enter melee one by one on a pull (1, 2, ... 5). A further rise
  -- during a rising stabilization keeps its start, so the window is 0.4 s from
  -- the first new enemy instead of restarting per enemy; the latest count is
  -- published. A drop still restarts the (longer) decrease window.
  local rising = T.count == nil and T.pending ~= nil and T.delay == 0.4 and count > T.pending
  if rising then
    T.pending = count
  elseif count ~= T.pending then
    local previous = T.count
    T.pending, T.pendingAt = count, now
    T.delay = previous and count < previous and 0.8 or 0.4
    T.count = nil
  end
  if now - T.pendingAt >= T.delay then T.count, T.reason, T.lower = count, "estimate", nil
  else
    -- Lower bound while stabilizing: the smallest count observed since the
    -- last published estimate. Every observation had no unresolved plates.
    T.reason = "stabilizing"
    T.lower = math.min(T.lower or count, count)
  end
  return T.count
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    wipe(T.tokens); T.Reset(); return
  end
  if issecretvalue and issecretvalue(unit) then return end
  if type(unit) ~= "string" then return end
  if event == "NAME_PLATE_UNIT_ADDED" then T.tokens[unit] = true else T.tokens[unit] = nil end
  T.nextScan = 0
end)
