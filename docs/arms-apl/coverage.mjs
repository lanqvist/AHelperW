// Inventory HUD dependencies of reachable Slayer APL expressions; not an APL evaluator.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const build = JSON.parse(fs.readFileSync(new URL('build-requirements.json', root), 'utf8'));
const variables = new Map();
const direct = [];
for (const action of build.actions) {
  const name = /^variable,name=([a-z0-9_]+)/.exec(action.expression)?.[1];
  if (name) variables.set(name, action); else direct.push(action);
}
const needed = new Set();
function visit(expression) {
  for (const [, name] of expression.matchAll(/\bvariable\.([a-z0-9_]+)/g)) {
    if (!needed.has(name)) {
      needed.add(name);
      if (variables.has(name)) visit(variables.get(name).expression);
    }
  }
}
direct.forEach(a => visit(a.expression));
const actions = [...direct, ...[...needed].map(n => variables.get(n)).filter(Boolean)];
const refs = [...new Set(actions.flatMap(a => a.expression.match(/\b(?:buff|debuff|dot|cooldown|target|talent|trinket|movement|variable|gcd)\.[a-z0-9_.]+|\b(?:rage|charges|active_enemies|fight_remains|time|gcd)\b/g) || []))].sort();
const buffs = { avatar:107574, bladestorm:446035, collateral_damage:334783, executioner:445584, executioners_precision:386633, imminent_demise:445606, opportunist:456120, sudden_death:52437 };
const spells = { avatar:107574, bladestorm:227847, colossus_smash:167105, mortal_strike:12294 };
function classify(ref) {
  const [, name] = ref.split('.');
  if (ref.startsWith('buff.') && buffs[name]) return { mode:'native-display', spellID:buffs[name], source:'Squares.lua AuraButton' };
  if (ref.startsWith('cooldown.') && spells[name]) return { mode:ref.endsWith('.duration') ? 'static-model-required' : 'native-display', spellID:spells[name], source:'Squares.lua / export baseCooldownMs' };
  if (ref.startsWith('debuff.colossus_smash.')) return { mode:'native-display', spellID:208086 };
  if (ref === 'dot.rend_dot.remains') return { mode:'native-display', spellID:388539 };
  if (ref.startsWith('talent.')) return { mode:'static-export', source:'Current talent string; decode and compare to selected build externally' };
  if (ref.startsWith('variable.')) return { mode:'derived', source:'APL expression; evaluator not implemented' };
  if (ref.startsWith('trinket.')) return { mode:ref.endsWith('.ilvl') || ref.includes('.is.') ? 'static-export' : 'manual-metadata', source:'ItemID/item link/level + /ahw trinket metadata; external item-ID mapping and APL evaluation required' };
  const table = {
    active_enemies:{mode:'manual', source:'targets cell: unknown / 1 / 2 / 3+'},
    fight_remains:{mode:'manual-forecast', source:'fight cell'},
    'target.time_to_die':{mode:'manual-forecast', source:'ttd cell; reset on target change'},
    'movement.distance':{mode:'partial', source:'Per-spell range + Charge range; exact movement distance unavailable'},
    'target.health.pct':{mode:'native-display', source:'Current target only, Resources.lua'},
    'target.debuff.casting.react':{mode:'native-display', source:'Target cast/channel + interruptibility marker'},
    time:{mode:'observed', source:'Combat start event; unknown after reload in combat'},
    rage:{mode:'native-display', source:'Current rage + maximum'},
    charges:{mode:'native-display', source:'Overpower charge count'},
    gcd:{mode:'derived', source:'1.5 seconds adjusted by displayed haste; Arms minimum 0.75'},
    'gcd.remains':{mode:'native-display', source:'61304 native cooldown'},
  };
  if (!table[ref]) throw new Error(`Unclassified HUD dependency: ${ref}`);
  return table[ref];
}
const result = {
  clientBuild:build.clientBuild, specID:71, heroTree:'slayer', complete:false,
  note:'Display coverage only. Native rendering, OCR accuracy and APL evaluation are separate concerns.',
  unusedVariables:[...variables.keys()].filter(k => !needed.has(k)),
  dependencies:refs.map(symbol => ({symbol, ...classify(symbol)})),
  operations:[{symbol:'target_if=min:target.health.pct',mode:'unavailable',reason:'No complete set of enemy units/health values; HUD displays only the current target'}],
  actions:{
    charge:100,pummel:6552,battle_stance:386164,
    heroic_strike:{spellID:1269383,displaySpellID:1464,procID:1269391},
    potion:'User-selected item',auto_attack:'Footer indicator',
    invoke_external_buff:'Player coordination; Power Infusion aura 10060 is displayed but cannot be requested by a warrior ability',
    snapshot_stats:'Simulation-only action',ravager:'Not selected in the supplied build',rend:'Direct cast conditions disabled by selected Cleave/Bloodletting talents',
  },
};
fs.writeFileSync(new URL('coverage.json',root),JSON.stringify(result,null,2)+'\n');
console.log(`Classified ${refs.length} dependencies; ${result.unusedVariables.length} unused variables. Full coverage: false.`);
