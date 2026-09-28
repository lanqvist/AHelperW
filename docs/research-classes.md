# Классы/спеки WoW 12.x Midnight — маппинг для HUD (ресерч, 2026-08-28)

40 спеков. Midnight добавил один новый спек — **Devourer DH**. 12.0 сильно порезал кнопки (пруninг).
Легенда: без метки = стабильный ID из 11.x; `[MN]` = новое/переименовано в Midnight; `[MN-ID?]` = ID не подтверждён — проверить на wowhead перед хардкодом; `ch:N` = заряды. В аддоне обязателен рантайм-валидатор: `C_Spell.GetSpellInfo(id)` при загрузке, неизвестные ID скрывать.

## Death Knight — Runic Power + Руны (6)
- **Blood**: Heart Strike 206930, Marrowrend 195182, Blood Boil 50842 (7.5s ch:2), Death Strike 49998, Death and Decay 43265 (15s), Consumption 274156 [MN]. Майджоры: Dancing Rune Weapon 49028, Vampiric Blood 55233, AMS 48707.
- **Frost**: Obliterate 49020, Frost Strike 49143, Howling Blast 49184, Remorseless Winter 196770 (20s). Майджоры: Pillar of Frost 51271, Empower Rune Weapon 47568, Breath of Sindragosa 152279, Frostwyrm's Fury 279302.
- **Unholy**: Festering Strike 85948, Scourge Strike 55090, Death Coil 47541, Epidemic 207317, Putrefy 1247378 [MN], Outbreak 77575. Майджоры: Dark Transformation 63560, Army 42650, Unholy Assault 207289. Festering Wounds УДАЛЕНЫ.

## Demon Hunter — Fury
- **Havoc**: Demon's Bite 162243 / Felblade 232893 (15s), Chaos Strike 162794, Blade Dance 188499 (15s), Eye Beam 198013 (40s), Immolation Aura 258920 (30s ch:1-2), Fel Rush 195072 (10s ch:2). Майджоры: Metamorphosis 191427, The Hunt 370965, Essence Break 258860, Blur 198589.
- **Vengeance** (+Soul Fragments 5): Fracture 263642 (ch:2), Soul Cleave 228477, Spirit Bomb 247454, Immolation Aura 258920, Sigil of Flame 204596 (30s), Fel Devastation 212084 (40s). Майджоры: Demon Spikes 203720 (ch:2), Fiery Brand 204021, Metamorphosis 187827.
- **Devourer** [MN, новый] (+Souls до 50): Consume 473662, Reap 1226019, Void Ray 473728, Devour 1217610, Cull 1245453, Devourer's Bite [MN-ID?]. Майджоры: Void Metamorphosis 471306, Collapsing Star 1221167, Soul Immolation 1241937, Blur 198589 (ch:2), Shift 1234796, Darkness 196718.

## Druid
- **Balance** (Astral Power): Wrath 190984, Starfire 194153, Starsurge 78674, Starfall 191034, Moonfire 8921 / Sunfire 93402, Eclipse-кнопка [MN-ID?], Fury of Elune 202770. Майджоры: Celestial Alignment 194223 / Incarnation 102560, Convoke 391528.
- **Feral** (Energy + Combo 5): Rake 1822, Shred 5221, Rip 1079, Ferocious Bite 22568, Thrash 106830, Tiger's Fury 5217 (30s). Майджоры: Berserk 106951 / Incarnation 102543, Convoke 391528.
- **Guardian** (Rage): Mangle 33917 (6s), Thrash 77758, Ironfur 192081, Frenzied Regeneration 22842 (ch:2), Maul 6807 / Raze 400254, Sundering Roar [MN-ID?]. Майджоры: Survival Instincts 61336 (ch:2), Barkskin 22812, Incarnation 102558 / Berserk 50334, Rage of the Sleeper 200851.
- **Restoration** (Mana): Rejuvenation 774, Lifebloom 33763, Wild Growth 48438 (10s), Swiftmend 18562 (15s ch:1-2), Regrowth 8936, Efflorescence 145205. Майджоры: Tranquility 740, Flourish 197721, Ironbark 102342, Tree of Life 33891, Convoke 391528.

## Evoker — Essence (5-6) + Mana
- **Devastation**: Fire Breath 357208 (30s emp), Eternity Surge 359073 (30s emp), Disintegrate 356995, Pyre 357211, Living Flame 361469, Azure Strike 362969, Shattering Star 370452 (20s). Майджоры: Dragonrage 375087, Deep Breath 357210, Hover 358267 (ch:2), Obsidian Scales 363916 (ch:2).
- **Preservation**: Reversion 366155 (ch:2), Echo 364343, Dream Breath 355936, Spiritbloom 367226, Emerald Blossom 355913, Temporal Anomaly 373861. Майджоры: Rewind 363534 (ch:1-2), Dream Flight 359816, Stasis 370537, Zephyr 374227.
- **Augmentation**: Ebon Might 395152 (30s), Prescience 409311 (12s ch:2), Upheaval 396286 (40s emp), Fire Breath 357208, Eruption 395160. Майджоры: Breath of Eons 403631, Time Skip 404977, Blistering Scales 360827.

## Hunter — Focus
- **Beast Mastery**: Kill Command 34026 (без КД [MN]), Barbed Shot 217200 (ch:2 ~12s), Cobra Shot 193455, Dire Beast 120679. Майджоры: Bestial Wrath 19574 (30s), Bloodshed 321530, The Beast Within [MN-ID?]. Убраны: Call of the Wild, Multi-Shot, Kill Shot, Frenzy-стаки.
- **Marksmanship**: Aimed Shot 19434 (ch:2), Rapid Fire 257044 (20s), Arcane Shot 185358, Steady Shot 56641, Kill Shot 53351, Black Arrow 466930 [MN-ID?], Multi-Shot 257620. Майджоры: Trueshot 288613, Volley 260243.
- **Survival**: Raptor Strike 186270, Kill Command 259489 (без КД [MN]), Wildfire Bomb 259495 (ch:2), Hatchet Toss [MN-ID?], Flamefang Pitch [MN-ID?], Harpoon 190925. Майджоры: Takedown 1250646 [MN] (90s), Boomstick 1261193 [MN] (1m).
- Класс: Counter Shot 147362 / Muzzle 187707, Exhilaration 109304, Survival of the Fittest 264735.

## Mage — Mana
- **Arcane** (+Arcane Charges 4): Arcane Blast 30451, Arcane Barrage 44425, Arcane Missiles 5143, Arcane Pulse 1241462 [MN], Arcane Orb 153626 (ch:1-2). Майджоры: Arcane Surge 365350, Touch of the Magi 321507 (45s), Evocation 12051.
- **Fire**: Fireball 133, **Fire Blast 108853 (ch: до 3!)**, Pyroblast 11366, Flamestrike 2120, Meteor 153561 (45s). Майджоры: Combustion 190319, Shifting Power 382440. Phoenix Flames УДАЛЁН.
- **Frost**: Frostbolt 116 / Glacial Spike 199786, Ice Lance 30455 (Freezing-стаки [MN]), Flurry 44614, Frozen Orb 84714 (1m), Blizzard 190356, Comet Storm 153595 (30s). Майджор: **Ray of Frost 205021 [MN]** (Icy Veins 12472 УДАЛЁН), Cold Snap 235219.
- Класс: Shimmer 212653 (ch:2), Alter Time 342245, Ice Block 45438, Mirror Image 55342.

## Monk — Energy + Chi (WW/BrM), Mana (MW). Roll 109132 ch:2 у всех.
- **Brewmaster**: Keg Smash 121253 (8s ch:1-2), Blackout Kick 100784, Tiger Palm 100780, Breath of Fire 115181 (15s), Rising Sun Kick 107428, Purifying Brew 119582 (ch:2), Celestial Brew 322507 (ch:1-2). Майджоры: Fortifying Brew 115203, Exploding Keg 325153, Invoke Niuzao 132578.
- **Windwalker**: Tiger Palm 100780, Blackout Kick 100784, Rising Sun Kick 107428 (10s), Fists of Fury 113656 (24s), Spinning Crane Kick 101546, Whirling Dragon Punch 152175 (30s), Strike of the Windlord 392983 (40s). Майджоры: Weapons of Order [MN, ID ~387184 проверить], Invoke Xuen 123904, Touch of Karma 122470. SEF УДАЛЁН.
- **Mistweaver**: Renewing Mist 115151 (ch:2), Vivify 116670, Enveloping Mist 124682, Rising Sun Kick 107428, Thunder Focus Tea 116680 (30s), Life Cocoon 116849. Майджоры: Revival 115310, Yu'lon 322118 / Chi-Ji 325197, Mana Tea 197908.

## Paladin — Holy Power (5)
- **Holy**: Holy Shock 20473 (ch:1-2), Word of Glory 85673 / Light of Dawn 85222, Judgment 20271, Crusader Strike 35395, Holy Prism 114165 / Divine Toll 375576, Beacon of Virtue 200025. Майджоры: Avenging Wrath 31884, Aura Mastery 31821, Blessing of Sacrifice 6940, Tyr's Deliverance 200652.
- **Protection**: Avenger's Shield 31935 (15s), Judgment 275779 (ch:1-2), Blessed Hammer 204019 (ch:3), Shield of the Righteous 53600, Consecration 26573, Hammer of Wrath 24275. Майджоры: Ardent Defender 31850, Guardian of Ancient Kings 86659, Divine Shield 642. Eye of Tyr УДАЛЁН.
- **Retribution**: Blade of Justice 184575 (12s, ch:2 талант), Judgment 20271 (ch:1-2), Final Verdict 383328 / Templar's Verdict 85256, Divine Storm 53385, Wake of Ashes 255937. Майджоры: Avenging Wrath 31884 / Crusade 231895, Execution Sentence 343527, Shield of Vengeance 184662, Lay on Hands 633.

## Priest — Mana; Shadow: Insanity
- **Discipline**: PW: Shield 17, Penance 47540 (9s), PW: Radiance 194509 (ch:2), Mind Blast 8092, Purge the Wicked 204197, Evangelism 246287. Майджоры: Rapture 47536, Pain Suppression 33206, PW: Barrier 62618, Ultimate Penitence 421453.
- **Holy**: Holy Word: Serenity 2050, Flash Heal 2061, Prayer of Mending 33076, Circle of Healing 204883 (15s), HW: Chastise 88625, Prayer of Healing 596. Майджоры: Divine Hymn 64843, Guardian Spirit 47788, Apotheosis 200183, HW: Salvation 265202. Renew и Heal УДАЛЕНЫ.
- **Shadow**: Mind Blast 8092 (ch:2), Devouring Plague 335467 (переим. [MN], ID может сохраниться), SW: Death 32379 (ch:1-2), Mind Flay 15407, Void Bolt 205448, Shadow Crash 205385 (переим. [MN]), SW: Pain 589. Майджоры: Void Eruption 228260, Mindbender 200174, Dispersion 47585, Vampiric Embrace 15286.

## Rogue — Energy + Combo (5, до 7). Класс: Kidney Shot 408 (20s), Vanish 1856 (ch:1-2), Evasion 5277, Cloak 31224, Crimson Vial 185311, Shiv 5938 (ch).
- **Assassination**: Garrote 703 (6s), Rupture 1943, Mutilate 1329, Envenom 32645, Crimson Tempest 121411, Kingsbane 385627 (1m). Майджоры: Deathmark 360194, Shiv 5938.
- **Outlaw**: Sinister Strike 193315, Pistol Shot 185763, Dispatch 2098, Between the Eyes 315341 (45s), Blade Flurry 13877 (30s), Roll the Bones 315508 [MN: 4 исхода]. Майджоры: Adrenaline Rush 13750, Killing Spree 51690 / Blade Rush 271877, Keep It Rolling 381989.
- **Subtlety**: Shadowstrike 185438, Backstab 53, Eviscerate 196819, Rupture 1943, Shuriken Storm 197835, Symbols of Death 212283 (30s), **Shadow Dance 185313 (ch:1-2)**. Майджоры: Shadow Blades 121471, Secret Technique 280719 (45s), Flagellation 384631.

## Shaman
- **Elemental** (Maelstrom): Lightning Bolt 188196, Chain Lightning 188443, Lava Burst 51505 (ch:2, 8s), Earth Shock 8042, Earthquake 61882, Voltaic Blaze 470053 [MN]. Майджоры: Fire Elemental 198067, Stormkeeper 191634, Ascendance 114050, Astral Shift 108271. Убраны: Storm Elemental, Primordial Wave, Icefury, Flame Shock.
- **Enhancement** (MSW-стаки 5/10): Stormstrike 17364 (~8s), Lava Lash 60103 (12s), Crash Lightning 187874 (12s), Voltaic Blaze 470053 [MN], Lightning Bolt/Chain Lightning (MSW-спендеры), Sundering 197214 (40s). Майджоры: Ascendance 114051 [MN, вместо Doom Winds], Feral Spirit 51533.
- **Restoration** (Mana): Riptide 61295 (ch:2), Healing Wave 77472, Healing Surge 8004, Chain Heal 1064, Healing Rain 73920 (10s), Healing Stream Totem 5394 (ch), Unleash Life 73685. Майджоры: Healing Tide 108280 / Ascendance 114052 (choice), Spirit Link 98008, Earth Shield 974, Spiritwalker's Grace 79206.

## Warlock — Mana + Soul Shards (5; Destro дробные). Класс: Unending Resolve 104773, Dark Pact 108416.
- **Affliction**: Agony 980, Corruption 172, Unstable Affliction 316099 + Seed 27243 (спендеры [MN]), Haunt 48181 (15s), Drain Soul 198590 / Shadow Bolt 686. Майджоры: Darkglare 205180, Soul Rot 386997. Malefic Rapture УДАЛЁН.
- **Demonology**: Hand of Gul'dan 105174, Call Dreadstalkers 104316 (20s, [MN] слит с Vilefiend), Demonbolt 264178 (Demonic Core стаки), Shadow Bolt 686, Power Siphon 264130 (30s), Implosion 196277. Майджоры: Demonic Tyrant 265187, Grimoire: Felguard 111898.
- **Destruction**: Immolate 348, Incinerate 29722, Conflagrate 17962 (ch:2, 13s), Chaos Bolt 116858, Rain of Fire 5740, Havoc 80240 (30s), Channel Demonfire 196447 (25s), Shadowburn 17877 (ch:2). Майджоры: Summon Infernal 1122, Dimensional Rift 387976.

## Warrior — Rage
- **Arms**: Mortal Strike 12294 (6s), Overpower 7384 (ch:2), Execute 163201, Slam 1464, Cleave 845 / Whirlwind 1680, Warbreaker 262161. Майджоры: Colossus Smash 167105 [MN] (45s), Bladestorm 227847, Sweeping Strikes 260708, Die by the Sword 118038.
- **Fury**: Bloodthirst 23881 (4.5s), Raging Blow 85288 (ch:2), Rampage 184367, Execute 5308, Whirlwind 190411, Onslaught 315720. Майджоры: Recklessness 1719, Odyn's Fury 385059 (45s), Bladestorm 227847, Enraged Regeneration 184364.
- **Protection**: Shield Slam 23922 (9s), Thunder Clap 6343 (6s), Revenge 6572 [MN], Ignore Pain 190456, **Shield Block 2565 (ch:2)**, Shield Charge 385952. Майджоры: Shield Wall 871 (ch:1-2), Last Stand 12975, Demoralizing Shout 1160, Avatar 401150, Spell Reflection 23920.

## Особые механики для HUD
- Вторичные максимумы: Combo 5(-7), Holy Power 5, Chi 5-6, Shards 5, Arcane Charges 4, Essence 5-6, Руны 6, Souls (Devourer) 50, MSW 5/10, Soul Fragments (Veng) 5.
- Заряды трекать обязательно: Fire Blast (3!), Roll, Barbed Shot, Aimed Shot, Wildfire Bomb, Lava Burst, Riptide, Renewing Mist, Reversion, Hover, Obsidian Scales, Prescience, Conflagrate, Shadowburn, Overpower, Raging Blow, Shield Block, Purifying Brew, Demon Spikes, Fracture, Fel Rush, Blood Boil, Shadow Dance, Vanish, Holy Shock, Judgment (Prot/Ret), Blessed Hammer, PW: Radiance, Mind Blast, SW: Death, Arcane Orb, Shimmer, Swiftmend, Immolation Aura, Shield Wall и др.
- Все [MN-ID?] проверить на wowhead; рантайм-валидация ID обязательна.
