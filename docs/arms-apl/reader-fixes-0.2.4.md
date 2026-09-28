# Привязка таймеров, 0.2.4

В журнале 0.2.3 цветовые состояния обычных КД менялись, но в областях Avatar/Colossus Smash фильтр не находил ни одного символа. Баффы и дебаффы продолжали показывать таймеры.

В Squares.lua обычные способности вызывали `SetCooldown(startTime, duration, modRate)` в pcall без проверки результата. Документация live помечает его `SecretArguments = AllowedWhenUntainted`: старый путь не подходит для секретных чисел из аддона. В отличие от него ауры получают привязанный движком Cooldown через AuraButton.

Исправление: `GetSpellCooldownDuration(id, true)` / `GetSpellChargeDuration(id)` передаются непосредственно в `SetCooldownFromDurationObject`. Содержимое объекта длительности в Lua не читается. Числовой fallback допустим только для несекретных start/duration/rate. Ошибки и выбранный путь сохранены в `ns.cooldownStatus` / `AHelperWDB.timerDiagnostics` и доступны командой `/ahw timerdebug`.

Поле status=bound подтверждает только успешное выполнение setter. Отображение и чтение таймеров нужно подтвердить в клиенте. Для этого считыватель сохраняет до трёх исходных фрагментов на квадрат за запуск. Геометрия HUD не менялась.

Источники интерфейса Blizzard:

- [C_Spell: объекты длительности](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
- [Cooldown: SetCooldown и SetCooldownFromDurationObject](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua).
