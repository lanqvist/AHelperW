# Unholy DK — пакет APL и модель ридера (Rider of the Apocalypse, San'layn)

## Исправление таймера на 30 сентября 2026

При таланте Gift of the San'layn модель читает `buff.dark_transformation` по
видимому баффу **434153**. Он добавлен в `fast_aura_timers`: период OCR теперь
**0.2 с**, как у исходного Dark Transformation, вместо общего периода 0.6 с.
Это изменение расписания реализовано в исходниках; нового игрового замера нет.

Последующие игровые результаты San'layn и известное ограничение Rider (Dark
Transformation не видна без Gift) — `docs/PROJECT_MEMORY.md`, раздел 0. Раздел
ниже сохраняет статус первой реализации, а не итог после игровых исправлений.

## Статус на 29 сентября 2026

Работа вслепую по `docs/melee-dps-plan.md` («Как добавить спек»), как Fury до первого боя.
Spec **252**, ветки **32 Rider of the Apocalypse** и **31 San'layn**, клиент 12.1.0.69933.
Готовы пакет данных, профиль `[252]` (аддон и ридер) и модель `reader/dk_unholy_apl.py`.
**Всё проверено только офлайн** (синтетические экспорты и кадры, `tests/apl/spec_252_unholy.py`);
в игре не было ни экспорта, ни ручного боя, в `_retail_` ничего не доставлялось.
Статус профиля — `in-development`: автонажатия после загрузки выключены.

## Что в закреплённой APL (важно не перепутать с TWW)

`unholy()` закреплённого коммита — APL Midnight: **нет** Apocalypse, Unholy Assault,
Festering Wound (стаков ран), Mind Freeze и `hero_tree.*`. Обе ветки идут по одним
спискам (`precombat`, `default`, `variables`, `racials`, `trinkets`, `cooldowns`,
`single_target` при <3 целях, `aoe` при ≥3), поэтому `build-requirements.json` = все
64 правила дословно. Особенность ветки — только ауры: у Rider баффы San'layn
(`vampiric_strike`, `essence_of_the_blood_queen`) — «пустые» (SimC `make_fallback`,
никогда не активны), у San'layn — читаются с HUD. Правил и баффов, особых для Rider,
в APL нет (всадники — пассивные питомцы, не отслеживаются).

Ключевые действия: Festering Strike (→ Festering Scythe), Scourge Strike (→ Vampiric
Strike у San'layn), Death Coil / Epidemic (→ Necrotic Coil / Graveyard в Forbidden
Knowledge), Putrefy, Soul Reaper, Outbreak, Army of the Dead (Raise Abomination и Summon
Gargoyle лишь меняют её, своей кнопки нет), Dark Transformation (→ Blightfall),
Death and Decay, Raise Dead (только precombat), расовые.

## Профиль [252] (реализован, в игре не проверен)

- `AHelperW/SpecProfiles.lua`: общий пресет (10 способностей + расовые, 10 аур игрока,
  4 дебаффа цели), ветка 31 добавляет Vampiric Strike 433899, Essence 433925, Gift 434153;
  ветка 32 ничего не добавляет. Отметка HP цели 35% (Soul Reaper). `/ahw apl` добавит набор.
- Алиасы замен на той же кнопке (`sharesBindingWith`): Festering Scythe 458128 → 85948,
  Vampiric Strike 433895 → 55090, Necrotic Coil 1242174 → 47541, Graveyard 383269 → 207317,
  Blightfall 1271967 → 1233448. Все — `set_replacement_action` в `sc_death_knight.cpp`.
- `reader/spec_profiles.py`: модель `dk_unholy_apl:UnholyAPL`; быстрые таймеры (0.2 с)
  Dark Transformation 1235391, Essence 433925, Festering Scythe 458123; бинарные (без OCR
  стака) — ауры-переключатели и дебаффы цели. Стаки Essence читаются OCR.
- Lua-тест: алиас `vampiric_strike` в записях 252 обеих веток.

## Модель `UnholyAPL`

- Наследует `APLRuntime`; таблица талантов `../traits/death_knight-traits.json`, ветки из
  профиля. Требует подтверждения применения (`require_cast_confirmation`, как Fury/ВВ).
- Гейты из `sc_death_knight.cpp`: действия талантов (Scourge Strike, Putrefy, Soul Reaper,
  Outbreak, Army, Dark Transformation) без таланта недоступны; **Soul Reaper** — только при
  HP цели ≤35% или ауре Reaping 1242654 (`target_ready`), не по одному цвету HUD;
  **Raise Dead** не нажимается (`ready()` требует отсутствия вурдалака — не наблюдается).
- Баффы без таланта (fallback SimC) — «нет» без квадрата; остальные — по квадрату,
  неизвестный квадрат/таймер/стак → неизвестно → блокировка правила.
- `cooldown.X.ready/remains` — только о КД: `nores`/`unusable` не означает «на КД».
  `cooldown.putrefy.charges/max_charges` и `charges/max_charges` (DnD): цифра зарядов для
  квадрата с несколькими зарядами, иначе 1/0 по состоянию КД; максимум — из экспорта.
  `duration` DnD = 10 с, `max_stack` Essence = 5 (оба из `sc_spell_data.inc`).
- **Замены на кнопке:** если выбранное действие заменено активной аурой, решение несёт
  `spellID` замены и `castAs` (подтверждение ждёт её событие; ID базовой кнопки тоже
  принимается). Vampiric Strike — при ауре 433899 **или** Gift of the San'layn 434153
  (SimC запускает бафф при начале Gift). Если аура замены неизвестна — блокировка
  «замена кнопки … неизвестна».
- Эквивалентность (не адаптация): `buff.lesser_ghoul_ready.stack=0` = аура снята,
  `stack>=1` = аура есть (стаки бывают только при ауре; цифра не читается).

### Помеченные адаптации (в каждом решении, поле `adaptations`)

1. **Текущая цель:** `target_if=min:health.pct` (Soul Reaper, Festering Strike, Death Coil,
   Scourge Strike в AoE) не переключает цели; `dot.*.active_dots=0` — по дебаффу на текущей
   цели (Outbreak распространяет чуму на соседей сам).
2. **Без предметов/зелий/PI:** `trinket.*` — «нет предмета» (как ВВ), `potion`/`use_item`/
   `invoke_external_buff` не исполняются.
3. **Событий рейда нет:** `raid_event.*.exists` = ложь; остальные поля за ним не нужны.
4. **Время боя:** при неизвестном `fight_remains` условия «бой продолжится»
   (`fight_remains>N`) выполняются, «бой кончается» (`fight_remains<3`) — нет; с `/ahw fight`
   работают как в SimC. Та же логика, что Bladestorm/TTD у Fury.
5. **Питомцы:** `pet.army_ghoul.active` = аура Army of the Dead 42650 (30 с = армия 30 с);
   `pet.gargoyle.active` = талант Summon Gargoyle и остаток ауры армии >5 с (горгулья 25 с
   из того же применения). Остаток не прочитан → неизвестно.
6. **Dark Transformation:** SimC требует живого вурдалака; ридер полагается на готовность
   кнопки в HUD (`IsSpellUsable`). Гипотеза: без вурдалака кнопка `unusable` — проверить.
7. ~~Festering Scythe как дебафф цели~~ — исправлено 29 сентября: 1241077 — **бафф игрока**
   (Wowhead: личная аура 25 с, ускоряет тики своих болезней; как дебафф цели не загорелся
   ни разу за 4315 кадров). Читается квадратом баффа; без него Army of the Dead никогда не
   выбиралась, а за ней Dark Transformation и Putrefy.

### Условия, которые будут блокировать выбор

- Руны не прочитаны → `variable.spending_rp` неизвестна → Epidemic/Death Coil в AoE.
- Сила рун не прочитана → `runic_power.deficit` в ST (Death Coil, Putrefy, Scourge Strike).
- Нет квадрата/таймера баффа 1241077 при таланте Festering Scythe → первое правило ST,
  Army of the Dead.
- San'layn: стаки/таймер Essence 433925 не прочитаны; нет квадратов 433899/434153 → замена
  Scourge Strike неизвестна.
- Горгулья (с Summon Gargoyle): таймер ауры армии в Forbidden Knowledge (AoE).
- Число целей неизвестно, если ST и AoE расходятся (общий механизм перебора 1..5).
- Нет квадратов чумы 191587/1240996 → Outbreak.
- Blightfall/Forbidden Knowledge/Festering Scythe/Blighted: при таланте нужен квадрат ауры.

### Не исполняется / не покрыто

Raise Dead (призывать вручную), предметы и зелья, выбор цели, Death and Decay как
наземное заклинание требует бинда без прицела (макрос `/cast [@player] …` или быстрое
применение) — иначе нет события применения и сработает блокировка подтверждения.
Desecrate (San'layn, 1232346 «поглотить DnD») в закреплённом SimC не моделируется.
Если аура замены появится между кадром и нажатием, придёт событие замены, которого
ридер не ждёт → блокировка подтверждения (редкий край; ожидание базового ID есть всегда).

## Итоги покрытия (`coverage.json`)

95 зависимостей, 0 неиспользуемых переменных, 0 затенённых правил. ID: 43 из закреплённого
`sc_death_knight.cpp`/`sc_spell_data.inc`, 1 по Wowhead (Sudden Doom 81340: в SimC — trigger
эффекта 1 таланта 49530), **нерешённых нет**. Проверка в игре не проводилась, так что
`client-export`/`game-observed` пока ни у одного ID. Racials: Arcane Torrent DK 50613 (Wowhead).

## Проверить в игре (по порядку)

1. `/reload` на Unholy (обе ветки по очереди), `/ahw apl` — какие ID клиент не знает
   (особенно 1254252, 1271199, 1241077, 433899, 434153); автоэкспорт; импорт в ридер.
2. Экспорт: ветка (`heroTreeID` 31/32) совпадает с талантами; `castSpellIDs` квадратов,
   у Putrefy `maxCharges` (Putrid Echoes → 3); цвета рун и OCR силы рун.
3. Ручной бой под записью **без автонажатий**: события применения замен (458128, 433895,
   1242174, 383269, 1271967) и что кнопка базы при этом остаётся той же.
4. Горят ли ауры: Sudden Doom 81340, Lesser Ghoul 1254252 (стаки?), Dark Transformation
   1235391, Forbidden Knowledge 1242223, Army 42650 (длительность 30 с), Essence (стаки 1–5),
   Vampiric Strike 433899 во время Gift 434153; дебафф Festering Scythe 1241077 на цели.
5. Dark Transformation без вурдалака — `unusable`? Soul Reaper выше 35% — `unusable`?
6. Death and Decay: как забинжено (без прицела) и приходит ли 43265 в журнал.
7. Офлайн-прогон лога через модель; автонажатия — только по решению пользователя.

## Источники

- APL — `unholy()` в `apl_death_knight.cpp` закреплённого коммита SimC
  `4c7c73621e596419b5bd6faa5d68940a9c640379` (копия в пакете, URL в `source.json`).
- ID и гейты — `sc_death_knight.cpp`, длительности/заряды/стаки — `sc_spell_data.inc`
  того же коммита (ссылки в `source.json`, файлы не хранятся), затем Wowhead (данные
  Midnight, не закреплённая сборка). Таблица талантов — `../traits/death_knight-traits.json`.

## Файлы

| Файл | Назначение |
|---|---|
| `apl_death_knight.cpp` | закреплённый исходник APL (GPL, `COPYING`) |
| `extract.mjs` | все списки `unholy()` → `requirements.json` и `build-requirements.json` |
| `coverage.mjs` | зависимости достижимых выражений по веткам, ID с источником → `coverage.json` |
| `build.txt`, `decoded-build.json` | личный билд; игнорируются Git |

Порядок: `node docs/traits/decode-build.mjs death_knight 252 docs/dk-unholy-apl/build.txt`
(необязательно: даёт `talentGates`), `node docs/dk-unholy-apl/extract.mjs`,
`node docs/dk-unholy-apl/coverage.mjs`. Сценарии: `python tests/apl/run.py 252`.
