// WoW loadout serialization v2 against a class table from extract-traits.mjs.
// Usage: node docs/traits/decode-build.mjs <class|table.json> <specId> <build.txt>
// <class> reads docs/traits/<class>-traits.json; older tables are passed by path
// (docs/arms-apl/warrior-traits.json, docs/windwalker-apl/monk-traits.json).
// Writes decoded-build.json next to build.txt (personal data: keep both ignored).
// Protocol/reference: SimC player.cpp generate_tree_nodes + parse_traits_hash at
// the pinned commit. Bit positions depend on every class node, so the table
// must match the client build. Mirrors reader/talent_decode.py.
import fs from 'node:fs';
import path from 'node:path';
const [className, specArg, buildFile] = process.argv.slice(2);
const specId = Number(specArg);
if (!className || !specId || !buildFile) throw new Error('Usage: decode-build.mjs <class> <specId> <build.txt>');
const table = className.endsWith('.json') ? path.resolve(className) : new URL(`./${className}-traits.json`, import.meta.url);
const data = JSON.parse(fs.readFileSync(table, 'utf8'));
if (data.build !== '12.1.0.69933') throw new Error('Wrong trait build');
const text = fs.readFileSync(buildFile, 'utf8').trim();
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
const version = take(8), exportedSpec = take(16);
if (version !== 2 || exportedSpec !== specId) throw new Error(`Expected v2 export for spec ${specId}, got v${version} spec ${exportedSpec}`);
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
  const max = trait.nodeType === 1 ? node.reduce((sum,t) => sum+t.maxRanks,0) : trait.maxRanks;
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
// The active hero tree is the subtree switch, never the auto-granted nodes of
// the inactive tree (PROJECT_MEMORY §6).
const heroTrees = [...new Set(selected.filter(t => t.tree === 4 && t.nodeType === 3 && t.rank).map(t => t.subtree))]
  .map(id => ({id, name:data.subtrees?.[id]?.name ?? null}));
const decoded = {clientBuild:data.build, serializationVersion:version, specId,
  treeHash, hashVerified:false, note:'Decoded against matching SimC build; client application not independently checked.',
  source:data.source, heroTrees, bitsConsumed:position, paddingBits:bits.length-position, selected};
const out = path.join(path.dirname(path.resolve(buildFile)), 'decoded-build.json');
fs.writeFileSync(out, JSON.stringify(decoded, null, 2) + '\n');
console.log(JSON.stringify({nodes:nodes.size, selected:selected.length, heroTrees, bitsConsumed:position, paddingBits:bits.length-position, out}));
for (const trait of selected) console.log(`${trait.tree} ${trait.spellId} ${trait.name} ${trait.rank}`);
