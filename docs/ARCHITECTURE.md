# Taskboard architecture

Taskboard is a WoW Forever addon loaded in the order listed by `Taskboard.toc`. Each Lua file receives the addon name and shared namespace. `Core/Init.lua` owns module registration, safe event dispatch, timers and the `OnInit`/`OnLogin` lifecycle. UI modules are constructed lazily after the saved data is loaded.

## Source layout

| Area | Responsibility |
| --- | --- |
| `Core/DB.lua` | Saved data defaults, input normalization, repair, board/card operations and one-time upgrades. |
| `Core/Parser.lua`, `Goals.lua`, `Items.lua`, `Engine.lua` | Quick Add syntax, live goal evaluation, inventory resolution and progress events. |
| `Core/Reminders.lua`, `Recurring.lua`, `Stats.lua` | Arrival/NPC/mail reminders, server-reset recurrence and completion history. |
| `Core/Sync.lua`, `Serialize.lua` | Board sharing and bounded text import/export. Incoming data is normalized before it enters the DB. |
| `Core/Commands.lua`, `Diagnostics.lua`, `Log.lua` | Slash commands, self-test/diagnostics and the copyable log. |
| `UI/` | Board, editor, tracker, settings, Help and feedback. `Theme.lua` and `Widgets.lua` provide shared appearance and controls. |
| `compat/Questboard/` | Saved-variable-only loader for a one-time upgrade. It contains no old runtime code. |

The DB stores boards by ID. Each board has a card map and per-column ordered card IDs. Column roles (`todo`, `doing`, `done`) drive status behavior; display names can change. A character has one personal board, and characters on the account can view each other's boards. Received shared boards are separate and read-only where ownership requires it. Call DB methods to change cards or columns so validation and change events stay consistent.

## Saved data and upgrades

`TaskboardDB` holds boards, settings, learned mailbox locations, statistics and UI state; `TaskboardLog` holds recent diagnostics. `DB:Load` checks types, fills defaults and repairs boards. The current stored shape is schema 1. Two earlier upgrades are guarded by purpose-specific flags: `taskboardBrandingUpdated` renames exact old default labels, and `oneBoardPerCharacter` consolidates older local boards at login, when the character key is available. New changes to the stored shape should use a numbered migration in `DB:Load`; changes requiring the logged-in character should be explicit and idempotent in `OnLogin` with tests across two reloads.

If `TaskboardDB` is absent and the saved-variable-only Questboard loader has loaded `QuestboardDB`, Taskboard deep-copies that legacy data. It does not delete the old save. Reset creates an empty personal board and keeps learned mailbox positions; see `DB:ResetAll` before changing reset behavior.

## Tests and distribution

`tests/run.py` runs the Lua 5.1 suite against `tests/wowmock.lua` and the Forever API fixture. It covers logic and simulated UI handlers; real rendering, sound, combat, server timing and two-player delivery still need in-game checks. GitHub Actions runs tests on pushes and pull requests on Windows and Linux, then builds ZIPs. `tests/tools/package.py` uses the TOC to select runtime files, so test helpers and fixtures do not enter the release package.

The default CurseForge ZIP contains only `Taskboard/`. The optional Legacy Loader ZIP contains only `Questboard/Questboard.toc` for manual installation. `tests/manual-addons/TaskboardWelcomePreview` is a separate wording/layout preview; it is not a fresh-install test or a release dependency. See [TESTING.md](TESTING.md) for manual checks and [CURSEFORGE.md](CURSEFORGE.md) for upload steps.
