local _, ns = ...
-- Native display of Blizzard's "last Combo Strikes ability" helper auras.
-- Lua never observes which marker is visible. First use is diagnostic.
local H = { markers = {} }
ns.ComboHistory = H
local definitions = {
  { "rising_sun_kick", 1249753 }, { "spinning_crane_kick", 1249754 },
  { "tiger_palm", 1249756 }, { "blackout_kick", 1249757 },
  { "fists_of_fury", 1249758 }, { "slicing_winds", 1249759 },
  { "zenith", 1249762 }, { "zenith_stomp", 1249763 },
  { "crackling_jade_lightning", 1249764 }, { "whirling_dragon_punch", 1249765 },
  { "strike_of_the_windlord", 1249766 }, { "celestial_conduit", 1249790 },
  { "touch_of_death", 1249791 },
}

function H.Build(parent, width, height, enabled)
  if H.frame then H.frame:Hide() end
  if not enabled then return end
  if not H.frame then
    H.frame = CreateFrame("Frame", nil, parent)
    H.label = H.frame:CreateFontString(nil, "OVERLAY")
    H.label:SetPoint("TOPLEFT", 2, -2)
    ns.SetFont(H.label, 7)
    H.label:SetText("ПОСЛЕДНИЙ УДАР КОМБО · ДИАГНОСТИКА")
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, H.frame, "CustomAuraContainerTemplate")
    if ok then H.container = container; container:SetAllPoints(); container:SetUnit("player") end
    for i, entry in ipairs(definitions) do
      local cell = CreateFrame("Frame", nil, H.frame)
      cell.bg = cell:CreateTexture(nil, "BACKGROUND")
      cell.bg:SetAllPoints()
      cell.bg:SetColorTexture(0.48, 0.35, 0, 1)
      local action, auraID = entry[1], entry[2]
      local marker = { frame = cell, auraID = auraID, action = action, configured = false }
      if H.container then
        local configured, button = pcall(H.container.AddAuraSlot, H.container, action, "HELPFUL", {
          candidateFilters = { includeSpellIDs = { [auraID] = true } },
          initializeFrame = function(btn)
            local fill = btn:CreateTexture(nil, "ARTWORK")
            fill:SetAllPoints()
            fill:SetColorTexture(0, 1, 0.53, 1)
          end,
        })
        if configured and button then
          button:SetAllPoints(cell)
          marker.configured = true
          cell.bg:SetColorTexture(0.16, 0.16, 0.16, 1)
        end
      end
      H.markers[i] = marker
    end
  end
  H.frame:SetParent(parent)
  H.frame:SetSize(width, height)
  H.frame:Show()
  H.label:SetWidth(width - 4)
  local cellW = width / #H.markers
  for i, marker in ipairs(H.markers) do
    marker.frame:ClearAllPoints()
    marker.frame:SetPoint("BOTTOMLEFT", H.frame, "BOTTOMLEFT", (i - 1) * cellW, 0)
    marker.frame:SetSize(math.max(1, cellW - 2), math.max(7, height - 12))
  end
end
