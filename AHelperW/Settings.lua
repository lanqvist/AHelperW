local _, ns = ...
local S = {}
ns.Settings = S
local window, diagnostics

local function CanChange()
  if InCombatLockdown() then
    print("AHelperW: настройки доступны вне боя.")
    return false
  end
  return true
end

local function Label(parent, text, size, x, y, width)
  local label = parent:CreateFontString(nil, "OVERLAY")
  ns.SetFont(label, size, "OUTLINE")
  label:SetPoint("TOPLEFT", x, -y)
  label:SetWidth(width)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

local function Button(parent, text, x, y, width, action)
  local button = CreateFrame("Button", nil, parent)
  button:SetPoint("TOPLEFT", x, -y)
  button:SetSize(width, 30)
  button.bg = button:CreateTexture(nil, "BACKGROUND")
  button.bg:SetAllPoints()
  button.bg:SetColorTexture(0.12, 0.14, 0.17, 1)
  button.text = button:CreateFontString(nil, "OVERLAY")
  ns.SetFont(button.text, 11, "OUTLINE")
  button.text:SetPoint("CENTER")
  button.text:SetWidth(width - 12)
  button.text:SetWordWrap(false)
  button.text:SetText(text)
  button:SetScript("OnEnter", function() button.bg:SetColorTexture(0.19, 0.23, 0.27, 1) end)
  button:SetScript("OnLeave", function() button.bg:SetColorTexture(0.12, 0.14, 0.17, 1) end)
  button:SetScript("OnClick", function()
    if not CanChange() then return end
    action()
    S.Refresh()
  end)
  return button
end

function S.Refresh()
  if not window then return end
  window.compact.text:SetText("Вид: " .. (ns.db.compact and "компактный" or "полный"))
  window.lock.text:SetText(ns.db.locked and "Разблокировать HUD" or "Закрепить HUD")
  window.icons.text:SetText("Иконки: " .. (ns.db.style == "mix" and "вкл" or "выкл"))
  window.preview.text:SetText("Превью: " .. (ns.db.preview and "вкл" or "выкл"))
  window.diagnostics.text:SetText(diagnostics:IsShown() and "Диагностика −" or "Диагностика +")
  window:SetHeight(diagnostics:IsShown() and 420 or 350)
end

local function Build()
  window = CreateFrame("Frame", "AHelperWSettingsWindow", UIParent, "BackdropTemplate")
  window:SetSize(440, 350)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", function(self) self:StartMoving() end)
  window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  window:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]] })
  window:SetBackdropColor(0.025, 0.03, 0.04, 0.98)
  Label(window, "AHelperW · Настройки", 16, 16, 14, 380)
  Label(window, "Вид и расположение HUD", 11, 16, 43, 408)
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  table.insert(UISpecialFrames, "AHelperWSettingsWindow")

  window.compact = Button(window, "", 16, 70, 198, function() ns.SetCompact(not ns.db.compact) end)
  window.lock = Button(window, "", 226, 70, 198, function()
    ns.db.locked = not ns.db.locked
    ns.ApplyLock()
    if not ns.db.locked then window:Hide() end
  end)
  Button(window, "Левый край", 16, 110, 128, function() ns.SetDock("left") end)
  Button(window, "Правый край", 156, 110, 128, function() ns.SetDock("right") end)
  Button(window, "Свободно", 296, 110, 128, function() ns.SetDock("free") end)
  window.icons = Button(window, "", 16, 150, 198, function()
    ns.db.style = ns.db.style == "mix" and "color" or "mix"
    ns.db.lastHUDExport = nil
    ns.ResetProcContainers()
    ns.Rebuild()
  end)
  window.preview = Button(window, "", 226, 150, 198, function()
    ns.db.preview = not ns.db.preview
    ns.db.lastHUDExport = nil
    ns.ResetProcContainers()
    ns.Rebuild()
  end)
  Label(window, "После изменения вида или положения останови ридер и загрузи новый экспорт.", 11, 16, 197, 408)
  Button(window, "Экспорт для ридера", 16, 241, 408, function()
    window:Hide()
    ns.ShowHUDExport()
  end)
  window.diagnostics = Button(window, "Диагностика +", 16, 300, 408, function()
    diagnostics:SetShown(not diagnostics:IsShown())
  end)
  diagnostics = CreateFrame("Frame", nil, window)
  diagnostics:SetPoint("TOPLEFT", 16, -342)
  diagnostics:SetSize(408, 62)
  Label(diagnostics, "Ручные изменения набора для диагностики", 10, 0, 0, 408)
  Button(diagnostics, "Редактор способностей", 0, 24, 408, function()
    window:Hide()
    ns.Manager.Toggle()
  end)
  diagnostics:Hide()
  window:SetScript("OnShow", S.Refresh)
  window:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
  window:RegisterEvent("PLAYER_REGEN_DISABLED")
  window:SetScript("OnEvent", function(self) self:Hide() end)
end

function S.Toggle()
  if not CanChange() then return end
  if not window then Build(); window:Hide() end
  window:SetShown(not window:IsShown())
end
