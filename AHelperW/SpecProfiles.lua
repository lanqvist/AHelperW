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
  -- --- Frost DK (251): edited only by the Frost work ---
  -- Reader model: reader/dk_frost_apl.py. IDs and evidence: docs/dk-frost-apl/coverage.json
  -- (pinned sc_death_knight.cpp, trait table, Wowhead); nothing observed in game yet.
  [251] = {
    id = "deathknight.frost", name = "Frost DK",
    heroTrees = {
      -- Reaper's Mark and its target debuff (rune_pooling, cooldowns).
      [33] = { key = "deathbringer", name = "Deathbringer",
        preset = { spells = { 439843 }, procs = {}, debuffs = { 434765 } } },
      -- The pinned APL names Rider only in target_if/trinket rules; Apocalypse
      -- Now acts through Frostwyrm's Fury (shared preset).
      [32] = { key = "rider_of_the_apocalypse", name = "Rider of the Apocalypse",
        preset = { spells = {}, procs = {}, debuffs = {} } },
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
    -- sc_death_knight.cpp set_replacement_action: the APL keeps frost_strike /
    -- frostwyrms_fury; while the buff is up the same button casts the replacement.
    aliases = {
      frostbane = { spellID = 1228433, displaySpellID = 49143, procID = 1229310, sharesBindingWith = "frost_strike", label = "Frostbane" },
      chosen_of_frostbrood = { spellID = 1265384, displaySpellID = 279302, procID = 1265639, sharesBindingWith = "frostwyrms_fury", label = "Chosen of Frostbrood" },
    },
    -- Shared by both hero trees. Spells: Obliterate, Frost Strike, Howling Blast,
    -- Frostscythe, Glacial Advance, Remorseless Winter, Pillar of Frost, Breath of
    -- Sindragosa (1249658 in the pinned trait table), Frostwyrm's Fury, Empower Rune
    -- Weapon, Raise Dead, Mind Freeze, racials. Procs: Killing Machine, Rime, Pillar,
    -- Breath, Remorseless Winter (196770; 1233152 with Frozen Dominion), Gathering
    -- Storm, Icy Onslaught, Bonegrinder, Frostbane, Unholy Strength, Chosen of
    -- Frostbrood (haste, recall), PI. Debuffs: Razorice, Frost Fever.
    preset = {
      spells = { 49020, 49143, 49184, 207230, 194913, 196770, 51271, 1249658, 279302, 47568,
        46585, 47528,
        20572, 26297, 260364, 255647, 274738, 265221, 312411 },
      procs = { 51124, 59052, 51271, 1249658, 196770, 1233152, 211805, 1230273, 377103, 1229310,
        53365, 1265630, 1265639, 10060 },
      debuffs = { 51714, 55095 },
    },
  },
  -- --- Unholy DK (252): edited only by the Unholy work ---
  -- In development, not seen in game; reader model: reader/dk_unholy_apl.py. IDs and
  -- evidence: docs/dk-unholy-apl/coverage.json. The pinned APL shares its lists
  -- between both trees; San'layn adds only its Vampiric Strike auras.
  [252] = {
    id = "deathknight.unholy", name = "Unholy DK",
    heroTrees = {
      [32] = { key = "rider_of_the_apocalypse", name = "Rider of the Apocalypse",
        preset = { spells = {}, procs = {}, debuffs = {} } },
      -- Vampiric Strike 433899, Essence of the Blood Queen 433925, Gift of the San'layn 434153.
      [31] = { key = "sanlayn", name = "San'layn",
        preset = { spells = {}, procs = { 433899, 433925, 434153 }, debuffs = {} } },
    },
    primary = "runic_power", powerType = Enum.PowerType.RunicPower,
    secondary = "runes", secondaryType = Enum.PowerType.Runes,
    referenceSpellID = 85948, -- Festering Strike (specialization_spells.inc, spec 252)
    executeThresholds = {35}, -- Soul Reaper: target at or below 35% (or Reaping)
    -- Replacements cast from the base button while their aura is up (sc_death_knight.cpp
    -- set_replacement_action); they share its binding.
    aliases = {
      festering_scythe = { spellID = 458128, displaySpellID = 85948, procID = 458123, sharesBindingWith = "festering_strike", label = "Festering Scythe" },
      vampiric_strike = { spellID = 433895, displaySpellID = 55090, procID = 433899, sharesBindingWith = "scourge_strike", label = "Vampiric Strike" },
      necrotic_coil = { spellID = 1242174, displaySpellID = 47541, procID = 1242223, sharesBindingWith = "death_coil", label = "Necrotic Coil" },
      graveyard = { spellID = 383269, displaySpellID = 207317, procID = 1242223, sharesBindingWith = "epidemic", label = "Graveyard" },
      blightfall = { spellID = 1271967, displaySpellID = 1233448, procID = 1271975, sharesBindingWith = "dark_transformation", label = "Blightfall" },
    },
    -- Spells: Festering Strike, Scourge Strike, Death Coil, Epidemic, Putrefy, Soul Reaper,
    -- Outbreak, Army of the Dead, Dark Transformation, Death and Decay, racials (DK Arcane
    -- Torrent 50613). Procs: Sudden Doom, Dark Transformation, Forbidden Knowledge, Lesser
    -- Ghoul, Festering Scythe, Blightfall, Blighted (set), Army of the Dead, Reaping, PI.
    -- Debuffs: Virulent Plague, Dread Plague, Soul Reaper, Festering Scythe (target).
    preset = {
      spells = { 85948, 55090, 47541, 207317, 1247378, 343294, 77575, 42650, 1233448, 43265,
        50613, 255647, 312411, 26297, 20572, 265221, 274738, 260364 },
      procs = { 81340, 1235391, 1242223, 1254252, 458123, 1271975, 1271199, 42650, 1242654, 10060 },
      debuffs = { 191587, 1240996, 1241521, 1241077 },
    },
    contextCells = {
      maxrage = { export = "maxrunic_power", title = "MAX СР" },
      chargeRange = { export = "runeNext", title = "РУНА, С", source = "runeNext",
        tip = "Секунды до следующей готовой руны (GetRuneCooldown). ? — значения скрыты клиентом, — — все руны готовы." },
    },
  },
  -- --- end of DK entries ---
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
