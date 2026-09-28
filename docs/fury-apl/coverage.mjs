// Inventory HUD dependencies of reachable Fury/Slayer APL expressions; not an APL evaluator.
// IDs carry their evidence: simc-source (pinned sc_warrior.cpp / trait table), research
// (docs/research-apl.md), game-observed (seen in a reader log), client-export (known to the client and shown in a HUD export),
// conflict or pending. Only a game check promotes an ID further.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const build = JSON.parse(fs.readFileSync(new URL('build-requirements.json', root), 'utf8'));
const gates = build.talentGates;
const talented = name => gates ? gates[`talent.${name}`] : undefined;
// Talent-gated branches that the decoded build can never reach are left out of the inventory.
const reachable = a => !(gates && /run_action_list,name=\w+,if=talent\.(\w+)/.test(a.expression)
  && gates[`talent.${/talent\.(\w+)/.exec(a.expression)[1]}`] === false);
const variables = new Map();
const direct = [];
for (const action of build.actions.filter(reachable)) {
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
const refs = [...new Set(actions.flatMap(a => a.expression.match(/\b(?:buff|debuff|dot|cooldown|target|talent|trinket|movement|raid_event|variable|gcd)\.[a-z0-9_.]+|\b(?:rage|charges|active_enemies|fight_remains|time|gcd)\b/g) || []))].sort();

const onslaught = talented('unrelenting_onslaught');
const buffs = {
  enrage:{spellID:184362, evidence:'simc-source', note:'find_spell(184362); research-apl: verified'},
  recklessness:{spellID:1719, evidence:'simc-source', note:'spell.recklessness_buff'},
  whirlwind:{spellID:85739, evidence:'simc-source', note:'Meat Cleaver/Improved Whirlwind stacks; research-apl: verified'},
  sudden_death:{spellID:52437, evidence:'game-observed', note:'Lit 22 frames with 1 stack and consumed by Execute in log 20260928T195134Z-649af31e; 280776 (research-apl) never lit'},
  hack_and_slash:{spellID:383873, evidence:'game-observed', note:'Wowhead (live): talent 383877 Proc Trigger Spell -> 383873, 8 s, +20% Raging/Crushing Blow damage, +1 charge; lit 129 frames in the first manual fight'},
  bladestorm:{spellID:onslaught === false ? 227847 : 446035, evidence:onslaught === undefined ? 'pending' : 'simc-source',
    note:'446035 with Unrelenting Onslaught + Bladestorm, otherwise 227847'},
};
const spells = {
  bladestorm:{spellID:227847, evidence:'client-export', note:'Export castSpellIDs [227847, 446035]: override present with Unrelenting Onslaught, as in Arms'},
  execute:{spellID:5308, evidence:'client-export', note:'Shown as the Fury Execute square without override (no Massacre in the build); usability gating in combat not yet observed'},
  recklessness:{spellID:1719, evidence:'simc-source'},
};
function classify(ref) {
  const [kind, name, field] = ref.split('.');
  if (kind === 'buff' && buffs[name]) return {mode:field === 'stack' || field === 'remains' ? 'native-display+ocr' : 'native-display', ...buffs[name]};
  if (kind === 'cooldown' && spells[name]) return {mode:field === 'duration' ? 'static-model-required' : 'native-display', ...spells[name]};
  if (kind === 'talent') return {mode:'static-export', source:'Talent string of the HUD export', selected:talented(ref.slice(7)) ?? 'pending'};
  if (kind === 'variable') return {mode:'derived', source:'APL expression'};
  if (kind === 'trinket') return {mode:ref.endsWith('.ilvl') || ref.includes('.is.') ? 'static-export' : 'manual-metadata', source:'Equipment export; runtime currently models trinkets as absent'};
  const table = {
    active_enemies:{mode:'native-display', source:'TargetCount estimate or manual override; unknown blocks branch choice'},
    fight_remains:{mode:'manual-forecast', source:'fight cell'},
    'target.time_to_die':{mode:'manual-forecast', source:'ttd cell; blocks bladestorm outside Recklessness while unknown'},
    'movement.distance':{mode:'partial', source:'Per-spell range + Charge range; exact distance unavailable'},
    'target.health.pct':{mode:'native-display', source:'Current target only, Resources.lua'},
    'target.debuff.casting.react':{mode:'native-display', source:'Target cast/channel + interruptibility marker'},
    time:{mode:'observed', source:'Combat start event'},
    rage:{mode:'native-display', source:'Current rage + maximum'},
    gcd:{mode:'derived', source:'1.5 s adjusted by displayed haste; minimum 0.75'},
  };
  if (table[ref]) return table[ref];
  if (kind === 'raid_event') return {mode:'unavailable', source:'Simulation raid events'};
  throw new Error(`Unclassified HUD dependency: ${ref}`);
}

// Rules that can never fire: an earlier rule of the same list casts the same
// action unconditionally. Kept verbatim; reported so they are not "fixed" silently.
const shadowed = [];
for (const list of new Set(build.actions.map(a => a.list))) {
  const seen = new Set();
  for (const a of build.actions.filter(x => x.list === list)) {
    const verb = a.expression.split(',')[0];
    if (['variable', 'use_item', 'call_action_list', 'run_action_list'].includes(verb)) continue;
    if (seen.has(verb)) shadowed.push({list, expression:a.expression, reason:`unconditional ${verb} earlier in the list`});
    if (!a.expression.includes(',if=')) seen.add(verb);
  }
}

// Actions whose talent is not selected stay in the source but cannot be pressed.
const talentActions = {recklessness:'recklessness', avatar:'avatar', bladestorm:'bladestorm', odyns_fury:'odyns_fury',
  bloodbath:'reckless_abandon', crushing_blow:'reckless_abandon', rampage:'rampage', raging_blow:'raging_blow',
  bloodthirst:'bloodthirst', storm_bolt:'storm_bolt', berserker_stance:'berserker_stance'};
const unavailable = gates ? Object.entries(talentActions).filter(([, t]) => gates[`talent.${t}`] === false).map(([a]) => a) : 'pending';

const result = {
  clientBuild:build.clientBuild, specID:72, heroTree:'slayer', complete:false,
  note:'Display coverage only. Native rendering, OCR accuracy and APL evaluation are separate concerns.',
  talentGates:gates ?? 'pending: supply build.txt and run decode-build.mjs, then extract.mjs',
  executeThresholdPercent:build.executeThresholdPercent,
  actionsWithoutSelectedTalent:unavailable,
  unusedVariables:[...variables.keys()].filter(k => !needed.has(k)),
  dependencies:refs.map(symbol => ({symbol, ...classify(symbol)})),
  shadowed,
  actions:{
    rampage:{spellID:184367, evidence:'simc-source'},
    bloodthirst:{spellID:23881, evidence:'simc-source'},
    bloodbath:{spellID:335096, displaySpellID:23881, evidence:'simc-source', note:'Bloodthirst replacement; shares its binding'},
    raging_blow:{spellID:85288, evidence:'simc-source'},
    crushing_blow:{spellID:335097, displaySpellID:85288, evidence:'simc-source', note:'Raging Blow replacement; ready only with Reckless Abandon during Recklessness'},
    execute:spells.execute, recklessness:{spellID:1719, evidence:'simc-source'},
    avatar:{spellID:107574, evidence:'simc-source', note:'Only in slayer_aoe in this pinned APL'},
    bladestorm:spells.bladestorm, odyns_fury:{spellID:385059, evidence:'simc-source'},
    whirlwind:{spellID:190411, evidence:'client-export', note:'Known to the client as Whirlwind; not yet observed in a cast receipt'},
    storm_bolt:{spellID:107570, evidence:'simc-source', note:'Only during Bladestorm; reuses the Arms channel exception'},
    berserker_stance:{spellID:386196, evidence:'simc-source', note:'Precombat toggle; needs aura-down guard like Arms battle_stance'},
    charge:100, pummel:6552,
    heroic_leap:'Raid movement event only; not executable',
    potion:'User-selected item; not executed', use_item:'Not executed; trinkets modelled as absent',
    auto_attack:'Footer indicator', snapshot_stats:'Simulation-only action',
    invoke_external_buff:'Player coordination; Power Infusion aura 10060 is displayed but cannot be requested',
  },
};
fs.writeFileSync(new URL('coverage.json', root), JSON.stringify(result, null, 2) + '\n');
const pending = [...result.dependencies, ...Object.entries(result.actions).map(([symbol, v]) => ({symbol, ...v}))]
  .filter(d => ['pending', 'conflict'].includes(d.evidence)).map(d => d.symbol);
console.log(`Classified ${refs.length} dependencies; ${result.unusedVariables.length} unused variables; ${shadowed.length} shadowed rules; ID pending/conflict: ${pending.join(', ')}. Full coverage: false.`);
