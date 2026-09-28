// Reproduce the Windwalker action lists from the pinned GPL SimC snapshot.
// No conditions, target selectors or channel options are discarded.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const text = fs.readFileSync(new URL('apl_monk.cpp',root),'utf8');
const start = text.indexOf('void live_apl(',text.indexOf('namespace windwalker'));
const end = text.indexOf('void ptr_apl(',start);
if (start < 0 || end < 0) throw new Error('Windwalker section missing');
const body = text.slice(start,end);
const lists = Object.fromEntries([...body.matchAll(/action_priority_list_t\*\s+(\w+)\s*=\s*player->get_action_priority_list\(\s*"([^"]+)"/g)].map(m=>[m[1],m[2]==='default'?'default_':m[2]]));
const actions = [...body.matchAll(/(\w+)->add_action\(\s*"([^"]+)"/g)].map(m=>{
  if (!lists[m[1]]) throw new Error('Unknown list '+m[1]);
  return {list:lists[m[1]],expression:m[2]};
});
const references = [...new Set(actions.flatMap(a=>a.expression.match(/\b(?:buff|cooldown|talent|target|gcd|pet|fight_style|trinket|variable|prev|energy|chi)\.[a-zA-Z0-9_.]+/g)||[]))].sort();
const source=JSON.parse(fs.readFileSync(new URL('source.json',root),'utf8'));
fs.writeFileSync(new URL('requirements.json',root),JSON.stringify({specId:269,source,scope:'all-windwalker-branches-unmodified',actions,references},null,2)+'\n');
fs.writeFileSync(new URL('build-requirements.json',root),JSON.stringify({specId:269,clientBuild:source.clientBuild,actions,note:'Full pinned Windwalker lists; runtime talent gates. Unknown inputs must remain unknown.'},null,2)+'\n');
console.log(JSON.stringify({actions:actions.length,references:references.length,lists:Object.values(lists)}));
