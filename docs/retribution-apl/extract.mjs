// GPL SimC snapshot: preserve the shared Retribution APL without rewrites.
// Usage: node docs/retribution-apl/extract.mjs
import fs from 'node:fs';
import crypto from 'node:crypto';
const root = new URL('./', import.meta.url);
const read = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const write = (name, data) => fs.writeFileSync(new URL(name,root),JSON.stringify(data,null,2)+'\n');
const source = read('source.json');
const text = fs.readFileSync(new URL(source.localSource,root),'utf8').replace(/\r\n/g,'\n');
if (crypto.createHash('sha256').update(text).digest('hex') !== source.localSourceSha256)
  throw new Error('Retribution APL differs from the pinned snapshot');
const traits = read(source.traitTable);
if (traits.build !== source.clientBuild) throw new Error('Trait/APL build mismatch');
const heroTrees = Object.fromEntries(Object.entries(traits.subtrees).filter(([,t])=>t.specs.includes(70)).map(([id,t])=>[id,t.name]));
if (Object.keys(heroTrees).sort().join() !== '48,50') throw new Error('Unexpected Retribution hero trees');
const actions = [];
for (const line of text.split('\n')) {
  const m = /^actions(?:\.([a-z0-9_]+))?\+?=\/?(.+)$/.exec(line.trim());
  if (m) actions.push({list:m[1] || 'default_',expression:m[2]});
}
if (!actions.length || !actions.some(a=>a.list==='finishers')) throw new Error('APL extraction incomplete');
const refs = /\b(?:buff|debuff|dot|cooldown|talent|target|raid_event|trinket|variable|hero_tree|equipped)\.[a-z0-9_.]+|\b(?:holy_power|active_enemies|fight_remains|gcd|time)\b/g;
const references = [...new Set(actions.flatMap(a=>a.expression.match(refs)||[]))].sort();
write('requirements.json',{specId:70,source,scope:'all-retribution-branches-unmodified',actions,references});
write('build-requirements.json',{
  specId:70,clientBuild:source.clientBuild,heroTrees,
  heroTreeKeys:{48:'templar',50:'herald_of_the_sun'},
  note:'Both hero trees share the pinned lists. Runtime evaluates talents from the actual export. Reader adaptations are labelled in retribution_apl.py; unknown values stay unknown.',
  actions,
});
console.log(JSON.stringify({actions:actions.length,references:references.length,heroTrees}));
