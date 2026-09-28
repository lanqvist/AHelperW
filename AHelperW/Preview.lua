local _, ns = ...

-- Optional legend for identifying the numbered squares in the live HUD.
-- This is a visual aid. It never reads aura or cooldown state.
local legend
local rows = {}
local names = { spell = "СПОСОБНОСТИ", proc = "БАФФЫ И ПРОКИ", debuff = "ДЕБАФФЫ ЦЕЛИ" }
local colors = {
  spell = { 0, 1, 0.53 },
  proc = { 1, 0.31, 0.85 },
  debuff = { 0.63, 0.42, 1 },
}

local function GetLegend()
  if legend then return legend end
  legend = CreateFrame("Frame", "AHelperWPreviewLegend", UIParent)
  legend:SetFrameStrata("HIGH")
  legend:SetClampedToScreen(true)
  legend:SetSize(250, 40)
  legend:SetScale(0.76)
  legend:EnableMouse(false)
  local bg = legend:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.96)
  legend.title = legend:CreateFontString(nil, "OVERLAY")
  ns.SetFont(legend.title, 12, "OUTLINE")
  legend.title:SetPoint("TOPLEFT", 10, -8)
  legend.title:SetText("AHelperW · ПРЕВЬЮ")
  legend.title:SetTextColor(1, 1, 1)
  return legend
end

local function GetRow(index)
  local row = rows[index]
  if row then return row end
  row = GetLegend():CreateFontString(nil, "OVERLAY")
  ns.SetFont(row, 11, "OUTLINE")
  row:SetWidth(230)
  row:SetJustifyH("LEFT")
  row:SetWordWrap(false)
  rows[index] = row
  return row
end

function ns.RefreshPreview()
  if ns.db.compact or not ns.db.preview or not ns.frame:IsShown() then
    if legend then legend:Hide() end
    return
  end
  local panel = GetLegend()
  local count, lastKind = 0, nil
  local y = -29
  for index, square in ipairs(ns.squares) do
    if square.spellID and square:IsShown() then
      local kind = square.kind
      if kind ~= lastKind then
        lastKind = kind
        count = count + 1
        local header = GetRow(count)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
        header:SetText(names[kind] or kind or "ДРУГОЕ")
        local c = colors[kind] or { 1, 1, 1 }
        header:SetTextColor(c[1], c[2], c[3])
        header:Show()
        y = y - 19
      end
      count = count + 1
      local row = GetRow(count)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
      local info = C_Spell.GetSpellInfo(square.spellID)
      local name = info and info.name or ("ID " .. square.spellID)
      row:SetText(("%02d  %s"):format(index, name))
      row:SetTextColor(0.94, 0.94, 0.94)
      row:Show()
      y = y - 17
    end
  end
  for i = count + 1, #rows do rows[i]:Hide() end
  panel:SetHeight(math.max(40, -y + 8))
  panel:ClearAllPoints()
  local frameRight = ns.frame:GetRight()
  if frameRight then
    frameRight = frameRight * ns.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end
  local screenRight = UIParent:GetRight()
  local scaledWidth = panel:GetWidth() * panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
  if ns.db.dock == "right" or (frameRight and screenRight and frameRight + scaledWidth + 8 > screenRight) then
    panel:SetPoint("TOPRIGHT", ns.frame, "TOPLEFT", -8, 0)
  else
    panel:SetPoint("TOPLEFT", ns.frame, "TOPRIGHT", 8, 0)
  end
  panel:Show()
end
