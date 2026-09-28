// Reproduce the Fury action lists from the pinned GPL SimC snapshot shared with Arms.
// The Slayer narrowing only removes Mountain Thane lists; other conditions stay verbatim.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const writeJson = (name, value) => fs.writeFileSync(new URL(name, root), JSON.stringify(value, null, 2) + '\n');
const source = readJson('source.json');
const shared = readJson('../arms-apl/source.json');
if (shared.commit !== source.commit) throw new Error('Arms and Fury sources are pinned to different commits');
const text = fs.readFileSync(new URL(source.sharedSource, root), 'utf8');
const start = text.indexOf('void fury(');
const end = text.indexOf('//fury_apl_end', start);
if (start < 0 || end < 0) throw new Error('Fury section missing');
const body = text.slice(start, end);
const lists = Object.fromEntries([...body.matchAll(/action_priority_list_t\*\s+(\w+)\s*=\s*p->get_action_priority_list\(\s*"([^"]+)"/g)]
  .map(m => [m[1], m[2] === 'default' ? 'default_' : m[2]]));
const actions = [...body.matchAll(/(\w+)->add_action\(\s*"([^"]+)"/g)].map(m => {
  if (!lists[m[1]]) throw new Error('Unknown list ' + m[1]);
  return {list: lists[m[1]], expression: m[2]};
});
const references = [...new Set(actions.flatMap(a => a.expression.match(/\b(?:buff|debuff|dot|cooldown|talent|target|gcd|movement|raid_event|trinket|variable)\.[a-zA-Z0-9_.]+/g) || []))].sort();
writeJson('requirements.json', {specId:72, source, scope:'all-fury-branches-unmodified', actions, references});

const thane = new Set(['thane', 'thane_aoe']);
const slayer = actions.filter(a => !thane.has(a.list) && !/name=(thane|thane_aoe)\b/.test(a.expression));
let talentGates = null, executeThresholdPercent = null;
const decodedPath = new URL('decoded-build.json', root);
if (fs.existsSync(decodedPath)) {
  const decoded = JSON.parse(fs.readFileSync(decodedPath, 'utf8'));
  if (decoded.specId !== 72 || decoded.heroTrees.length !== 1 || decoded.heroTrees[0] !== 60)
    throw new Error('decoded-build.json is not a Fury/Slayer build');
  const names = new Set(decoded.selected.filter(t => t.rank > 0).map(t => t.name.toLowerCase().replaceAll("'", '').replace(/[^a-z0-9]+/g, '_')));
  // APL gates plus the talents that grant executable actions or change their IDs;
  // the full personal selection stays in the ignored decoded-build.json.
  const actionTalents = ['avatar', 'berserker_stance', 'bladestorm', 'bloodthirst', 'odyns_fury', 'raging_blow',
    'rampage', 'reckless_abandon', 'recklessness', 'storm_bolt', 'unrelenting_onslaught'].map(n => 'talent.' + n);
  const gates = [...new Set([...slayer.flatMap(a => a.expression.match(/\btalent\.[a-z0-9_.]+/g) || []), ...actionTalents])].sort();
  talentGates = Object.fromEntries(gates.map(r => [r, names.has(r.split('.')[1])]));
  executeThresholdPercent = names.has('massacre') ? 35 : 20;
}
writeJson('build-requirements.json', {
  specId:72, clientBuild:source.clientBuild, heroTree:'slayer', executeThresholdPercent, talentGates,
  note:'Mountain Thane lists removed. Other conditions are retained verbatim; runtime talent gates. Unknown inputs must remain unknown.',
  actions:slayer,
});
console.log(JSON.stringify({actions:actions.length, slayerActions:slayer.length, references:references.length,
  lists:Object.values(lists), talentGates:talentGates ? 'decoded' : 'pending-build.txt'}));
