#!/usr/bin/env python3
"""Validate the conflict source files and generate Data/Conflicts.lua.

Source: data/conflicts/*.csv, one row per quest. Conflict-level columns repeat on
every row of a conflict and must agree.

Characters store alliances under the conflict id and as the letter of a side, so ids and
sides are permanent once written. data/conflicts/registry.csv records every id the
generator has written, with each side's faction and quests; data/conflicts/renamed.csv is
the only way to rename or retire one. Neither is an area file.

Usage:
  python3 tools/conflicts.py           validate, write Data/Conflicts.lua and update the registry
  python3 tools/conflicts.py --check   validate and fail if Data/Conflicts.lua or the registry is stale
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
REGISTRY = "registry.csv"
REGISTRY_COLUMNS = ["conflict_id", "faction_a", "faction_b", "quests_a", "quests_b"]
RENAMED = "renamed.csv"
RENAMED_COLUMNS = ["old_id", "new_id", "reason"]
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


def read_table(path, columns):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != columns:
            raise ValidationError(
                f"{path.name}: header must be {','.join(columns)}, got {','.join(reader.fieldnames or [])}"
            )
        for line, row in enumerate(reader, start=2):
            yield f"{path.name}:{line}", {k: (v or "").strip() for k, v in row.items()}


def read_rows():
    files = [p for p in sorted(SOURCE_DIR.glob("*.csv")) if p.name not in (REGISTRY, RENAMED)]
    if not files:
        raise ValidationError(f"no source files in {SOURCE_DIR.relative_to(ROOT)}")
    for path in files:
        yield from read_table(path, COLUMNS)


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


def check_id(cid, field, where):
    if not ID_PATTERN.match(cid):
        raise ValidationError(f"{where}: {field} {cid!r} must match {ID_PATTERN.pattern}")


def parse_quests(value, field, where):
    return [parse_int(q, field, where, minimum=1) for q in value.split()]


def read_registry():
    path = SOURCE_DIR / REGISTRY
    registry = {}
    if not path.exists():
        return registry
    for where, row in read_table(path, REGISTRY_COLUMNS):
        cid = row["conflict_id"]
        check_id(cid, "conflict_id", where)
        if cid in registry:
            raise ValidationError(f"{where}: {cid} is registered twice")
        registry[cid] = {
            s: {
                "faction": parse_int(row[f"faction_{s.lower()}"], f"faction_{s.lower()}", where),
                "quests": parse_quests(row[f"quests_{s.lower()}"], f"quests_{s.lower()}", where),
            }
            for s in SIDES
        }
    return registry


def read_renamed():
    path = SOURCE_DIR / RENAMED
    renamed = {}
    if not path.exists():
        return renamed
    for where, row in read_table(path, RENAMED_COLUMNS):
        old, new = row["old_id"], row["new_id"]
        check_id(old, "old_id", where)
        if new:
            check_id(new, "new_id", where)
        if old in renamed:
            raise ValidationError(f"{where}: {old} is renamed twice")
        if not row["reason"]:
            raise ValidationError(f"{where}: reason is required")
        renamed[old] = new or None
    return renamed


def check_registry(conflicts, registry, renamed):
    """Released ids never disappear and released sides never change meaning."""
    by_id = {c["id"]: c for c in conflicts}
    targets = {}
    for old, new in renamed.items():
        if old not in registry:
            raise ValidationError(f"{RENAMED}: {old} is not in {REGISTRY}; only a written id can be renamed")
        if old in by_id:
            raise ValidationError(f"{RENAMED}: {old} is renamed or retired, so the data must not use it")
        if new is not None and new not in by_id:
            raise ValidationError(f"{RENAMED}: {old} is renamed to {new}, which is not in the data")
        if new is not None and new in targets:
            raise ValidationError(f"{RENAMED}: {targets[new]} and {old} are both renamed to {new}")
        # A rename target enters the registry with every quest of the old id (update_registry), so a target
        # registered without them was written under its own id: merging it would make two ids one.
        if new is not None and new in registry and any(
            not set(registry[old][s]["quests"]) <= set(registry[new][s]["quests"]) for s in SIDES
        ):
            raise ValidationError(
                f"{RENAMED}: {new} was written under its own id before {old} was renamed to it; "
                "two released ids cannot become one"
            )
        targets[new] = old
    for cid, released in registry.items():
        if cid in renamed and renamed[cid] is None:
            continue
        target = renamed.get(cid, cid)
        conflict = by_id.get(target)
        if conflict is None:
            raise ValidationError(
                f"{cid} is in {REGISTRY} but not in the data; ids are permanent: restore it or add it to {RENAMED}"
            )
        for s, other in (("A", "B"), ("B", "A")):
            was, now = released[s]["faction"], conflict["sides"][s]["faction"]
            if was != now:
                raise ValidationError(
                    f"{target}: side {s} was written with faction {was}, now {now}; sides are permanent"
                )
            moved = sorted(set(released[s]["quests"]) & set(conflict["sides"][other]["quests"]))
            if moved:
                raise ValidationError(
                    f"{target}: quest {', '.join(map(str, moved))} was written on side {s}, now on {other}; "
                    "sides are permanent"
                )


def update_registry(conflicts, registry, renamed=None):
    updated = {cid: {s: {"faction": e[s]["faction"], "quests": list(e[s]["quests"])} for s in SIDES}
               for cid, e in registry.items()}
    # A rename target not yet registered starts from the old id's sides, so it keeps every quest the old id
    # was ever written with and check_registry can tell it from an id released under its own name.
    for old, new in (renamed or {}).items():
        if new is not None and new not in updated and old in registry:
            updated[new] = {s: {"faction": registry[old][s]["faction"], "quests": list(registry[old][s]["quests"])}
                            for s in SIDES}
    for c in conflicts:
        entry = updated.setdefault(c["id"], {s: {"faction": c["sides"][s]["faction"], "quests": []} for s in SIDES})
        for s in SIDES:
            entry[s]["quests"] += [q for q in c["sides"][s]["quests"] if q not in entry[s]["quests"]]
    return updated


def render_registry(registry):
    lines = [",".join(REGISTRY_COLUMNS)]
    for cid in sorted(registry):
        e = registry[cid]
        quests = [" ".join(str(q) for q in e[s]["quests"]) for s in SIDES]
        lines.append(f"{cid},{e['A']['faction']},{e['B']['faction']},{quests[0]},{quests[1]}")
    return "\n".join(lines) + "\n"


def lua_list(values):
    return "{ " + ", ".join(str(v) for v in values) + " }"


def render(conflicts, renamed=None):
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
    lines.append("  },")
    renames = {old: new for old, new in (renamed or {}).items() if new}
    if renames:
        # Old id -> current id, so stored alliances can follow a renamed conflict.
        lines.append("  renamed = {")
        for old in sorted(renames):
            lines.append(f'    ["{old}"] = "{renames[old]}",')
        lines.append("  },")
    lines += ["}", ""]
    return "\n".join(lines)


def main(argv):
    check = "--check" in argv
    try:
        conflicts = build()
        registry = read_registry()
        renamed = read_renamed()
        check_registry(conflicts, registry, renamed)
    except ValidationError as error:
        print(f"conflicts: {error}", file=sys.stderr)
        return 1
    output = render(conflicts, renamed)
    registry_path = SOURCE_DIR / REGISTRY
    registry_text = render_registry(update_registry(conflicts, registry, renamed))
    if check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != output:
            print("conflicts: Data/Conflicts.lua is out of date; run python3 tools/conflicts.py", file=sys.stderr)
            return 1
        current = registry_path.read_text(encoding="utf-8") if registry_path.exists() else ""
        if current != registry_text:
            print(f"conflicts: {REGISTRY} is out of date; run python3 tools/conflicts.py", file=sys.stderr)
            return 1
        print(f"conflicts: {len(conflicts)} conflicts, Data/Conflicts.lua and {REGISTRY} are current")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(output, encoding="utf-8")
    registry_path.write_text(registry_text, encoding="utf-8")
    print(f"conflicts: wrote {len(conflicts)} conflicts to {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
