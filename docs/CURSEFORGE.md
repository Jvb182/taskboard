# Taskboard CurseForge submission kit

This file prepares a CurseForge listing. Uploading is a separate action in the owner's CurseForge account. The repository has no explicit open-source license; choose **All Rights Reserved** unless the owner chooses and adds a different license.

## Upload file

Read the current version from `Taskboard.toc`. Run `python tests/tools/package.py --curseforge` and upload `dist/Taskboard-<version>-CurseForge.zip` as the default file. It has exactly one top-level folder, `Taskboard`, containing the TOC, Bindings.xml, README, docs/TESTING.md and runtime Lua files. Do **not** make the two-folder `Taskboard-<version>.zip` the default file; that is a manual upgrade package.

Build `dist/Taskboard-<version>-Legacy-Loader.zip` with `python tests/tools/package.py --legacy-loader`. It contains only `Questboard/Questboard.toc`, which loads old saved data without running the old addon code. Attach it to the main release as an **Additional File** and label it "Legacy Questboard data loader — manual download". CurseForge [does not install Additional Files through its app](https://support.curseforge.com/support/solutions/articles/9000197242-file-types-and-additional-fields), so link to the helper on the project page and explain the manual step. An existing Questboard user installs the main Taskboard file, extracts this helper over the old Questboard TOC while WoW is closed, enables both Taskboard and the loader for one login, checks migrated data after a reload, then disables/removes the loader. Do not direct public users to the private GitHub repository or tell them to run the original Questboard code beside Taskboard. No SavedVariables are included in any ZIP.

## Project fields

- Game: World of Warcraft
- Class: Addons
- Project name: Taskboard (check availability in the submission form)
- Summary: A customizable task board for WoW Forever with live goals, location reminders, and an optional on-screen tracker.
- Main category: Miscellaneous (or the closest task/planning category the form offers)
- Additional categories: Quests & Leveling, Map & Minimap, Professions, if available; only choose relevant ones.
- License: All Rights Reserved unless a different license is deliberately selected.
- Source link: leave blank while the repository is private. Add a source link only when public visitors can actually open it.
- Logo: upload the approved `assets/Taskboard-logo-400.png` (400 × 400 PNG). It is separate from the addon ZIP. Preview screenshots are optional for a WoW addon; genuine in-game screenshots will make the listing clearer.

## Suggested description

**Taskboard** is a customizable to-do board built for World of Warcraft: Forever. Keep ordinary tasks alongside goals that track your inventory, money, level, profession skill, reputation, and completed quests. A card can move to In Progress as you start and to Done when its goals are complete.

Type `/tb` or click the minimap button to open the board. Quick Add accepts tasks such as `Get 17 Silverleaf`, `save 10g`, `Herbalism 150`, or `Buy vials @Goldshire`. Shift-click an item or quest link into Quick Add, or use `@` location suggestions to attach an arrival reminder. Combine tags, priorities, daily or weekly repeats, and subtasks. The on-screen tracker can show in-progress cards, all open tasks, and nearby location reminders.

Choose from nine theme choices, including Quest parchment, custom RGB/hex colors, and Classic stone/leather skins using original WoW frame artwork. Change accent colors, adjust board/tracker opacity, and set separate sounds for moves, completions, subtasks, and reminders. Settings, editor, Help, logs, and menus stay opaque. Each character has one board that your other characters can open. Choose the standard three-column workflow or Simple To Do/Done mode per board, and optionally hide completed tasks. Boards can be shared with party/raid/guild members or exported and imported as text.

Mail tasks can remind you within 35 yards of a mailbox Taskboard has learned from a previous visit. With automatic completion enabled, opening a mailbox completes a plain `Check mail @mail` task without goals or subtasks; other mail tasks stay open.

Taskboard targets **WoW Forever 1.60.1** (interface `16001`). It is not advertised for Retail or other Classic versions. Type `/tb help` for the guide and `/tb options` for settings. Report problems through the project's Issues tab (or Comments if unavailable) with your client build, steps to reproduce, and `/tb diag` output.

## First file

- Display name: Taskboard <version> for WoW Forever (match `Taskboard.toc`)
- Release type: Release after the owner has completed the in-game checklist; use Beta if gathering broader test feedback first. A Release file is needed for default CurseForge app syncing.
- Game version type/flavor: **Forever**
- Supported version: **1.60.1**
- Changelog: First CurseForge package. Includes live goal tracking, recurring tasks, mailbox proximity reminders, configurable tracker and sounds, nine theme choices including Quest parchment and custom colors, one board per character, board sharing, and in-game Help. Closing the board closes Settings, Help and the editor. Optional repeating audio accompanies nearby flashing tasks.

## Submission steps

1. Sign in at https://authors.curseforge.com/#/projects/create/choose-game and create a World of Warcraft addon project.
2. Fill the English title, summary, description, category, license and logo. Do not select Retail or a different Classic flavor for this build.
3. On the project's Files tab upload the **CurseForge ZIP**, enter the changelog, choose Forever / 1.60.1 and the release type.
4. Attach the **Legacy Loader ZIP** to that file as an Additional File. Check that a public visitor can download it manually and that the description links to it before announcing Questboard migration support.
5. CurseForge reviews the project/file. After approval, check that it appears under the Forever flavor and that the app installs `AddOns/Taskboard/Taskboard.toc`.

The release should follow the real-game checks in [TESTING.md](TESTING.md). Offline CI validates Lua 5.1 behavior and package layout; it cannot verify real UI layout or server delivery.
