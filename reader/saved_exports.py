"""Read HUD exports the addon keeps in its SavedVariables. Read-only: WTF is never written.

WoW writes SavedVariables only on /reload, logout or exit, so an export made
by the addon at PLAYER_LOGOUT becomes visible here right after that.
"""
import json
from pathlib import Path

DEFAULT_RETAIL = (Path(r'C:\Program Files (x86)\World of Warcraft\_retail_'),
                  Path(r'C:\Program Files\World of Warcraft\_retail_'))


def parse_lua(data):
    """Parse the subset of Lua WoW uses for SavedVariables: `name = value` lines
    with tables, strings, numbers and booleans. Returns {name: value}."""
    pos = 0
    n = len(data)

    def skip():
        nonlocal pos
        while pos < n:
            c = data[pos:pos+1]
            if c in (b' ', b'\t', b'\r', b'\n'):
                pos += 1
            elif data.startswith(b'--', pos):
                end = data.find(b'\n', pos)
                pos = n if end < 0 else end + 1
            else:
                return

    def string():
        nonlocal pos
        quote = data[pos:pos+1]; pos += 1
        out = bytearray()
        while pos < n:
            c = data[pos]
            if c == quote[0]:
                pos += 1
                return out.decode('utf-8', errors='replace')
            if c == 0x5C:  # backslash
                pos += 1
                e = data[pos:pos+1]
                simple = {b'n': 10, b't': 9, b'r': 13, b'\\': 92, b'"': 34, b"'": 39, b'a': 7,
                          b'b': 8, b'f': 12, b'v': 11, b'\n': 10}
                if e in simple:
                    out.append(simple[e]); pos += 1
                elif e.isdigit():
                    digits = data[pos:pos+3]
                    k = 1
                    while k < len(digits) and digits[k:k+1].isdigit():
                        k += 1
                    out.append(int(digits[:k]) & 0xFF); pos += k
                else:
                    raise ValueError('Неизвестная escape-последовательность в SavedVariables')
            else:
                out.append(c); pos += 1
        raise ValueError('Незакрытая строка в SavedVariables')

    def value():
        nonlocal pos
        skip()
        c = data[pos:pos+1]
        if c == b'{':
            return table()
        if c in (b'"', b"'"):
            return string()
        for word, result in ((b'true', True), (b'false', False), (b'nil', None)):
            if data.startswith(word, pos):
                pos += len(word); return result
        start = pos
        while pos < n and data[pos:pos+1] not in (b',', b'}', b']', b'\n', b'\r', b' ', b'\t', b';'):
            pos += 1
        token = data[start:pos].decode('ascii')
        number = float(token)
        return int(number) if number.is_integer() and 'e' not in token.lower() and '.' not in token else number

    def table():
        nonlocal pos
        pos += 1
        result, index = {}, 1
        while True:
            skip()
            if data[pos:pos+1] == b'}':
                pos += 1
                return result
            if data[pos:pos+1] == b'[':
                pos += 1
                key = value()
                skip()
                if data[pos:pos+1] != b']':
                    raise ValueError('Ожидалась ] в SavedVariables')
                pos += 1; skip()
                if data[pos:pos+1] != b'=':
                    raise ValueError('Ожидалось = в SavedVariables')
                pos += 1
                result[key] = value()
            else:
                result[index] = value(); index += 1
            skip()
            if data[pos:pos+1] in (b',', b';'):
                pos += 1

    top = {}
    while True:
        skip()
        if pos >= n:
            return top
        start = pos
        while pos < n and (data[pos:pos+1].isalnum() or data[pos:pos+1] == b'_'):
            pos += 1
        name = data[start:pos].decode('ascii')
        skip()
        if not name or data[pos:pos+1] != b'=':
            raise ValueError('Неожиданный формат SavedVariables')
        pos += 1
        top[name] = value()


def candidate_files(extra_roots=()):
    roots = [Path(r) for r in extra_roots if r] + list(DEFAULT_RETAIL)
    seen, files = set(), []
    for root in roots:
        for path in sorted((root / 'WTF' / 'Account').glob('*/SavedVariables/AHelperW.lua')):
            key = str(path).lower()
            if key not in seen:
                seen.add(key); files.append(path)
    return files


def read_exports(files):
    """Every stored export: {specID, text, at, stale, source}. Unreadable files are skipped."""
    found = []
    for path in files:
        try:
            db = parse_lua(path.read_bytes()).get('AHelperWDB') or {}
        except (OSError, ValueError):
            continue
        for spec, item in (db.get('hudExports') or {}).items():
            if not isinstance(item, dict) or not isinstance(item.get('text'), str):
                continue
            try:
                parsed = json.loads(item['text'])
            except ValueError:
                continue
            if parsed.get('schema') != 'AHelperW.HUD' or parsed.get('specID') != spec:
                continue
            found.append({'specID': spec, 'text': item['text'], 'at': item.get('at') or 0,
                          'stale': bool(item.get('stale')), 'source': str(path)})
    return found
