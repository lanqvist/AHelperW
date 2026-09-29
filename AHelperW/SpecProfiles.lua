local _, ns = ...

-- Static specialization configuration. Live/secret values belong to renderers.
-- heroTrees: { [subtreeID] = { key = SimC hero_tree.<key>, name, preset? } }.
-- A single-tree profile keeps its legacy heroTree/preset; with several trees the
-- active one comes from the client and an unknown/unsupported tree is refused.
-- contextCells: per-profile meaning of the "maxrage"/"chargeRange" context cells
-- (export key, title, tooltip, source: range | powerRegen | runeNext).
-- The field reference and a filled example: docs/melee-dps-plan.md, «Как добавить спек».
ns.specProfiles = {
  [71] = {
    id = "warrior.arms.slayer", name = "Arms / Slayer", heroTree = "slayer",
    heroTrees = { [60] = { key = "slayer", name = "Slayer" } },
    primary = "rage", powerType = Enum.PowerType.Rage, referenceSpellID = 12294,
    executeThresholds = {20, 35},
    contextCells = { chargeRange = { source = "range", spellID = 100 } },
    preset = ns.armsAplPreset,
    aliases = { heroic_strike = { spellID = 1269383, displaySpellID = 1464, procID = 1269391, sharesBindingWith = "slam" } },
  },
  -- In development; reader model: reader/fury_apl.py. IDs and evidence:
  -- docs/fury-apl/coverage.json. Sudden Death 52437 and Hack and Slash 383873
  -- were observed in the first manual fight (280776 never lit).
  [72] = {
    id = "warrior.fury.slayer", name = "Fury / Slayer", heroTree = "slayer",
    heroTrees = { [60] = { key = "slayer", name = "Slayer" } },
    primary = "rage", powerType = Enum.PowerType.Rage, referenceSpellID = 23881,
    executeThresholds = {20, 35},
    contextCells = { chargeRange = { source = "range", spellID = 100 } },
    aliases = {
      crushing_blow = { spellID = 335097, displaySpellID = 85288, sharesBindingWith = "raging_blow", label = "Crushing Blow" },
      bloodbath = { spellID = 335096, displaySpellID = 23881, sharesBindingWith = "bloodthirst", label = "Bloodbath" },
    },
    preset = {
      spells = { 184367, 23881, 85288, 5308, 1719, 227847, 385059, 190411,
        107570, 100, 6552, 386196,
        69179, 255647, 312411, 26297, 20572, 265221, 274738 },
      procs = { 184362, 1719, 52437, 85739, 383873, 446035, 445606, 386196, 10060 },
      debuffs = {},
    },
  },
  [269] = {
    id = "monk.windwalker.shado-pan", name = "ВВ / Шадо-Пан", heroTree = "shado_pan",
    heroTrees = { [65] = { key = "shado_pan", name = "Шадо-Пан" } },
    primary = "energy", secondary = "chi", powerType = Enum.PowerType.Energy,
    secondaryType = Enum.PowerType.Chi, referenceSpellID = 100780,
    executeThresholds = {15},
    contextCells = {
      maxrage = { export = "maxenergy", title = "MAX ЭН." },
      chargeRange = { export = "energyRegen", title = "ЭН./С", source = "powerRegen" },
    },
    comboHistory = true,
    -- The historical talent ID becomes the actual tracked buff ID on /ahw apl.
    procReplacements = { [1261844] = 1261724 },
    chargeSources = { [1249625] = 1249625 },
    rechargeTelemetry = { { key = "zenithRecharge", spellID = 1249625, title = "ВОССТ. ЗЕНИТА" } },
    aliases = {
      rushing_wind_kick = { spellID = 467307, displaySpellID = 107428, sharesBindingWith = "rising_sun_kick" },
      zenith_stomp = { spellID = 1272696, displaySpellID = 1249625, procID = 1291484, sharesBindingWith = "zenith" },
    },
    preset = {
      spells = { 100780, 100784, 107428, 113656, 101546, 152175, 1249625,
        322109, 122470, 116705, 392983, 123904, 443028, 1217413 },
      procs = { 116768, 325202, 1261724, 1249625, 1291484, 1250554,
        196742, 1297033, 10060, 2825, 32182, 80353, 90355, 160452, 264667, 390386 },
      debuffs = {},
    },
  },
  -- Death Knight: in development offline (docs/melee-dps-plan.md). Runic power is
  -- the primary number, the six runes are coloured squares (Resources.lua).
  -- Presets, aliases and the reader model are added by the Frost/Unholy work.
  [251] = {
    id = "deathknight.frost", name = "Frost DK",
    heroTrees = {
      [33] = { key = "deathbringer", name = "Deathbringer" },
      [32] = { key = "rider_of_the_apocalypse", name = "Rider of the Apocalypse" },
    },
    primary = "runic_power", powerType = Enum.PowerType.RunicPower,
    secondary = "runes", secondaryType = Enum.PowerType.Runes,
    referenceSpellID = 49020, -- Obliterate (trait table, spec 251)
    executeThresholds = {},
    contextCells = {
      maxrage = { export = "maxrunic_power", title = "MAX СР" },
      chargeRange = { export = "runeNext", title = "РУНА, С", source = "runeNext",
        tip = "Секунды до следующей готовой руны (GetRuneCooldown). ? — значения скрыты клиентом, — — все руны готовы." },
    },
  },
  [252] = {
    id = "deathknight.unholy", name = "Unholy DK",
    heroTrees = {
      [32] = { key = "rider_of_the_apocalypse", name = "Rider of the Apocalypse" },
      [31] = { key = "sanlayn", name = "San'layn" },
    },
    primary = "runic_power", powerType = Enum.PowerType.RunicPower,
    secondary = "runes", secondaryType = Enum.PowerType.Runes,
    referenceSpellID = 85948, -- Festering Strike (specialization_spells.inc, spec 252)
    executeThresholds = {},
    contextCells = {
      maxrage = { export = "maxrunic_power", title = "MAX СР" },
      chargeRange = { export = "runeNext", title = "РУНА, С", source = "runeNext",
        tip = "Секунды до следующей готовой руны (GetRuneCooldown). ? — значения скрыты клиентом, — — все руны готовы." },
    },
  },
}

function ns.GetAPLProfile()
  local _, spec = ns.GetSpecData()
  return ns.specProfiles[spec]
end

function ns.GetMeleeReference()
  local profile = ns.GetAPLProfile()
  return profile and profile.referenceSpellID
end

-- Active hero tree of the profile: entry and subtree ID, or nil when the client
-- does not report it. An ID outside profile.heroTrees returns nil, id.
function ns.GetActiveHeroTree(profile)
  profile = profile or ns.GetAPLProfile()
  if not profile or not profile.heroTrees then return nil, nil end
  local id = C_ClassTalents and ns.ReadValue(C_ClassTalents.GetActiveHeroTalentSpec)
  if type(id) ~= "number" then return nil, nil end
  return profile.heroTrees[id], id
end

-- Spec preset plus the active hero tree's additions (for /ahw apl). A profile
-- with several hero trees refuses an unknown or unsupported tree.
function ns.GetAPLPreset(profile)
  local trees = 0
  for _ in pairs(profile.heroTrees or {}) do trees = trees + 1 end
  local hero, id = ns.GetActiveHeroTree(profile)
  if trees > 1 and not hero then
    if id then return nil, "героическая ветка " .. id .. " не поддержана профилем " .. profile.name end
    return nil, "активная героическая ветка не определена; повтори вне боя"
  end
  local base, extra = profile.preset, trees > 1 and hero.preset or nil
  if not base and not extra then return nil, "для " .. profile.name .. " набор HUD ещё не подготовлен" end
  if not (base and extra) then return base or extra, nil, trees > 1 and hero or nil end
  local merged = {}
  for _, kind in ipairs({ "spells", "procs", "debuffs" }) do
    merged[kind] = {}
    for _, list in ipairs({ base[kind] or {}, extra[kind] or {} }) do
      for _, spellID in ipairs(list) do merged[kind][#merged[kind] + 1] = spellID end
    end
  end
  return merged, nil, hero
end

ns.externalAuras = { [10060] = true, [2825] = true, [32182] = true, [80353] = true,
  [90355] = true, [160452] = true, [264667] = true, [390386] = true }
