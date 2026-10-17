# Frost DK (251) — пакет APL и модель ридера

## Исправления на 30 сентября 2026

Текущий итог игровых проверок — в `docs/PROJECT_MEMORY.md`, раздел 0. Статус ниже
сохраняет историю первой реализации, а не отменяет последующие бои Deathbringer.

- Экспорт пишет `equipment[].equipLoc` через `C_Item.GetItemInfoInstant`. По слоту 16
  `main_hand.2h` различает двуручное и одноручное оружие; отсутствие типа не считается
  двуручным оружием. Старый экспорт с предметом в слоте 17 сохраняет прежний вывод
  `false`; противоречивый экспорт «двуручное + левая рука» остаётся неизвестным.
  Смена экипировки планирует новый автоэкспорт вне боя.
- Добавлен отдельный бинарный бафф **1269322** для бесплатного ERW от MID1 4pc:
  `item_set_bonus.inc` → 1264802 → эффект №2 в `sc_spell_data.inc` → 1269322;
  `empower_rune_weapon_t::ready/update_ready` обходят обычные заряды. Если бафф
  подтверждён по цвету, ERW может выбираться с нулём обычных зарядов или их КД.
  `unknown`, `unusable`, `nores` и `outofrange` кнопки не перекрываются баффом.
  Обычная перезарядка продолжает читаться отдельно, не подменяется нулём.
- Старый экспорт без 1269322 поддерживает только обычные применения ERW; отсутствие
  нового канала указано в `coverage_gaps`. Нужны `/ahw apl` и новый экспорт.
- Эти изменения реализованы в исходниках; отображение нового баффа и применение
  ERW с комплектом **ещё не проверены в игре**. Старые игровые результаты к ним не относятся.

## Статус на 29 сентября 2026

Работа вслепую по `docs/melee-dps-plan.md` («Как добавить спек»), как Fury до первого
входа в игру. Ветки: **Deathbringer** (hero subtree 33) и **Rider of the Apocalypse** (32),
клиент 12.1.5.70448, SimC `b36fc0a2e299f925bc0f72375eea013d7ff5b1cf`. С 17.10 — патч 12.1.5, `docs/patch-12.1.5.md`.

| Что | Состояние |
|---|---|
| Пакет данных (`extract.mjs`, `coverage.mjs`) | реализован |
| Профиль аддона `[251]` (пресеты, алиасы) | реализован, в игре не проверен |
| Профиль ридера (`dk_frost_apl:FrostAPL`, быстрые/бинарные ауры) | реализован, статус `in-development` |
| Модель `reader/dk_frost_apl.py` | реализована, проверена только офлайн (27 сценариев) |
| Игра: экспорт, руны, OCR силы рун, ID, бой | **ничего не проверено** |

Автонажатия после загрузки профиля выключены (статус не `game-observed`).
В `_retail_` ничего не доставлялось, ридер с захватом/вводом не запускался.

## Закреплённая APL

Функция `frost()` в `apl_death_knight.cpp` (сохранён здесь, GPL, хэш LF-текста в
`source.json`; общий файл с Unholy — при интеграции можно оставить одну копию).
Списки: `precombat`, `default`, `variables`, `trinkets`, `high_prio_actions`,
`cooldowns`, `racials`, `aoe` (≥2 целей), `single_target` — 85 правил.

**Списки не делятся по веткам.** Deathbringer и Rider используют одни и те же
списки; различие — только условия `hero_tree.*` и таланты веток. Поэтому
`build-requirements.json` содержит все списки дословно, а `heroTreeRules` перечисляет
правила, где ветка названа:

- Deathbringer: `pillar_of_frost` (два правила, `rune>=2`), `variable.rune_pooling`
  (копить руны за 6 с до Reaper's Mark), `breath_of_sindragosa_check` (порог 60−20 СР);
  действие `reapers_mark` (талант ветки 33); `talent.deathly_blows` в пороге Glacial Advance.
- Rider: только `target_if` у Obliterate в AoE (Chains of Ice Trollbane) и правила
  аксессуаров. Apocalypse Now действует через `frostwyrms_fury` (общее правило).

## Профиль

- `AHelperW/SpecProfiles.lua` `[251]`: руническая сила (число) + шесть рун, эталон
  дальности Obliterate 49020, порогов HP нет (APL Frost их не использует).
- Общий пресет: Obliterate 49020, Frost Strike 49143, Howling Blast 49184, Frostscythe
  207230, Glacial Advance 194913, Remorseless Winter 196770, Pillar of Frost 51271,
  Breath of Sindragosa 1249658, Frostwyrm's Fury 279302, Empower Rune Weapon 47568,
  Raise Dead 46585, Mind Freeze 47528, расовые. Ауры: Killing Machine 51124, Rime 59052,
  Pillar 51271, Breath 1249658, Remorseless Winter 196770 и 1233152 (Frozen Dominion),
  Gathering Storm 211805, Icy Onslaught 1230273, Bonegrinder 377103, Frostbane 1229310,
  Unholy Strength 53365, Chosen of Frostbrood 1265630/1265639, PI 10060.
  Дебаффы: Razorice 51714, Frost Fever 55095.
- Deathbringer: Reaper's Mark 439843 и его дебафф 434765. Rider: ничего сверх общего.
- Алиасы (общая кнопка, `set_replacement_action`): Frostbane 1228433 → Frost Strike
  (пока горит 1229310), Chosen of Frostbrood 1265384 → Frostwyrm's Fury (пока горит 1265639).
- Ридер: таймеры Pillar 51271 и Remorseless Winter 196770/1233152 читаются каждые 0.2 с
  (сравнения с `gcd.max`); стаки читаются только у Killing Machine, Razorice, Gathering
  Storm и Icy Onslaught, остальные ауры — по цвету.
- Квадраты Remorseless Winter 196770 (без Frozen Dominion) и 1233152 (с ним) лишний
  убрать в `/ahw editor`; ненужные квадраты безвредны.

## Модель `FrostAPL`

Гейты по закреплённому `sc_death_knight.cpp` (HUD-цвет их не кодирует):

- действия, выдаваемые талантом (Obliterate, Frost Strike, Howling Blast, Frostscythe,
  Pillar, Breath, Frostwyrm's Fury, ERW, Reaper's Mark, Raise Dead, Mind Freeze), без
  таланта недоступны; `cooldown.X` такого действия — «готов», остаток 0;
- **Frozen Dominion** заменяет Remorseless Winter (узел 377226, replacementId 196770):
  кнопка не жмётся, `buff.remorseless_winter` — аура 1233152;
- бафф невыбранного таланта (`make_fallback`) — точно отсутствует: KM, Pillar, Breath,
  Gathering Storm, Icy Onslaught, Bonegrinder, Frostbane, Chosen of Frostbrood (бафф
  возврата FWF — только с третьей ступенью апекса, ранг 4);
- Frostbane/возврат Chosen of Frostbrood: пока горит бафф, решение несёт ID замены
  (1228433/1265384) для подтверждения применения; при таланте состояние баффа должно
  быть известно, иначе правило блокируется;
- `cooldown.X.ready/remains` — только о кулдауне (нехватка рун/СР или `unusable` не КД);
- `cooldown.empower_rune_weapon.full_recharge_time`: 0 при полных зарядах, таймер
  перезарядки при max−1, глубже — неизвестно (длительность перезарядки HUD не показывает);
- `buff.killing_machine.react` / `debuff.razorice.react` в сравнениях — число стаков
  (OCR); без сравнения — эквивалентное `.up` (стаки есть только у висящей ауры);
- `main_hand.2h`: тип из `equipment[].equipLoc` слота 16; для старых экспортов с
  предметом в слоте 17 — `false`, без этих данных — неизвестно;
- `talent.bonegrinder.rank` — ранг из строки талантов; `gcd.max` = `gcd`.
- При неизвестном числе целей перебираются 1..6 (все сравнения `active_enemies` — с
  константами ≤5: литералы, `frostscythe_priority`=3, `3+deathly_blows`).

**Адаптации** (помечены в `rule` и `adaptations` каждого решения):

1. **Текущая цель вместо `target_if`.** `max:` отброшен (Frost Strike по Razorice,
   Obliterate по Chains of Ice Trollbane); `first:` (Reaper's Mark по
   `debuff.reapers_mark_debuff.down`) проверяется на текущей цели.
2. **Нет сценарных событий рейда:** `raid_event.*.in/cooldown` — очень большое число,
   прочие — 0, как в `raid_event.cpp` без событий. Итог: `sending_cds` истинно при
   любом известном числе целей.
3. **`fight_remains<N` — только при решённом сравнении** (`~(…)`: прогноз `/ahw fight` или
   нижняя граница по TTD текущей цели, у которой нет верхней — поэтому «бой кончается» без
   прогноза не наступает); `fight_remains>10` (Remorseless Winter по стакам Gathering Storm)
   при нерешённом сравнении считается выполненным (`!~(!(…))`).
4. Не исполняются: зелья, `use_item`, Anti-Magic Shell (защитное; `death_knight.first_ams_cast`
   — опция симуляции), `invoke_external_buff` (PI). Аксессуары — модель «отсутствуют».
5. Действия вне GCD (Breath, ERW, Raise Dead, расовые, возврат Chosen) выбираются только
   при готовом GCD — общее ограничение исполнителя.

Не адаптация: Breath of Sindragosa в закреплённом SimC — бафф фиксированной длительности,
а не переключатель; повторное нажатие не отменяет его, правило и так требует `!buff.up`.

## Условия, которые будут блокировать выбор

- Руны: хотя бы одна руна «неизвестно» → `rune` неизвестно → почти все правила
  (Pillar у Deathbringer, KM-Obliterate, rune_pooling, ERW) блокируются.
- Сила рун не прочитана → `runic_power.deficit` (Frost Strike у потолка), ERW, rp_pooling.
- Стаки Killing Machine не прочитаны при горящем KM → `react=2`, ERW (`react<2-...`).
- Стаки Razorice (Shattering Blade), Gathering Storm (стак 10), Icy Onslaught (ERW) — OCR.
- Нет квадрата/неизвестен цвет: Frostbane при таланте (любое правило Frost Strike),
  Chosen of Frostbrood recall при апексе 3 (FWF), Unholy Strength (`fwf_buffs` вне
  Apocalypse Now/Chosen), дебафф Reaper's Mark (Deathbringer), Frost Fever (AoE HB).
- Таймеры Pillar (`remains<gcd.max`, ERW Obliteration) и Remorseless Winter
  (Gathering Storm), кулдауны Pillar/Reaper's Mark/Breath (`remains` из OCR).
- ERW с зарядами ≤ max−2 → `full_recharge_time` неизвестен (второе правило ERW).
- `main_hand.2h` без метаданных типа оружия и без предмета в левой руке — в пятом правиле FWF (Obliteration без
  Apocalypse Now/Chosen).
- Число целей неизвестно и ST/AoE дают разные действия → ждём оценку.

## Проверить в игре первым (вне боя, затем ручной бой под записью без автонажатий)

1. `/reload` → `/ahw apl`: пресет общий + ветка; экспорт пишет `heroTreeID` 33 или 32
   (`C_ClassTalents.GetActiveHeroTalentSpec` в 12.1 не проверен); ридер сверяет с талантами.
2. Экспорт: `castSpellIDs` Frost Strike и Frostwyrm's Fury, `maxCharges` ERW (ожидается 2),
   `baseCooldownMs`; Breath of Sindragosa 1249658 известен клиенту (ClassData/ресерч — 152279).
3. Руны: шесть квадратов готова/КД в бою (секретность `GetRuneCooldown`), ячейка «РУНА, С»,
   OCR силы рун и «MAX СР».
4. Ауры по логу обычного боя: KM 51124 со стаками 1–2 (цифра «1» видна), Rime 59052,
   Razorice 51714 стаки 1–5 на цели, Frost Fever 55095, Pillar 51271, Remorseless Winter
   196770 (или 1233152), Unholy Strength 53365, Icy Onslaught/Gathering Storm — стаки.
5. Receipt: события Obliterate 49020, Frost Strike 49143, Howling Blast 49184,
   Frostscythe 207230, Glacial Advance 194913, Pillar 51271, ERW 47568, FWF 279302,
   Reaper's Mark 439843; при таланте — Frostbane 1228433 и возврат Chosen 1265384
   (кнопка и её цвет следуют за заменой?).
6. Deathbringer: дебафф Reaper's Mark 434765 на цели. Rider: призыв всадников от FWF с
   Apocalypse Now (в APL не читается).
7. Сопоставить выбор модели с ручными GCD офлайн; автонажатия — только по решению пользователя.

## Файлы

| Файл | Назначение |
|---|---|
| `apl_death_knight.cpp` | закреплённый исходник SimC (GPL), проверяется по хэшу |
| `extract.mjs` | все списки Frost → `requirements.json`, `build-requirements.json` (целиком, `heroTreeRules`) |
| `coverage.mjs` | зависимости достижимых выражений по веткам, доказательность ID → `coverage.json` |
| `source.json` | коммит, URL, хэши, ссылки на `sc_death_knight.cpp`, `specialization_spells.inc`, `raid_event.cpp` |
| `build.txt`, `decoded-build.json` | личный билд; игнорируются Git |

Порядок: `node docs/traits/decode-build.mjs death_knight 251 docs/dk-frost-apl/build.txt`
(необязательно), `node docs/dk-frost-apl/extract.mjs`, `node docs/dk-frost-apl/coverage.mjs`.
Сценарии: `python tests/apl/run.py 251`.

## Итоги покрытия (`coverage.json`)

Deathbringer — 106 зависимостей, Rider — 104 (без `cooldown.reapers_mark.remains`,
`debuff.reapers_mark_debuff`, `talent.deathly_blows`; с `talent.apocalypse_now`).
ID: 40 из `simc-source` (закреплённые `sc_death_knight.cpp`, таблица талантов,
`specialization_spells.inc`), 1 Wowhead (Killing Machine 51124: в SimC — trigger таланта
51128 без литерала; ресерч — verified), 7 расовых — как в профилях 72/269 (`profile-reuse`,
для DK не сверялись). `unresolved` — нет. `game-observed` — нет.
Расхождение: ClassData/`research-apl.md` дают Breath of Sindragosa 152279, закреплённая
таблица — 1249658 (использован он).

## Первые бои в игре (29 сентября, Deathbringer)

Итог и исправления — `docs/PROJECT_MEMORY.md`, раздел «Первые бои Frost DK / Deathbringer».
Коротко: руны/сила рун/стаки Killing Machine читаются; Raise Dead не нажимается (квадрат
всегда «неизвестно»); дальность Frostscythe и Glacial Advance подтверждается по Obliterate
(`ns.rangeProxies`). После правок 77/78 подтверждено, все окна GCD с нажатием.
