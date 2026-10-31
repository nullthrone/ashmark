#!/usr/bin/env python3
"""Tests for tools/conflicts.py. Run: python3 -B -m unittest discover -s tools -p "test_*.py"."""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True  # keep tools/ free of __pycache__
import conflicts as tool  # noqa: E402

HEADER = ",".join(tool.COLUMNS)


def row(cid, side, faction, quest, zone=1443):
    return f"{cid},{zone},feud,,,,,{side},{faction},{quest},Quest {quest},false,https://example.org/quest={quest}"


def pair(cid, a=92, b=93, qa=(101,), qb=(201,)):
    return [row(cid, "A", a, q) for q in qa] + [row(cid, "B", b, q) for q in qb]


class Dataset:
    """A throwaway repository root with data/conflicts and Data/Conflicts.lua."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source = self.root / "data" / "conflicts"
        self.source.mkdir(parents=True)
        self.output = self.root / "Data" / "Conflicts.lua"
        self.saved = (tool.ROOT, tool.SOURCE_DIR, tool.OUTPUT)
        tool.ROOT, tool.SOURCE_DIR, tool.OUTPUT = self.root, self.source, self.output

    def close(self):
        tool.ROOT, tool.SOURCE_DIR, tool.OUTPUT = self.saved
        self.tmp.cleanup()

    def area(self, rows):
        (self.source / "area.csv").write_text("\n".join([HEADER] + rows) + "\n", encoding="utf-8")

    def renamed(self, rows):
        (self.source / tool.RENAMED).write_text("\n".join(["old_id,new_id,reason"] + rows) + "\n", encoding="utf-8")

    def run(self, *argv):
        err = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            code = tool.main(list(argv))
        return code, err.getvalue()

    def registry(self):
        return (self.source / tool.REGISTRY).read_text(encoding="utf-8")

    def lua(self):
        return self.output.read_text(encoding="utf-8")


class RepositoryData(unittest.TestCase):
    def test_shipped_data_and_registry_are_current(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            code = tool.main(["--check"])
        self.assertEqual(code, 0, err.getvalue())


class Registry(unittest.TestCase):
    def setUp(self):
        self.ds = Dataset()
        self.ds.area(pair("old_feud"))
        self.assertEqual(self.ds.run()[0], 0)

    def tearDown(self):
        self.ds.close()

    def test_written_ids_are_registered_with_both_sides(self):
        self.assertIn("old_feud,92,93,101,201\n", self.ds.registry())
        self.assertEqual(self.ds.run("--check")[0], 0)

    def test_check_fails_without_the_registry(self):
        (self.ds.source / tool.REGISTRY).unlink()
        code, err = self.ds.run("--check")
        self.assertEqual(code, 1)
        self.assertIn("registry.csv is out of date", err)

    def test_a_registered_id_cannot_disappear(self):
        self.ds.area(pair("new_feud"))
        lua = self.ds.lua()
        code, err = self.ds.run()
        self.assertEqual(code, 1)
        self.assertIn("old_feud is in registry.csv but not in the data", err)
        self.assertEqual(self.ds.lua(), lua)

    def test_a_rename_ships_the_old_id(self):
        self.ds.area(pair("new_feud"))
        self.ds.renamed(["old_feud,new_feud,split by zone"])
        self.assertEqual(self.ds.run()[0], 0)
        self.assertIn('  renamed = {\n    ["old_feud"] = "new_feud",\n  },\n', self.ds.lua())
        self.assertIn("old_feud,92,93", self.ds.registry())
        self.assertIn("new_feud,92,93", self.ds.registry())
        self.assertEqual(self.ds.run("--check")[0], 0)

    def test_a_retired_id_is_not_shipped_and_cannot_return(self):
        self.ds.area(pair("new_feud"))
        self.ds.renamed(["old_feud,,quests removed from the game"])
        self.assertEqual(self.ds.run()[0], 0)
        self.assertNotIn("renamed", self.ds.lua())
        self.ds.area(pair("new_feud", qa=(102,), qb=(202,)) + pair("old_feud"))
        code, err = self.ds.run()
        self.assertEqual(code, 1)
        self.assertIn("old_feud is renamed or retired", err)

    def test_a_rename_needs_a_reason_and_a_target_in_the_data(self):
        self.ds.area(pair("new_feud"))
        self.ds.renamed(["old_feud,new_feud,"])
        self.assertIn("reason is required", self.ds.run()[1])
        self.ds.renamed(["old_feud,other_feud,typo"])
        self.assertIn("renamed to other_feud, which is not in the data", self.ds.run()[1])

    def test_swapped_sides_fail(self):
        self.ds.area(pair("old_feud", a=93, b=92, qa=(201,), qb=(101,)))
        code, err = self.ds.run()
        self.assertEqual(code, 1)
        self.assertIn("old_feud: side A was written with faction 92, now 93", err)

    def test_swapped_sides_without_factions_fail(self):
        self.ds.area(pair("old_feud") + pair("bare_feud", a=0, b=0, qa=(301,), qb=(401,)))
        self.assertEqual(self.ds.run()[0], 0)
        self.ds.area(pair("old_feud") + pair("bare_feud", a=0, b=0, qa=(401,), qb=(301,)))
        code, err = self.ds.run()
        self.assertEqual(code, 1)
        self.assertIn("bare_feud: quest 301 was written on side A, now on B", err)

    def test_added_quests_join_the_registry(self):
        self.ds.area(pair("old_feud", qa=(101, 102)))
        self.assertEqual(self.ds.run()[0], 0)
        self.assertIn("old_feud,92,93,101 102,201\n", self.ds.registry())
        self.ds.area(pair("old_feud", qa=(101,), qb=(201, 102)))
        self.assertIn("quest 102 was written on side A, now on B", self.ds.run()[1])


if __name__ == "__main__":
    unittest.main()
