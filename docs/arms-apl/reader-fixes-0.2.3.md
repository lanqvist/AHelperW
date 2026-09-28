# Исправления отображения и OCR, 28 сентября 2026

По журналу `20260928T110505Z-121f16f2.jsonl`: медианный интервал цветовых кадров 0,106 с; OCR 0,641 с; GCD больше не unknown. Стаки проков принимаются значительно чаще, но обычные таймеры КД практически пропали. Поле haste возвращает строки вроде `20....`, одиночный ноль скорости получает уверенность 0,875.

## Изменения

- `DisplayNumber(decimal)` раньше вызывал `formatter:FormatNumber(value)` из аддонного Lua и при ошибке передавал `value` в SetText. Это оставляло длинный float без ограничения дробной части. Теперь форматирование выполняет `FontString:SetFormattedText`; при ошибке показывается `?`.
- Цвет текста таймера явно белый при настройке виджета. OCR обычных КД дополнительно учитывает цветные цифры, сравнивая их с фоновым цветом квадрата; прежняя маска пропускала только светлые нейтральные пиксели. Причина конкретных пропусков в игре требует повторного наблюдения: изображения в предыдущем журнале не сохранялись.
- Сомнительные числа читаются повторно из оригинального фрагмента с отступами; принятие требует прежнего порога 0,92 и отсутствия числового противоречия с первым проходом. Низкий балл `0` не становится исключением из порога.
- Для зарядов на зелёном/оранжевом фоне используется маска тёмных символов согласно отрисовке Squares.lua.

Положение и размер HUD не меняются. Новый экспорт не обязателен при неизменной геометрии. Улучшение после этих изменений ещё не измерено в игре.

## API-источники

Прочитана документация Blizzard из зеркала исходников интерфейса (ветка live):

- [NumericFormatter: FormatNumber — AllowedWhenUntainted](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericFormatterAPIDocumentation.lua).
- [FontString: SetFormattedText — AllowedWhenTainted](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua).
- [Структуры NumericRuleFormatter](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericRuleFormatterSharedDocumentation.lua).
