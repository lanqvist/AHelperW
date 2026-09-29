const fs = require('node:fs');
const path = require('node:path');
// Dependencies are kept in a temporary directory; no addon runtime dependency.
const deps = process.env.AHW_TEST_DEPS || path.join(process.env.TEMP, 'ahw-lua-check', 'node_modules');
const parser = require(path.join(deps, 'luaparse'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(deps, 'fengari'));
for (const f of fs.readdirSync('AHelperW').filter(f => f.endsWith('.lua'))) {
  parser.parse(fs.readFileSync(path.join('AHelperW', f), 'utf8'), { luaVersion: '5.1' });
}
// Expected values mirror AHelperW/SpecProfiles.lua; each entry runs in a fresh VM.
// heroID is the client's active hero subtree (mocked); resources/context list
// the keys the export must contain once Core has built the resource row.
const specs = [
  { specID: 71, profileID: 'warrior.arms.slayer', reference: 12294, alias: ['heroic_strike', 1269383], heroID: 60,
    heroTree: 'slayer', resources: ['rage'], context: ['chargeRange', 'maxrage'] },
  { specID: 72, profileID: 'warrior.fury.slayer', reference: 23881, alias: ['crushing_blow', 335097], heroID: 60,
    heroTree: 'slayer', resources: ['rage'], context: ['chargeRange', 'maxrage'] },
  { specID: 269, profileID: 'monk.windwalker.shado-pan', reference: 100780, alias: ['rushing_wind_kick', 467307], heroID: 65,
    heroTree: 'shado_pan', resources: ['energy', 'chi'], context: ['energyRegen', 'maxenergy', 'zenithRecharge'], comboHistory: true },
  // Death Knight: runic power number, six rune squares. Frost entries — Frost work only.
  { specID: 251, profileID: 'deathknight.frost', reference: 49020, alias: ['frostbane', 1228433], heroID: 33, heroTree: 'deathbringer',
    resources: ['runic_power'], context: ['runeNext', 'maxrunic_power'], runes: true },
  { specID: 251, profileID: 'deathknight.frost', reference: 49020, alias: ['frostbane', 1228433], heroID: 32, heroTree: 'rider_of_the_apocalypse',
    resources: ['runic_power'], context: ['runeNext', 'maxrunic_power'], runes: true },
  // Unholy entries — Unholy work only.
  { specID: 252, profileID: 'deathknight.unholy', reference: 85948, alias: ['vampiric_strike', 433895], heroID: 32,
    heroTree: 'rider_of_the_apocalypse', resources: ['runic_power'], context: ['runeNext', 'maxrunic_power'], runes: true },
  { specID: 252, profileID: 'deathknight.unholy', reference: 85948, alias: ['vampiric_strike', 433895], heroID: 31,
    heroTree: 'sanlayn', resources: ['runic_power'], context: ['runeNext', 'maxrunic_power'], runes: true },
  // End of DK entries.
];
const legacyTree = new Set([71, 72, 269]);
for (const spec of specs) {
  const name = `spec ${spec.specID}/${spec.heroTree}`;
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_pushinteger(L, spec.specID);
  lua.lua_setglobal(L, to_luastring('SPEC_ID'));
  lua.lua_pushinteger(L, spec.heroID);
  lua.lua_setglobal(L, to_luastring('HERO_ID'));
  const status = lauxlib.luaL_dofile(L, to_luastring('tests/hud-context.lua'));
  if (status !== lua.LUA_OK) throw new Error(`${name}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
  const read = key => { lua.lua_getglobal(L, to_luastring(key)); return JSON.parse(to_jsstring(lua.lua_tostring(L, -1))); };
  const config = read('HUD_EXPORT'), full = read('HUD_EXPORT_FULL');
  const fail = why => { throw new Error(`Invalid export for ${name}: ${why}`); };
  if (!config.static || config.specID !== spec.specID || config.apl.profileID !== spec.profileID
    || config.targetCounting.referenceSpellID !== spec.reference
    || !(config.squares.length > 0) || config.context.targets.width <= 0
    || config.castReceipt?.version !== 2 || config.castReceipt.rows !== 8) fail('schema');
  if (spec.alias && config.aliases[spec.alias[0]]?.spellID !== spec.alias[1]) fail('alias');
  // Single-tree profiles keep their static tree and export no subtree ID.
  if (full.apl.heroTree !== spec.heroTree) fail(`heroTree ${full.apl.heroTree}`);
  if (legacyTree.has(spec.specID) ? 'heroTreeID' in full.apl : full.apl.heroTreeID !== spec.heroID) fail('heroTreeID');
  for (const key of spec.resources) if (!(full.resources[key]?.width > 0) || !full.resourceMeta[key]) fail(`resource ${key}`);
  for (const key of spec.context) if (!(full.context[key]?.width > 0)) fail(`context ${key}`);
  if (!spec.context.includes('chargeRange') && 'chargeRange' in full.context) fail('chargeRange must be renamed');
  if (!!full.comboHistory !== !!spec.comboHistory) fail('comboHistory');
  if (spec.runes ? !(full.runes?.version === 1 && full.runes.rects.length === 6 && !('runes' in full.resources))
    : 'runes' in full) fail('runes');
}
{
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  if (lauxlib.luaL_dofile(L, to_luastring('tests/target-count.lua')) !== lua.LUA_OK)
    throw new Error(`target count: ${to_jsstring(lua.lua_tostring(L, -1))}`);
}
console.log(`Lua 5.1 syntax, exported JSON schema (${specs.map(s => `${s.specID}/${s.heroTree}`).join(', ')}) and target count timing checked`);
