// Inventory HUD dependencies of reachable Frost DK APL expressions per hero tree; not an APL evaluator.
// IDs carry their evidence: simc-source (pinned sc_death_knight.cpp / trait table / specialization_spells.inc),
// wowhead, profile-reuse (same ID as another checked profile, not re-checked for DK), unresolved.
// Nothing here is game-observed yet; only a game check promotes an ID further.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, root), 'utf8'));
const build = readJson('build-requirements.json');
const source = readJson('source.json');
const traits = JSON.parse(fs.readFileSync(new URL(source.traitTable, root), 'utf8'));
const gates = build.talentGates;
const trees = {33:'deathbringer', 32:'rider_of_the_apocalypse'};
const slug = name => name.toLowerCase().replaceAll("'", '').replace(/[^a-z0-9]+/g, '_');
// Hero talents by subtree: a talent of the other tree is statically absent.
const heroTalents = {};
for (const t of traits.entries) if (t.tree === 3 && trees[t.subtree]) heroTalents[slug(t.name)] = t.subtree;

const TA = 'sc_death_knight.cpp', TT = 'trait table (death_knight-traits.json)', SS = 'specialization_spells.inc';
const buffs = {
  killing_machine:{spellID:51124, evidence:'wowhead', note:`${TA}: talent 51128 effect#1 trigger (no literal ID); Wowhead 51124 "Killing Machine" 10 s buff modifying Obliterate/Frostscythe crit; research-apl: verified, 2 stacks`},
  rime:{spellID:59052, evidence:'simc-source', note:`${TA} spell.rime_buff`},
  pillar_of_frost:{spellID:51271, evidence:'simc-source', note:`${TA}: buff uses the talent spell (${TT})`},
  breath_of_sindragosa:{spellID:1249658, evidence:'simc-source', note:`${TA}: buff uses the talent spell (${TT}); fixed-duration buff, not a toggle. ClassData/research-apl list the older 152279`},
  remorseless_winter:{spellID:196770, evidence:'simc-source', note:`${SS} spec spell; with Frozen Dominion the buff is 1233152 (spell.frozen_dominion_remorseless_winter_buff)`},
  gathering_storm:{spellID:211805, evidence:'simc-source', note:`${TA} spell.gathering_storm_buff`},
  icy_onslaught:{spellID:1230273, evidence:'simc-source', note:`${TA} spell.icy_onslaught_buff`},
  bonegrinder_frost:{spellID:377103, evidence:'simc-source', note:`${TA} spell.bonegrinder_frost_buff`},
  frostbane:{spellID:1229310, evidence:'simc-source', note:`${TA} spell.frostbane_buff; Frost Strike is replaced by Frostbane 1228433 while up`},
  unholy_strength:{spellID:53365, evidence:'simc-source', note:`${TA} runeforge_spell.unholy_strength (Rune of the Fallen Crusader)`},
  chosen_of_frostbrood_haste:{spellID:1265630, evidence:'simc-source', note:`${TA} apex tier 1 buff`},
  chosen_of_frostbrood_fwf:{spellID:1265639, evidence:'simc-source', note:`${TA} apex tier 3 buff; Frostwyrm's Fury is replaced by the recall 1265384 while up`},
};
const debuffs = {
  razorice:{spellID:51714, evidence:'simc-source', note:`${TA} runeforge_spell.razorice_debuff; stacks to 5`},
  frost_fever:{spellID:55095, evidence:'simc-source', note:`${TA} spell.frost_fever`},
  reapers_mark_debuff:{spellID:434765, evidence:'simc-source', note:`${TA} spell.reapers_mark_debuff; only in target_if=first: (current-target adaptation)`},
  chains_of_ice_trollbane_slow:{spellID:444826, evidence:'simc-source', note:`${TA} pet_spell.trollbanes_chains_of_ice_ability; only in target_if=max: (adapted away, not tracked)`},
};
const actions = {
  obliterate:{spellID:49020, evidence:'simc-source', note:TT},
  frost_strike:{spellID:49143, evidence:'simc-source', note:`${TT}; replacement Frostbane 1228433 (${TA} spell.frostbane_driver) on the same button`},
  howling_blast:{spellID:49184, evidence:'simc-source', note:TT},
  frostscythe:{spellID:207230, evidence:'simc-source', note:TT},
  glacial_advance:{spellID:194913, evidence:'simc-source', note:`${SS} (baseline Frost spec spell)`},
  remorseless_winter:{spellID:196770, evidence:'simc-source', note:`${SS}; removed by Frozen Dominion (trait 377226 replacementId 196770)`},
  pillar_of_frost:{spellID:51271, evidence:'simc-source', note:TT},
  breath_of_sindragosa:{spellID:1249658, evidence:'simc-source', note:`${TT}; use_off_gcd`},
  frostwyrms_fury:{spellID:279302, evidence:'simc-source', note:`${TT}; replacement Chosen of Frostbrood 1265384 (${TA} chosen_of_frostbrood_fwf_action, off-GCD)`},
  empower_rune_weapon:{spellID:47568, evidence:'simc-source', note:`${TT}; charges from spell data, off-GCD (min_gcd 0)`},
  reapers_mark:{spellID:439843, evidence:'simc-source', note:`${TT} (Deathbringer, subtree 33)`, heroTree:'deathbringer'},
  raise_dead:{spellID:46585, evidence:'simc-source', note:`${TT} (class); temporary ghoul, ready() false while it lives — the HUD cooldown covers it`},
  mind_freeze:{spellID:47528, evidence:'simc-source', note:`${TT} (class); target_ready needs a casting target`},
  blood_fury:{spellID:20572, evidence:'profile-reuse', note:'Same ID as Fury/Windwalker profiles; not re-checked for DK'},
  berserking:{spellID:26297, evidence:'profile-reuse'}, arcane_pulse:{spellID:260364, evidence:'profile-reuse'},
  lights_judgment:{spellID:255647, evidence:'profile-reuse'}, ancestral_call:{spellID:274738, evidence:'profile-reuse'},
  fireblood:{spellID:265221, evidence:'profile-reuse'}, bag_of_tricks:{spellID:312411, evidence:'profile-reuse'},
  antimagic_shell:'Defensive; not executed (death_knight.first_ams_cast is a simulation option)',
  potion:'User-selected item; not executed', use_item:'Not executed; trinkets modelled as absent',
  auto_attack:'Footer indicator', snapshot_stats:'Simulation-only action',
  invoke_external_buff:'Player coordination; Power Infusion aura 10060 is displayed but cannot be requested',
};

function classify(ref) {
  const [kind, name, field] = ref.split('.');
  if (kind === 'buff' && buffs[name]) return {mode:['stack', 'remains'].includes(field) || (field === 'react' && name === 'killing_machine') ? 'native-display+ocr' : 'native-display', ...buffs[name]};
  if ((kind === 'debuff' || kind === 'dot') && debuffs[name]) return {mode:['stack'].includes(field) || (field === 'react' && name === 'razorice') ? 'native-display+ocr' : 'native-display', ...debuffs[name]};
  if (kind === 'cooldown' && actions[name]) return {mode:field === 'duration' ? 'static-model-required' : field === 'full_recharge_time' ? 'native-display+ocr (exact at max or max-1 charges)' : 'native-display', ...actions[name]};
  if (kind === 'talent') return {mode:'static-export', source:'Talent string of the HUD export', selected:gates ? gates[`talent.${name}`] ?? 'not-gated' : 'pending'};
  if (kind === 'hero_tree') return {mode:'static-export', source:'Subtree switch of the talent string'};
  if (kind === 'variable') return {mode:'derived', source:'APL expression'};
  if (kind === 'trinket') return {mode:'manual-metadata', source:'Equipment export; runtime models trinkets as absent'};
  if (kind === 'raid_event') return {mode:'adapted', source:'No scripted raid events: in/cooldown huge, others 0 (raid_event.cpp without matching events)'};
  const table = {
    active_enemies:{mode:'native-display', source:'TargetCount estimate or manual override; unknown blocks only when the choice depends on it'},
    fight_remains:{mode:'manual-forecast', source:'fight cell; fight_remains<N applies only when set (adaptation)'},
    rune:{mode:'native-display', source:'Six rune colours (ready / recharging / unknown)'},
    runic_power:{mode:'native-display', source:'Runic power OCR'}, 'runic_power.deficit':{mode:'derived', source:'MAX СР cell or export max minus runic power'},
    'target.debuff.casting.react':{mode:'native-display', source:'Target cast/channel + interruptibility marker'},
    gcd:{mode:'derived', source:'1.5 s adjusted by displayed haste; minimum 0.75'}, 'gcd.max':{mode:'derived', source:'Same as gcd'},
    time:{mode:'observed', source:'Combat start event'},
    'main_hand.2h':{mode:'partial', source:'False with an off-hand weapon in the export (slot 17); otherwise unknown'},
    'death_knight.first_ams_cast':{mode:'unavailable', source:'SimC option; only in the Anti-Magic Shell rule, which is not executed'},
  };
  if (table[ref]) return table[ref];
  throw new Error(`Unclassified HUD dependency: ${ref}`);
}

const refPattern = /\b(?:buff|debuff|dot|cooldown|target|talent|trinket|raid_event|variable|hero_tree|death_knight|main_hand)\.[a-z0-9_.]+|\b(?:runic_power\.deficit|runic_power|rune|active_enemies|fight_remains|time|gcd\.max|gcd)\b/g;
// Conditions plus target_if=first: selectors (the reader checks them on the current target).
const conditionOf = a => [...a.expression.split(',').filter(p => /^(if|value|condition)=/.test(p)).map(p => p.split('=').slice(1).join('=')),
  ...a.expression.split(',').filter(p => p.startsWith('target_if=first:')).map(p => p.slice(16))].join(',');
function inventory(id) {
  const key = trees[id], other = Object.values(trees).find(k => k !== key);
  // A rule whose whole condition starts with the other tree's hero_tree guard is constant false here.
  const reachable = a => {
    const verb = a.expression.split(',')[0];
    if (heroTalents[verb] && heroTalents[verb] !== id) return false;
    return !conditionOf(a).startsWith(`hero_tree.${other}&`);
  };
  const variables = new Map(), direct = [];
  for (const a of build.actions) {
    const name = /^variable,name=([a-z0-9_]+)/.exec(a.expression)?.[1];
    if (name) variables.set(name, a); else if (reachable(a)) direct.push(a);
  }
  const needed = new Set();
  const visit = text => {
    for (const [, name] of text.matchAll(/\bvariable\.([a-z0-9_]+)/g)) {
      if (needed.has(name)) continue;
      needed.add(name);
      const v = variables.get(name);
      if (v && reachable(v)) visit(conditionOf(v));
    }
  };
  direct.forEach(a => visit(conditionOf(a)));
  const used = [...direct.map(conditionOf), ...[...needed].map(n => variables.get(n)).filter(v => v && reachable(v)).map(conditionOf)];
  const refs = [...new Set(used.flatMap(t => t.match(refPattern) || []))]
    .filter(r => !(r.startsWith('talent.') && heroTalents[r.split('.')[1]] && heroTalents[r.split('.')[1]] !== id)).sort();
  const targetIf = build.actions.filter(a => reachable(a) && a.expression.includes('target_if='))
    .map(a => ({list:a.list, targetIf:/target_if=([^,]+)/.exec(a.expression)[1],
      adaptation:/target_if=first:/.test(a.expression) ? 'current target must satisfy the selector' : 'current target (selector dropped)'}));
  return {heroTree:key, dependencies:refs.map(symbol => ({symbol, ...classify(symbol)})), targetIf,
    unusedVariables:[...variables.keys()].filter(k => !needed.has(k)),
    actions:Object.fromEntries(Object.entries(actions).filter(([, v]) => typeof v !== 'object' || !v.heroTree || v.heroTree === key))};
}

const perTree = Object.fromEntries(Object.keys(trees).map(id => [id, inventory(Number(id))]));
const ids = Object.values(perTree).flatMap(t => [...t.dependencies, ...Object.entries(t.actions).map(([symbol, v]) => typeof v === 'object' ? {symbol, ...v} : null).filter(Boolean)]);
const unresolved = [...new Set(ids.filter(d => d.evidence === 'unresolved').map(d => d.symbol))];
const result = {
  clientBuild:build.clientBuild, specID:251, complete:false,
  note:'Display coverage only. Native rendering, OCR accuracy and APL evaluation are separate concerns. Nothing is game-observed yet.',
  talentGates:gates ?? 'pending: supply build.txt, run docs/traits/decode-build.mjs death_knight 251, then extract.mjs',
  fallbackBuffs:'Buffs of unselected talents are absent exactly (make_fallback); Chosen of Frostbrood recall needs apex tier 3',
  replacements:{frost_strike:{spellID:1228433, buff:1229310, evidence:'simc-source'}, frostwyrms_fury:{spellID:1265384, buff:1265639, evidence:'simc-source'}},
  heroTrees:perTree,
  unresolved,
};
fs.writeFileSync(new URL('coverage.json', root), JSON.stringify(result, null, 2) + '\n');
const count = e => [...new Set(ids.filter(d => d.evidence === e).map(d => d.symbol))].length;
console.log(`Deathbringer ${perTree[33].dependencies.length} / Rider ${perTree[32].dependencies.length} dependencies; `
  + `simc-source ${count('simc-source')}, wowhead ${count('wowhead')}, profile-reuse ${count('profile-reuse')}, unresolved ${unresolved.length}. Full coverage: false.`);
