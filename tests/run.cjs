const fs = require('node:fs');
const path = require('node:path');
// Dependencies are kept in a temporary directory; no addon runtime dependency.
const deps = process.env.AHW_TEST_DEPS || path.join(process.env.TEMP, 'ahw-lua-check', 'node_modules');
const parser = require(path.join(deps, 'luaparse'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(deps, 'fengari'));
for (const f of fs.readdirSync('AHelperW').filter(f => f.endsWith('.lua'))) {
  parser.parse(fs.readFileSync(path.join('AHelperW', f), 'utf8'), { luaVersion: '5.1' });
}
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const status = lauxlib.luaL_dofile(L, to_luastring('tests/hud-context.lua'));
if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
lua.lua_getglobal(L, to_luastring('HUD_EXPORT'));
const config = JSON.parse(to_jsstring(lua.lua_tostring(L, -1)));
if (!config.static || config.specID !== 71 || config.context.targets.width <= 0) throw new Error('Invalid export');
console.log('Lua 5.1 syntax and exported JSON schema checked');
