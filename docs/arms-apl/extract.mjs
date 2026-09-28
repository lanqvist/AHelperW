// Extract references, not evaluate APL or decode talents.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const source = fs.readFileSync(new URL('apl_warrior.cpp', root), 'utf8');
const begin = source.indexOf('void arms(');
const end = source.indexOf('//arms_apl_end', begin);
if (begin < 0 || end < 0) throw new Error('Arms section missing');
const arms = source.slice(begin, end);
const actions = [];
for (const line of arms.split('\n')) {
  const match = line.match(/^\s*(\w+)->add_action\(\s*"([^"]+)"/);
  if (match) actions.push({list: match[1], expression: match[2]});
}
const refs = [...new Set(actions.flatMap(a => a.expression.match(/\b(?:buff|debuff|dot|cooldown|talent|target|gcd|movement|raid_event|trinket|variable)\.[a-zA-Z0-9_.]+/g) || []))].sort();
const decodedPath = new URL('decoded-build.json', root);
const decoded = fs.existsSync(decodedPath) ? JSON.parse(fs.readFileSync(decodedPath, 'utf8')) : null;
const manifest = {
  source: JSON.parse(fs.readFileSync(new URL('source.json', root), 'utf8')),
  specId: 71,
  talentString: fs.readFileSync(new URL('build.txt', root), 'utf8').trim(),
  talentDecodeStatus: decoded ? 'decoded-matching-build-not-client-validated' : 'pending-version-matched-tree',
  scope: 'all-arms-branches-not-filtered-to-user-talents',
  actions,
  references: refs,
  scalarInputs: [...new Set(actions.flatMap(a => a.expression.match(/(?<![\w.])(?:rage|charges|active_enemies|fight_remains|time|gcd)(?![\w.])/g) || []))].sort()
};
fs.writeFileSync(new URL('requirements.json', root), JSON.stringify(manifest, null, 2) + '\n');
if (decoded) {
  const names = new Set(decoded.selected.filter(t => t.rank > 0).map(t => t.name.toLowerCase().replaceAll("'", '').replace(/[^a-z0-9]+/g, '_')));
  const gates = Object.fromEntries(refs.filter(r => r.startsWith('talent.')).map(r => [r, names.has(r.split('.')[1])]));
  const branch = decoded.heroTrees.length === 1 && decoded.heroTrees[0] === 60 ? 'slayer' : null;
  if (!branch) throw new Error('This narrowing step expects the supplied Slayer build');
  const lists = actions.filter(a => !a.list.startsWith('colossus_') && !a.expression.includes('name=colossus_'));
  fs.writeFileSync(new URL('build-requirements.json', root), JSON.stringify({
    specId:71, clientBuild:decoded.clientBuild, heroTree:branch,
    executeThresholdPercent:gates['talent.massacre.enabled'] ? 35 : 20,
    talentGates:gates,
    note:'Colossus lists removed. Other conditions are retained verbatim, not evaluated. Gear/race are not in the talent string.',
    actions:lists
  }, null, 2) + '\n');
}
console.log(`Extracted ${actions.length} action entries and ${refs.length} distinct references.`);
