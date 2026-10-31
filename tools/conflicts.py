#!/usr/bin/env python3
"""Validate the conflict source files and generate Data/Conflicts.lua.

Source: data/conflicts/*.csv, one row per quest. Conflict-level columns repeat on
every row of a conflict and must agree.

Usage:
  python3 tools/conflicts.py           validate and write Data/Conflicts.lua
  python3 tools/conflicts.py --check   validate and fail if Data/Conflicts.lua is stale
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "data" / "conflicts"
OUTPUT = ROOT / "Data" / "Conflicts.lua"

COLUMNS = [
    "conflict_id", "zone", "theme", "honored", "anchor_m", "anchor_x", "anchor_y",
    "side", "faction", "quest", "quest_name", "verified", "source",
]
CONFLICT_COLUMNS = ["zone", "theme", "honored", "anchor_m", "anchor_x", "anchor_y"]
THEMES = {"feud", "law", "trade", "nature", "faith", "other"}
SIDES = ("A", "B")
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]{2,47}$")
# Standing IDs as C_Reputation reports them: 4 Neutral .. 8 Exalted (9 is unused in Forever data).
STANDINGS = {"", "5", "6", "7", "8"}


class ValidationError(Exception):
    pass


def parse_int(value, field, where, minimum=0):
    try:
        number = int(value)
    except ValueError:
        raise ValidationError(f"{where}: {field} must be an integer, got {value!r}")
    if number < minimum:
        raise ValidationError(f"{where}: {field} must be >= {minimum}, got {number}")
    return number


def parse_coord(value, field, where):
    if value == "":
        return None
    try:
        number = float(value)
    except ValueError:
        raise ValidationError(f"{where}: {field} must be a number, got {value!r}")
    if not 0.0 <= number <= 1.0:
        raise ValidationError(f"{where}: {field} must be between 0 and 1, got {number}")
    return round(number, 3)


def read_rows():
    files = sorted(SOURCE_DIR.glob("*.csv"))
    if not files:
        raise ValidationError(f"no source files in {SOURCE_DIR.relative_to(ROOT)}")
    for path in files:
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != COLUMNS:
                raise ValidationError(
                    f"{path.name}: header must be {','.join(COLUMNS)}, got {','.join(reader.fieldnames or [])}"
                )
            for line, row in enumerate(reader, start=2):
                yield f"{path.name}:{line}", {k: (v or "").strip() for k, v in row.items()}


def build():
    conflicts = {}
    quest_owner = {}
    for where, row in read_rows():
        cid = row["conflict_id"]
        if not ID_PATTERN.match(cid):
            raise ValidationError(f"{where}: conflict_id {cid!r} must match {ID_PATTERN.pattern}")
        if row["theme"] not in THEMES:
            raise ValidationError(f"{where}: theme must be one of {sorted(THEMES)}")
        if row["side"] not in SIDES:
            raise ValidationError(f"{where}: side must be A or B")
        if row["honored"] not in STANDINGS:
            raise ValidationError(f"{where}: honored must be empty or a standing id 5-8")
        if row["verified"] not in ("true", "false"):
            raise ValidationError(f"{where}: verified must be true or false")
        if not row["source"].startswith("https://"):
            raise ValidationError(f"{where}: source must be an https URL")
        if not row["quest_name"]:
            raise ValidationError(f"{where}: quest_name is required (English, for review)")

        quest = parse_int(row["quest"], "quest", where, minimum=1)
        faction = parse_int(row["faction"], "faction", where) if row["faction"] else 0
        if quest in quest_owner:
            raise ValidationError(f"{where}: quest {quest} already belongs to {quest_owner[quest]}")
        quest_owner[quest] = cid

        conflict = conflicts.setdefault(cid, {"id": cid, "first": where, "header": None, "sides": {}})
        header = tuple(row[c] for c in CONFLICT_COLUMNS)
        if conflict["header"] is None:
            conflict["header"] = header
            conflict["zone"] = parse_int(row["zone"], "zone", where, minimum=1)
            conflict["theme"] = row["theme"]
            conflict["honored"] = int(row["honored"]) if row["honored"] else None
            anchor_m = parse_int(row["anchor_m"], "anchor_m", where) if row["anchor_m"] else 0
            ax = parse_coord(row["anchor_x"], "anchor_x", where)
            ay = parse_coord(row["anchor_y"], "anchor_y", where)
            if (ax is None) != (ay is None) or (ax is not None and not anchor_m):
                raise ValidationError(f"{where}: anchor_m, anchor_x and anchor_y are all set or all empty")
            conflict["anchor"] = (anchor_m, ax, ay) if ax is not None else None
        elif header != conflict["header"]:
            raise ValidationError(f"{where}: conflict columns differ from {conflict['first']}")

        side = conflict["sides"].setdefault(row["side"], {"faction": faction, "quests": [], "verified": True, "sources": set()})
        if side["faction"] != faction:
            raise ValidationError(f"{where}: side {row['side']} of {cid} has two factions")
        side["quests"].append(quest)
        side["verified"] = side["verified"] and row["verified"] == "true"
        side["sources"].add(row["source"])

    for cid, conflict in conflicts.items():
        missing = [s for s in SIDES if s not in conflict["sides"]]
        if missing:
            raise ValidationError(f"{cid}: side {' and '.join(missing)} has no quests")
        a, b = conflict["sides"]["A"]["faction"], conflict["sides"]["B"]["faction"]
        if a and a == b:
            raise ValidationError(f"{cid}: both sides use faction {a}")
        if conflict["honored"] and not (a or b):
            raise ValidationError(f"{cid}: honored is set but no side has a faction")
    return [conflicts[k] for k in sorted(conflicts)]


def lua_list(values):
    return "{ " + ", ".join(str(v) for v in values) + " }"


def render(conflicts):
    lines = [
        "-- GENERATED by tools/conflicts.py from data/conflicts/*.csv. Do not edit.",
        "local _, ns = ...",
        "ns.Data = ns.Data or {}",
        "ns.Data.Conflicts = {",
        f"  count = {len(conflicts)},",
        "  list = {",
    ]
    for c in conflicts:
        verified = all(c["sides"][s]["verified"] for s in SIDES)
        lines.append("    {")
        lines.append(f'      id = "{c["id"]}", zone = {c["zone"]}, theme = "{c["theme"]}",')
        for s in SIDES:
            side = c["sides"][s]
            lines.append(f"      {s} = {{ faction = {side['faction']}, quests = {lua_list(side['quests'])} }},")
        if c["honored"]:
            lines.append(f"      honored = {c['honored']},")
        if c["anchor"]:
            m, x, y = c["anchor"]
            lines.append(f"      anchor = {{ m = {m}, x = {x}, y = {y} }},")
        lines.append(f"      verified = {'true' if verified else 'false'},")
        lines.append("    },")
    lines += ["  },", "}", ""]
    return "\n".join(lines)


def main(argv):
    check = "--check" in argv
    try:
        conflicts = build()
    except ValidationError as error:
        print(f"conflicts: {error}", file=sys.stderr)
        return 1
    output = render(conflicts)
    if check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != output:
            print("conflicts: Data/Conflicts.lua is out of date; run python3 tools/conflicts.py", file=sys.stderr)
            return 1
        print(f"conflicts: {len(conflicts)} conflicts, Data/Conflicts.lua is current")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(output, encoding="utf-8")
    print(f"conflicts: wrote {len(conflicts)} conflicts to {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
