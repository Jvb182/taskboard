# Taskboard

Formerly Questboard. Open with `/tb` or `/taskboard`; existing key bindings are retained.

The board's **Help** button (or `/tb help`) opens a full reference with **Quick Add**, **Tracking & reminders**, and **Settings & sharing** tabs. It covers goal examples, location suggestions, bank counting, recurring item modes, tracker behavior, boards, appearance, sounds, sharing, import/export, commands, and troubleshooting. Each tab scrolls; help never pops up merely from hovering over Quick Add.

Type `@` followed by a letter in Quick Add to suggest locations: `@g` narrows to `@go` for Goldshire. Suggestions come from the client's localized area names, indexed in small batches on first use (area IDs 1–30000), including zones and subzones. Click a result or use Up/Down and Tab/Enter; Enter accepts the location first, then a second Enter adds the task. Scroll for more matches. Multiword locations are quoted automatically. Escape dismisses suggestions, and unlisted locations can still be typed manually. `@Goldshire` adds an arrival reminder for an unfinished task; it does not complete the task on arrival.

A Kanban to-do board for **World of Warcraft: Forever** (interface `16001`) whose cards track themselves.

Type `Get 20 Peacebloom` and the card counts `0/20 → 5/20 → 20/20` as you loot. It moves to **In Progress** when you start and to **Done** with a sound and a popup when you finish.

## Features

- **Board:** To Do → In Progress → Done.
  - Rename columns or add your own.
  - Drag and drop cards, or reorder them.
  - Search, filter by tag, and show only this character's cards.
  - Multiple boards, shared across all your characters or limited to one.
  - A horizontal scrollbar keeps extra columns reachable in narrow windows.
- **Make it yours:** `/tb options` → **Appearance** offers Midnight, Warm leather, Forest, Arcane and High contrast themes; Sky, Gold, Mint, Rose and Lilac accents; and 35–100% panel opacity. Changes apply live and persist across reloads. Text stays opaque; status/priority colors retain consistent meanings.
- **Event sounds:** `/tb options` → **Sounds** lets you choose Off, Soft click, Chime or Quest complete separately for status changes, completions, subtasks and zone/NPC reminders. Each has a Preview button. Manual and automatic completions both give feedback; reordering and daily/weekly resets are silent. The master Play sounds switch is under General, and volume follows the game settings. Sounds can remain on when popups are off.
- **Live goals:** each card or subtask can track any of these:

  | Goal | Example |
  |---|---|
  | Items (bags, optionally the bank) | `20 Peacebloom`, `[item link] x5` |
  | Gold | `save 100g` |
  | Level, with XP progress | `reach level 40` |
  | Profession skill | `Herbalism 150` |
  | Reputation | `Honored with Stormwind` |
  | Quest | `[quest link]` or `quest: The Defias Brotherhood` |

- **Quest-style messages:** "Peacebloom 6/20" appears on screen as you loot, like quest objectives.
- **Quick add:** type a line or shift-click an item into the box. For example:

  ```
  /tb add Alchemy prep #herbs !high @bank *daily; 20 Peacebloom; 20 Silverleaf; buy vials
  ```

  | Token | Meaning |
  |---|---|
  | `#tag` | tag |
  | `!low` `!med` `!high` | priority |
  | `@Ironforge` / `@"Stormwind City"` | zone reminder |
  | `@bank` `@vendor` `@mail` `@ah` `@trainer` | NPC reminder |
  | `*daily` `*weekly` | repeating card |
  | `>doing` `>done` | starting column |
  | `;` | separates subtasks |

- **Reminders:** a card pinned to a zone or an NPC pops up when you arrive there or open that NPC.
  - At the AH: lists the goal items you still need.
  - At the bank: shows goal items sitting in your bank.
- **Map pins:** pin a card to where you're standing. "Show on map" sets the game's waypoint arrow.
- **Repeating cards:** daily and weekly cards reset at server reset, including boards belonging to offline alts. Missing a period breaks the streak; archived cards stay archived.
  - Repeating item goals default to **extra inventory this period**: net inventory above the amount held when the card/period starts. Spending or selling reduces that net gain; this is not a cumulative loot counter.
  - Uncheck **Items: collect extra each period (net gain)** in the editor to track current stock instead. After reset, a stock goal must become incomplete before it can automatically complete again.
  - Baselines survive reloads. An offline character starts a new baseline on their next login; activity while the add-on is disabled cannot be reconstructed. Changing bank-counting options starts a fresh baseline for affected goals.
- **Tracker:** a compact on-screen list of in-progress and pinned cards with progress bars. Enable **Tracker: include all open tasks** in General settings (or **Show all open tasks** in the tracker header menu) to also include manual To Do tasks and reminders. Scroll to reach additional tasks. Done/archived tasks and tasks belonging to other characters remain excluded. It can hide in combat.
- **Stats:** completions today and this week, a day streak, and a total.
- **Sharing:** `/tb share party|raid|guild`.
  - Members are asked before anything is imported.
  - Each member's progress on the shared goals shows on the owner's cards.
  - Everything received is validated and sanitized.
  - Temporary message throttling is retried with backoff. Terminal failures appear in chat/logs; share again after resolving them.
  - Boards above the 60 KB transport limit must be shared using text export. Pending offers expire after 60 seconds; unsolicited whispers are ignored.
- **Export and import:** copy a whole board as text.
  - Imports create a new board owned by you and assign its live goals to the importing character.
- **Diagnostics:**

  | Command | What it does |
  |---|---|
  | `/tb log [n]` | recent log lines in chat |
  | `/tb log show` | copyable log window |
  | `/tb debug on` | verbose logging |
  | `/tb diag` | client build, data counts, engine timings, event counters, API availability, last error with stack |
  | `/tb selftest` | in-game checks |

  Core event dispatch, timers and action handlers capture errors for the diagnostic log. Enable the game's script-error display during testing as well.

## Install

Use the packaged ZIP: extract both included folders into `World of Warcraft/_forever_/Interface/AddOns/`. The main addon is `Taskboard/Taskboard.toc`. The small `Questboard/Questboard.toc` compatibility folder only loads legacy saved data and has no UI or tracking code. Restart the game after installing the newly named add-on.

**Upgrading from Questboard:** with the game closed, back up your old SavedVariables, then extract the ZIP and allow it to replace `Questboard/Questboard.toc`. Enable Taskboard and **Taskboard - legacy data loader** for the first login. Taskboard copies existing boards, settings and logs once, then saves to `TaskboardDB`/`TaskboardLog`; the old save is left intact. After a successful logout/reload and verification of your boards, the legacy loader can be disabled. Do not run the original Questboard code alongside Taskboard.

For a source checkout, install the runtime folder as `Taskboard` and also copy `compat/Questboard` alongside it if you need legacy migration. Running `python tests/tools/package.py` prepares the correct layout automatically.

Open the board with `/tb` or the minimap button, or bind a key under Key Bindings → AddOns.

## Commands

| Command | |
|---|---|
| `/tb` | open or close the board |
| `/tb add <text>` or `/todo <text>` | add a card |
| `/tb list`, `/tb done <n or text>` | list open cards, finish one |
| `/tb tracker` | show or hide the tracker |
| `/tb board [name]` | list, switch or create boards |
| `/tb share party\|raid\|guild`, `/tb unshare` | sharing |
| `/tb export`, `/tb import` | copy boards as text |
| `/tb options` | settings |
| `/tb log`, `/tb diag`, `/tb selftest`, `/tb debug on\|off` | diagnostics |

## Tests

The test suite runs without the game. It needs Python with `lupa`, which provides Lua 5.1, the version WoW uses.

```
pip install -r tests/requirements.txt
python tests/run.py              # everything
python tests/run.py engine_spec  # one spec
```

`tests/wowmock.lua` is a mock Forever client with simulated bags, bank, money, level, skills, reputations, quests, zones, map, group, addon messages and time. The checks are built from **Blizzard's generated API documentation for the Forever client** (`tests/fixtures/forever_api.lua`), so:

- Every widget method the UI calls must exist on that widget type in the real client. Anything else errors.
- Every `C_` API, global, event, XML template, font object and `SOUNDKIT` name the code uses must exist in Forever.
- Every API the mock simulates must exist in Forever too, so a misspelled API can't pass just because it was mocked.
- A full scripted session is audited for unknown globals, missing APIs and stray global writes.

To refresh the fixture after a client patch, run `tests/tools/gen_api_fixture.py`. Its header lists the steps.

What the offline tests cannot cover: texture paths, real layout and visuals, and real server behavior such as item cache timing and addon-message throttling. Those need an in-game check.

See [the in-game test checklist](docs/TESTING.md) before releasing. CI runs Lua 5.1 tests on Windows and Linux, then builds an installable ZIP:

```
python tests/tools/package.py
```

The archive contains the Taskboard runtime and the legacy data loader, ready to extract into `Interface/AddOns/`.

