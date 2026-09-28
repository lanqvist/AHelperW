local _, ns = ...

-- Format in the engine: the result may remain secret and only flows to SetText.
-- No arithmetic, comparisons or tostring on combat values.
local formatters = {}
function ns.GetNumberFormatter(kind)
  if formatters[kind] ~= nil then return formatters[kind] or nil end
  local ok, formatter = pcall(function()
    local f = C_StringUtil.CreateNumericRuleFormatter()
    local rule = { threshold = 0, format = "%.0f" }
    if kind == "stack" then rule.min = 1 end
    if kind == "decimal" then rule.format = "%.1f" end
    if kind == "timer" then rule.format = "%.1f" end
    if kind == "percent" then
      rule.format = "%.1f%%"
      rule.components = { { div = 0.01 } }
    end
    f:AddBreakpoint(rule)
    if kind == "timer" then f:AddBreakpoint({ threshold = 100, format = "%.0f" }) end
    return f
  end)
  formatters[kind] = ok and formatter or false
  return ok and formatter or nil
end

function ns.ConfigureCountdown(cooldown)
  if cooldown.SetMinimumCountdownDuration then pcall(cooldown.SetMinimumCountdownDuration, cooldown, 0) end
  local f = ns.GetNumberFormatter("timer")
  if f and cooldown.SetCountdownFormatter then pcall(cooldown.SetCountdownFormatter, cooldown, f) end
  -- Configure the region before it receives a secret duration.
  pcall(function()
    local text = cooldown:GetCountdownFontString()
    if text then text:SetTextColor(1, 1, 1, 1) end
  end)
end

function ns.DisplayNumber(text, value, kind)
  if kind == "decimal" then
    -- FormatNumber(secret) is AllowedWhenUntainted; FontString:SetFormattedText
    -- accepts secret arguments from addon code and formats inside the renderer.
    -- Do not fall back to raw floats: their long tails get ellipsized by the cell.
    local ok = pcall(text.SetFormattedText, text, "%.1f", value)
    if not ok then text:SetText("?") end
    return ok
  end
  local formatter = ns.GetNumberFormatter(kind or "integer")
  local ok = formatter and pcall(function() text:SetText(formatter:FormatNumber(value)) end)
  if not ok then ok = pcall(text.SetText, text, value) end
  if not ok then text:SetText("?") end
  return ok
end

-- Separate the timer's line from the bottom-right charge/aura counter.
-- Geometry is configured outside combat, before any secret duration is bound.
function ns.LayoutSquareCountdown(cooldown, size)
  pcall(function()
    local text = cooldown:GetCountdownFontString()
    if not text then return end
    ns.SetFont(text, math.floor(size * 0.3), "OUTLINE")
    text:ClearAllPoints()
    text:SetPoint("CENTER", cooldown, "CENTER", 0, ns.Round(size * 0.17))
    text:SetWidth(size - ns.Round(4))
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
  end)
end

function ns.ReadValue(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or (issecretvalue and issecretvalue(value)) then return nil end
  return value
end
