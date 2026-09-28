# Fury / Slayer — пакет APL (подготовка)

## Статус на 28 сентября 2026

Разработка Fury разрешена пользователем; выбрана ветка **Slayer** (hero subtree 60),
spec **72**, клиент 12.1.0.69933. Готовы пакет данных (извлечение APL,
декодирование билда, отчёт покрытия) и профиль `[72]` для HUD/экспорта/чтения.
`FuryAPL` **не реализован**: ридер явно отказывает в модели APL для spec 72.
В игре ничего не проверялось, автонажатия не запускались.

## Профиль [72] (реализован, в игре не проверен)

- `AHelperW/SpecProfiles.lua`: `warrior.fury.slayer`, ярость, эталон дальности
  Bloodthirst 23881, отметки 20/35, алиасы Crushing Blow 335097 → Raging Blow
  и Bloodbath 335096 → Bloodthirst с общими биндами. `/ahw furyapl` (или
  `/ahw apl`) дополняет набор HUD пресетом. Sudden Death включён под обоими
  спорными ID (52437 и 280776), чтобы `/ahw procdebug` показал, какой горит.
  Execute 5308 и Whirlwind 190411 — непроверенные ID; Hack and Slash без ID
  в пресет не входит. Avatar исключён: его нет в билде.
- Компактная строка Arms теперь относится к любому профилю с одной яростью,
  то есть и к Fury. Отметки порогов одинаковы с Arms: в билде нет Massacre,
  поэтому для APL значим только 20%.
- Пресет Fury по умолчанию в `ClassData.lua` дополнен Rampage 184367.
- `reader/spec_profiles.py`: статус `in-development`; `create_apl` для spec 72
  выбрасывает понятную ошибку, чтение HUD и назначение клавиш работают.
  Автонажатия при загрузке профилей не из `game-observed` выключены.
- OCR: таймер Enrage 184362 читается каждые 0.2 с вместо 0.6; стаки
  бинарных аур (Enrage, Recklessness, Bladestorm 446035, Berserker Stance, PI)
  не распознаются, как у Arms. Список Arms перенесён в профиль без изменения.
- Проверка без игры: экспорт `MakeHUDExport` и `Resources.Build` в Lua VM
  (моки из `tests/hud-context.lua`) для spec 71 и 72, обычный и компактный вид;
  план OCR Arms до/после правки совпал.

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

## Итоги покрытия (`coverage.json`)

54 зависимости; полного покрытия нет. ID со статусом **pending/conflict**:

| Символ | Проблема |
|---|---|
| `buff.sudden_death` | **конфликт**: SimC — 52437; research-apl и пресет Fury в ClassData — 280776 |
| `buff.hack_and_slash` | ID — trigger таланта 383877, числа нет в исходнике |
| `execute` | Fury-версия через `find_specialization_spell`; 5308/280735 — догадки |
| `whirlwind` | `find_class_spell("Whirlwind")`; ID нет в исходнике |

Проверять вне боя/в бою через `/ahw procdebug` и экспорт `castSpellIDs`, не
вписывать догадку как подтверждённое значение.

### Условия, которые будут блокировать выбор

- `rampage,if=buff.enrage.remains<gcd` — нужен свежий OCR таймера Enrage.
  Обычный период таймеров ~0.6 с; при просрочке значение неизвестно и
  блокирует список. Потребуется повышенный приоритет чтения.
- `bladestorm,if=buff.recklessness.up|target.time_to_die<=5` — вне Recklessness
  зависит от ручного TTD; на манекене повторит проблему Avatar у Arms.
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
2. `FuryAPL(APLRuntime)`: таблицы ID, гейты замен, явные адаптации.
3. В игре вне боя: доставить Lua, `/reload`, `/ahw furyapl`, `/ahw procdebug`
   для pending-ID, `/ahw export`, ручной бой с логом ридера.
4. Офлайн-прогон ручного лога без нажатий; автонажатия — только по решению пользователя.
