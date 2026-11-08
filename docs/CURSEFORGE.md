# Taskboard CurseForge submission kit

This file prepares a CurseForge listing. Uploading is a separate action in the owner's CurseForge account. The repository has no explicit open-source license; choose **All Rights Reserved** unless the owner chooses and adds a different license.

## Upload file

Build with `python tests/tools/package.py --curseforge`. Upload `dist/Taskboard-1.1.3-CurseForge.zip`. It has exactly one top-level folder, `Taskboard`, containing `Taskboard.toc`, Bindings.xml, README, docs/TESTING.md and the runtime Lua files. Do **not** upload `Taskboard-1.1.3.zip`: that manual upgrade package also includes the old Questboard migration loader and has two top-level folders.

The CurseForge build installs Taskboard for new users. Existing Questboard users can migrate their saved data by installing the two-folder upgrade ZIP from the GitHub repository first, enabling **Taskboard - legacy data loader** for one login, and then managing Taskboard through CurseForge. The old SavedVariables are not included in any ZIP.

## Project fields

- Game: World of Warcraft
- Class: Addons
- Project name: Taskboard (check availability in the submission form)
- Summary: A customizable task board for WoW Forever with live goals, location reminders, and an optional on-screen tracker.
- Main category: Miscellaneous (or the closest task/planning category the form offers)
- Additional categories: Quests & Leveling, Map & Minimap, Professions, if available; only choose relevant ones.
- License: All Rights Reserved unless a different license is deliberately selected.
- Source link: https://github.com/Jvb182/taskboard (private; public visitors cannot browse it). A public source link is optional if the owner wants to make it public later.
- Logo: choose an original Taskboard image or icon. Preview screenshots are optional for a WoW addon; genuine in-game screenshots will make the listing clearer.

## Suggested description

**Taskboard** is a customizable to-do board built for World of Warcraft: Forever. Keep ordinary tasks alongside goals that track your inventory, money, level, profession skill, reputation, and completed quests. A card can move to In Progress as you start and to Done when its goals are complete.

Type `/tb` or click the minimap button to open the board. Quick Add accepts tasks such as `Get 17 Silverleaf`, `save 10g`, `Herbalism 150`, or `Buy vials @Goldshire`. Shift-click an item or quest link into Quick Add, or use `@` location suggestions to attach an arrival reminder. Combine tags, priorities, daily or weekly repeats, and subtasks. The on-screen tracker can show in-progress cards, all open tasks, and nearby location reminders.

Choose from five themes and accent colors, adjust board/tracker opacity, and set separate sounds for moves, completions, subtasks, and reminders. Settings, editor, Help, logs, and menus stay opaque. The in-game Help panel explains every feature with examples. Boards can be limited to one character, shared with party/raid/guild members, or exported and imported as text.

Taskboard targets **WoW Forever 1.60.1** (interface `16001`). It is not advertised for Retail or other Classic versions. Type `/tb help` for the guide and `/tb options` for settings. Report problems with your client build, steps to reproduce, and `/tb diag` output.

## First file

- Display name: Taskboard 1.1.3 for WoW Forever
- Release type: Release after the owner has completed the in-game checklist; use Beta if gathering broader test feedback first. A Release file is needed for default CurseForge app syncing.
- Game version type/flavor: **Forever**
- Supported version: **1.60.1**
- Changelog: First CurseForge package. Includes live goal tracking, recurring tasks, location reminders, configurable tracker and sounds, theme controls, board sharing, and in-game Help. The 1.1.3 build keeps dialogs and menus opaque.

## Submission steps

1. Sign in at https://authors.curseforge.com/#/projects/create/choose-game and create a World of Warcraft addon project.
2. Fill the English title, summary, description, category, license and logo. Do not select Retail or a different Classic flavor for this build.
3. On the project's Files tab upload the **CurseForge ZIP**, enter the changelog, choose Forever / 1.60.1 and the release type.
4. CurseForge reviews the project/file. After approval, check that it appears under the Forever flavor and that the app installs `AddOns/Taskboard/Taskboard.toc`.

The release should follow the real-game checks in [TESTING.md](TESTING.md). Offline CI validates Lua 5.1 behavior and package layout; it cannot verify real UI layout or server delivery.
