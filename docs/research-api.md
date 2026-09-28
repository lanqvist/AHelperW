# WoW Addon API — факты для 12.1.0 Midnight (ресерч, 2026-08-28)

## КЛЮЧЕВОЕ: Secret Values (12.0, «addon disarmament»)
В бою / активных энкаунтерах / M+ / PvP числа кулдаунов, здоровья и первичных ресурсов приходят как «секреты»: их можно хранить/передавать/выводить в санкционированные виджеты, но НЕЛЬЗЯ сравнивать, считать, использовать в условиях (Lua-ошибка). `issecretvalue(v)` — проверка. Вторичные ресурсы (комбо, руны, holy power, chi, shards, arcane charges, essence, стаггер) — **никогда не секретны**, полная логика разрешена.

Санкционированные пути отображения секретов:
- `FontString:SetText(secret)`, `StatusBar:SetValue(secret)`
- `Cooldown:SetCooldown(secretStart, secretDur)`, `SetCooldownFromDurationObject(d)` — секунды на КД показывать ТОЛЬКО так
- `Region:SetAlphaFromBoolean(val, aTrue, aFalse)`, `Texture/FontString:SetVertexColorFromBoolean(val, c1, c2)` (12.0)
- ColorCurve (`C_CurveUtil.CreateColorCurve()`) — градиент значение→цвет (для окраски HP по порогам в бою)
- Состояние рестрикций: `C_RestrictedActions.IsAddOnRestrictionActive()`, `C_Secrets.ShouldCooldownsBeSecret()`, событие `ADDON_RESTRICTION_STATE_CHANGED`.

Свои фреймы двигать/красить/прятать в бою МОЖНО (protected — только secure action frames).

## TOC
- `## Interface: 120100` (12.1.0, build 68412). `## SavedVariables: AHelperWDB`.
- `AHelperW_Mainline.toc` побеждает обычный `.toc` (нам хватит обычного).

## Кулдауны
```lua
local cd = C_Spell.GetSpellCooldown(spellID)
-- cd.isActive  (NeverSecret!)  false = кулдаун не идёт → ГОТОВО
-- cd.isOnGCD   (NeverSecret)   true = это просто GCD; читать в обработчике SPELL_UPDATE_COOLDOWN
-- cd.isEnabled (NeverSecret)   false = кулдаун «на паузе»
-- cd.startTime/duration/modRate — СЕКРЕТНЫ в бою
local ch = C_Spell.GetSpellCharges(spellID) -- nil если не заряды
-- ch.currentCharges СЕКРЕТЕН в бою; ch.maxCharges, ch.isActive — нет
```
- Готово: `not cd.isActive`. Реальный КД: `cd.isActive and not cd.isOnGCD`.
- Вне боя классика работает: `remaining = cd.startTime + cd.duration - GetTime()`.
- ВНИМАНИЕ: currentCharges секретен в бою → счётчик зарядов в бою выводить через SetText(secret) без логики, а цвет — через isActive/SetVertexColorFromBoolean.

## События
- `SPELL_UPDATE_COOLDOWN(spellID?, ...)` — НЕ стреляет при окончании КД → нужен тикер `C_Timer.NewTicker(0.1, fn)` для перекраски в «готово».
- `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_USABLE`.
- `frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")` — энергия/фокус; `UNIT_POWER_UPDATE` — дискретные; `UNIT_MAXPOWER`, `UNIT_DISPLAYPOWER`.
- `UNIT_HEALTH`, `UNIT_MAXHEALTH`; `RUNE_POWER_UPDATE(runeIndex, added)`.
- `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED/ENABLED`.
- Стратегия: события + один общий тикер 0.1s только для repaint кулдаунов.

## Ресурсы
```lua
UnitPower("player", Enum.PowerType.X), UnitPowerMax(...)
UnitHealth("player") -- секретен в бою; UnitHealthMax — нет (для игрока)
-- 12.0: UnitHealthPercent, UnitPowerPercent (тоже секреты в бою — в ColorCurve/SetText)
-- ПРОВЕРЕНО В ИГРЕ (12.1 live, источник — VodkaUI: CONTRIBUTING.md + Modules/UnitFrames.lua):
-- * UnitHealth/UnitHealthPercent/UnitPower секретны для аддонов ВСЕГДА, даже вне боя
--   и для своего персонажа. Читаем только UnitHealthMax вне боя.
-- * UnitHealthPercent/UnitPowerPercent возвращают ДОЛЮ 0..1, не проценты.
-- * Curve:Evaluate и форматтеры (FormatNumber) ОТВЕРГАЮТ секреты из tainted-кода —
--   масштабировать долю в проценты нечем. Проценты ХП цифрами недостижимы.
-- * Секрет рендерят только StatusBar:SetValue (на правильной шкале) и
--   FontString:SetText/SetFormattedText («сквозняком», без преобразований).
-- * StatusBar:SetToTargetValue — НЕ анимация значения (рисует полный бар), не использовать.
```
- Enum.PowerType: Mana 0, Rage 1, Focus 2, Energy 3, ComboPoints 4, Runes 5, RunicPower 6, SoulShards 7, LunarPower 8, HolyPower 9, Maelstrom 11, Chi 12, Insanity 13, ArcaneCharges 16, Fury 17, Essence 19.
- Дробные shards: `UnitPower("player", 7, true)` → 0–50, делить на 10.
- Руны: `GetRuneCooldown(1..6)` → startTime, duration, isRuneReady.

## Спек/класс
- `C_SpecializationInfo.GetSpecialization()` (GetSpecialization deprecated с 11.2), `C_SpecializationInfo.GetSpecializationInfo(idx)` → id, name...
- `local _, classFile, classID = UnitClass("player")` — classFile = "ROGUE" и т.п.

## UI
- `CreateFrame("Frame", "AHelperWFrame", UIParent)`; квадрат: `f:CreateTexture(nil,"ARTWORK")` + `t:SetColorTexture(r,g,b,a)`.
- Шрифт: `fs:SetFont([[Interface\AddOns\AHelperW\Media\JetBrainsMono-ExtraBold.ttf]], size, "")` — 12.x ОШИБАЕТСЯ на кривом пути (нет тихого фолбэка), проверять возврат.
- Перетаскивание: SetMovable + RegisterForDrag + StartMoving/StopMovingOrSizing, сохранять GetPoint() в SavedVariables, восстанавливать на PLAYER_LOGIN.
- Пиксель-чёткость: `mult = 768 / select(2, GetPhysicalScreenSize()) / UIParent:GetEffectiveScale()`, все размеры кратны mult; или PixelUtil.SetSize/SetPoint. Пересчёт на UI_SCALE_CHANGED/DISPLAY_SIZE_CHANGED.
- Вспышка: AnimationGroup, Alpha 0.8→0, duration 0.22.

## Ауры/проки в 12.1 (ресерч 2026-08-28)
- Читать ауры в бою НЕЛЬЗЯ: GetPlayerAuraBySpellID → nil при рестрикциях (неотличимо от «нет бафа»); index/instanceID-геттеры — Lua-ошибка; UNIT_AURA приходит с полностью секретным payload (годен только как «что-то изменилось»); AuraData в 12.1 «always fully secret». 12.0-лазейки (auraInstanceID NeverSecret, OnSizeChanged-инференс) закрыты в 12.1.
- САНКЦИОНИРОВАННЫЙ путь — AuraContainer (ПРОВЕРЕНО по wow-ui-source live, Blizzard_AuraContainer; вики врёт):
  ВЕСЬ API — Lua-миксины из аддона Blizzard_AuraContainer (secure environment), НЕ C-методы.
  Голый `CreateFrame("AuraContainer")` имеет только SetUnit/GetUnit/SetEnabled/IsEnabled!
  Правильно: `c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` —
  на шаблоне живут AddAuraGroup/AddAuraSlot/Set*CandidateFilters/флоу-лейаут.
  Для одиночного прок-квадрата — `AddAuraSlot(key, "HELPFUL|PLAYER", opts)` → ВОЗВРАЩАЕТ кнопку,
  якорить вручную (слоты вне флоу-лейаута). `candidateFilters.includeSpellIDs` — MAP {[id]=true}, НЕ массив.
  В opts.initializeFrame(btn): свои регионы + движковые роли (кнопка = CustomAuraButtonTemplate):
  SetIcon(tex), SetApplicationCount(fs[,{formatter}]) — стаки при >1, SetApplicationBar(bar,{maxApplications}),
  SetDurationCooldown(cd), SetDurationText(fs), SetDurationBar(bar), AddPandemicRegion(region).
  Кнопка сама SetShown по ауре (secret-wrapped). spellID-фильтр разрешён для HELPFUL на игроке.
  Удаления групп/слотов НЕТ — только переконфигурация (SetAuraSlotCandidateFilters/FilterString).
  Кнопки forbidden в бою; конфиг вне рестрикций. Кнопки создаются пачками по 10 (обфускация количества).
- C_CooldownViewer: GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff=2) → курируемый список трекаемых бафов спека (статичный конфиг, читается); GetCooldownViewerCooldownInfo(id) → {spellID, linkedSpellIDs, hasAura, selfAura, ...}. Годен как источник дефолтов.
- WeakAuras/Hekili мертвы в Midnight; живые аддоны либо скинят Blizzard Cooldown Manager, либо мигрировали на AuraContainer.

## 12.1 прочее
- Ауры: index-based UnitAura в бою → секреты/nil (нам не критично, ауры не трекаем в v1).
- CLEU регистрация — ошибка (заменён C_CombatLog); не нужен.
- `getglobal/setglobal` deprecated.
