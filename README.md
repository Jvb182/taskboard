# Questboard

A Kanban to-do board for **World of Warcraft: Forever** (interface `16001`) whose cards track themselves.

Type `Get 20 Peacebloom` and the card counts `0/20 → 5/20 → 20/20` as you loot. It moves to **In Progress** when you start and to **Done** with a sound and a popup when you finish.

## Features

- **Board:** To Do → In Progress → Done.
  - Rename columns or add your own.
  - Drag and drop cards, or reorder them.
  - Search, filter by tag, and show only this character's cards.
  - Multiple boards, shared across all your characters or limited to one.
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
  /qb add Alchemy prep #herbs !high @bank *daily; 20 Peacebloom; 20 Silverleaf; buy vials
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
- **Repeating cards:** daily and weekly cards reset at server reset and keep a streak.
- **Tracker:** a compact on-screen list of in-progress cards with progress bars. It can hide in combat.
- **Stats:** completions today and this week, a day streak, and a total.
- **Sharing:** `/qb share party|raid|guild`.
  - Members are asked before anything is imported.
  - Each member's progress on the shared goals shows on the owner's cards.
  - Everything received is validated and sanitized.
- **Export and import:** copy a whole board as text.
- **Diagnostics:**

  | Command | What it does |
  |---|---|
  | `/qb log [n]` | recent log lines in chat |
  | `/qb log show` | copyable log window |
  | `/qb debug on` | verbose logging |
  | `/qb diag` | client build, data counts, engine timings, event counters, API availability, last error with stack |
  | `/qb selftest` | in-game checks |

  Every handler runs under error capture, so a bug is logged with a stack and never breaks your UI.

## Install

Put this folder at `World of Warcraft/_forever_/Interface/AddOns/Questboard/`. The `.toc` must be directly inside that folder. Restart the game, or `/reload` if it was already installed.

Open the board with `/qb` or the minimap button, or bind a key under Key Bindings → AddOns.

## Commands

| Command | |
|---|---|
| `/qb` | open or close the board |
| `/qb add <text>` or `/todo <text>` | add a card |
| `/qb list`, `/qb done <n or text>` | list open cards, finish one |
| `/qb tracker` | show or hide the tracker |
| `/qb board [name]` | list, switch or create boards |
| `/qb share party\|raid\|guild`, `/qb unshare` | sharing |
| `/qb export`, `/qb import` | copy boards as text |
| `/qb options` | settings |
| `/qb log`, `/qb diag`, `/qb selftest`, `/qb debug on\|off` | diagnostics |

## Tests

The test suite runs without the game. It needs Python with `lupa`, which provides Lua 5.1, the version WoW uses.

```
pip install lupa
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
