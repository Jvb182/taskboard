# Taskboard 1.3.1 in-game test checklist

Offline tests exercise Lua 5.1 and the API fixture for Forever 1.60.1 (70862), interface 16001. They cannot certify real rendering, client event order or server delivery. Record `/tb diag` and the actual client build with each test report.

## Install and load

1. Back up an existing Taskboard SavedVariables file while the game is closed.
2. Extract the ZIP into `World of Warcraft/_forever_/Interface/AddOns/`. Confirm `Taskboard/Taskboard.toc` is one folder below AddOns, not nested twice.
3. Enable Lua error display with `/console scriptErrors 1`. Log in and run `/tb selftest` and `/tb diag`.
4. Check `/tb`, the minimap button and all three key bindings. Reload with a populated board and verify cards, order, settings, position and recurring progress survive.
5. Upgrade from an actual Questboard installation using the packaged legacy loader. Verify old boards/settings/logs appear in Taskboard, legacy bindings still work, and a second login does not overwrite new edits with the old save.
6. Check the ZIP layouts: the default CurseForge ZIP contains only `Taskboard/`, and the optional Legacy Loader ZIP contains only `Questboard/Questboard.toc`. Neither includes `tests/manual-addons/`.

The optional `tests/manual-addons/TaskboardWelcomePreview` helper opens the current welcome card on an existing board for copy/layout review. It adds a card and does not satisfy the isolated fresh-install check.

## Appearance and sound

1. Open `/tb options`. Try all nine theme choices, including Classic stone, Classic leather and Quest parchment, and accents while the board, tracker and a popup are visible. Confirm changes apply immediately and survive reload.
2. Drag opacity from 35% to 100%. Check that board/tracker backgrounds fade and text remains readable over a bright outdoor scene and a dark dungeon. Settings, editor, Help, logs and the Board dropdown must remain opaque.
3. Preview every sound choice. Move cards between statuses, manually finish one, automatically complete an item goal, and check manual/automatic subtasks. Each event uses its selected sound; Off and the master switch silence it.
4. Disable visual popups but leave sound on. Completions/reminders must still sound. Reordering within a column and daily/weekly resets must stay silent. Check sound levels with the game's own audio settings.
5. Confirm Appearance and Sounds pages fit at your UI scale and all controls are reachable.

## Editor and goals

1. Edit A's title, tags and notes without pressing Enter; click B. A receives the edit, B remains unchanged. Repeat through tracker/toast entry points.
2. Exercise items (cached and uncached), money, level/XP, profession, reputation and quests. Confirm progress, automatic movement and completion. A turned-in quest completes; a quest merely ready to turn in does not.
3. Test bags versus bank, spending/selling after completion, manual moves out of Done, manual subtasks, archive/restore and deletion while the editor is open.
4. Shift-click item and quest links into quick-add and the goal editor. Test multiword names, tags, reminders and subtasks.

## Recurring and multiple characters

1. Hold 7 Peacebloom; add `20 Peacebloom *daily`. It starts at zero extra. Acquire 20 more and verify one completion.
2. At reset, the card returns to To Do without another completion. Acquire 20 more to complete again. Repeat with item subtasks, weekly goals and a reload midway through the period.
3. Switch to current-stock mode. After reset, already-held stock must not immediately complete it again; reduce stock below target, then replenish it.
4. Complete a daily on A's character board. Log B in first after reset, then A: A's card must be reset. Repeat after several missed periods and confirm the streak breaks. Archived cards must stay untouched.
5. When an offline character returns, their new inventory baseline begins at login. Verify the displayed extra-count text matches that rule. Changing bank-counting options starts a fresh baseline.

## Two-player sharing and imports

1. Both testers use this version. Share a small board in party, raid and guild separately. Decline once, accept once, and let an offer expire. Disabled offers must not create new boards.
2. Each player changes their own inventory. Verify member progress is separate. `/tb done` and editor/menu operations must not modify the owner's shared cards.
3. Keep the recipient editor open while the owner changes or deletes a card. The view must update or close. Local tracker choices should survive owner updates.
4. Share a larger board while other add-ons are active. Check completion and diagnostics for retries. Terminal failures must be visible; no permanent partial board should be imported.
5. Stop sharing while a transfer is queued; unsent chunks must stop. Text export a board too large for addon messages, import it on another character, and verify its goals track that character.
6. Check the board limit, damaged/truncated export handling and that imported titles/notes cannot inject textures or hyperlinks.

## Layout and interaction

Test narrow/wide windows, UI scaling, long titles and notes, a full board, eight columns, long menus, filtering and drag/drop while progress updates. Test the tracker hidden during combat, zone/NPC reminders, map pins and toast expiry. Capture screenshots of clipping or unreachable controls.

## Bug reports

Include the version, client build, exact steps, expected and observed result, `/tb diag`, and relevant `/tb log show` lines. Include screenshots for layout problems. Review copied diagnostics and images for private names or task details. Use the project Issues tab (or Comments if unavailable); test-build users can report to the person who shared the addon. Keep the SavedVariables backup until migration and reset behavior have been checked.

## 1.3.x focused in-game checks

- [ ] For a zone task such as `Train in @Stormwind City`, enter Stormwind and confirm a popup appears. Leave until the tracker stops flashing, then return within five minutes. Confirm a second popup appears; moving among Stormwind subzones must not repeat it.

- [ ] Add populated custom columns, move them left/right through their header menus, and reload. Cards and status roles stay intact. Boundary actions are disabled; hidden columns keep their saved slots.
- [ ] Archive more than 25 tasks. Browse Previous/Next pages through all tasks, restore one on the last page, and verify the total drops by one.
- [ ] Check Classic stone's solid dark Blizzard backdrop and light text. Check parchment artwork and dark text in Classic leather and Quest parchment. Try narrow columns, different window sizes and UI scales.
- [ ] Read Help with its larger body text/headings; check wrapping and scrolling. Search across tabs for mailbox, sound and columns, including mixed case and no results. Clear or select a tab to restore normal browsing.

- [ ] Switch one character board to Simple; confirm In Progress/custom tasks move to To Do with progress preserved. Other characters retain their own layout. Reload and switch back.
- [ ] Hide completed in Standard and Simple modes. Complete a task in the editor and via a live goal, then reveal Done; cards and history remain intact.
- [ ] Check Simple tasks in the tracker and verify hiding the tracker still works.
- [ ] Select Quest parchment. Confirm the quest artwork loads and dark text is readable on board, tracker, editor, Help and Settings.
- [ ] Open all dialogs at 35% opacity under each classic skin; Help and other dialog backgrounds must be solid.
- [ ] Use RGB sliders and hex input for each custom color. Test Apply, Cancel, Escape, preset switching, reload and Reset appearance.
- [ ] Close the board via X, Escape, slash command, minimap and key binding, including in combat. Settings, Help, picker and editor close. Focused edits survive; reopening the board does not reopen dialogs.
- [ ] Open a disposable card in the editor. Its footer Close responds; Delete opens a visible confirmation, Cancel keeps the card, and Yes removes only that card. Archive also responds and the card appears under archived tasks.
- [ ] Enable repeating nearby sound and test 15/30/60 seconds with two nearby tasks. Confirm one sound per interval and silence after leaving, completion, collapsing/hiding the tracker, sound Off, reminders Off and master sound Off.
