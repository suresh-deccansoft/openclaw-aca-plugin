#!/usr/bin/env python3
"""
Pre-commit guard for the 1000-line file limit (decision #9 in
reference/architecture-decisions.md). Applies to backend Python files only —
the JS/TS side is covered by ESLint's `max-lines` rule instead.

Add new exceptions to EXEMPT_GLOBS below deliberately (generated code,
Alembic version files that shouldn't be hand-split) — don't bypass this
script another way.
"""
import fnmatch
import sys
from pathlib import Path

MAX_LINES = 1000

EXEMPT_GLOBS = [
    "alembic/versions/*.py",  # auto-generated migration files
]


def is_exempt(path: Path) -> bool:
    posix = path.as_posix()
    return any(fnmatch.fnmatch(posix, glob) for glob in EXEMPT_GLOBS)


def main(argv: list[str]) -> int:
    failed = False
    for arg in argv:
        path = Path(arg)
        if path.suffix != ".py" or is_exempt(path):
            continue
        try:
            line_count = sum(1 for _ in path.open("r", encoding="utf-8"))
        except FileNotFoundError:
            continue
        if line_count > MAX_LINES:
            print(
                f"[check_file_length] {path} has {line_count} lines "
                f"(limit {MAX_LINES}). Split by responsibility — see "
                f"app/features/<domain>/ for the vertical-slice pattern. "
                f"If this file is genuinely generated/vendored, add its "
                f"path to EXEMPT_GLOBS in scripts/check_file_length.py."
            )
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
