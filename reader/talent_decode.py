"""WoW v2 class-tree decoder, using a pinned table and explicit hero selector."""
import re


def decode(text, table, spec_id, allowed_heroes):
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    bits = []
    for char in text.strip():
        if char not in alphabet:
            raise ValueError('Некорректная строка талантов')
        bits.extend((alphabet.index(char) >> i) & 1 for i in range(6))
    cursor = 0
    def take(count):
        nonlocal cursor
        if cursor + count > len(bits):
            raise ValueError('Оборванная строка талантов')
        value = sum(bits[cursor+i] << i for i in range(count))
        cursor += count
        return value
    if take(8) != 2 or take(16) != spec_id:
        raise ValueError('Строка талантов не соответствует специализации и версии пакета')
    take(128)
    nodes = {}
    for trait in table['entries']:
        nodes.setdefault(trait['nodeId'], []).append(trait)
    selected = []
    for _, node in sorted(nodes.items()):
        if not take(1):
            continue
        trait = node[0]
        maximum = sum(t['maxRanks'] for t in node) if trait['nodeType'] == 1 else trait['maxRanks']
        rank = maximum
        if not take(1):
            rank = 1
        else:
            if take(1):
                rank = take(6)
                if not 1 <= rank < maximum:
                    raise ValueError('Ранг таланта вне диапазона')
            if take(1):
                if trait['nodeType'] not in (2, 3):
                    raise ValueError('Неожиданный выбор таланта')
                choice = take(2)
                if choice >= len(node):
                    raise ValueError('Выбор таланта вне диапазона')
                trait = node[choice]
        if trait['tree'] != 3 and trait['specs'] and spec_id not in trait['specs']:
            raise ValueError('Чужая специализация в дереве')
        if trait['nodeType'] == 1:
            for tier in node:
                allocated = min(rank, tier['maxRanks'])
                if allocated:
                    selected.append(dict(tier, rank=allocated))
                rank -= allocated
        else:
            selected.append(dict(trait, rank=rank))
    if len(bits)-cursor > 5 or any(bits[cursor:]):
        raise ValueError('Неизвестный остаток строки талантов')
    heroes = {t['subtree'] for t in selected if t['tree'] == 4 and t['nodeType'] == 3}
    if len(heroes) != 1 or not heroes.issubset(allowed_heroes):
        names = table.get('subtrees', {})
        found = ', '.join(f"{h} {names.get(str(h), {}).get('name', '')}".strip() for h in sorted(heroes)) or 'нет'
        raise ValueError(f'Для этой героической ветки пакет ещё не подготовлен (ветка: {found})')
    ranks = {}
    for trait in selected:
        if not trait['spellId'] or (trait['subtree'] and trait['subtree'] not in heroes):
            continue
        name = re.sub('[^a-z0-9]+', '_', trait['name'].lower().replace("'", ''))
        ranks[name] = ranks.get(name, 0) + trait['rank']
    return ranks, heroes
