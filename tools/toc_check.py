#!/usr/bin/env python3
"""Check that both TOC files list the same files in the same order.

With --strict, every listed file must also exist (used once all units are in).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOCS = ["Ashmark_Forever.toc", "Ashmark_Camelot.toc"]
VARIANT_KEYS = ("## X-TocVariant",)


def read(name):
    lines = (ROOT / name).read_text(encoding="utf-8").splitlines()
    headers = [l for l in lines if l.startswith("##") and not l.startswith(VARIANT_KEYS)]
    files = [l.strip() for l in lines if l.strip() and not l.startswith("#")]
    return headers, files


def main(strict):
    errors = []
    warnings = []
    parsed = {}
    for name in TOCS:
        if not (ROOT / name).exists():
            errors.append(f"{name} is missing")
            continue
        parsed[name] = read(name)
    if len(parsed) == len(TOCS):
        (h1, f1), (h2, f2) = parsed[TOCS[0]], parsed[TOCS[1]]
        if h1 != h2:
            errors.append("TOC headers differ (apart from X-TocVariant)")
        if f1 != f2:
            errors.append("TOC file lists differ")
        for entry in f1:
            if not (ROOT / entry.replace("\\", "/")).exists():
                (errors if strict else warnings).append(f"listed file does not exist: {entry}")
    for warning in warnings:
        print(f"toc: warning: {warning}", file=sys.stderr)
    for error in errors:
        print(f"toc: {error}", file=sys.stderr)
    if not errors:
        print(f"toc: {len(parsed[TOCS[0]][1])} files, both TOCs agree")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main("--strict" in sys.argv[1:]))
