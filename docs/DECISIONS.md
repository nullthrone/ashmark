# Decisions

Decisions for Embertale v1, set in the design interview on 2026-10-30. The concept itself lives in the Claude Doc "Embertale: Addon-Konzept für Solo-Rollenspiel in WoW Forever" (German). Where this file and the concept disagree, this file wins.

## Platform

| Decision | Detail |
| --- | --- |
| Target | World of Warcraft Forever only. Retail and Classic Era are not supported targets. The addon is built around the character of Forever. |
| Libraries | None. Blizzard APIs only, including map pins and addon-message throttling. |
| Dev environment | Code is written in the cloud. In-client verification runs locally on Windows. |
| In-game test mode | `/et test` checks frames, templates, atlas entries, secret-value handling and locale completeness against the live client. It writes results to SavedVariables, then reloads the UI. A screenshot of the chronicle next to the real quest dialog is part of the run. |
| Release | Prepared for CurseForge: `.pkgmeta` plus a GitHub Action that packages on tag. Upload happens only once a CurseForge project ID and API token are configured. Name availability on CurseForge is unverified. |

## Scope v1

| Module | v1 |
| --- | --- |
| Core event log | yes |
| 1 Conflicts (mutually exclusive quests, reputation coupling) | yes |
| 2 Profile (identity from behaviour) | yes |
| 3 Private world-state map layer | yes |
| 4 Encounters (social memory) | yes |
| 5 House (alts sharing a surname) | yes |
| 6 Campfire (chapter boundaries) | yes |
| 7 Character knowledge (hidden item tooltips) | yes, if technically feasible in Forever; feature-detected at runtime |
| Rumours, silent shared fiction (addon messages) | yes |
| Traces in the world, companion app | v2. v1 prepares the data model and the file interface, nothing more. |

## Rules

| Topic | Decision |
| --- | --- |
| Violations (Module 1) | Counted. A violation is written to the chronicle and the decisions tab and breaks the alliance. No further penalty: the forfeited rewards are the consequence. |
| Profile axes (Module 2) | Three axes. Fidelity: principled to opportunistic (broken alliances, abandoned quests, gold sources). Habitat: civil to wild (time in cities vs. wilderness, resting). Mercy: merciful to ruthless (killing non-aggressive creatures). |
| Feud inheritance (Module 5) | A hint, not a lock. Siblings see "Your house stands against …" in the quest dialog. Taking the quest anyway is recorded as turning from the house in the family chronicle, not as a violation. |
| Conflict dataset (Module 1) | About 20 pilot conflicts: Desolace and Shen'dralas, plus a few starter zones. Every entry carries `verified = false` until it is checked in the client. Contributions use a plain-text source format that a generator turns into the shipped Lua table, guarded by a validator. |

## Localization

Nine client locales, matching the ten languages on the Battle.net shop listing for Forever (`enGB` reports as `enUS` in the client):

`enUS`, `deDE`, `frFR`, `esES`, `esMX`, `ptBR`, `ruRU`, `koKR`, `zhTW`

Not included: `zhCN`, `itIT`. Game terms such as faction, zone, quest and item names are read from the client API at runtime, not translated by hand.

## Documentation

English. A static HTML page in the Nullthrone Design System (`docs/index.html`), also published as an Artifact. The README stays short and links to it.

## Process

Work is committed and pushed after every phase and every agent unit, so an interrupted session loses at most one unit of work.
