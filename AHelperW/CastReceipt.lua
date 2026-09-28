local _, ns = ...
-- A short visible journal of PUBLIC player cast events. Never inspect secret IDs.
-- Eight rows: one Fury GCD can emit 4-5 events (cast + child hits) within a
-- single reader frame, which overflowed the original four-row journal.
local R = { sequence = 0, records = {}, rows = {}, ROWS = 8, ROW_HEIGHT = 1.5 }
ns.CastReceipt = R

local function Paint(index, sequence, spellID)
  local bytes = { 165, math.floor(sequence / 256), sequence % 256,
    math.floor(spellID / 65536), math.floor(spellID / 256) % 256, spellID % 256 }
  local checksum = 0
  for _, byte in ipairs(bytes) do checksum = (checksum + byte) % 256 end
  bytes[7] = checksum
  R.records[index] = bytes
  if not R.rows[index] then return end
  for b, byte in ipairs(bytes) do
    for bit = 0, 7 do
      local value = math.floor(byte / 2 ^ (7 - bit)) % 2 == 1 and 1 or 0
      R.rows[index][(b - 1) * 8 + bit + 1]:SetColorTexture(value, value, value, 1)
    end
  end
end

function R.Build(parent, width)
  if not R.frame then
    R.frame = CreateFrame("Frame", nil, parent)
    R.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -12)
    for row = 1, R.ROWS do
      R.rows[row] = {}
      for col = 1, 56 do
        R.rows[row][col] = R.frame:CreateTexture(nil, "OVERLAY")
      end
    end
  end
  R.frame:SetSize(width - 4, R.ROWS * R.ROW_HEIGHT)
  for row = 1, R.ROWS do
    for col = 1, 56 do
      local texture = R.rows[row][col]
      texture:ClearAllPoints()
      texture:SetPoint("TOPLEFT", R.frame, "TOPLEFT", (col - 1) * (width - 4) / 56, -(row - 1) * R.ROW_HEIGHT)
      texture:SetSize((width - 4) / 56, R.ROW_HEIGHT)
    end
    local bytes = R.records[row]
    Paint(row, bytes and bytes[2] * 256 + bytes[3] or 0,
      bytes and bytes[4] * 65536 + bytes[5] * 256 + bytes[6] or 0)
  end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, _, _, _, spellID)
  if issecretvalue and issecretvalue(spellID) then return end
  if type(spellID) ~= "number" or spellID < 1 or spellID >= 16777216 or spellID % 1 ~= 0 then return end
  R.sequence = R.sequence % 65535 + 1
  Paint((R.sequence - 1) % R.ROWS + 1, R.sequence, spellID)
end)
