// Inventory HUD dependencies of reachable Unholy APL expressions per hero tree; not an APL evaluator.
// IDs carry their evidence: simc-source (pinned sc_death_knight.cpp / sc_spell_data.inc / trait table),
// wowhead (live tooltip, Midnight data; not the pinned build), game-observed / client-export (after a game
// session), unresolved. Only a game check promotes an ID further.
import fs from 'node:fs';
const root = new URL('./', import.meta.url);
const build = JSON.parse(fs.readFileSync(new URL('build-requirements.json', root), 'utf8'));
const gates = build.talentGates;
const talented = name => gates ? gates[`talent.${name}`] : undefined;
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
const refs = [...new Set(actions.flatMap(a => a.expression.match(/\b(?:buff|debuff|dot|cooldown|target|talent|trinket|pet|raid_event|variable|gcd|runic_power)\.[a-z0-9_.]+|\b(?:runic_power|rune|charges|max_charges|duration|active_enemies|fight_remains|time|gcd)\b(?!\.)/g) || []))].sort();

// Player auras. `tree` marks a hero-tree buff: in the other tree SimC builds a fallback
// buff that is never up, so the reader resolves it as down without a HUD square.
const buffs = {
  sudden_doom:{spellID:81340, evidence:'wowhead', talent:'sudden_doom', note:'SimC: trigger of talent 49530 effect 1 (buffs.sudden_doom); Wowhead 81340: 10 s buff, next Death Coil/Epidemic cheaper; spell data max stack 1'},
  dark_transformation:{spellID:1235391, evidence:'simc-source', talent:'dark_transformation', note:'spell.dark_transformation_player_buff (player aura, 15 s)'},
  forbidden_knowledge:{spellID:1242223, evidence:'simc-source', talent:'forbidden_knowledge', note:'spell.forbidden_knowledge_buff; Death Coil/Epidemic become Necrotic Coil/Graveyard for 30 s'},
  lesser_ghoul_ready:{spellID:1254252, evidence:'simc-source', note:'spell.lesser_ghoul_buff (baseline with Festering Strike), max 8; stack>=1 read as aura up, the 12.1.5 AoE stack<3 reads the digit'},
  festering_scythe:{spellID:458123, evidence:'simc-source', talent:'festering_scythe', note:'spell.festering_scythe_buff: next Festering Strike is Festering Scythe (15 s)'},
  festering_scythe_tt:{spellID:1241077, kind:'debuff', evidence:'simc-source', talent:'festering_scythe',
    note:'SimC tracks spell.festering_scythe_debuff as a player buff; in game it is a debuff on the target hit (Wowhead: "Hastens your Plagues on the target", 25 s). Read on the current target (adaptation)'},
  blightfall:{spellID:1271975, evidence:'simc-source', talent:'blightfall', note:'spell.blightfall_buff: Dark Transformation becomes Blightfall'},
  blighted:{spellID:1271199, evidence:'simc-source', note:'MID1 4-piece set buff (spell.blighted_buff); set bonus is not in the export, the square decides'},
  essence_of_the_blood_queen:{spellID:433925, evidence:'simc-source', talent:'vampiric_strike', tree:'sanlayn', note:'max_stack 5 and 20 s from pinned sc_spell_data.inc; stacks via OCR'},
  vampiric_strike:{spellID:433899, evidence:'simc-source', talent:'vampiric_strike', tree:'sanlayn',
    note:'spell.vampiric_strike_buff; SimC also triggers it when Gift of the San\'layn (434153) starts, so the reader accepts either aura'},
  gift_of_the_sanlayn:{spellID:434153, evidence:'simc-source', talent:'gift_of_the_sanlayn', tree:'sanlayn', note:'Not referenced by the APL; replacement signal for Vampiric Strike during Dark Transformation'},
  army_of_the_dead:{spellID:42650, evidence:'simc-source', talent:'army_of_the_dead', note:'buffs.army_of_the_dead uses the talent spell (30 s); basis of the pet.* adaptation'},
  reaping:{spellID:1242654, evidence:'simc-source', talent:'reaping', note:'spell.reaping_buff: Soul Reaper usable on any target (soul_reaper_t::target_ready)'},
};
const debuffs = {
  soul_reaper_debuff:{spellID:1241521, evidence:'simc-source', note:'td debuff "soul_reaper_debuff" = spell.soul_reaper_debuff'},
  virulent_plague:{spellID:191587, evidence:'simc-source', note:'spell.virulent_plague; active_dots from the current target only (adaptation)'},
  dread_plague:{spellID:1240996, evidence:'simc-source', note:'spell.dread_plague; one host at a time; active_dots from the current target only (adaptation)'},
};
const spells = {
  festering_strike:{spellID:85948, evidence:'simc-source', note:'spec.festering_strike (baseline); profile melee reference'},
  scourge_strike:{spellID:55090, evidence:'simc-source', talent:'scourge_strike', note:'Clawing Shadows (1241567) is a modifier talent in this build, not a replacement'},
  death_coil:{spellID:47541, evidence:'simc-source'}, epidemic:{spellID:207317, evidence:'simc-source'},
  putrefy:{spellID:1247378, evidence:'simc-source', talent:'putrefy', note:'1 charge in spell data; Putrid Echoes adds 2 (Wowhead)'},
  soul_reaper:{spellID:343294, evidence:'simc-source', talent:'soul_reaper', note:'target_ready: HP <= 35% (spell data effect 2) or Reaping'},
  outbreak:{spellID:77575, evidence:'simc-source', talent:'outbreak'},
  army_of_the_dead:{spellID:42650, evidence:'simc-source', talent:'army_of_the_dead', note:'Raise Abomination / Summon Gargoyle only modify it (no own button)'},
  dark_transformation:{spellID:1233448, evidence:'simc-source', talent:'dark_transformation', note:'ready() needs an active ghoul unless Blightfall is up; ghoul state is not in the HUD'},
  death_and_decay:{spellID:43265, evidence:'simc-source', note:'find_spell(43265); 1 charge, 30 s recharge, 10 s duration (spell data); ground-targeted'},
  raise_dead:{spellID:46584, evidence:'simc-source', note:'spec.raise_dead; ready() needs no active ghoul — not observable, not executed'},
};
const replacements = {
  festering_scythe:{spellID:458128, displaySpellID:85948, procID:458123, evidence:'simc-source', note:'festering_strike_t replacement while buffs.festering_scythe'},
  vampiric_strike:{spellID:433895, displaySpellID:55090, procID:433899, evidence:'simc-source', note:'scourge_strike_t replacement while buffs.vampiric_strike (San\'layn)'},
  necrotic_coil:{spellID:1242174, displaySpellID:47541, procID:1242223, evidence:'simc-source', note:'death_coil_t replacement while buffs.forbidden_knowledge'},
  graveyard:{spellID:383269, displaySpellID:207317, procID:1242223, evidence:'simc-source', note:'epidemic_t replacement while buffs.forbidden_knowledge'},
  blightfall:{spellID:1271967, displaySpellID:1233448, procID:1271975, evidence:'simc-source', note:'dark_transformation_t replacement while buffs.blightfall'},
};
const essenceMaxStack = 5;
const dndDuration = 10;
const cooldownAlias = {any_dnd:'death_and_decay'};
function classify(ref) {
  const [kind, name, field] = ref.split('.');
  if (kind === 'buff' && buffs[name]) {
    if (field === 'max_stack') return {mode:'static-model', value:essenceMaxStack, source:'sc_spell_data.inc 433925 max_stack', ...buffs[name]};
    return {mode:field === 'stack' || field === 'remains' ? 'native-display+ocr' : 'native-display', ...buffs[name]};
  }
  if (kind === 'debuff' && debuffs[name]) return {mode:field === 'remains' ? 'native-display+ocr' : 'native-display', target:'current', ...debuffs[name]};
  if (kind === 'dot' && debuffs[name]) return {mode:'adapted', source:'Current target debuff only: active_dots=0 <=> no plague on the current target', ...debuffs[name]};
  if (kind === 'cooldown') {
    const spell = spells[cooldownAlias[name] ?? name];
    if (!spell) throw new Error(`Unknown cooldown ${ref}`);
    if (field === 'duration') return {mode:'static-export', source:'baseCooldownMs of the HUD square', ...spell};
    if (field === 'charges' || field === 'max_charges') return {mode:'native-display+ocr', source:'Charge digit (multi-charge square) or cooldown state (single charge); maxCharges from export', ...spell};
    return {mode:'native-display', ...spell};
  }
  if (kind === 'talent') return {mode:'static-export', source:'Talent string of the HUD export', selected:talented(ref.slice(7)) ?? 'pending'};
  if (kind === 'variable') return {mode:'derived', source:'APL expression'};
  if (kind === 'trinket') return {mode:'disabled-model', source:'No-items model: trinket buffs/procs absent, numbers 0 (as Windwalker)'};
  if (kind === 'pet') return {mode:'adapted', source:name === 'army_ghoul' ? 'buff.army_of_the_dead.up (42650, 30 s = army ghoul duration 30 s)'
    : 'talent.summon_gargoyle & buff.army_of_the_dead.remains>5 (gargoyle 25 s from the same cast, sc_spell_data.inc 49206)'};
  if (ref === 'raid_event.pull.has_boss') return {mode:'adapted', source:'No scheduled pulls: has_boss is false (as SimC without pull events)'};
  if (kind === 'raid_event') return {mode:'adapted', source:'No scheduled raid events: *.exists is false; other fields are never reached'};
  const table = {
    active_enemies:{mode:'native-display', source:'TargetCount estimate or manual override; unknown blocks aoe/single_target choice'},
    fight_remains:{mode:'manual-forecast+adapted', source:'fight cell; unknown: "fight ends" triggers off, "fight continues" guards pass (labelled)'},
    'target.health.pct':{mode:'native-display', source:'Current target only, Resources.lua'},
    time:{mode:'observed', source:'Combat start event'},
    runic_power:{mode:'native-display', source:'Runic power number (OCR)'},
    'runic_power.deficit':{mode:'derived', source:'Live maximum (MAX СР cell, else export snapshot) minus runic power'},
    rune:{mode:'native-display', source:'Six rune colour squares; one unreadable rune makes the count unknown'},
    gcd:{mode:'derived', source:'1.5 s adjusted by displayed haste; minimum 0.75'}, 'gcd.max':{mode:'derived', source:'Same as gcd'},
    charges:{mode:'native-display+ocr', source:'Current action (death_and_decay): charge digit or cooldown state'},
    max_charges:{mode:'static-export', source:'maxCharges of the square, 1 for single-charge squares'},
    duration:{mode:'static-model', value:dndDuration, source:'death_and_decay 43265 duration 10 s (sc_spell_data.inc)'},
  };
  if (table[ref]) return table[ref];
  throw new Error(`Unclassified HUD dependency: ${ref}`);
}

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

const unavailable = gates ? Object.entries(spells).filter(([, s]) => s.talent && gates[`talent.${s.talent}`] === false).map(([a]) => a) : 'pending';
const dependencies = refs.map(symbol => ({symbol, ...classify(symbol)}));
// Per hero tree: squares the reachable rules need, and hero buffs that are constant there.
const heroTrees = {};
for (const tree of build.heroTrees) {
  const auras = dependencies.filter(d => d.spellID && d.symbol.split('.')[0] !== 'cooldown');
  const constant = auras.filter(d => d.tree && d.tree !== tree).map(d => d.symbol);
  const squares = {
    spells:[...new Set(Object.values(spells).map(s => s.spellID).filter(id => id !== 46584))],
    procs:[...new Set(auras.filter(d => !(d.tree && d.tree !== tree) && d.symbol.startsWith('buff.') && d.kind !== 'debuff').map(d => d.spellID)
      .concat(tree === 'sanlayn' ? [buffs.gift_of_the_sanlayn.spellID] : [], [buffs.army_of_the_dead.spellID, buffs.reaping.spellID]))].sort((a, b) => a - b),
    debuffs:[...new Set(auras.filter(d => d.kind === 'debuff' || d.symbol.startsWith('debuff.') || d.symbol.startsWith('dot.')).map(d => d.spellID))].sort((a, b) => a - b),
  };
  heroTrees[tree] = {squares, constantDown:constant,
    note:tree === 'sanlayn' ? 'Vampiric Strike replaces Scourge Strike on its button while 433899 or Gift of the San\'layn is up'
      : 'The pinned APL has no Rider-specific rule or buff; horsemen are passive pets and are not tracked'};
}
const result = {
  clientBuild:build.clientBuild, specID:252, heroTrees:build.heroTrees, complete:false,
  note:'Display coverage only. Native rendering, OCR accuracy and APL evaluation are separate concerns. The pinned unholy() has no hero_tree.* conditions.',
  talentGates:gates ?? 'pending: supply build.txt, run docs/traits/decode-build.mjs death_knight 252, then extract.mjs',
  actionsWithoutSelectedTalent:unavailable,
  unusedVariables:[...variables.keys()].filter(k => !needed.has(k)),
  perHeroTree:heroTrees,
  dependencies,
  shadowed,
  actions:{...spells,
    replacements,
    racials:{arcane_torrent:50613, blood_fury:20572, berserking:26297, fireblood:265221, ancestral_call:274738,
      lights_judgment:255647, bag_of_tricks:312411, arcane_pulse:260364, evidence:'wowhead (50613: DK Arcane Torrent, 20 RP)'},
    potion:'User-selected item; not executed', use_item:'Not executed; trinkets modelled as absent',
    auto_attack:'Footer indicator', snapshot_stats:'Simulation-only action',
    invoke_external_buff:'Player coordination; Power Infusion aura 10060 is displayed but cannot be requested',
  },
  notInPinnedApl:['Apocalypse', 'Unholy Assault', 'Festering Wound stacks', 'Mind Freeze', 'Raise Abomination as a button', 'Rider horsemen buffs'],
};
fs.writeFileSync(new URL('coverage.json', root), JSON.stringify(result, null, 2) + '\n');
const ids = [...dependencies, ...Object.entries(spells).map(([symbol, v]) => ({symbol, ...v})), ...Object.entries(replacements).map(([symbol, v]) => ({symbol, ...v}))];
const unresolved = ids.filter(d => ['unresolved', 'conflict'].includes(d.evidence)).map(d => d.symbol);
const byEvidence = {};
for (const d of ids.filter(d => d.evidence)) byEvidence[d.evidence] = (byEvidence[d.evidence] || 0) + 1;
console.log(`Classified ${refs.length} dependencies; ${result.unusedVariables.length} unused variables; ${shadowed.length} shadowed rules; evidence ${JSON.stringify(byEvidence)}; unresolved: ${unresolved.join(', ') || 'none'}. Full coverage: false.`);
