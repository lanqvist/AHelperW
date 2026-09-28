local _, ns = ...

-- Маппинг spec → HUD-набор по APL 12.1 Midnight (источник: docs/research-apl.md,
-- сверено с SimC midnight branch + wowhead). ID валидируются в рантайме — неизвестные скрываются.
-- spells: кулдауны (порядок = порядок квадратов). procs: ID АУР баффов (движковый AuraContainer).
-- secondary: Enum.PowerType.* | "RUNES" | nil. Первичный ресурс берётся из UnitPowerType.

local PT = Enum.PowerType

-- Additive preset for the user's decoded Arms/Slayer build (69933).
-- Provenance and exact talent export: docs/arms-apl/. These are display IDs,
-- not a priority order or a claim of full APL coverage. Existing custom lists
-- are preserved; apply explicitly with /ahw armsapl.
ns.armsAplPreset = {
  spells = { 12294, 7384, 845, 163201, 1464, 260708, 167105, 107574,
    227847, 384110, 107570, 100, 6552, 386164,
    69179, 255647, 312411, 26297, 20572, 265221, 274738 },
  procs = { 52437, 445606, 456120, 445584, 386633, 334783,
    260708, 107574, 446035, 1269391, 386164, 10060 },
  debuffs = { 208086, 388539 },
}

ns.classData = {
  -- Death Knight
  [250] = { secondary = "RUNES",
    spells = { 50842, 43265, 274156, 49028, 55233, 48707, 439843 },
    procs  = { 195181, 81141, 1310372, 433925 },
    debuffs = { 55078 } },                                                                -- Blood: Bone Shield, Crimson Scourge
  [251] = { secondary = "RUNES",
    spells = { 196770, 51271, 47568, 152279, 279302, 439843, 48707 },
    procs  = { 51124, 59052, 1230273, 53365 },
    debuffs = { 55095, 51714 } },                                                         -- Frost: Killing Machine, Rime
  [252] = { secondary = "RUNES",
    spells = { 1247378, 63560, 42650, 343294, 77575 },
    procs  = { 81340, 1254252, 1271199, 458123 },
    debuffs = { 1240996, 191587 } },                                                      -- Unholy: Sudden Doom, Lesser Ghoul

  -- Demon Hunter
  [577] = {
    spells = { 232893, 188499, 198013, 258920, 195072, 258860, 370965, 198793, 191427, 198589 },
    procs  = { 343312, 390145, 347462, 208628, 337567, 452416 },
    debuffs = { 320338, 391191 } },                                                       -- Havoc
  [581] = {
    spells = { 263642, 204596, 212084, 258920, 203720, 204021, 390163, 207407, 187827 },
    procs  = { 203981, 203819, 391166, 1256302 },
    debuffs = { 207771, 247456 } },                                                       -- Vengeance: Soul Fragments со стаками
  ["DEMONHUNTER:3"] = {
    spells = { 1226019, 1241937, 370965, 1245412, 1221167, 198589 },
    procs  = { 1256302, 1246160, 1232310, 1238488 },
    debuffs = { 1240201 },
    stackLinks = { [1226019] = 1256302 } },                                               -- Devourer [MN]; Reap ← стаки Voidfall

  -- Druid
  [102] = {
    spells = { 1239669, 202770, 205636, 194223, 391528, 274281, 88747, 22812 },
    procs  = { 48517, 48518, 393942, 393944, 450360, 1263382 },
    debuffs = { 164812, 164815 } },                                                       -- Balance: Eclipse, Starweaver
  [103] = { secondary = PT.ComboPoints,
    spells = { 5217, 274837, 106951, 391528, 1244258, 22812 },
    procs  = { 135700, 1244483, 391882, 441585, 69369 },
    debuffs = { 1079, 155722 } },                                                         -- Feral: Apex Predator
  [104] = {
    spells = { 33917, 77758, 204066, 1252871, 1253799, 50334, 391528, 22812, 61336, 22842 },
    procs  = { 201671, 441602, 1308647, 1308176, 192081 },
    debuffs = { 192090, 1252871 } },                                                      -- Guardian: Gory Fur, Ironfur uptime
  [105] = {
    spells = { 18562, 48438, 102693, 132158, 33891, 391528, 740, 197721, 29166, 102351 },
    procs  = { 16870, 114108, 207640 } },                                                 -- Restoration: Clearcasting, SotF

  -- Evoker
  [1467] = { secondary = PT.Essence,
    spells = { 357208, 359073, 375087, 357210, 370553, 358267, 363916 },
    procs  = { 359618, 375802, 370901, 370454 },
    debuffs = { 357209 } },                                                               -- Devastation: Essence Burst, Burnout
  [1468] = { secondary = PT.Essence,
    spells = { 366155, 355936, 373861, 357170, 370537, 363534, 359816, 374227 },
    procs  = { 369299, 373835, 373267, 1242031 } },                                       -- Preservation
  [1473] = { secondary = PT.Essence,
    spells = { 395152, 409311, 396286, 357208, 403631, 404977, 370553, 360827 },
    procs  = { 395296, 392268, 1297728 },
    debuffs = { 409560 } },                                                               -- Augmentation: Ebon Might self

  -- Hunter
  [253] = {
    spells = { 19574, 1264359, 217200, 34026, 466930, 109304, 264735 },
    procs  = { 1273043, 1299389 } },                                                      -- BM: Nature's Ally, Cobra Fang
  [254] = {
    spells = { 212431, 288613, 260243, 257044, 19434, 53351, 109304, 264735 },
    procs  = { 260242, 257622, 194594 },
    debuffs = { 466872, 212431 } },                                                       -- MM: Precise Shots, Lock and Load
  [255] = {
    spells = { 1250646, 1261193, 259495, 259489, 190925, 109304, 264735 },
    procs  = { 460852, 1252708 } },                                                       -- SV: Tip of the Spear

  -- Mage
  [62] = { secondary = PT.ArcaneCharges,
    spells = { 365350, 321507, 12051, 153626, 1241462, 205025, 342245, 45438 },
    procs  = { 263725, 1242974, 1296930, 451038 },
    debuffs = { 210824 } },                                                               -- Arcane: Clearcasting, Salvo
  [63] = {
    spells = { 190319, 153561, 108853, 2948, 212653, 45438 },
    procs  = { 48108, 48107, 269651, 383874, 1257348 },
    debuffs = { 12654 },
    stackLinks = { [190319] = 1257348 } },                                                -- Fire; Combustion ← стаки Fired Up (apex)
  [64] = {
    spells = { 205021, 153595, 84714, 44614, 157997, 235219, 212653, 45438 },
    procs  = { 44544, 190446, 1247730, 205473, 228600 },
    debuffs = { 1221389 } },                                                              -- Frost: FoF, Brain Freeze, Icicles + стаки Freezing на цели

  -- Monk
  [268] = {
    spells = { 121253, 115181, 325153, 119582, 322507, 115399, 115203, 132578, 322101, 109132 },
    procs  = { 228563, 215479, 195630, 325092, 1265307 },
    debuffs = { 121253 },
    stackLinks = { [322507] = 325092 } },                                                 -- Brewmaster; Celestial Brew ← стаки Purified Chi
  [269] = { secondary = PT.Chi,
    spells = { 1249625, 113656, 107428, 152175, 392983, 1248989, 123904, 322109, 109132 },
    procs  = { 116768, 1261844, 456368 },
    stackLinks = { [1249625] = 1261844 } },                                               -- WW; Zenith ← стаки Tigereye Brew
  [270] = {
    spells = { 115151, 116680, 467307, 107428, 115869, 116849, 115310, 322118 },
    procs  = { 202090, 392883, 446326, 1260511, 388491 } },                               -- MW: Teachings, Spiritfont

  -- Paladin
  [65] = { secondary = PT.HolyPower,
    spells = { 20473, 20271, 375576, 114165, 200025, 384376, 31821, 6940 },
    procs  = { 54149, 387178 } },                                                         -- Holy: Infusion of Light
  [66] = { secondary = PT.HolyPower,
    spells = { 275779, 31935, 204019, 24275, 26573, 375576, 31884, 31850, 86659, 642 },
    procs  = { 327510, 132403, 1267203, 433106 },
    stackLinks = { [26573] = 433106 } },                                                  -- Prot; Consecration ← стаки Divine Guidance
  [70] = { secondary = PT.HolyPower,
    spells = { 184575, 20271, 255937, 24275, 343527, 375576, 31884, 184662, 633 },
    procs  = { 387178 },
    debuffs = { 383346 } },                                                               -- Ret: Empyrean Legacy

  -- Priest
  [256] = {
    spells = { 47540, 194509, 8092, 246287, 123040, 421453, 62618, 33206 },
    procs  = { 1253828, 1253724, 114255, 450612 },
    debuffs = { 589 } },                                                                  -- Disc: Void Shield, Greater Smite
  [257] = {
    spells = { 2050, 34861, 88625, 200183, 64843, 47788, 204883 },
    procs  = { 114255, 390993, 390636 } },                                                -- Holy: Surge of Light, Lightweaver
  [258] = {
    spells = { 228260, 263165, 200174, 32379, 8092, 10060, 47585, 15286 },
    procs  = { 373204, 375981, 390978, 194249 },
    debuffs = { 589, 34914, 335467 } },                                                   -- Shadow: Mind Devourer, Voidform

  -- Rogue
  [259] = { secondary = PT.ComboPoints,
    spells = { 360194, 385627, 5938, 381623, 382245, 408, 1856, 5277, 31224, 185311 },
    procs  = { 457280, 1273017 },
    debuffs = { 703, 1943, 457129 } },                                                    -- Assa: Darkest Night
  [260] = { secondary = PT.ComboPoints,
    spells = { 13750, 315508, 381989, 315341, 51690, 271877, 13877, 408, 1856, 185311 },
    procs  = { 1214933, 1214934, 1214935, 1214937, 195627, 256171 } },                    -- Outlaw: стадии RtB, Opportunity
  [261] = { secondary = PT.ComboPoints,
    spells = { 185313, 121471, 280719, 426591, 382245, 408, 1856, 185311 },
    procs  = { 185422, 457280, 343173 } },                                                -- Sub: Dance window, Darkest Night

  -- Shaman
  [262] = {
    spells = { 191634, 114050, 443454, 470053, 51505, 108271 },
    procs  = { 77762, 260734, 454015, 191877, 1300219 },
    debuffs = { 188389, 197209 },
    stackLinks = { [191634] = 191634 } },                                                 -- Ele; Stormkeeper ← заряды своего бафа
  [263] = {
    spells = { 17364, 60103, 187874, 384352, 114051, 444995, 197214, 1218090, 108271 },
    procs  = { 344179, 201846, 215785, 466772, 454015 },
    debuffs = { 188389 },
    stackLinks = { [17364] = 198300 } },                                                  -- Enh; Stormstrike ← стаки Converging Storms (талант)
  [264] = {
    spells = { 444995, 5394, 73685, 378081, 108280, 114052, 98008, 61295 },
    procs  = { 53390 } },                                                                 -- Resto: Tidal Waves

  -- Warlock
  [265] = { secondary = PT.SoulShards,
    spells = { 1257052, 205180, 442726, 48181, 104773, 108416 },
    procs  = { 264571, 1261125, 1260269, 1305774 },
    debuffs = { 980, 316099 } },                                                          -- Aff: Nightfall, Shard Instability
  [266] = { secondary = PT.SoulShards,
    spells = { 104316, 265187, 264130, 1276452, 1276467, 1276672, 104773 },
    procs  = { 264173, 1276166, 433885, 433891 },
    debuffs = { 460553 } },                                                               -- Demo: Demonic Core
  [267] = { secondary = PT.SoulShards,
    spells = { 1122, 6353, 152108, 17962, 17877, 80240, 442726, 104773 },
    procs  = { 117828, 433885, 433891, 1244947 },
    debuffs = { 157736 } },                                                               -- Destro: Backdraft, Ruination

  -- Warrior
  [71] = {
    spells = { 12294, 7384, 845, 260708, 167105, 107574, 227847, 376079, 436358, 228920 },
    procs  = { 52437, 386633, 334783 },
    debuffs = { 208086, 388539 },
    stackLinks = { [227847] = 445606, [260708] = 260708 } },                              -- Arms; стаки: Вихрь←Imminent Demise, Размашистые←свой бафф
  [72] = {
    spells = { 23881, 85288, 1719, 107574, 227847, 385059, 184364 },
    procs  = { 184362, 280776, 85739, 435615 },
    stackLinks = { [227847] = 445606 } },                                                 -- Fury; стаки Imminent Demise в углу Вихря клинков
  [73] = {
    spells = { 23922, 6343, 2565, 190456, 6572, 385952, 1160, 401150, 871, 12975 },
    procs  = { 386478, 386486, 52437, 5302, 437121 },
    debuffs = { 115767 } },                                                               -- Prot: Violent Outburst, Seeing Red
}

-- Поиск: сначала по specID, затем по "CLASSFILE:specIndex" (для новых спеков без известного ID).
-- Возвращает data, key — key служит и ключом пользовательских наборов в SavedVariables.
function ns.GetSpecData()
  local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
    and C_SpecializationInfo.GetSpecialization()
    or (GetSpecialization and GetSpecialization())
  if not specIndex then return nil, nil end

  local specID
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    specID = C_SpecializationInfo.GetSpecializationInfo(specIndex)
  elseif GetSpecializationInfo then
    specID = GetSpecializationInfo(specIndex)
  end

  if specID and ns.classData[specID] then
    return ns.classData[specID], specID
  end
  local _, classFile = UnitClass("player")
  local key = (classFile or "?") .. ":" .. specIndex
  return ns.classData[key], key
end

-- Итоговые списки для HUD: пользовательский набор (если есть) или дефолт спека
function ns.GetTrackList()
  local data, key = ns.GetSpecData()
  local custom = key and ns.db and ns.db.custom and ns.db.custom[key]
  local spells  = (custom and custom.spells)  or (data and data.spells)  or {}
  local procs   = (custom and custom.procs)   or (data and data.procs)   or {}
  local debuffs = (custom and custom.debuffs) or (data and data.debuffs) or {}
  return spells, procs, debuffs, data, key
end

-- Copy-on-write: первый /ahw add|del копирует дефолты спека в SavedVariables
function ns.EnsureCustom()
  local data, key = ns.GetSpecData()
  if not key then return nil end
  ns.db.custom = ns.db.custom or {}
  local c = ns.db.custom[key]
  if not c then
    c = { spells = {}, procs = {}, debuffs = {} }
    if data then
      for i, id in ipairs(data.spells or {}) do c.spells[i] = id end
      for i, id in ipairs(data.procs or {}) do c.procs[i] = id end
      for i, id in ipairs(data.debuffs or {}) do c.debuffs[i] = id end
    end
    ns.db.custom[key] = c
  end
  c.debuffs = c.debuffs or {} -- наборы, сохранённые до появления дебаффов
  return c, key
end

-- One-time additive upgrade for the Arms build being developed in this project.
-- Later manual removals remain respected. The same list is available via /ahw armsapl.
function ns.ExpandArmsHUD()
  local _, key = ns.GetSpecData()
  local _, build = GetBuildInfo()
  if key ~= 71 or tostring(build) ~= "69933" or ns.db.armsHudVersion == 2 then return end
  local c = ns.EnsureCustom()
  for _, kind in ipairs({ "spells", "procs", "debuffs" }) do
    local present = {}
    for _, id in ipairs(c[kind]) do present[id] = true end
    for _, id in ipairs(ns.armsAplPreset[kind]) do
      if not present[id] and C_Spell.GetSpellInfo(id) then c[kind][#c[kind] + 1] = id end
    end
  end
  ns.db.cdText, ns.db.auraTimers, ns.db.armsHudVersion = true, true, 2
end
