// Executes actual service-independent Lua modules, with Roblox dependencies mocked
// by each test. This is not a Luau type checker or a Roblox engine emulator.
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const root = path.resolve(__dirname, '..');
const testDirectory = path.join(root, 'tests');
const tests = fs.readdirSync(testDirectory).filter(name => name.endsWith('.lua')).sort();
if (tests.length === 0) throw new Error('No regression tests found');
let failed = 0;
for (const name of tests) {
  const state = lauxlib.luaL_newstate();
  try {
    lualib.luaL_openlibs(state);
    // Fengari's JS runtime has no native filesystem dofile. Inline the explicitly
    // named source module unchanged; each test receives an isolated Lua state.
    const source = fs.readFileSync(path.join(testDirectory, name), 'utf8')
      .replace(/dofile\("([^"]+)"\)/g, (_, relative) => {
        const filename = path.resolve(root, relative);
        if (!filename.startsWith(root + path.sep)) throw new Error('Module path outside project');
        return '(function()\n' + fs.readFileSync(filename, 'utf8') + '\nend)()';
      });
    const status = lauxlib.luaL_dostring(state, to_luastring(source));
    if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
    console.log('PASS ' + name);
  } catch (error) {
    failed++;
    console.error('FAIL ' + name + ': ' + error.message);
  } finally {
    lua.lua_close(state);
  }
}
console.log(`${tests.length - failed}/${tests.length} suites passed`);
process.exitCode = failed ? 1 : 0;
