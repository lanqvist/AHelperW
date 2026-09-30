// Inventory source-backed display requirements; not a game/behavioural test.
import fs from 'node:fs';
const root=new URL('./',import.meta.url);
const read=name=>JSON.parse(fs.readFileSync(new URL(name,root),'utf8'));
const req=read('requirements.json'), source=read('source.json');
const data=(spellID,note)=>({spellID,evidence:'simc-source',note});
const actions={
  rebuke:data(96231,'sc_paladin.cpp: class Rebuke; sc_spell_data.inc 96231; only on an interruptible casting target'),
  execution_sentence:data(343527,'paladin-traits.json, sc_paladin_retribution.cpp execution_sentence_t'),
  avenging_wrath:data(31884,'sc_paladin.cpp avenging_wrath_t; background with Radiant Glory'),
  hammer_of_light:data(427453,'sc_paladin.cpp spells.templar.hammer_of_light_driver; 255937 override in sc_spell_data.inc aura 427441'),
  divine_storm:data(53385,'paladin-traits.json, divine_storm_t; 3 Holy Power or confirmed free proc'),
  templars_verdict:data(85256,'sc_spell_data.inc 85256; Final Verdict 383328 replaces it (trait table, templars_verdict_t)'),
  wake_of_ashes:data(255937,'paladin-traits.json; wake_of_ashes_t::target_ready rejects while 427441 is up'),
  divine_toll:data(375576,'paladin-traits.json, sc_paladin.cpp divine_toll_t'),
  blade_of_justice:data(184575,'paladin-traits.json, blade_of_justice_t'),
  hammer_of_wrath:data(24275,'sc_paladin_retribution.cpp spells.hammer_of_wrath_ret; sc_paladin.cpp action_ready requires 1277026, not execute HP'),
  judgment:data(20271,'sc_paladin_retribution.cpp spells.judgment_ret; sc_paladin.cpp action_ready rejects during 1277026'),
  templar_strike:data(407480,'sc_paladin_retribution.cpp templar_strike_t; replaces 35395, follows absence of 406648'),
  templar_slash:data(406647,'sc_paladin_retribution.cpp templar_slash_t; 406648 effect replaces 407480, shared 35395 bind'),
  crusader_strike:data(35395,'sc_spell_data.inc, sc_paladin.cpp; background if Crusading Strikes or Templar Strikes selected'),
  arcane_torrent:data(155145,'sc_spell_data.inc Paladin Arcane Torrent; racial, only with a configured bind/ready observation'),
  lights_judgment:data(255647,'sc_spell_data.inc racial Light’s Judgment'),
  fireblood:data(265221,'sc_spell_data.inc racial Fireblood'),
};
const buffs={
  avenging_wrath:data(31884,'sc_paladin.cpp spells.avenging_wrath = 454351 under Radiant Glory, otherwise 31884; stacks with Crusade'),
  hammer_of_light_ready:data(427441,'sc_paladin.cpp buffs.templar.hammer_of_light_ready; readiness gate, not a timer assumption'),
  hammer_of_light_free:data(433732,'sc_paladin.cpp buffs.templar.hammer_of_light_free'),
  undisputed_ruling:data(432629,'sc_paladin.cpp buffs.templar.undisputed_ruling'),
  divine_arbiter_verdict:data(1306161,'sc_paladin.cpp spells.divine_arbiter_verdict; MID2 4pc effect, not a decoded talent (sc_paladin_retribution.cpp init_actions)'),
  divine_arbiter_divine_storm:data(1306162,'sc_paladin.cpp spells.divine_arbiter_divine_storm; MID2 4pc effect, not a decoded talent (sc_paladin_retribution.cpp init_actions)'),
  empyrean_legacy:data(387178,'sc_paladin_retribution.cpp create_buffs'),
  art_of_war:data(406086,'sc_paladin_retribution.cpp create_buffs; stacking under Light Within'),
  righteous_cause:data(402916,'sc_paladin_retribution.cpp create_buffs; stacking under Light Within'),
  templar_strikes:data(406648,'sc_paladin_retribution.cpp create_buffs; follow-up gate'),
  divine_purpose:data(408458,'sc_paladin.cpp spells.divine_purpose_buff for Retribution; holy_power_consumer_t cost'),
  empyrean_power:data(326733,'sc_paladin_retribution.cpp create_buffs; Divine Storm free cast'),
  hammer_of_wrath:data(1277026,'sc_paladin.cpp create_buffs; exact AW lifecycle proxy for up/down, native aura retained for diagnostics'),
};
const debuffs={
  execution_sentence_debuff:data(343527,'sc_paladin.hpp execution_sentence_debuff_t uses talent spell; trait table 343527'),
  expurgation:data(383346,'sc_paladin_retribution.cpp spells.expurgation; current target only'),
};
function classify(symbol){
  const [kind,name,field]=symbol.split('.');
  if(kind==='buff'&&buffs[name])return {mode:['remains','stack'].includes(field)?'native-display+ocr':'native-display',...buffs[name]};
  if(['dot','debuff'].includes(kind)&&debuffs[name])return {mode:'native-display',...debuffs[name]};
  if(kind==='cooldown'&&actions[name])return {mode:name==='wake_of_ashes'?'base-cooldown-telemetry':field==='duration'?'static-export':'native-display+ocr',...actions[name]};
  if(kind==='talent')return {mode:'static-export',note:'Actual v2 talent string decoded against the pinned class table'};
  if(kind==='variable')return {mode:'derived',note:'Pinned expression; pre_es_wake reset -> upstream default 0'};
  if(['trinket','equipped'].includes(kind))return {mode:'adapted',note:'No-items mode; these selectors are explicitly disabled, not discovered as absent'};
  if(kind==='raid_event')return {mode:'adapted',note:'No scripted raid events'};
  const known={
    holy_power:{mode:'native-display+ocr',note:'Numeric secondary resource, white digits 00..05; exported maximum validates input'},
    active_enemies:{mode:'native-display+ocr',note:'HUD estimate; unknown stays unknown unless result is count-independent'},
    gcd:{mode:'derived',note:'1.5 seconds scaled by displayed haste, lower bound 0.75'},
    fight_remains:{mode:'manual-forecast',note:'Short-fight clauses only with known forecast'},
    'target.time_to_die':{mode:'manual-forecast',note:'ES trigger disabled without TTD; Wake does not wait for that disabled trigger'},
  };
  return known[symbol]||{mode:'unresolved',evidence:'unresolved'};
}
const dependencies=req.references.map(symbol=>({symbol,...classify(symbol)}));
const unresolved=dependencies.filter(d=>d.mode==='unresolved').map(d=>d.symbol);
const result={specID:70,clientBuild:source.clientBuild,complete:false,status:'in-development',
  note:'Source inventory only, not an APL fidelity test. Partial manual Templar observations and remaining HUD issues are recorded separately in README.md; automatic inputs and Herald unverified.',
  source,heroTrees:{48:'templar',50:'herald_of_the_sun'},dependencies,actions,
  readinessDependencies:buffs,readinessDebuffs:debuffs,
  adaptations:['current-target-no-items','known-forecast-clauses-only','ES disabled without TTD; Wake sync adapted accordingly','off-GCD waits for ready GCD'],
  replacements:{hammer_of_light:{spellID:427453,displaySpellID:255937,auraID:427441},
    templar_strike:{spellID:407480,displaySpellID:35395},templar_slash:{spellID:406647,displaySpellID:35395,auraID:406648},
    final_verdict:{spellID:383328,displaySpellID:85256}},
  unresolved,
};
fs.writeFileSync(new URL('coverage.json',root),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({dependencies:dependencies.length,unresolved}));
