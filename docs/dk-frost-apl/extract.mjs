// Reproduce the Frost DK action lists from the pinned GPL SimC snapshot.
// The pinned frost() lists do not split by hero tree: Deathbringer (33) and
// Rider of the Apocalypse (32) share every list and differ only through runtime
// hero_tree.* / talent.* conditions. No condition, target selector or option is
// edited here; reader adaptations live in reader/dk_frost_apl.py and are labelled.
import crypto from 'node:crypto';
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const writeJson = (name, value) => fs.writeFileSync(new URL(name, root), JSON.stringify(value, null, 2) + '\n');
const source = readJson('source.json');
// Git may check the file out with CRLF; the pinned hash is of the LF text.
const text = fs.readFileSync(new URL(source.localSource, root), 'utf8').replace(/\r\n/g, '\n');
const sha = crypto.createHash('sha256').update(text).digest('hex');
if (sha !== source.localSourceSha256) throw new Error('apl_death_knight.cpp differs from the pinned snapshot');
const start = text.indexOf('void frost(');
const end = text.indexOf('//frost_apl_end', start);
if (start < 0 || end < 0) throw new Error('Frost section missing');
const body = text.slice(start, end);
const lists = Object.fromEntries([...body.matchAll(/action_priority_list_t\*\s+(\w+)\s*=\s*p->get_action_priority_list\(\s*"([^"]+)"/g)]
  .map(m => [m[1], m[2] === 'default' ? 'default_' : m[2]]));
const actions = [...body.matchAll(/(\w+)->add_action\(\s*"([^"]+)"/g)].map(m => {
  if (!lists[m[1]]) throw new Error('Unknown list ' + m[1]);
  return {list: lists[m[1]], expression: m[2]};
});
const refPattern = /\b(?:buff|debuff|dot|cooldown|talent|target|gcd|movement|raid_event|trinket|variable|hero_tree|death_knight|main_hand|rune|runic_power)\.[a-zA-Z0-9_.]+/g;
const references = [...new Set(actions.flatMap(a => a.expression.match(refPattern) || []))].sort();
writeJson('requirements.json', {specId:251, source, scope:'all-frost-branches-unmodified', actions, references});

// Hero trees of spec 251 in the pinned trait table (subtree switch, tree 4).
const traits = JSON.parse(fs.readFileSync(new URL(source.traitTable, root), 'utf8'));
if (traits.build !== source.clientBuild) throw new Error('Trait table and source are for different builds');
const heroTrees = Object.fromEntries(Object.entries(traits.subtrees).filter(([, t]) => t.specs.includes(251))
  .map(([id, t]) => [id, t.name]));
if (Object.keys(heroTrees).sort().join() !== '32,33') throw new Error('Unexpected Frost hero trees: ' + JSON.stringify(heroTrees));
const heroKeys = {33:'deathbringer', 32:'rider_of_the_apocalypse'};
// Rules whose text names a hero tree; everything else is shared verbatim.
const heroRules = Object.fromEntries(Object.entries(heroKeys).map(([id, key]) =>
  [id, actions.filter(a => a.expression.includes('hero_tree.' + key)).map(a => `${a.list}: ${a.expression}`)]));

// Optional personal build (ignored by Git): talent gates for the README/coverage only.
let talentGates = null, decodedHeroTree = null;
const decodedPath = new URL('decoded-build.json', root);
if (fs.existsSync(decodedPath)) {
  const decoded = JSON.parse(fs.readFileSync(decodedPath, 'utf8'));
  if (decoded.specId !== 251 || decoded.heroTrees.length !== 1 || !heroKeys[decoded.heroTrees[0].id])
    throw new Error('decoded-build.json is not a Frost Deathbringer/Rider build');
  decodedHeroTree = decoded.heroTrees[0].id;
  const names = new Set(decoded.selected.filter(t => t.rank > 0 && (!t.subtree || t.subtree === decodedHeroTree))
    .map(t => t.name.toLowerCase().replaceAll("'", '').replace(/[^a-z0-9]+/g, '_')));
  const actionTalents = ['frost_strike', 'obliterate', 'howling_blast', 'killing_machine', 'empower_rune_weapon', 'frostscythe',
    'pillar_of_frost', 'frostwyrms_fury', 'breath_of_sindragosa', 'reapers_mark', 'raise_dead', 'mind_freeze', 'frozen_dominion',
    'frostbane'].map(n => 'talent.' + n);
  const gates = [...new Set([...actions.flatMap(a => a.expression.match(/\btalent\.[a-z0-9_]+/g) || []), ...actionTalents])].sort();
  talentGates = Object.fromEntries(gates.map(r => [r, names.has(r.split('.')[1])]));
}
writeJson('build-requirements.json', {
  specId:251, clientBuild:source.clientBuild, heroTrees, heroTreeKeys:heroKeys, decodedHeroTree, talentGates,
  note:'Pinned Frost lists are shared by both hero trees and kept whole: hero_tree.* and talent.* are evaluated at runtime. '
    + 'Conditions and target selectors are verbatim; reader adaptations are labelled in reader/dk_frost_apl.py. Unknown inputs must remain unknown.',
  heroTreeRules:heroRules,
  actions,
});
console.log(JSON.stringify({actions:actions.length, references:references.length, lists:Object.values(lists),
  heroTreeRules:Object.fromEntries(Object.entries(heroRules).map(([k, v]) => [k, v.length])),
  talentGates:talentGates ? 'decoded' : 'pending-build.txt'}));
