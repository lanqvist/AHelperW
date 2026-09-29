# План: все мили-DPS спеки × героические ветки (вслепую, как Fury)

**Текущий объём (решение пользователя 29 сентября): только Death Knight** — Frost
(Deathbringer, Rider of the Apocalypse) и Unholy (Rider, San'layn). Фаза 0 делается
в объёме, нужном DK; остальные классы из таблицы ниже отложены.

Порядок для DK: (0) основа DK одним агентом — несколько веток в профиле, таблица
талантов DK, руны и сила рун, офлайн-стенд сценариев; затем (1) два агента
параллельно в отдельных worktree — Frost и Unholy; (2) интеграция и память.

Составлен 29 сентября 2026 по закреплённому коммиту SimC
`4c7c73621e596419b5bd6faa5d68940a9c640379` (клиент 12.1.0.69933). Танки, хилеры
и Devourer (DH, дальний бой) не входят. Решение пользователя: делать все мили-DPS.

## Что значит «вслепую, как Fury»

Повторяем три шага Fury до первого входа в игру (`325bc86`, `ed41c56`, `e938225`):

1. **Пакет данных** `docs/<spec>-apl/`: `source.json` (закреплённый коммит и URL),
   `extract.mjs` → `requirements.json` (все списки дословно) и `build-requirements.json`
   (сужение по героической ветке, без правки условий), `decode-build.mjs`,
   `coverage.mjs` → `coverage.json` (зависимости достижимых правил, ID с источником:
   `sc_<class>.cpp` того же коммита, затем Wowhead; `unresolved` — честно).
2. **Профиль** в `AHelperW/SpecProfiles.lua` и `reader/spec_profiles.py`: ресурсы,
   эталон дальности, пороги, алиасы замен (общие бинды), пресет HUD по каждой ветке,
   быстрые/бинарные ауры для OCR.
3. **Модель** `reader/<spec>_apl.py` поверх `APLRuntime`: гейты `ready()` из
   `sc_<class>.cpp`, помеченные адаптации, офлайн-сценарии на синтетических кадрах.
4. `docs/<spec>-apl/README.md`: что сделано, что блокирует выбор, что проверить в игре.

Статус всех новых профилей — `in-development`: автонажатия после загрузки выключены.
Ничего не доставляется в папку игры, ридер с захватом/вводом не запускается.
Неизвестное не заменяется нулём/отсутствием ауры/готовностью (правило AGENTS.md).

## Охват: 23 пары, готово 3 (DK: основа готова, модели в работе)

| Класс | Спек (ID) | Ветки | Ветвление в APL | Трудность | Статус |
|---|---|---|---|---|---|
| Warrior | Arms (71) | Slayer / Colossus | списки `slayer*`/`colossus*` | низкая | Slayer `game-observed` |
| Warrior | Fury (72) | Slayer / Mountain Thane | списки `slayer*`/`thane*` | низкая | Slayer `experimental` |
| Monk | Windwalker (269) | Shado-Pan / Conduit | общий список, таланты | средняя | Shado-Pan `experimental` |
| Paladin | Retribution (70) | Templar / Herald of the Sun | общий список, `talent.*` | средняя | — |
| Death Knight | Frost (251) | Deathbringer / Rider | `hero_tree.*` в условиях | высокая (руны) | основа (Фаза 0), модели нет |
| Death Knight | Unholy (252) | Rider / San'layn | общий список (в закреплённой APL нет `hero_tree.*`), питомцы, DoT | высокая | модель офлайн (`dk-unholy-apl/README.md`), в игре нет |
| Demon Hunter | Havoc (577) | Aldrachi Reaver / Fel-Scarred | `hero_tree.felscarred`, Demonsurge | высокая (рывки) | — |
| Rogue | Assassination (259) | Deathstalker / Fatebound | таланты, DoT, стелс | высокая | — |
| Rogue | Outlaw (260) | Trickster / Fatebound | `hero_tree.fatebound`, Roll the Bones | высокая | — |
| Rogue | Subtlety (261) | Trickster / Deathstalker | Deathstalker's Mark, Shadow Dance | высокая | — |
| Shaman | Enhancement (263) | Stormbringer / Totemic | списки `single_sb`/`single_totemic` | средняя | — |
| Hunter | Survival (255) | Pack Leader / Sentinel | списки `plst/plcleave`/`sentst/sentcleave` | средняя (питомец) | — |
| Druid | Feral (103) | Druid of the Claw / Wildstalker | `hero_tree.*`, кровотечения | высокая | — |

Источник APL: C++ в `engine/class_modules/apl/` (DK, воин, монах, Ret — `retribution_apl.inc`,
Feral — `druid/feral_apl.inc`), `.simc` (Havoc, разбойники), `hunter/sv.txt`,
Enhancement — `ActionPriorityLists/default/shaman_enhancement.simc`.

## ID героических веток

Из таблицы `__trait_sub_tree_data` в `engine/dbc/generated/trait_data.inc` закреплённого
коммита (сборка 12.1.0.69933). Спеки — по узлам-переключателям поддерева (дерево 4,
тип 3) той же таблицы; полный список — `docs/traits/<class>-traits.json`, поле `subtrees`.

| ID | Ветка | Класс | Спеки | Ключ `hero_tree.*` в APL |
|---|---|---|---|---|
| 31 | San'layn | Death Knight | Blood 250, Unholy 252 | `sanlayn` |
| 32 | Rider of the Apocalypse | Death Knight | Frost 251, Unholy 252 | `rider_of_the_apocalypse` |
| 33 | Deathbringer | Death Knight | Blood 250, Frost 251 | `deathbringer` |
| 60 | Slayer | Warrior | Arms 71, Fury 72 | — (в APL не используется) |
| 65 | Shado-Pan | Monk | Brewmaster 268, Windwalker 269 | — |

Для DK в работе: Frost 251 — 33 и 32; Unholy 252 — 32 и 31.

## Фаза 0 — общая основа (последовательно, до разветвления)

**Статус для DK: сделано 29 сентября, только офлайн** (коммиты `aeac41e`, `0819060`,
`7b6eaae`, `72c76fa` и документация; в игре не проверялось, в `_retail_` не доставлялось).
Сделано: профили с несколькими ветками (Lua и ридер, `hero_tree.<key>` в APL), таблица
DK `docs/traits/death_knight-traits.json` и общие `extract-traits.mjs`/`decode-build.mjs`,
сила рун и руны (HUD → экспорт → ридер → `APLRuntime`), офлайн-стенд `tests/apl/`,
табличные Lua-проверки экспорта, заготовки профилей 251/252 без модели. Поведение
71/72/269 не изменилось: экспорт в Lua-моке побайтно тот же, области и план OCR
на локальных экспортах те же, сценарии стенда дают те же ответы на прежнем коде.
Для остальных классов пункты 2–3 ниже остаются планом.

Без неё девять агентов параллельно переписывают одни и те же места.

1. **Профили с несколькими ветками.** Профиль остаётся на спек, но несёт
   `heroTrees = { [subtreeID] = { key, name, preset, aliases? } }`; экспорт пишет
   активную ветку; ридер выбирает ветку по переключателю поддерева. Slayer/Shado-Pan
   без изменений поведения.
2. **Таблицы талантов всех мили-классов** из `trait_data.inc` закреплённого коммита
   (проверка сборки 69933): `docs/traits/<class>-traits.json` + общий декодер. ID
   поддеревьев (героических веток) — в таблицу в этом документе.
3. **Ресурсы по профилю вместо `spec == 269`:** энергия, комбо-очки, руны + сила рун,
   Holy Power, Fury, фокус, Maelstrom. Подписи ячеек и отдельные ветки кода — поля
   профиля. Предупреждение: Maelstrom Weapon у Enhancement — стаки баффа, не ресурс.
4. **Общий офлайн-стенд сценариев** `tests/apl/`: синтетический кадр из экспорта,
   запуск модели, проверка выбора/блокировки с причиной. Arms/Fury/ВВ — первые сценарии.
5. Регистрация: `AGENTS.md`/память — мили-DPS разрешены вслепую; танки отложены.

## Как добавить спек (Frost, Unholy и следующие)

Работать в своём worktree; всё офлайн. Пример — Frost (251); для Unholy (252) то же
с `dk-unholy-apl`, `dk_unholy_apl.py`, `UnholyAPL`, ветками 32/31.

**1. Пакет данных `docs/dk-frost-apl/`** (как `docs/fury-apl/`): `source.json` (коммит,
URL `apl_death_knight.cpp` закреплённого коммита, `"traitTable": "../traits/death_knight-traits.json"`,
`"clientBuild": "12.1.0.69933"`), `extract.mjs` → `requirements.json` и
`build-requirements.json` (формат `{"actions": [{"list", "expression"}]}`, как у Fury;
условия `hero_tree.*` оставлять — ридер их вычисляет), `coverage.mjs` → `coverage.json`,
`README.md`, `COPYING` (копия `docs/traits/COPYING`). Личный билд — `build.txt`
(игнорируется): `node docs/traits/decode-build.mjs death_knight 251 docs/dk-frost-apl/build.txt`
→ `decoded-build.json` (тоже игнорируется). `packaging/AHelperW.spec` сам включит пакет,
когда появятся `build-requirements.json`, `source.json` и `COPYING`.

**2. Профиль аддона `AHelperW/SpecProfiles.lua`** — только своя запись между
комментариями `--- Frost DK (251) ---` и `--- Unholy DK (252) ---`. Уже заполнено:
`id`, `name`, `heroTrees` (ключи = SimC), ресурсы, `referenceSpellID`, `contextCells`
(не менять). Добавить пресеты, алиасы, пороги:

```lua
[251] = {
  id = "deathknight.frost", name = "Frost DK",
  heroTrees = {
    [33] = { key = "deathbringer", name = "Deathbringer",
      preset = { spells = { 439843 }, procs = {}, debuffs = {} } },   -- только своё для ветки
    [32] = { key = "rider_of_the_apocalypse", name = "Rider of the Apocalypse",
      preset = { spells = {}, procs = {}, debuffs = {} } },
  },
  primary = "runic_power", powerType = Enum.PowerType.RunicPower,
  secondary = "runes", secondaryType = Enum.PowerType.Runes,
  referenceSpellID = 49020, executeThresholds = {},
  contextCells = { ... },                                             -- как есть
  preset = { spells = { 49020, 49143, 49184, 51271 }, procs = { 51124, 59052 }, debuffs = {} }, -- общее
  -- aliases = { <действие> = { spellID = <замена>, displaySpellID = <кнопка>, sharesBindingWith = "<действие кнопки>" } },
},
```

ID в примере показывают формат (взяты из `death_knight-traits.json` и `ClassData.lua`),
это не проверенный набор: сверять по `sc_death_knight.cpp` и Wowhead. Алиас нужен,
только если способность подменяет другую на той же кнопке (как Crushing Blow у Fury). `/ahw apl` добавит `preset`
спека плюс `preset` активной ветки; при неизвестной или чужой ветке откажет. Новых
команд `/ahw ...` не нужно. Отметки HP цели — `executeThresholds` (например, `{35}`
для Soul Reaper у Unholy, если это нужно APL).

**3. Профиль ридера `reader/spec_profiles.py`** — только своя запись:
`model='dk_frost_apl:FrostAPL'`, при необходимости `fast_aura_timers` (таймеры аур,
от которых зависят ключевые правила) и `binary_auras` (ауры без счётчика). Ветки
`(DEATHBRINGER, RIDER)`, ресурсы и статус `in-development` не менять.

**4. Модель `reader/dk_frost_apl.py`**:

```python
from apl import APLRuntime, Unknown, unknown, binary

class FrostAPL(APLRuntime):
    spec_id = 251
    trait_file = '../traits/death_knight-traits.json'  # allowed_heroes не задавать: ветки из профиля
    require_cast_confirmation = True
    spells = {'obliterate': 49020, 'frost_strike': 49143, 'howling_blast': 49184}
    buffs = {'killing_machine': 51124, 'rime': 59052}
```

Готово в `APLRuntime`: `hero_tree.<key>` (в том числе как число 0/1), `self.hero_tree` и
`self.hero_tree_id`, `runic_power`, `runic_power.max`, `runic_power.deficit`, `rune`,
`rune.max`, `rune.deficit`, `rune.time_to_N`, `talent.*`, `buff.*`/`cooldown.*` через
`spells`/`buffs`. Своё (гейты `ready()` из `sc_death_knight.cpp`, `talent_actions`,
помеченные адаптации) — переопределением `resolve()`/`available()`/`decide()`, как в
`fury_apl.py`. Отдельные списки на ветку — атрибут `requirements_file`.

**5. Сценарии `tests/apl/spec_251_frost.py`**: `FIXTURE` (синтетический билд: `hero`,
`talents` — имена в нижнем регистре через `_`, `squares`, `aliases`,
`resources=('runic_power',)`, `resourceMeta`, `runes=True`,
`traitFile='../traits/death_knight-traits.json'`) и `SCENARIOS` из
`harness.Scenario(имя, ('ready', действие) | ('blocked', текст) | ('waiting', текст) | ('refused', текст), ...)`.
Кадр: `spells={'obliterate': 'ready'}`, `buffs={'killing_machine': (8, 2)}` (остаток, стаки),
`runes=2` или список из шести состояний, `numbers={'resource/runic_power': 80, 'context/runeNext': 3.}`
(`None` — неизвестно). Образцы — `spec_core.py` (руны, ветки) и `spec_72_fury.py`.
Запуск: `python tests/apl/run.py 251`, весь стенд — без аргумента. Нужен только
Python 3 без зависимостей; личные экспорты не используются и не коммитятся.

**6. Lua-тест**: записи 251/252 для обеих веток уже есть в `tests/run.cjs` (свои строки
между комментариями); при алиасах добавить в свою запись `alias: ['<действие>', spellID]`.
Запуск: `node tests/run.cjs`.

**Не трогать** (не должно понадобиться): `reader/apl.py`, `reader/reader.py`,
`reader/ocr_plan.py`, `reader/talent_decode.py`, `AHelperW/Resources.lua`, `Export.lua`,
`CombatContext.lua`, `Options.lua`, `tests/apl/harness.py`, `tests/hud-context.lua`,
чужие записи профилей, `docs/traits/`, `packaging/AHelperW.spec`, `PROJECT_MEMORY.md`.
Если без правки ядра нельзя — только аддитивно, отдельным коммитом, с перечислением в отчёте.

**Известные ограничения основы:**

- Руны: число готовых — по цвету шести квадратов (готова / восстанавливается /
  неизвестно). `rune.time_to_N` известен только для N ≤ готовых + 1: ячейка «РУНА, С» —
  отсчёт до следующей руны с поправкой на возраст кадра OCR, сбрасывается при смене
  цвета любой руны; для остальных N — неизвестно. Секретность `GetRuneCooldown` в бою
  12.1 не проверена (ресерч: не секретны); если секретны — руны «неизвестно», правила
  с `rune` блокируются.
- Сила рун — OCR числа, как ярость; максимум — из ячейки «MAX СР», иначе снимок экспорта.
- Активная ветка в аддоне — `C_ClassTalents.GetActiveHeroTalentSpec` (в 12.1 не проверено);
  ридер всё равно берёт ветку из строки талантов и сверяет с экспортом.
- `target_if` при нескольких целях по-прежнему блокирует правило; во Frost это
  `obliterate,target_if=max:(hero_tree.rider_of_the_apocalypse&...)`. Решение (например,
  адаптация «текущая цель», как у ВВ) — в модели спека, с пометкой.
- Питомцы Unholy, DoT на нескольких целях, каналы и переключатели (Breath of Sindragosa),
  выражения `death_knight.*` (`first_ams_cast` и т. п.), предметы и зелья основой не покрыты.
- Ничего из DK в игре не проверено: геометрия и цвета рун, OCR силы рун, ID.

## Фаза 1 — по агенту на класс (параллельно, отдельные worktree)

| Агент | Работа |
|---|---|
| warrior | Arms/Colossus, Fury/Mountain Thane в существующих пакетах; Slayer не трогать по поведению |
| monk | ВВ/Conduit в существующем пакете; Shado-Pan не трогать |
| paladin | Ret: Templar, Herald of the Sun |
| deathknight | Frost (Deathbringer, Rider), Unholy (Rider, San'layn) |
| demonhunter | Havoc: Aldrachi Reaver, Fel-Scarred |
| rogue | Assassination, Outlaw, Subtlety (по две ветки) |
| shaman | Enhancement: Stormbringer, Totemic |
| hunter | Survival: Pack Leader, Sentinel |
| druid | Feral: Druid of the Claw, Wildstalker |

Правила для агентов:

- Свои файлы: `docs/<spec>-apl/`, `reader/<spec>_apl.py`, `tests/apl/<spec>*`,
  запись профиля своего спека. Общие файлы (`apl.py`, `Resources.lua`, `Export.lua`,
  `CombatContext.lua`, `reader.py`, `ocr_plan.py`) — только аддитивно, с перечислением
  в отчёте; изменение поведения других спеков запрещено.
- `PROJECT_MEMORY.md` не трогать (обновляется при интеграции).
- Нельзя: доставка в `_retail_`, запуск ридера с захватом/вводом, отладочные заходы.
- Действия, опасные для автонажатия (рывки/перемещения: Fel Rush, Vengeful Retreat,
  Heroic Leap, Charge вне мили; стелс/исчезновение), не исполняются — помечаются.
- Итог — коммиты в своей ветке и отчёт: что сделано, покрытие, блокирующие условия,
  изменения общих файлов, список проверок в игре.

## Фаза 2 — интеграция (последовательно)

Слияние веток по одной, после каждой: `node tests/run.cjs`, офлайн-сценарии всех
спеков. Разрешение конфликтов в реестрах. Обновление памяти и сводной таблицы. Push
в GitHub и новый установщик — только по решению пользователя.

## Фаза 3 — игра (по наличию персонажей)

Для каждой пары: `/reload` → автоэкспорт → ручной бой под записью без автонажатий →
офлайн-прогон лога → решение пользователя об автонажатиях. Из известных персонажей
есть только воины и монах 81-го уровня; остальные классы остаются непроверенными.

## Известные трудности (не решать догадкой)

- **DK:** шесть рун с отдельным восстановлением; `rune.time_to_X` потребует оценки.
- **Разбойники:** стелс/Vanish/Shadow Dance, Roll the Bones (набор баффов), DoT с `target_if`.
- **Unholy, Survival:** питомцы — состояние питомца из HUD ограничено.
- **Feral:** форма кошки, snapshot кровотечений, Wildstalker-кусты.
- **Havoc:** рывки, Metamorphosis с приземлением, Demonsurge-замены.
- **`target_if` на нескольких целях** по-прежнему блокируется (нет состояния всех врагов).
