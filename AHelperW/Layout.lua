local _, ns = ...

local FONT_CUSTOM = [[Interface\AddOns\AHelperW\Media\JetBrainsMono-ExtraBold.ttf]]
local FONT_FALLBACK = [[Fonts\ARIALN.TTF]]

function ns.HUDLayout()
  local compact = ns.db.compact == true
  return { compact = compact, pad = ns.Round(compact and 4 or 8),
    sectionGap = ns.Round(compact and 4 or 8),
    gap = ns.Round(compact and 2 or ns.db.gap),
    perRow = compact and 7 or ns.db.perRow }
end

function ns.SetCompact(enabled)
  if InCombatLockdown() then
    print("AHelperW: переключай раскладку вне боя.")
    return false
  end
  ns.db.compact = enabled
  ns.db.lastHUDExport = nil
  ns.ResetProcContainers()
  ns.Rebuild()
  print("AHelperW: " .. (enabled and "компактный" or "полный") .. " вид; останови ридер и обнови /ahw export.")
  return true
end

-- 12.x ошибается на кривом пути шрифта вместо тихого фолбэка — валидируем возврат и pcall
function ns.SetFont(fs, size, flags)
  local ok, applied = pcall(fs.SetFont, fs, FONT_CUSTOM, size, flags or "")
  if not ok or not applied then
    fs:SetFont(FONT_FALLBACK, size, flags or "")
  end
end

-- Множитель для попадания в физические пиксели (техника ElvUI)
function ns.PixelMult()
  local _, screenH = GetPhysicalScreenSize()
  return 768 / screenH / UIParent:GetEffectiveScale()
end

function ns.Round(v)
  local mult = ns.pixelMult or 1
  return math.floor(v / mult + 0.5) * mult
end

function ns.SavePosition(frame)
  local point, _, relPoint, x, y = frame:GetPoint()
  ns.db.pos = { point = point, relPoint = relPoint, x = x, y = y }
  ns.db.dock = "free"
  ns.db.lastHUDExport = nil
  if ns.RefreshPreview then ns.RefreshPreview() end
end

function ns.CreateMainFrame()
  local f = CreateFrame("Frame", "AHelperWFrame", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetSize(200, 100)

  f.plate = f:CreateTexture(nil, "BACKGROUND")
  f.plate:SetAllPoints()
  f.plate:SetColorTexture(0, 0, 0, ns.db.plateAlpha)

  f.unlockLabel = f:CreateFontString(nil, "OVERLAY")
  ns.SetFont(f.unlockLabel, 11, "OUTLINE")
  f.unlockLabel:SetPoint("BOTTOM", f, "TOP", 0, 4)
  f.unlockLabel:SetText("AHelperW — перетащи, /ahw lock")
  f.unlockLabel:SetTextColor(0, 1, 0.53)
  f.unlockLabel:Hide()

  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not ns.db.locked then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.SavePosition(self)
  end)

  ns.frame = f
  ns.ApplyLock()
  ns.RestorePosition()
  return f
end

function ns.RestorePosition()
  local f, pos = ns.frame, ns.db.pos
  f:ClearAllPoints()
  if ns.db.dock == "left" then
    f:SetPoint("LEFT", UIParent, "LEFT", ns.Round(12), 0)
  elseif ns.db.dock == "right" then
    f:SetPoint("RIGHT", UIParent, "RIGHT", -ns.Round(12), 0)
  elseif pos then
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
  end
end

function ns.SetDock(mode)
  ns.db.dock = mode
  ns.RestorePosition()
  ns.db.lastHUDExport = nil
  if ns.RefreshPreview then ns.RefreshPreview() end
end

function ns.ApplyLock()
  local f = ns.frame
  if not f then return end
  f:EnableMouse(not ns.db.locked)
  if ns.ApplySquareMouse then ns.ApplySquareMouse() end
  if ns.db.locked then f.unlockLabel:Hide() else f.unlockLabel:Show() end
end

function ns.ApplyScale()
  if ns.frame then
    ns.frame:SetScale(ns.db.scale)
    ns.db.lastHUDExport = nil
    if ns.RefreshPreview then ns.RefreshPreview() end
  end
end

function ns.ApplyPlateAlpha()
  if ns.frame then ns.frame.plate:SetColorTexture(0, 0, 0, ns.db.plateAlpha) end
end

-- Итоговый размер окна: сетка квадратов сверху, строка ресурсов под ней
function ns.LayoutFrame(gridW, gridH, resW, resH)
  local layout = ns.HUDLayout()
  local pad = layout.pad
  local gap = layout.sectionGap
  local w = math.max(gridW, resW) + pad * 2
  local h = gridH + (resH > 0 and (gap + resH) or 0) + pad * 2
  ns.frame:SetSize(math.max(w, 40), math.max(h, 40))
end
