"""Read-only development prerequisite check. Does not print environment secrets."""

import argparse
import importlib.metadata
from pathlib import Path
import re
import shutil
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--dart', default='dart')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    failures = []

    def report(label, ok, detail):
        print(f'{"OK" if ok else "MISSING"}  {label}: {detail}')
        if not ok:
            failures.append(label)

    report('Python', sys.version_info >= (3, 12), sys.version.split()[0])
    print(f'Interpreter: {sys.executable}')
    for manifest in ('requirements.txt', 'requirements-dev.txt'):
        for line in (root / 'backend' / manifest).read_text().splitlines():
            match = re.fullmatch(r'([\w-]+)(?:\[[\w,.-]+\])?==([\w.]+)', line.strip())
            if not match:
                continue
            name, expected = match.groups()
            try:
                actual = importlib.metadata.version(name)
            except importlib.metadata.PackageNotFoundError:
                actual = 'not installed'
            report(name, actual == expected, f'{actual} (expected {expected})')

    for label, executable in (('Flutter', args.flutter), ('Dart', args.dart)):
        resolved = shutil.which(executable)
        report(label, resolved is not None, resolved or 'not found on PATH')

    for relative in ('mobile/pubspec.lock', 'backend/manage.py', '.env.example'):
        report(relative, (root / relative).is_file(), 'repository prerequisite')

    database = root / 'backend/db.sqlite3'
    print(f'Local SQLite file: {"present" if database.exists() else "not created yet; run make migrate"}')
    print('Next: flutter --version; flutter doctor; make check test')
    print('This check does not validate devices, network services or provider credentials.')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
