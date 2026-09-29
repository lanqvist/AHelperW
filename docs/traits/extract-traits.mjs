// Class trait table from SimC trait_data.inc at the pinned commit.
// Usage: node docs/traits/extract-traits.mjs <class> [path/to/trait_data.inc]
// Without a path the file is downloaded from the pinned commit. The output
// keeps the schema of arms-apl/warrior-traits.json and windwalker-apl/monk-traits.json
// (entries in source order) and adds `subtrees` (hero tree ID -> name, specs).
import fs from 'node:fs';
const COMMIT = '4c7c73621e596419b5bd6faa5d68940a9c640379';
const BUILD = '12.1.0.69933';
const URL_ = `https://raw.githubusercontent.com/simulationcraft/simc/${COMMIT}/engine/dbc/generated/trait_data.inc`;
// SimC class IDs (second field of a trait row; hero tree table uses the same).
const CLASSES = {warrior:1, paladin:2, hunter:3, rogue:4, priest:5, death_knight:6, shaman:7,
  mage:8, warlock:9, monk:10, druid:11, demon_hunter:12, evoker:13};
const [name, file] = process.argv.slice(2);
const classId = CLASSES[name];
if (!classId) throw new Error(`Usage: extract-traits.mjs <${Object.keys(CLASSES).join('|')}> [trait_data.inc]`);
const raw = file ? fs.readFileSync(file, 'utf8') : await (await fetch(URL_)).text();
const build = raw.match(/wow build ([\d.]+)/)?.[1];
if (build !== BUILD) throw new Error(`Unexpected trait data build: ${build}`);
const entries = [];
for (const line of raw.split('\n')) {
  const match = line.match(/^\s*\{\s*(\d[^"\n]+),\s*"([^"]*)",\s*\{([^}]+)\},\s*\{([^}]+)\},\s*(\d+),\s*(\d+)\s*\},?$/);
  if (!match) continue;
  const f = match[1].split(',').map(s => Number(s.trim()));
  if (f.length !== 13 || f[1] !== classId) continue;
  entries.push({tree:f[0], entryId:f[2], nodeId:f[3], maxRanks:f[4],
    spellId:f[7], replacementId:f[8], overrideId:f[9], name:match[2],
    specs:match[3].split(',').map(Number).filter(Boolean),
    grantedSpecs:match[4].split(',').map(Number).filter(Boolean),
    subtree:Number(match[5]), nodeType:Number(match[6])});
}
if (entries.length < 100) throw new Error('Trait table extraction incomplete');
// Hero trees: `{ id, "Name", class }`; specs come from the subtree switch nodes
// (tree 4, nodeType 3) that the talent string selects.
const subtrees = {};
for (const m of raw.matchAll(/\{\s*(\d+),\s*"([^"]+)",\s*(\d+)\s*\}/g)) {
  if (Number(m[3]) === classId) subtrees[m[1]] = {name:m[2], specs:[]};
}
for (const e of entries.filter(e => e.tree === 4 && e.nodeType === 3)) {
  const tree = subtrees[e.subtree];
  if (!tree) throw new Error(`Subtree ${e.subtree} missing from the hero tree table`);
  for (const spec of e.specs) if (!tree.specs.includes(spec)) tree.specs.push(spec);
  tree.specs.sort((a, b) => a - b);
}
const out = new URL(`./${name}-traits.json`, import.meta.url);
fs.writeFileSync(out, JSON.stringify({build, source:{commit:COMMIT, retrieved:new Date().toISOString().slice(0,10),
  url:URL_, clientBuild:BUILD}, subtrees, entries}, null, 2) + '\n');
console.log(JSON.stringify({class:name, entries:entries.length, subtrees}));
