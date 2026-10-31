# Contributing to Ashmark

Thanks for helping. Ashmark is a small open-source addon for World of Warcraft Forever, and every kind of help counts: a bug report from the live client, a conflict found in a quest log, a better translation, a fix.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## 🐞 Report a bug or a test result

[Open an issue](https://github.com/nullthrone/ashmark/issues/new/choose) and pick the matching form: bug report, launch test results, conflict proposal, translation fix or idea. A good report includes:

- the Ashmark version (the release tag, or the commit if you run the source)
- your client language and the Experience Preset (Classic or Enhanced)
- what you did, what you expected and what happened
- the text of any Lua error: turn error display on with `/console scriptErrors 1`
- if you can, the results of `/ashmark test` and `/ashmark probe`: they are stored in `AshmarkDB.dev` in `_forever_\WTF\Account\<ACCOUNT>\SavedVariables\Ashmark.lua`

That file also holds your characters, the people you grouped with and your notes on them. If you prefer, copy only the `dev` table into the issue.

## ⚔️ Add or correct a conflict

A good conflict is one where the quest texts themselves set one side against the other. Conflicts below level 30 outside Zephras Isle are the most wanted.

1. Add rows to the area's CSV in `data/conflicts/`, or a new CSV for a new area. The format is in [data/conflicts/README.md](data/conflicts/README.md).
2. Give every row an https `source` and leave `verified` at `false` unless you checked the quest in the Forever client.
3. Run `python3 tools/conflicts.py` to validate and regenerate `Data/Conflicts.lua`.
4. Commit the CSVs, `data/conflicts/registry.csv` and the generated `Data/Conflicts.lua` together. Never edit the generated file by hand.

Conflict ids and sides are permanent once generated, because players' alliances are stored under them. Rename or retire an id only with a row in `data/conflicts/renamed.csv`.

## 🌍 Improve a translation

Translations live in `Locales/<locale>.lua` (deDE, frFR, esES, esMX, ptBR, ruRU, koKR, zhTW, zhCN); English is in `Locales/enUS/`.

- Each file starts with its conventions, such as the form of address and how names from the client are framed. Keep to them.
- Keep every placeholder of the English text, such as `{faction}` or `{zone}`.
- A feminine form uses the key with `_F` appended, and only the keys listed in `tests/core_locale_spec.lua` may have one.
- Faction, zone, quest, item, class and race names come from the client at runtime: never translate them in the file.
- `busted` checks every locale for missing keys, unknown keys and placeholders.

Not sure about a wording? Open a translation fix issue with the current text and your proposal.

## 🛠️ Change the code

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first: it is the contract every part builds against. The decisions behind it are in [docs/DECISIONS.md](docs/DECISIONS.md).

The ground rules:

- Lua 5.1, Blizzard APIs only, no libraries.
- WoW Forever only: no code paths for Retail or Classic Era.
- No combat log, no automation, no protected calls, no StaticPopup.
- Feature-detect every API that may be missing, and read every value that can be secret through `ns.Safe`.
- Every string a player sees goes through `ns.L`, with the English text in `Locales/enUS/`.
- Every file belongs to one unit (section 9 of the architecture). Keep a change inside one unit where you can, and say in the pull request when it crosses units.
- A new file goes into both TOC files, which must stay identical apart from `## X-TocVariant`.
- Every fix comes with a spec that fails without it.

Run the checks before you push. CI runs the same five on every push and every pull request:

```
luacheck .
busted
python3 tools/conflicts.py --check
python3 -B -m unittest discover -s tools -p "test_*.py"
python3 tools/toc_check.py --strict
```

You need Lua 5.1, LuaRocks, `luacheck` and `busted`, and Python 3.

## 📬 Pull requests

- Branch from `main` and keep one topic per pull request.
- Say what changes for the player and why; link the issue if there is one.
- Write commit messages as one plain sentence about the change, such as "Keep a contact's name when the client still calls them Unknown".
- CI must be green before a review.

## 📄 License

Ashmark is released under the [MIT License](LICENSE). By contributing you agree that your contribution is released under it too.
