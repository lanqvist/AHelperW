const fs = require('node:fs');
const path = require('node:path');
// Dependencies are kept in a temporary directory; no addon runtime dependency.
const deps = process.env.AHW_TEST_DEPS || path.join(process.env.TEMP, 'ahw-lua-check', 'node_modules');
const parser = require(path.join(deps, 'luaparse'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(deps, 'fengari'));
for (const f of fs.readdirSync('AHelperW').filter(f => f.endsWith('.lua'))) {
  parser.parse(fs.readFileSync(path.join('AHelperW', f), 'utf8'), { luaVersion: '5.1' });
}
// Expected values mirror AHelperW/SpecProfiles.lua; each spec runs in a fresh VM.
const specs = [
  { specID: 71, profileID: 'warrior.arms.slayer', reference: 12294, alias: ['heroic_strike', 1269383] },
  { specID: 72, profileID: 'warrior.fury.slayer', reference: 23881, alias: ['crushing_blow', 335097] },
];
for (const spec of specs) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_pushinteger(L, spec.specID);
  lua.lua_setglobal(L, to_luastring('SPEC_ID'));
  const status = lauxlib.luaL_dofile(L, to_luastring('tests/hud-context.lua'));
  if (status !== lua.LUA_OK) throw new Error(`spec ${spec.specID}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
  lua.lua_getglobal(L, to_luastring('HUD_EXPORT'));
  const config = JSON.parse(to_jsstring(lua.lua_tostring(L, -1)));
  const [aliasKey, aliasSpell] = spec.alias;
  if (!config.static || config.specID !== spec.specID || config.apl.profileID !== spec.profileID
    || config.targetCounting.referenceSpellID !== spec.reference
    || config.aliases[aliasKey]?.spellID !== aliasSpell
    || !(config.squares.length > 0) || config.context.targets.width <= 0
    || config.castReceipt?.version !== 2 || config.castReceipt.rows !== 8) {
    throw new Error(`Invalid export for spec ${spec.specID}`);
  }
}
console.log(`Lua 5.1 syntax and exported JSON schema checked for specs ${specs.map(s => s.specID).join(', ')}`);
