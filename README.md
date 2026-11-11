# Taskboard

Taskboard is a personal task board for **World of Warcraft: Forever**. Keep errands, gathering goals, reminders, and recurring work in one place without turning them into game quests.

Add `Get 20 Peacebloom` and Taskboard tracks your bags as you gather: `0/20 → 5/20 → 20/20`. You can also keep ordinary manual tasks, such as `Buy vials @Goldshire`.

**Requires:** WoW Forever, interface `16001` · **Open:** `/tb`, `/taskboard`, or the minimap button · **In-game guide:** `/tb help`

## What it does

- **Organizes tasks:** use To Do, In Progress, and Done; add and reorder columns; drag cards; search and filter; archive finished work. Each character has one board, and you can view your character boards from your other characters. Simple mode reduces a board to To Do and Done, and you can hide the completed column.
- **Tracks goals:** items in your bags, optional bank counts, gold, level and XP, profession skill, reputation, and quests. Goals can belong to a card or a subtask. Typed item names work without an item link. If a typed name cannot resolve to an item, you can complete that subtask manually or clear the card's item tracking.
- **Reminds you:** attach a zone with `@Goldshire` or a supported service with `@mail`, `@bank`, `@vendor`, `@ah`, or `@trainer`. Location suggestions appear as you type `@` in Quick Add and the editor. A location reminder alerts you on arrival; it does not complete the task.
- **Keeps a compact tracker:** show in-progress and pinned cards, or include every open task. Nearby location tasks can pulse until you leave. The tracker can be hidden independently of the board.
- **Repeats tasks:** daily or weekly cards reset at server reset. For repeating item goals, choose between collecting additional inventory during the period and tracking current stock.
- **Fits your UI:** choose a preset or custom colors, adjust board and tracker opacity, and select separate sounds for status changes, completions, subtasks, and reminders. Settings, Help, and editor windows stay opaque.
- **Shares and exports:** offer a board to party, raid, or guild members who also use Taskboard, or copy a board as text for import elsewhere. Recipients confirm before importing.

The **Help** panel explains each feature with examples and has search. See [the manual QA checklist](docs/TESTING.md) for in-game release checks.

## Install

Install [Taskboard from CurseForge](https://www.curseforge.com/wow/addons/taskboard), or download the current `Taskboard-<version>-CurseForge.zip` and extract it so this file exists:

```text
World of Warcraft/_forever_/Interface/AddOns/Taskboard/Taskboard.toc
```

Restart the game after installing. Open the board with `/tb` or its minimap button. You can assign shortcuts for the board, tracker, and Quick Add under **Key Bindings → AddOns → Taskboard**.

If you are upgrading saved data from **Questboard**, use the optional `Taskboard-<version>-Legacy-Loader.zip` for one login. Close the game, back up SavedVariables, install Taskboard, and extract the loader into `Interface/AddOns/`. Enable **Taskboard** and **Taskboard - legacy data loader**. Taskboard copies the old boards and settings without running the old add-on code; the original save remains intact. After a reload and verification, remove or disable the loader. The CurseForge app does not install this optional file automatically. See [the release guide](docs/CURSEFORGE.md) for packaging and upload details.

## Add tasks

Use the **Add a card** box, `/tb add <text>`, or `/todo <text>`. For example:

```text
Get 20 Peacebloom
Buy vials @Goldshire #alchemy !high
Check mail @mailbox
Alchemy prep *daily; 20 Peacebloom; 20 Silverleaf; buy vials
```

| Syntax | Use |
| --- | --- |
| `#tag` | Group or filter tasks |
| `!low`, `!med`, `!high` | Set priority |
| `@Goldshire`, `@"Stormwind City"` | Remind on entering a location |
| `@bank`, `@vendor`, `@mail`, `@ah`, `@trainer` | Remind at a supported service |
| `*daily`, `*weekly` | Repeat after server reset |
| `>doing`, `>done` | Choose an initial column |
| `;` | Separate subtasks |

Service aliases include `@merchant`, `@mailbox`, `@auction`, and `@auctionhouse`. Other `@words` are locations, not NPC names. For example, `Talk to innkeeper @Goldshire` reminds you in Goldshire; `@innkeeper` does not detect an innkeeper.

Type `@` followed by letters to search localized locations. Select a suggestion with the mouse or keyboard. Multiword names are quoted for you. You can also type an unlisted location yourself.

### How reminders behave

Tasks can remind you while they are in **To Do** or **In Progress**. Bank, vendor, auction house, trainer, and mailbox service reminders react when the matching window opens. Taskboard also learns mailbox positions when you open them; on a later visit, `@mail` tasks can remind you within about 35 yards. An unvisited mailbox has no known position.

Plain “Check mail,” “Check mailbox,” and similar tasks receive a mail reminder automatically. Opening a mailbox can complete a plain check-mail task when automatic completion is enabled. Other mailbox errands and tasks with goals or subtasks stay open until you finish them.

## Commands

| Command | Action |
| --- | --- |
| `/tb` | Open or close the board |
| `/tb add <text>`, `/todo <text>` | Add a task |
| `/tb list`, `/tb done <number or text>` | List or finish tasks |
| `/tb tracker` | Toggle the tracker |
| `/tb board [name]` | List or switch boards |
| `/tb share party\|raid\|guild`, `/tb unshare` | Share or stop sharing |
| `/tb export`, `/tb import` | Copy board data |
| `/tb options`, `/tb help` | Open settings or Help |
| `/tb log`, `/tb diag`, `/tb selftest` | Inspect diagnostics |

You can report a bug using the steps in **Help → Settings & sharing → Reporting a bug**. Include the add-on version, what you did, what happened, and relevant `/tb diag` or `/tb log show` output.

## Roadmap

See the [roadmap](ROADMAP.md) for ideas being explored: automatic mail-task creation, map pings for task locations, and NPC-aware trainer reminders such as `/tb train in swords`. These are proposals that need WoW Forever client validation; they are not features of the current release.

## Development and testing

Taskboard's offline suite uses Lua 5.1 through Python's `lupa` package. It checks the core logic and UI calls against a fixture generated from the Forever client's API documentation.

```bash
pip install -r tests/requirements.txt
python tests/run.py
python tests/tools/package.py --curseforge
python tests/tools/package.py --legacy-loader
python tests/tools/check_package.py
```

GitHub Actions runs the tests on Windows and Linux, builds the packages, and tests the extracted CurseForge package. Visual layout, real server behavior, and live client timing still need in-game checks.

For maintainers: [architecture](docs/ARCHITECTURE.md) · [test coverage](docs/QA-COVERAGE.md) · [manual QA](docs/TESTING.md) · [CurseForge release guide](docs/CURSEFORGE.md).
