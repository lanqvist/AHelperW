// WoW loadout serialization v2. Protocol/reference: SimC player.cpp,
// generate_tree_nodes + parse_traits_hash, pinned by source.json.
// A matching client build is essential: bit positions depend on all class nodes.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const writeJson = (name, value) => fs.writeFileSync(new URL(name, root), JSON.stringify(value, null, 2) + '\n');
if (process.argv[2]) {
  const raw = fs.readFileSync(process.argv[2], 'utf8');
  const build = raw.match(/wow build ([\d.]+)/)?.[1];
  if (build !== '12.1.0.69933') throw new Error(`Unexpected trait data build: ${build}`);
  const entries = [];
  for (const line of raw.split('\n')) {
    const match = line.match(/^\s*\{\s*(\d[^"\n]+),\s*"([^"]*)",\s*\{([^}]+)\},\s*\{([^}]+)\},\s*(\d+),\s*(\d+)\s*\},?$/);
    if (!match) continue;
    const f = match[1].split(',').map(s => Number(s.trim()));
    if (f.length !== 13 || f[1] !== 1) continue;
    entries.push({tree:f[0], entryId:f[2], nodeId:f[3], maxRanks:f[4],
      spellId:f[7], replacementId:f[8], overrideId:f[9], name:match[2],
      specs:match[3].split(',').map(Number).filter(Boolean),
      grantedSpecs:match[4].split(',').map(Number).filter(Boolean),
      subtree:Number(match[5]), nodeType:Number(match[6])});
  }
  if (entries.length < 100) throw new Error('Trait table extraction incomplete');
  writeJson('warrior-traits.json', {build, source:readJson('source.json'), entries});
}
const data = readJson('warrior-traits.json');
if (data.build !== '12.1.0.69933') throw new Error('Wrong trait build');
const text = fs.readFileSync(new URL('build.txt', root), 'utf8').trim();
const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const bits = [...text].flatMap(c => {
  const n = alphabet.indexOf(c);
  if (n < 0) throw new Error('Invalid export character');
  return Array.from({length:6}, (_,i) => (n >> i) & 1);
});
let position = 0;
function take(n) {
  if (position + n > bits.length) throw new Error(`Truncated export at bit ${position}`);
  let value = 0;
  for (let i=0;i<n;i++) value += bits[position++] * 2**i;
  return value;
}
const version = take(8), specId = take(16);
if (version !== 2 || specId !== 71) throw new Error('Expected Arms v2 export');
const treeHash = Array.from({length:16}, () => take(8));
const nodes = new Map();
for (const trait of data.entries) {
  if (!nodes.has(trait.nodeId)) nodes.set(trait.nodeId, []);
  nodes.get(trait.nodeId).push(trait);
}
const selected = [];
for (const [id, node] of [...nodes].sort((a,b) => a[0]-b[0])) {
  if (!take(1)) continue;
  let trait = node[0];
  let max = trait.nodeType === 1 ? node.reduce((sum,t) => sum+t.maxRanks,0) : trait.maxRanks;
  let rank = max;
  if (!take(1)) rank = 1;
  else {
    if (take(1)) {
      rank = take(6);
      if (rank < 1 || rank >= max) throw new Error(`Invalid partial rank at ${id}`);
    }
    if (take(1)) {
      if (![2,3].includes(trait.nodeType)) throw new Error(`Unexpected choice at ${id}`);
      trait = node[take(2)];
      if (!trait) throw new Error(`Choice index out of range at ${id}`);
    }
  }
  if (trait.tree !== 3 && trait.specs.length && !trait.specs.includes(specId))
    throw new Error(`Selected node ${id} is for another spec`);
  if (trait.nodeType === 1) {
    for (const tier of node) {
      const allocated = Math.min(rank, tier.maxRanks);
      if (allocated) selected.push({...tier, rank:allocated});
      rank -= allocated;
    }
  } else selected.push({...trait, rank});
}
if (bits.length-position > 5 || bits.slice(position).some(Boolean))
  throw new Error(`Unexpected trailing data: ${bits.length-position} bits`);
const heroTrees = [...new Set(selected.filter(t => t.subtree && t.rank).map(t => t.subtree))];
const decoded = {clientBuild:data.build, serializationVersion:version, specId,
  treeHash, hashVerified:false, note:'Decoded against matching SimC build; client application not independently checked.',
  source:readJson('source.json'), heroTrees, bitsConsumed:position, paddingBits:bits.length-position, selected};
writeJson('decoded-build.json', decoded);
console.log(JSON.stringify({nodes:nodes.size, selected:selected.length, heroTrees, bitsConsumed:position,paddingBits:bits.length-position}));
for (const trait of selected) console.log(`${trait.tree} ${trait.spellId} ${trait.name} ${trait.rank}`);
