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

## Охват: 23 пары, готово 3

| Класс | Спек (ID) | Ветки | Ветвление в APL | Трудность | Статус |
|---|---|---|---|---|---|
| Warrior | Arms (71) | Slayer / Colossus | списки `slayer*`/`colossus*` | низкая | Slayer `game-observed` |
| Warrior | Fury (72) | Slayer / Mountain Thane | списки `slayer*`/`thane*` | низкая | Slayer `experimental` |
| Monk | Windwalker (269) | Shado-Pan / Conduit | общий список, таланты | средняя | Shado-Pan `experimental` |
| Paladin | Retribution (70) | Templar / Herald of the Sun | общий список, `talent.*` | средняя | — |
| Death Knight | Frost (251) | Deathbringer / Rider | `hero_tree.*` в условиях | высокая (руны) | — |
| Death Knight | Unholy (252) | Rider / San'layn | `hero_tree.*`, питомцы, DoT | высокая | — |
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
