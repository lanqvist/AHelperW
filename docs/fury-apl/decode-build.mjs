// WoW loadout serialization v2 for Fury/Slayer. Same protocol as ../arms-apl/decode-build.mjs;
// the class trait table is shared with Arms and pinned to the same client build.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const source = readJson('source.json');
const data = readJson(source.traitTable);
if (data.build !== source.clientBuild) throw new Error('Wrong trait build');
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
if (version !== 2 || specId !== 72) throw new Error('Expected Fury v2 export');
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
// The active hero tree is the subtree selector, not automatically granted nodes.
const heroTrees = [...new Set(selected.filter(t => t.tree === 4 && t.nodeType === 3).map(t => t.subtree))];
if (heroTrees.length !== 1 || heroTrees[0] !== 60) throw new Error(`Expected Slayer hero tree, got ${heroTrees}`);
const decoded = {clientBuild:data.build, serializationVersion:version, specId,
  treeHash, hashVerified:false, note:'Decoded against matching SimC build; client application not independently checked.',
  source, heroTrees, bitsConsumed:position, paddingBits:bits.length-position,
  selected:selected.filter(t => !t.subtree || heroTrees.includes(t.subtree))};
fs.writeFileSync(new URL('decoded-build.json', root), JSON.stringify(decoded, null, 2) + '\n');
console.log(JSON.stringify({nodes:nodes.size, selected:decoded.selected.length, heroTrees, bitsConsumed:position, paddingBits:bits.length-position}));
for (const trait of decoded.selected) console.log(`${trait.tree} ${trait.spellId} ${trait.name} ${trait.rank}`);
