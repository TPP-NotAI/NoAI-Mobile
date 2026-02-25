from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, List

L10N_DIR = Path('lib/l10n')
BASE_FILE = L10N_DIR / 'app_localizations.dart'
EN_FILE = L10N_DIR / 'app_localizations_en.dart'

ABSTRACT_GETTER_RE = re.compile(r'^\s*String get (\w+);\s*$', re.M)
GETTER_IMPL_NAME_RE = re.compile(r'String get (\w+)\s*=>')


def parse_base_getters(base_text: str) -> List[str]:
    return ABSTRACT_GETTER_RE.findall(base_text)


def parse_english_blocks(en_text: str) -> Dict[str, str]:
    """Return getter name -> full @override getter block from English locale file.

    Supports both styles used by generated Flutter localization files:
    - single-line: @override String get foo => 'bar';
    - multi-line with wrapped value after @override and/or getter line
    """
    blocks: Dict[str, str] = {}
    lines = en_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if '@override' not in line:
            i += 1
            continue

        start = i
        j = i
        name = None
        while j < len(lines):
            m = GETTER_IMPL_NAME_RE.search(lines[j])
            if m:
                name = m.group(1)
                break
            j += 1
        if name is None:
            i += 1
            continue

        k = j
        while k < len(lines):
            if ';' in lines[k]:
                break
            k += 1
        if k >= len(lines):
            raise RuntimeError(f'Could not find end of getter block for {name}')

        block = '\n'.join(lines[start : k + 1]).rstrip()
        blocks[name] = block
        i = k + 1

    return blocks


def patch_locale_file(path: Path, base_getters: List[str], en_blocks: Dict[str, str], dry_run: bool) -> int:
    text = path.read_text(encoding='utf-8')

    # If a locale class was accidentally left abstract, make it concrete.
    text = re.sub(r'^abstract class (AppLocalizations\w+) extends AppLocalizations \{$', r'class \1 extends AppLocalizations {', text, flags=re.M)

    existing = set(GETTER_IMPL_NAME_RE.findall(text))
    missing = [g for g in base_getters if g not in existing]
    if not missing:
        if not dry_run:
            path.write_text(text, encoding='utf-8')
        return 0

    missing_blocks = []
    unresolved = []
    for getter in missing:
        block = en_blocks.get(getter)
        if block is None:
            unresolved.append(getter)
            continue
        missing_blocks.append('  ' + block.replace('\n', '\n  '))

    if unresolved:
        raise RuntimeError(f'{path.name}: missing English blocks for: {", ".join(unresolved)}')

    insert_at = text.rfind('}')
    if insert_at == -1:
        raise RuntimeError(f'{path.name}: could not find class closing brace')

    addition = '\n\n' + '\n\n'.join(missing_blocks) + '\n'
    new_text = text[:insert_at].rstrip() + addition + text[insert_at:]

    if not dry_run:
        path.write_text(new_text, encoding='utf-8')
    return len(missing)


def iter_target_locale_files() -> List[Path]:
    files = []
    for path in sorted(L10N_DIR.glob('app_localizations_*.dart')):
        if path.name in {'app_localizations.dart', 'app_localizations_en.dart'}:
            continue
        files.append(path)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description='Add English fallback getters to non-English localization files.')
    parser.add_argument('--dry-run', action='store_true', help='Report missing getters without writing files')
    args = parser.parse_args()

    base_text = BASE_FILE.read_text(encoding='utf-8')
    en_text = EN_FILE.read_text(encoding='utf-8')

    base_getters = parse_base_getters(base_text)
    en_blocks = parse_english_blocks(en_text)

    total_added = 0
    changed_files = 0
    for path in iter_target_locale_files():
        added = patch_locale_file(path, base_getters, en_blocks, dry_run=args.dry_run)
        if added:
            changed_files += 1
            total_added += added
            print(f'{path.name}: added {added} fallback getter(s)')

    if changed_files == 0:
        print('All locale files already implement the current AppLocalizations getters.')
    else:
        mode = 'would add' if args.dry_run else 'added'
        print(f'Summary: {mode} {total_added} getter(s) across {changed_files} file(s).')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
