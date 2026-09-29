// Reproduce the Unholy action lists from the pinned GPL SimC snapshot (apl_death_knight.cpp).
// The pinned unholy() has no hero_tree.* conditions and no per-tree lists: Rider of the
// Apocalypse and San'layn run the same lists, so build-requirements keeps every rule
// verbatim; hero talents and their buffs are gated at runtime by the reader model.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const writeJson = (name, value) => fs.writeFileSync(new URL(name, root), JSON.stringify(value, null, 2) + '\n');
const source = readJson('source.json');
const text = fs.readFileSync(new URL(source.localSource, root), 'utf8');
const start = text.indexOf('void unholy(');
const end = text.indexOf('//unholy_apl_end', start);
if (start < 0 || end < 0) throw new Error('Unholy section missing');
const body = text.slice(start, end);
const lists = Object.fromEntries([...body.matchAll(/action_priority_list_t\*\s+(\w+)\s*=\s*p->get_action_priority_list\(\s*"([^"]+)"/g)]
  .map(m => [m[1], m[2] === 'default' ? 'default_' : m[2]]));
const actions = [...body.matchAll(/(\w+)->add_action\(\s*"([^"]+)"/g)].map(m => {
  if (!lists[m[1]]) throw new Error('Unknown list ' + m[1]);
  return {list: lists[m[1]], expression: m[2]};
});
const pattern = /\b(?:buff|debuff|dot|cooldown|talent|target|gcd|pet|hero_tree|raid_event|trinket|variable|death_knight)\.[a-zA-Z0-9_.]+/g;
const references = [...new Set(actions.flatMap(a => a.expression.match(pattern) || []))].sort();
if (references.some(r => r.startsWith('hero_tree.'))) throw new Error('hero_tree.* appeared: split build-requirements per tree');
writeJson('requirements.json', {specId:252, source, scope:'all-unholy-lists-unmodified', actions, references});

let talentGates = null, heroTree = null;
const decodedPath = new URL('decoded-build.json', root);
if (fs.existsSync(decodedPath)) {
  const decoded = JSON.parse(fs.readFileSync(decodedPath, 'utf8'));
  const trees = decoded.heroTrees.map(t => t.id ?? t);
  if (decoded.specId !== 252 || trees.length !== 1 || ![31, 32].includes(trees[0]))
    throw new Error('decoded-build.json is not an Unholy Rider/San\'layn build');
  heroTree = trees[0] === 31 ? 'sanlayn' : 'rider_of_the_apocalypse';
  const slug = n => n.toLowerCase().replaceAll("'", '').replace(/[^a-z0-9]+/g, '_');
  const names = new Set(decoded.selected.filter(t => t.rank > 0).map(t => slug(t.name)));
  // APL gates plus the talents that grant executable actions or replace them on
  // their buttons; the full personal selection stays in the ignored decoded-build.json.
  const actionTalents = ['army_of_the_dead', 'dark_transformation', 'outbreak', 'putrefy', 'scourge_strike',
    'soul_reaper', 'sudden_doom', 'festering_scythe', 'forbidden_knowledge', 'blightfall', 'vampiric_strike',
    'summon_gargoyle', 'raise_abomination', 'reaping', 'blightburst', 'cycle_of_death'].map(n => 'talent.' + n);
  const gates = [...new Set([...actions.flatMap(a => a.expression.match(/\btalent\.[a-z0-9_]+/g) || []), ...actionTalents])].sort();
  talentGates = Object.fromEntries(gates.map(r => [r, names.has(r.split('.')[1])]));
}
writeJson('build-requirements.json', {
  specId:252, clientBuild:source.clientBuild, heroTrees:['rider_of_the_apocalypse', 'sanlayn'], decodedHeroTree:heroTree, talentGates,
  note:'All unholy() lists verbatim: the pinned APL has no hero_tree.* conditions or per-tree lists. Talents and hero buffs are gated at runtime. Unknown inputs must remain unknown.',
  actions,
});
console.log(JSON.stringify({actions:actions.length, references:references.length, lists:[...new Set(Object.values(lists))],
  talentGates:talentGates ? 'decoded' : 'pending-build.txt'}));
