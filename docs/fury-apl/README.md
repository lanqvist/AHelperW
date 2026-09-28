# Fury / Slayer — пакет APL и модель ридера

## Статус на 28 сентября 2026

Разработка Fury разрешена пользователем; выбрана ветка **Slayer** (hero subtree 60),
spec **72**, клиент 12.1.0.69933. Готовы пакет данных (извлечение APL,
декодирование билда, отчёт покрытия), профиль `[72]` и модель `reader/fury_apl.py`.
Модель проверена только офлайн на синтетических кадрах; ручного боя под
записью и автонажатий Fury ещё не было.

## Профиль [72] (реализован, в игре не проверен)

- `AHelperW/SpecProfiles.lua`: `warrior.fury.slayer`, ярость, эталон дальности
  Bloodthirst 23881, отметки 20/35, алиасы Crushing Blow 335097 → Raging Blow
  и Bloodbath 335096 → Bloodthirst с общими биндами. `/ahw furyapl` (или
  `/ahw apl`) дополняет набор HUD пресетом. Sudden Death 52437 и
  Hack and Slash 383873 подтверждены в бою. Avatar исключён: его нет в билде.
  Уже добавленные квадраты 280776 и Thunder Blast безвредны; убрать в `/ahw editor`.
- Компактная строка Arms теперь относится к любому профилю с одной яростью,
  то есть и к Fury. Отметки порогов одинаковы с Arms: в билде нет Massacre,
  поэтому для APL значим только 20%.
- Пресет Fury по умолчанию в `ClassData.lua` дополнен Rampage 184367.
- `reader/spec_profiles.py`: статус `in-development`, модель `FuryAPL`.
  Автонажатия при загрузке профилей не из `game-observed` выключены.
- `/ahw auradump` — все баффы игрока вне боя со spellID (поиск новых ID).
- OCR: таймер Enrage 184362 читается каждые 0.2 с вместо 0.6; стаки
  бинарных аур (Enrage, Recklessness, Bladestorm 446035, Berserker Stance, PI)
  не распознаются, как у Arms. Список Arms перенесён в профиль без изменения.
- Проверка без игры: экспорт `MakeHUDExport` и `Resources.Build` в Lua VM
  (моки из `tests/hud-context.lua`) для spec 71 и 72, обычный и компактный вид;
  план OCR Arms до/после правки совпал.

## Первый ручной бой (28 сентября, лог `20260928T195134Z-649af31e`)

Чтение без автонажатий, ~20 с, 320 кадров (~16 Гц), все валидны, receipt
читаем во всех кадрах. 5 целей (автооценка), цели с ~25% HP до смерти —
в основном фаза добивания, ветка `slayer_aoe`. Модель прогнана офлайн по
кадрам с подменой времени на `capturedAt`; клавиши не отправлялись.

- **ID подтверждены событиями применения:** Rampage 184367, Bloodbath 335096,
  Crushing Blow 335097, Execute 5308, Whirlwind 190411, Bladestorm 446035,
  Odyn's Fury 385059. Дочерние удары (184707/184709, 280849, 335098/335100,
  385060–385062, 199667/44949, тики 50622) идут отдельными событиями.
- **Sudden Death = 52437** (горел 22 кадра, снят Execute); 280776 не загорался
  ни разу — удалён из модели и пресетов. **Hack and Slash 383873** горел 129 кадров.
- OCR: таймер Enrage читается гладко (4 → 0.1), неизвестен только первый кадр
  после прока; стаки Whirlwind 4→3→2→1, затем аура гаснет.
- Unhinged: во время Bladestorm клиент сам применяет Bloodbath (события 335096
  без нажатия). Подтверждение ввода может принять их за ответ на нажатие Bloodbath.
- Rampage был `ready` уже при 49–66 ярости по OCR; кнопка следует
  `IsSpellUsable` клиента, стоимость отдельно не проверялась.
- Начало боя: 1.5 с `blocked` по `context/targets`, пока автооценка
  стабилизировалась (0 → 5); вы успели Recklessness и Whirlwind.
- Сопоставление: из 10 ваших GCD-действий после стабилизации совпало одно
  (Whirlwind при 0 стаков). В остальных модель выбирала Rampage: по APL
  `slayer_aoe` он безусловно стоит сразу после Whirlwind/Recklessness, а ярость
  держалась на максимуме 130 примерно с 6.4 с до конца (~11 с). Это расхождение
  с ручной игрой, а не дефект чтения.
- Во время Bladestorm все кнопки `unusable`; модель выбирает только Storm Bolt
  (общее исключение Arms), вы его не нажимали.

## Модель `FuryAPL` (офлайн-проверка; боевого исполнения ещё не было)

- Наследует `APLRuntime`; списки из `build-requirements.json`, таблица
  талантов — общая `../arms-apl/warrior-traits.json`. Требует подтверждения
  применения (как ВВ): без события за 2.5 с автонажатия блокируются.
- Гейты `ready()` из закреплённого `sc_warrior.cpp`: с Reckless Abandon во
  время Recklessness Bloodthirst/Raging Blow недоступны, Bloodbath/Crushing
  Blow — только во время Recklessness; действия без таланта недоступны;
  Berserker Stance — только при отсутствии ауры; Execute — только при
  Sudden Death или HP цели ≤ 20% (35% с Massacre), не по одному цвету HUD.
- `cooldown.X.ready/remains` — только о кулдауне: `nores`/`unusable` кнопки
  не делает её «на КД».
- **Адаптация** (помечена в каждом решении): `bladestorm,if=buff.recklessness.up|
  target.time_to_die<=5` исполняется как `…|ahw_ttd_known&target.time_to_die<=5`.
  Без заданного TTD Bladestorm идёт только в Recklessness; догадки о TTD нет.
- Предметы/зелья/PI не исполняются (как у Arms/ВВ).
- Офлайн-сценарии на сохранённом экспорте (без захвата/ввода): открытие
  Recklessness; Rampage при rage≥100 в Recklessness и при спадающем Enrage;
  Crushing Blow в Recklessness; Odyn's Fury/Raging Blow вне неё; Execute только
  с Sudden Death выше 20%; Whirlwind первым в AoE при 0 стаков; Bladestorm
  при TTD 3 и не при TTD 60; Berserker Stance вне боя. Блокировки с причиной:
  нет квадрата Hack and Slash, устаревший таймер Enrage, неизвестное число
  целей, неизвестные оба квадрата Sudden Death.
- Во время канала Bladestorm выбирается только Storm Bolt (общее исключение
  Arms); если APL выбирает другое действие, ридер ждёт конца канала.

## Источники

- APL — функция `fury()` в `../arms-apl/apl_warrior.cpp`, тот же закреплённый
  коммит SimC `4c7c73621e596419b5bd6faa5d68940a9c640379`, что и у Arms.
  `extract.mjs` проверяет совпадение коммитов в двух `source.json`.
- Таблица талантов — общая `../arms-apl/warrior-traits.json` (узлы spec 72 и
  hero subtree 60/61 той же сборки). Копия не создаётся.
- ID баффов/замен сверены по `sc_warrior.cpp` того же коммита (ссылка в
  `source.json`, файл не хранится). Это источник SimC, не проверка на клиенте.

## Файлы

| Файл | Назначение |
|---|---|
| `extract.mjs` | все списки Fury → `requirements.json`; Slayer-сужение → `build-requirements.json` |
| `decode-build.mjs` | строка талантов v2 из `build.txt` → `decoded-build.json`, требует spec 72 и Slayer |
| `coverage.mjs` | зависимости достижимых выражений, доказательность ID, недостижимые правила → `coverage.json` |
| `build.txt`, `decoded-build.json` | личный билд; игнорируются Git |

Порядок: `node decode-build.mjs`, `node extract.mjs`, `node coverage.mjs`.
Slayer-сужение убирает только списки `thane`/`thane_aoe` и их `run_action_list`;
остальные 77 из 121 правил сохранены дословно, таланты проверяются в runtime.

## Билд пользователя (декодирован, в клиенте не сверялся)

Slayer, 77 выбранных узлов. Для APL важно:

- **Нет Massacre** → порог добивания **20%**, не 35% как у Arms.
- **Нет Avatar** → `avatar` из `slayer_aoe` неприменим.
- Есть Reckless Abandon (Crushing Blow / Bloodbath), Improved Whirlwind,
  Hack and Slash, Sudden Death, Odyn's Fury, Bladestorm, Unrelenting Onslaught
  (бафф Bladestorm — 446035, как у Arms), Storm Bolt, Berserker Stance.

## Первый экспорт из игры (28 сентября)

Сохранён локально как `reader/profile-spec-72.json` (игнорируется Git).
Компактный вид, 3840×2160, 23 квадрата. Ридер разбирает экспорт; план OCR:
таймер Enrage — 0.2 с, стаки Bladestorm берутся из Imminent Demise,
модель APL для spec 72 ожидаемо отклоняется. Захват и нажатия не запускались.

- Таланты из игры декодируются в тот же набор, что `build.txt`
  (74 названия, ранги совпадают); строки различаются только хэшем дерева.
- Execute показан как 5308 без override (Massacre нет); Whirlwind 190411
  известен клиенту; Raging Blow — 2 заряда; Bladestorm `castSpellIDs`
  [227847, 446035] — override Unrelenting Onslaught вне боя подтверждён.
- Sudden Death: клиент знает оба ID (52437 и 280776) под одним именем.
  Экспорт конфликт не решает — нужен `/ahw procdebug` при активном прок.
- Hack and Slash в HUD нет (ID неизвестен).
- В наборе остались квадраты из прежнего умолчания ClassData:
  Enraged Regeneration 184364 (защитный, в APL не используется) и
  Thunder Blast 435615 (Mountain Thane, для Slayer бесполезен).
- Экипирован комплект «нефритового полководца» (4 предмета). Принадлежность
  к MID2 не проверена; Slayer-списки на бонусы комплекта не ссылаются.
- Аксессуары 265657/274493 без `useSpellID` в экспорте; trinket-модель — отсутствие.

## Итоги покрытия (`coverage.json`)

54 зависимости; полного покрытия нет. Нерешённых ID нет:

| Символ | Статус |
|---|---|
| `buff.sudden_death` | 52437, наблюдался в бою; 280776 не горел |
| `buff.hack_and_slash` | 383873 (Wowhead: trigger таланта 383877), наблюдался в бою |

Execute 5308 и Whirlwind 190411 получили статус `client-export` по первому
экспорту (см. ниже); применение и подсветка в бою ещё не наблюдались.

Уточнять по логу обычного ручного боя (цвета квадратов, receipt), без
отдельных отладочных сессий; не вписывать догадку как подтверждённое значение.

### Условия, которые будут блокировать выбор

- `rampage,if=buff.enrage.remains<gcd` — нужен свежий OCR таймера Enrage
  (период поднят до 0.2 с); при просрочке значение неизвестно и блокирует список.
- `rampage,if=buff.recklessness.up&!buff.hack_and_slash.up` — без квадрата
  383873 в HUD блокирует выбор в Recklessness, если Rampage доступен.
- Bladestorm/TTD — см. адаптацию выше.
- `whirlwind,if=talent.improved_whirlwind&buff.whirlwind.stack=0` (AoE) —
  стаки Whirlwind через OCR; отсутствие ауры даёт 0, неизвестность — блок.
- `active_enemies` выбирает slayer / slayer_aoe; неизвестное число целей блокирует.
- `charge` (`movement.distance`) и `pummel` — как у Arms.

### Особенности закреплённой APL (сохранены как есть)

- В ST-списке `slayer` нет `avatar` (только в `slayer_aoe`).
- Два правила `execute` после безусловного `execute` недостижимы (`shadowed`).
- Fury `execute` в SimC готов только при HP цели ≤ порога или Sudden Death.
  Безусловное правило опирается на состояние `unusable` квадрата в HUD;
  нужна отдельная проверка, что HUD не показывает `ready` выше порога
  (урок Touch of Death у ВВ).
- Crushing Blow (335097) и Bloodbath (335096) — замены Raging Blow/Bloodthirst
  с общими биндами; Crushing Blow в SimC готов только во время Recklessness.
- `trinkets`, `potion`, `invoke_external_buff`, `heroic_leap` не исполняются;
  trinket-переменные моделируются как у Arms/ВВ (предметы отсутствуют).

## Следующие шаги

1. Профиль `[72]` в `SpecProfiles.lua` и `spec_profiles.py`: эталон дальности
   Bloodthirst, порог 20, алиасы Crushing Blow/Bloodbath, пресет HUD по
   `coverage.json`. — сделано, см. выше.
2. `FuryAPL(APLRuntime)` — сделано, см. выше.
3. В игре вне боя: `/reload`, `/ahw furyapl` (добавит Hack and Slash),
   убрать Thunder Blast в `/ahw editor`, `/ahw export`, импорт в ридер,
   назначить клавиши, ручной бой под записью ридера без автонажатий.
4. Офлайн-прогон этого лога; автонажатия — только по решению пользователя.
