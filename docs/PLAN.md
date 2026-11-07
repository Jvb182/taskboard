# Taskboard: design plan

An in-game Kanban board for WoW: Forever (interface `16001`, client 1.60.1) with cards that track themselves.

## Goals

1. A real Kanban board: To Do → In Progress → Done (columns can be renamed and added), drag and drop, priorities, tags, notes and subtasks.
2. **Live goal tracking.** "Get 20 Peacebloom" shows `5/20` as you loot, moves itself to In Progress, and celebrates when it hits 20/20 and moves to Done.
3. Fast entry: `/qb add Get 20 Peacebloom #herbs !high`, or shift-click an item or quest link into the add box or the `/qb add` chat line.
4. Context reminders by zone, and when you open the bank, a vendor, the mailbox, the AH or a trainer.
5. Map pins, using the built-in waypoint arrow.
6. Daily and weekly repeating cards, streaks and stats.
7. Party and guild board sharing, with per-member progress.
8. Logs and diagnostics that make bug reports easy: `/qb log`, `/qb diag` and `/qb selftest`.
9. An offline test suite that runs without the game. It checks Taskboard's logic and also every API, event, widget method and template it uses against the Forever client's generated API docs.

## Non-goals

- No data from outside the game. WoW gives addons no live inbound channel.
- No automated game input and no protected actions. Everything is plain UI and read-only game queries.

## Architecture

```
Taskboard.toc
Bindings.xml               key bindings (toggle board, toggle tracker, quick add)
Core/
  Init.lua                 namespace, version, event bus (safe dispatch), module registry
  Log.lua                  leveled ring-buffer logger, persisted tail, error capture
  Util.lua                 string, table, money, time and link helpers (pure)
  Serialize.lua            safe serializer and deserializer for sync and export (pure)
  DB.lua                   SavedVariables schema, defaults, migrations, repair, CRUD (pure over a table)
  Items.lua                item name→ID resolution (link, cache, bags, built-in mats table, verification)
  Parser.lua               quick-add syntax → card spec (pure, resolvers injected)
  Goals.lua                goal types: item, money, level, skill, rep, quest (evaluate/describe)
  Engine.lua               re-evaluates goals on events (throttled), auto-moves cards, fires celebrations
  Reminders.lua            zone and NPC-interaction reminders
  Recurring.lua            daily/weekly resets, streaks
  Stats.lua                completion history and counters
  Sync.lua                 party/guild share, progress broadcast (addon messages, chunked)
  Diagnostics.lua          /qb diag report, API capability probe, in-game self-test
  Commands.lua             slash commands
UI/
  Theme.lua                colors, fonts, backdrop helpers
  Widgets.lua              small reusable widgets (button, progress bar, text input)
  Board.lua                main window: columns, cards, drag/drop, search/filter, footer stats
  Editor.lua               card editor (title, notes, priority, tags, goal, subtasks, reminders, pin)
  Tracker.lua              pinned on-screen tracker of in-progress cards
  Toast.lua                celebration and reminder toasts
  LogWindow.lua            copyable log and diagnostics viewer
  Minimap.lua              minimap button
tests/
  run.py / run.lua         runner (lupa Lua 5.1, or a plain `lua` 5.1 if installed)
  wowmock.lua              mock WoW client: frames, events, bags, quests, skills, reps, time
  fixtures/forever_api.lua generated from Blizzard's API docs (tests/tools/gen_api_fixture.py)
  spec/*.lua               test files
```

Core modules are pure Lua over injected or wrapped APIs, so they can be unit tested directly. UI modules are exercised in the mock client, where every widget method call is checked against the real Forever widget API.

## Data model (SavedVariables)

`TaskboardDB` (account-wide):

```lua
{
  schema = 1,
  settings = { autoStart, autoComplete, sounds, toasts, reminders, includeBank, trackerShown,
               trackerLocked, syncAccept = "ask"|"never", debug, minimap = { angle, hide } },
  boards = {
    [boardID] = {
      id, name, scope = "account"|"character"|"shared", owner = "Name-Realm",
      columns = { {id="todo",name="To Do"}, {id="doing",name="In Progress"}, {id="done",name="Done"} },
      cards = { [cardID] = Card }, order = { [columnID] = {cardID...} },
      shared = { from, version, members = { [charKey] = { [cardID] = {cur, target, t} } } } -- shared only
    }
  },
  stats = { history = { {t, title, char, boardID} ... (capped 500) }, total, streak = { days, lastDay } },
  ui = { board = {point...,w,h}, tracker = {point...}, activeBoard },
  resets = { nextDaily, nextWeekly },
}
```

A **Card** looks like this:

```lua
{ id, title, notes, priority = 0..3, tags = {...}, column, created, updated, completedAt,
  char = "Name-Realm" (owner), goal = Goal|nil, subtasks = { {id, text, done, goal = Goal|nil} },
  recur = nil|"daily"|"weekly", streak, where = { zone = "Ironforge" } | { npc = "bank" }, pin = {mapID, x, y, label},
  auto = { started = bool, completed = bool }, archived = bool }
```

A **Goal** looks like this:

```lua
{ type = "item", itemID, name, target, bank = true }
{ type = "money", target }                     -- copper
{ type = "level", target }
{ type = "skill", name, target }
{ type = "rep",   name, factionID?, target }   -- target = reaction index (5 = Honored)
{ type = "quest", questID, name }
```

`TaskboardLog` (account) holds the most recent 300 log lines, so logs survive `/reload` and crashes.

## Live tracking (the main feature)

- Events go to dirty flags by goal type. For example, `BAG_UPDATE_DELAYED` and `PLAYERBANKSLOTS_CHANGED` mark item goals dirty, and `PLAYER_MONEY` marks money goals dirty. One throttled pass (at most every 0.25 s) re-evaluates only the dirty types.
- Items are counted with `C_Item.GetItemCount(itemID, includeBank)`.
- Names are resolved in this order:
  1. An item link in the text.
  2. `C_Item.GetItemInfoInstant(name)`, which works for cached items.
  3. A scan of your bags for an item with that name.
  4. A built-in table of ~70 common gathering materials. Each ID from the table is verified asynchronously against the real item name, and a mismatch is logged and unbound.
  5. Otherwise the goal stays *pending*. Its name is matched on every bag update, so the first Peacebloom you loot binds it.
- Transitions:
  - progress > 0 in To Do → In Progress (`autoStart`).
  - All goals and subtasks complete → Done, with a toast, sound and history entry (`autoComplete`).
  - Done cards don't move back on their own when the count drops, for example after you craft with the herbs. The card shows a "↓ now 12/20" hint instead.
- Each card's progress is cached (`card._progress`), so the UI and tracker never query the game directly.

## Quick-add syntax

`/qb add <text>` (aliases `/todo` and `/qb a`):

| Token | Meaning |
|---|---|
| `#herbs` | tag |
| `!high` `!med` `!low` `!1`-`!3` | priority |
| `@Ironforge` / `@"Stormwind City"` | zone reminder |
| `@bank` `@vendor` `@mail` `@ah` `@trainer` | NPC reminder |
| `*daily` `*weekly` | repeating card |
| `>doing` `>done` | starting column |
| `get/collect/gather/farm/loot/mine/skin 20 Peacebloom`, `20x Peacebloom`, `Peacebloom x20`, `[item link] x20` | item goal |
| `save/have/earn 100g`, `100g 50s` | money goal |
| `reach level 40`, `ding 40`, `lvl 40` | level goal |
| `Herbalism 150`, `get Tailoring to 150` | skill goal |
| `Honored with Stormwind`, `exalted argent dawn` | reputation goal |
| `[quest link]`, `quest: The Defias Brotherhood` | quest goal |
| `; sub one; sub two` | subtasks (each can carry its own goal: `; 20 Peacebloom; 20 Silverleaf`) |

## UI

- **Board:** a movable, resizable window with one scrollable column per board column. Cards show a priority stripe, title, tags, goal progress bar (`5/20`), a subtask count and icons for reminders, pins and repeats. Drag a card to move it or reorder within a column. Right-click for a menu (move, edit, pin, archive, delete). The header has a board selector, a search box, a tag filter and a character filter. The footer shows "this week / streak / total".
- **Editor:** a side panel with every field, a "Pin current location" button, and goal pickers.
- **Tracker:** a compact list of In Progress cards with progress bars that sits under the minimap. It can be dragged, locked, and hidden in combat.
- **Toasts:** a slide-in and fade-out celebration with an icon and a sound.
- **Log window:** a scrollable, read-only edit box, so you can select and copy the text into a bug report.

## Sharing

- `/qb share party|raid|guild` sends the active board, serialized and chunked through `C_ChatInfo.SendAddonMessage` with the prefix `QBRD1`.
- Receivers are asked before importing (setting `syncAccept`). An imported board is read-only for non-owners and keeps its board ID.
- Members broadcast their own progress on the shared board's goal cards (throttled). The owner's card shows each member's progress.
- Received data is validated:
  - size caps (100 cards, 200-character text)
  - type and range checks
  - escape sequences stripped, except item and quest hyperlinks

## Diagnostics

- `/qb log [n] [level]`, `/qb log show` (window), `/qb debug on|off`.
- `/qb diag` shows:
  - version and client build
  - a capability table of every API Taskboard uses, present or missing
  - DB counts
  - event counters
  - engine timing (last and average ms per pass)
  - error count with the last error and its stack
  - sync counters
  - memory use
- `/qb selftest` runs the parser, serializer and DB checks plus live API probes in game.
- Every event handler, script handler and timer runs under `xpcall`. Errors are logged with a stack and shown once in chat, and they never break the UI.

## Testing (offline)

- **Unit tests:** Util, Serialize (round trip, malformed input), DB (defaults, migration, repair), Parser (every row in the syntax table and edge cases), Items resolution order, Goals per type, Engine transitions, Recurring resets, Stats, Sync (chunking, reassembly, validation, hostile input), Commands.
- **Integration tests:** load the full `.toc` file list into the mock client in order, fire `ADDON_LOADED`/`PLAYER_LOGIN`, run slash commands, simulate looting Peacebloom 5 → 20 and watch the card move and the toast fire, open the board, drag a card, use the editor, open the log window.
- **API conformance:**
  - Every `C_*.Fn` and documented global used in the source exists in the fixture.
  - Every event registered exists.
  - Every template used exists.
  - Every widget method called on a mock frame exists for that widget type. Unknown methods raise errors.
  - Every SOUNDKIT used exists.
- **Static checks:** a `luac`-style syntax check of every file, and no accidental globals (a test enforces that only whitelisted globals are written).

