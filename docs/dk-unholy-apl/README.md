# Unholy DK — пакет APL (Rider of the Apocalypse, San'layn)

Статус: `in-development`, работа вслепую по `docs/melee-dps-plan.md`. В игре ничего не проверялось.

## Источники

- APL — функция `unholy()` в `apl_death_knight.cpp` закреплённого коммита SimC
  `4c7c73621e596419b5bd6faa5d68940a9c640379` (копия в пакете, URL в `source.json`).
- ID — `sc_death_knight.cpp` и `sc_spell_data.inc` того же коммита (ссылки в `source.json`,
  файлы не хранятся), затем Wowhead. Таблица талантов — общая `../traits/death_knight-traits.json`.

## Файлы

| Файл | Назначение |
|---|---|
| `extract.mjs` | все списки `unholy()` → `requirements.json` и `build-requirements.json` |
| `coverage.mjs` | зависимости достижимых выражений по веткам, ID с источником → `coverage.json` |
| `build.txt`, `decoded-build.json` | личный билд; игнорируются Git |

Порядок: `node docs/traits/decode-build.mjs death_knight 252 docs/dk-unholy-apl/build.txt`
(необязательно), `node docs/dk-unholy-apl/extract.mjs`, `node docs/dk-unholy-apl/coverage.mjs`.

В закреплённой APL нет `hero_tree.*` и отдельных списков по веткам: обе ветки идут по
одним спискам, `build-requirements.json` содержит все 64 правила дословно.
