# Taskboard 1.2.2 in-game test checklist

Offline tests exercise Lua 5.1 and the API fixture for Forever 1.60.1 (70862), interface 16001. They cannot certify real rendering, client event order or server delivery. Record `/tb diag` and the actual client build with each test report.

## Install and load

1. Back up an existing Taskboard SavedVariables file while the game is closed.
2. Extract the ZIP into `World of Warcraft/_forever_/Interface/AddOns/`. Confirm `Taskboard/Taskboard.toc` is one folder below AddOns, not nested twice.
3. Enable Lua error display with `/console scriptErrors 1`. Log in and run `/tb selftest` and `/tb diag`.
4. Check `/tb`, the minimap button and all three key bindings. Reload with a populated board and verify cards, order, settings, position and recurring progress survive.
5. Upgrade from an actual Questboard installation using the packaged legacy loader. Verify old boards/settings/logs appear in Taskboard, legacy bindings still work, and a second login does not overwrite new edits with the old save.

## Appearance and sound

1. Open `/tb options`. Try all seven themes, including Classic stone and Classic leather, and accents while the board, tracker and a popup are visible. Confirm changes apply immediately and survive reload.
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

Include the version, client build, exact steps, expected and observed result, `/tb diag`, and `/tb log show`. Include screenshots for layout problems. Keep the SavedVariables backup until migration and reset behavior have been checked.
