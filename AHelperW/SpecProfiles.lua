local _, ns = ...

-- Static specialization configuration. Live/secret values belong to renderers.
ns.specProfiles = {
  [71] = {
    id = "warrior.arms.slayer", name = "Arms / Slayer", heroTree = "slayer",
    primary = "rage", powerType = Enum.PowerType.Rage, referenceSpellID = 12294,
    executeThresholds = {20, 35},
    aliases = { heroic_strike = { spellID = 1269383, displaySpellID = 1464, procID = 1269391, sharesBindingWith = "slam" } },
  },
  [269] = {
    id = "monk.windwalker.shado-pan", name = "ВВ / Шадо-Пан", heroTree = "shado_pan",
    primary = "energy", secondary = "chi", powerType = Enum.PowerType.Energy,
    secondaryType = Enum.PowerType.Chi, referenceSpellID = 100780,
    executeThresholds = {15},
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
}

function ns.GetAPLProfile()
  local _, spec = ns.GetSpecData()
  return ns.specProfiles[spec]
end

function ns.GetMeleeReference()
  local profile = ns.GetAPLProfile()
  return profile and profile.referenceSpellID
end

ns.externalAuras = { [10060] = true, [2825] = true, [32182] = true, [80353] = true,
  [90355] = true, [160452] = true, [264667] = true, [390386] = true }
