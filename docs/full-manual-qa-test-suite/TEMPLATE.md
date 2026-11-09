# Taskboard full manual QA test suite

Copy this template to `YYYY-MM-DD-taskboard-qa.md` for each run. Fill in the run details, check a case only after it passes, and record a bug for every failure. Mark unavailable cases **Not run** with a reason; use **Not applicable** only when the feature truly does not apply.

| Field | Result |
| --- | --- |
| Tester and date | |
| Taskboard version and client build | |
| Character, realm, and zone | |
| UI scale and resolution | |
| Lua errors and `/tb selftest` result | |
| Build or PR under test | |

## Latest Taskboard UI changes

- [ ] **UI1301** On-screen tracker shows Daily and Weekly markers next to repeated tasks without covering the title or priority.

- [ ] **UI1302** The edit card has no Column selector; cards move between statuses by dragging on the board.

- [ ] **UI1303** Open cards set to Never, Daily, and Weekly. The selected repeat button is visibly highlighted, and switching choices updates the highlight.

- [ ] **UI1304** Capture all nine themes with the board, tracker, cards, and Options open. Confirm readable text, distinct skins, solid dialogs, and usable contrast: Midnight, Warm Leather, Forest, Arcane, High Contrast, Classic Stone, Classic Leather, Quest Parchment, and Custom.

- [ ] **UI1305** Open Appearance after a UI reload and confirm the taller Options window shows Background, Text, Border, Accent, and Reset appearance without scrolling.

## Board layouts

- [ ] **LAY01** Enable Simple mode on a populated board. Confirm the warning; In Progress/custom-column tasks move to To Do with progress, notes and subtasks intact.

- [ ] **LAY02** Reload and switch characters. Simple/Standard preferences persist separately for each character board; switching back to Standard restores columns without restoring old task positions.

- [ ] **LAY03** In Simple mode, advance a live goal. It stays To Do until complete; reminders and tracker visibility still work.

- [ ] **LAY04** Hide Show completed in Standard and Simple. Finish a manual task and a live goal; reveal Done and verify both cards and history remain.

- [ ] **LAY05** Add two custom columns containing tasks. Use each header's Move column left/right controls. Tasks stay in their columns and the edge actions are disabled.

- [ ] **LAY06** Reorder, reload and switch boards. Order persists per board; core status behavior still works after moving/renaming columns.

- [ ] **LAY07** Reorder with Done hidden, then reveal it. Hidden columns retain their saved slots. Repeat in Simple mode; received read-only boards cannot be changed.

## Archived tasks

- [ ] **ARC1301** Open Board > Show archived cards. Verify total count and that only this board's archived cards appear.

- [ ] **ARC1302** With more than 25 archived tasks, use Next/Previous page to reach every task, including the final page.

- [ ] **ARC1303** Restore an entry from the last page. It returns to its original column, archive count drops, and it remains restored after reload.

## Appearance and custom colors

- [ ] **STYLE01** Select Classic Stone, Classic Leather, and Quest Parchment. Classic Stone shows a solid dark Blizzard dialog style with light text; the other two show warm parchment with dark text.

- [ ] **STYLE02** Resize the board and test several UI scales. Check parchment on board, columns, tracker, Help and dialogs for stretching, clipping and obscured controls.

- [ ] **STYLE03** Set panel opacity to 35%. Settings, Help, editor, board dropdown, other menus and logs remain solid while board/tracker honor the opacity setting.

- [ ] **STYLE04** Change Background, Text, Border and Accent using RGB sliders and six-digit hex. Apply selects Custom and updates existing windows.

- [ ] **STYLE05** Try invalid hex, Cancel, X and Escape. Invalid values do not save; dismissed drafts leave saved colors unchanged.

- [ ] **STYLE06** Switch presets, return to Custom and reload. Custom colors persist; Reset appearance restores documented defaults.

- [ ] **STYLE07** Classic Stone, Classic Leather, and Quest Parchment show readable column names and counts. Stone uses light text on dark panels; Leather and Quest Parchment use dark text on solid header strips.

## Help, bindings and closing windows

- [ ] **HELP1301** Read all Help tabs. Larger body text/headings wrap correctly and every entry can be reached by scrolling.

- [ ] **HELP1302** Search for mailbox, sounds and columns from different tabs. Search covers all Help, ignores letter case, and shows explanations with their examples.

- [ ] **HELP1303** Try an unmatched query and punctuation. Show a useful empty state without errors; Clear, Escape or selecting a tab restores normal browsing.

- [ ] **HELP1304** Confirm Help and General Settings explain WoW Key Bindings > AddOns > Taskboard. Check all three bindings: board, tracker and Quick Add.

- [ ] **CLOSE01** Open Help, Settings, editor and a color picker, then close the board using X, Escape, /tb, minimap and its binding. Dependent windows close too.

- [ ] **CLOSE02** Edit a focused title or notes field, then close the board. Reopen the card and verify the edit was preserved; reopening the board does not reopen dialogs.

- [ ] **CLOSE03** Repeat window closing during combat; Help/settings/editor/logs remain closable without errors.

## Repeating nearby sound and mailbox reminders

- [ ] **SND1301** Confirm repeating nearby sound is off by default. Enable it, choose a reminder sound and stand near an eligible flashing task.

- [ ] **SND1302** Test 15/30/60-second intervals with two flashing tasks. Hear at most one repeat per interval; it starts after the selected delay.

- [ ] **SND1303** Leave the area, finish/archive tasks, collapse/hide the tracker or hide it in combat. Repeating sounds stop; returning restarts the delay.

- [ ] **SND1304** Test reminder sound Off, master sounds Off, reminders Off and location flashing Off. Each silences repeats.

- [ ] **MAIL1301** Add plain Check mail, Check mailbox and Open mail tasks. Confirm Mail is inferred, a learned mailbox triggers proximity reminders, and opening it completes eligible check-mail tasks when automatic completion is enabled.

- [ ] **MAIL1302** Set a mail task's reminder to Off and reload. It stays Off. Send-items tasks and tasks with unfinished goals/subtasks are not incorrectly completed by opening mail.

# Detailed manual reference

# Test run details

- [ ] **SET01** Run `/tb diag` and record the addon version and client build above. Record the version under test.

- [ ] **SET02** Enable Lua errors with `/console scriptErrors 1`. Run `/tb selftest`; save the result and investigate any reported failure.

- [ ] **SET03** Choose a character with access to a bank, vendor, mailbox, auction house, and trainer. Arrange a second character for account tests.

- [ ] **SET04** Note your starting bags, bank contents, money, level, profession skill, and relevant reputation. Choose goals that are not already satisfied.

- [ ] **SET05** Use disposable tasks for delete, archive, import, and bulk tests. Run fresh-install and legacy migration tests against an isolated test setup with recoverable saved data.

- [ ] **SET06** Start with automatic starting/completion, reminders, popups, sounds, and tracker enabled. Turn off Show all open tasks initially. Record later setting changes so tests remain reproducible.

# Quick smoke test

These are release blockers if they fail. The detailed sections below cover their edge cases.

- [ ] **SM01** Open with `/tb`, close, and reopen using the minimap button. The same board appears without an error.

- [ ] **SM02** Add `Organize bags #qa`. It starts in To Do and does not immediately jump to Done.

- [ ] **SM03** Drag that task through In Progress and Done. The status changes once per move, with the selected feedback.

- [ ] **SM04** Add `get 17 Silverleaf #qa` while holding fewer than 17. The target is 17, and the count matches the selected bag/bank settings.

- [ ] **SM05** Add the same quantity using a real shift-clicked Silverleaf link. The title is readable and contains no raw color/link fragments such as `/cn1Q1:`.

- [ ] **SM06** Open Settings, then close the main board with its X. Settings closes too.

- [ ] **SM07** Select Classic stone, then Classic leather. Frame artwork changes immediately; text and controls remain readable.

- [ ] **SM08** Set opacity to 35%. The board/tracker fade, while Settings, editor, Help, logs, and the Board dropdown remain opaque.

- [ ] **SM09** Hide the tracker with `/tb tracker`. It stays hidden while you can still open and use the main board.

- [ ] **SM10** Enter the location on a To Do reminder task. It reminds and pulses without requiring In Progress.

- [ ] **SM11** Complete the learned-mailbox approach test MB03 below. It reminds before the mailbox is opened.

- [ ] **SM12** Add `Check mail @mail` and open a mailbox. The task moves to Done.

- [ ] **SM13** Reload the UI. Cards, settings, positions, and counts survive without duplicates or lost tasks.

- [ ] **SM14** Log into character B. B has its own board, can select A's board, and does not update A's live goals using B's inventory.

# Installation upgrades and branding

- [ ] **IN01** Install the release ZIP. Confirm `Interface/AddOns/Taskboard/Taskboard.toc` exists with no extra nested Taskboard folder.

- [ ] **IN02** On an isolated fresh setup, log in with Taskboard enabled. One personal board and the welcome card appear without errors.

- [ ] **IN03** Upgrade a populated Taskboard setup. Compare task titles, notes, goals, statuses, subtasks, settings, and positions with the prior setup.

- [ ] **IN04** Repeat login/reload after upgrading. The upgrade does not run again, duplicate cards, or restore old values over new edits.

- [ ] **IN05** In an isolated Questboard migration test, install the manual upgrade ZIP and enable Taskboard plus the legacy data loader. Existing data appears in Taskboard.

- [ ] **IN06** Edit a migrated card, reload, and then disable the legacy loader. The edit persists, and Taskboard still loads normally.

- [ ] **IN07** Check the board, tracker, editor, Help, Settings, minimap tooltip, and logs. User-facing branding says Taskboard and tasks; legacy compatibility identifiers may remain internally.

- [ ] **IN08** Verify `/tb` and `/taskboard` work. Taskboard does not register the retired `/qb` command. If another addon owns that command, record it separately.

- [ ] **IN09** Disable and re-enable Taskboard through the normal addon flow. Saved cards and preferences return.

# Opening closing windows and combat

- [ ] **UI01** Left-click the minimap button repeatedly. It toggles the board reliably without opening duplicate windows.

- [ ] **UI02** Right-click the minimap button. It toggles the tracker; the board remains usable.

- [ ] **UI03** Drag the minimap button, reload, and check its position. Hide it in General settings and restore it through `/tb options`.

- [ ] **UI04** Assign and test all three key bindings: board toggle, tracker toggle, and Quick Add. Quick Add opens the board and focuses the input.

- [ ] **UI05** Drag the title or empty top strip of the main board. It moves; header buttons remain clickable.

- [ ] **UI06** Resize with the bottom-right grip. Columns, inputs, footer, and scrollbars remain reachable at narrow and wide sizes.

- [ ] **UI07** Reload after moving/resizing. Position and size persist, with the window reachable on screen.

- [ ] **UI08** With Settings open, close the board using its X, `/tb`, the minimap, and the board binding in separate attempts. Settings closes each time.

- [ ] **UI09** Test Escape with the board and Settings open, including after clicking each window. Nothing becomes stranded or impossible to close.

- [ ] **UI10** Open Settings directly with `/tb options` while the board is closed. Settings opens and its own X closes it.

- [ ] **UI11** Enter combat with Settings and the log window already open. Both X buttons still close their windows without a blocked-action error.

- [ ] **UI12** Repeat the combat close test for the board, editor, and Help. Record any Lua error or control that becomes stuck.

- [ ] **UI13** Close the board with a dropdown open or while dragging a card. The dropdown/drag indicator disappears and no input remains captured.

- [ ] **UI14** Open Help and close the board. Help closes too; reopening the board leaves Help closed until requested.

# One board per character

Use A and B on the same WoW account and saved-data installation.

- [ ] **BD01** Log into A. There is one personal board for A, and the Board menu has no New board entries.

- [ ] **BD02** Log into B for the first time. One personal board is created for B; A's board remains available.

- [ ] **BD03** Switch between A's and B's boards from B. Names/owner labels identify which board is selected.

- [ ] **BD04** Return to A. A's personal board is selected on login and contains A's original cards.

- [ ] **BD05** Rename a board. The name updates in the selector and survives reload without creating another board.

- [ ] **BD06** Use `/tb board` to list boards and `/tb board <exact name>` to switch. A nonexistent name produces a helpful message without creating a board.

- [ ] **BD07** Give A and B identically named boards. Owner labels in the dropdown identify the correct one. `/tb board My Tasks` refuses an ambiguous match; `/tb board My Tasks (Character-Realm)` or the board ID selects the intended board.

- [ ] **BD08** View A's live item goal from B and change B's inventory. A's recorded progress does not become B's inventory count.

- [ ] **BD09** Add a task while viewing another character's board. It defaults to that board's owner; live tracking must use the assigned character, not the logged-in character's inventory.

- [ ] **BD10** Change a task's assigned character in the editor. Progress and tracker eligibility follow that assignment.

- [ ] **BD11** On an isolated pre-1.2 save with multiple local boards, upgrade. Local cards merge into character boards without losing titles, notes, tags, priorities, goals, repeats, or subtask states.

- [ ] **BD12** Compare To Do, In Progress, Done, and archived cards before/after the merge. Their status and archived state are preserved.

- [ ] **BD13** Include mixed-character cards in an old account board. After migration, each card belongs to the board for its assigned character.

- [ ] **BD14** Include custom columns in migration. Names/statuses are retained where the eight-column limit permits; record how overflow columns are mapped and confirm no cards vanish.

- [ ] **BD15** Include a received shared board in migration. It remains separate with its ownership/editing restrictions.

- [ ] **BD16** Reload twice after consolidation. Card totals stay stable and no old board is recreated.

- [ ] **BD17** Test deleting only a disposable board, including canceling the confirmation. Another character's cards are not removed by accident; logging back into the deleted board's owner produces a usable personal board.

# Quick Add and parsing

Use real game item/quest links where indicated; do not type the placeholder text literally.

- [ ] **QA01** Add plain text with the Add button, Enter, `/tb add`, and `/todo`. Each action creates exactly one manual task.

- [ ] **QA02** Submit an empty or spaces-only input. No empty card is created.

- [ ] **QA03** Add `Organize bags #qa !low`. The tag and low priority are stored, without the tokens cluttering the title.

- [ ] **QA04** Test `!med` and `!high`. Priority indicators match the selection in the editor and tracker.

- [ ] **QA05** Add separate manual tasks with `>todo`, `>doing`, and `>done`. Each starts in the requested status.

- [ ] **QA06** Add `get 17 Silverleaf #qa` and `20 Peacebloom #qa`. Item and target are parsed correctly.

- [ ] **QA07** Type `get 17 `, then shift-click Silverleaf from a bag. The target remains 17 and the title contains no broken color/link escape codes.

- [ ] **QA14** Test apostrophes, punctuation, a roughly 200-character title, pasted two-line notes, and a 600-character title in the editor. Reopen the card; text remains saved, long titles truncate without errors, and semicolons in Quick Add create subtasks.

- [ ] **QA09** Test a multiword item, an item not currently in bags, and a name not yet resolved by the client. No wrong item is silently substituted; a pending name can resolve after matching item data/loot becomes available.

- [ ] **QA10** Add `save 10g 50s #qa`. The goal represents 10 gold and 50 silver, not 10 gold alone.

- [ ] **QA11** Add a level, profession, reputation, and quest example from the goal section below. Each becomes the correct goal type.

- [ ] **QA12** Add `Alchemy prep #qa; 20 Peacebloom; 20 Silverleaf; buy vials`. Three subtasks appear with two live item goals and one manual checkbox.

- [ ] **QA13** Put tags, priority, repeat, and location tokens after a semicolon. They apply to the task as documented, rather than appearing as accidental subtask text.

- [ ] **QA15** Add several tasks rapidly. Five rapid Enter submissions produced five distinct chat confirmations and raised the Queue count from 11 to 16, without duplicates or dropped submissions.

# Location suggestions and reminder editing

- [ ] **LC01** Type `Buy vials @g`, then add `o`. Suggestions narrow to matching locations such as Goldshire when available in the client's area data.

- [ ] **LC02** Choose a suggestion with the mouse. Only the intended location token is replaced.

- [ ] **LC03** Choose with Up/Down and Tab. The selected location is inserted without prematurely creating the task.

- [ ] **LC04** Choose with Enter. The first Enter accepts the suggestion; the next Enter adds the task.

- [ ] **LC05** Press Escape while suggestions are open. The list closes without erasing the task.

- [ ] **LC06** Choose a multiword location. Quoting is inserted correctly, and the saved reminder contains the complete place name.

- [ ] **LC07** Edit a location token in the middle of a task. Text, tags, and quantities on either side remain intact.

- [ ] **LC08** Type an unmatched location manually. It can still be saved; the suggestion list does not block submission.

- [ ] **LC09** Type `mail@example` in ordinary text. It does not unexpectedly open location suggestions.

- [ ] **LC10** Edit a reminder's zone, press Enter, and reopen the editor. The zone persists; Here uses the current zone.

- [ ] **LC11** Switch between zone, Bank, Vendor, Mail, AH, Trainer, and Off. Only the selected reminder destination remains attached.

- [ ] **LC12** Enter more than one @ destination. Verify the saved destination is the last parsed one, as documented; use separate tasks for multiple destinations.

# Cards editor columns and filtering

- [ ] **ED01** Open a card by clicking it, through its right-click menu, and from the tracker. Each route opens the correct card.

- [ ] **ED02** Change title, notes, tags, and priority. Reopen the card and verify each change.

- [ ] **ED03** Edit card A's title/notes, then immediately open card B without pressing Enter. A receives its edit; B is not overwritten.

- [ ] **ED04** Switch cards while a goal field or location field is focused. No value leaks into the newly selected card.

- [ ] **ED05** Resize the main board while its editor is open. The editor scales with the board and its lower controls remain scrollable and accessible.

- [ ] **ED06** Open the editor from the tracker with the board closed. Its height and scrolling remain usable.

- [ ] **ED07** Add, edit, check, uncheck, and remove manual subtasks. Text and checkbox states persist.

- [ ] **ED08** Add/change/remove a live goal. Counts refresh and the old goal stops controlling the card.

- [ ] **ED09** Duplicate a disposable card. The copy is independently editable; changing it does not alter the original.

- [ ] **ED10** Drag a card between columns and reorder cards within a column. Each appears exactly once in the intended order.

- [ ] **ED11** Move cards using their context menus. Results match dragging, including Done and moving back out of Done.

- [ ] **ED12** Rename the three standard columns. Their underlying To Do/In Progress/Done behavior still works.

- [ ] **ED13** Added custom columns to the eight-column maximum. Horizontal scrolling exposed every column; attempting a ninth displayed “Taskboard: too many columns” and left the eight intact. The editor remained usable at this width.

- [ ] **ED14** Empty custom columns remove cleanly. A populated custom column refused removal until its card moved; the renamed standard Working and Finished columns showed disabled Remove controls.

- [ ] **ED15** Search by task text, filter by tag, and toggle Mine. Matching tasks are shown, and clearing filters restores the full board.

- [ ] **ED16** Drag or edit while a filter is active and a live count changes. No wrong card moves, disappears permanently, or changes ownership.

- [ ] **ED17** Archive a card, find it under Show archived cards, and restore it. Data survives and the tracker excludes it while archived.

- [ ] **ED18** Test archiving Done cards through the Done-column menu. Unfinished cards remain untouched.

- [ ] **ED19** Cancel a delete confirmation, then confirm deletion of a disposable card. Cancel keeps it; confirmation removes only that card.

- [ ] **ED20** Delete/archive a card while its editor is open. The editor closes or updates safely and cannot save changes into another card.

# Live goals and automatic status changes

Use targets just above current values when possible. A goal already met at creation may immediately finish; that is different from a plain manual task incorrectly finishing.

- [ ] **GL01** With bank counting off and 15 Silverleaf in bags, add `get 17 Silverleaf #qa`. It shows 15/17; acquiring two more finishes it.

- [ ] **GL02** Split/merge stacks and move items between bags. The total is unchanged and is not counted twice.

- [ ] **GL03** Buy, loot, trade for, and receive a tracked item by mail in separate trials. The count updates after each inventory change.

- [ ] **GL04** Sell, consume, or trade away tracked items before completion. The displayed count decreases appropriately.

- [ ] **GL05** Complete an item goal, then spend/sell the items. The task stays Done instead of reopening itself.

- [ ] **GL06** Manually move a satisfied item goal out of Done. It does not immediately snap back; let the count fall below target and then replenish it to test rearming.

- [ ] **GL07** Disable automatic starting. Make partial progress on a new goal. It stays in its chosen status while its numeric progress updates.

- [ ] **GL08** Disable automatic completion. Meet a new goal. It does not move to Done automatically, and manual completion still works.

- [ ] **GL09** Re-enable both options and repeat on fresh incomplete goals. Partial progress starts them and meeting all requirements finishes them.

- [ ] **GL10** Create a money goal above current funds. Earning money increases progress and spending before completion reduces it; it is current funds, not lifetime income.

- [ ] **GL11** Create `reach level 40 #qa`, or use an attainable level for your character. XP/level progress updates, and reaching the target completes it.

- [ ] **GL12** Create `Herbalism 150 #qa`, or use a profession/target you can test. Skill gains update the correct profession goal.

- [ ] **GL13** Create `Honored with Stormwind #qa`, or use a faction relevant to your character. Reputation gains and reaching the standing update the goal correctly.

- [ ] **GL14** Create a quest goal with a real shift-clicked quest link. It tracks the intended quest, with a clean display title.

- [ ] **GL15** Finish the quest objectives without turning it in. The task does not report the quest as turned in.

- [ ] **GL16** Turn in the tracked quest. The task completes once; reloading does not generate another completion.

- [ ] **GL17** Combine live and manual subtasks. The card waits for every required subtask before ordinary goal-driven completion.

- [ ] **GL18** Track the same item on two different cards with different targets. Both update independently without cross-editing.

- [ ] **GL19** Use `/tb refresh` after inventory/goal changes. Reevaluation is safe and does not create duplicate completion feedback.

# Bank counting

Taskboard uses the client's item counts; it does not maintain its own bank cache or scan other characters' banks. Record what the client can supply away from the bank.

- [ ] **BK01** Place a known amount of the goal item in bags and bank. With both bank switches on, the displayed total equals bags plus bank.

- [ ] **BK02** Turn off Count items in the bank on that card. Its count becomes bags only.

- [ ] **BK03** Turn the card switch on but the General bank-counting switch off. The result is still bags only.

- [ ] **BK04** Turn both back on. The count returns to bags plus bank without duplication.

- [ ] **BK05** Deposit and withdraw while the bank is open. Counts and status update correctly.

- [ ] **BK06** Close the bank and travel away. Record whether the client continues supplying bank totals; the addon must not invent additional counts or error.

- [ ] **BK07** Reload away from the bank, then visit the bank again. Record before/after counts and any correction after opening it.

- [ ] **BK08** Switch to B with different bag/bank contents. B's tasks use B's inventory and do not change A's recorded goals.

# Zone NPC and smart reminders

- [ ] **RM01** Create `Buy vials @Goldshire #qa` outside Goldshire, leaving it in To Do. Enter Goldshire: a reminder appears.

- [ ] **RM02** Repeat with an In Progress task. It reminds too; Done and archived equivalents do not.

- [ ] **RM03** Test a matching subzone and case-insensitive prefix, such as `@gold`. Matching follows the saved zone/subzone text.

- [ ] **RM04** Remain in the destination and move around. The task does not repeatedly spam reminders.

- [ ] **RM05** Leave and reenter within five minutes. The same task/context is suppressed; after the cooldown, a new entry can remind again.

- [ ] **RM06** Enter a matching location on the wrong assigned character. That character does not receive another character's task reminder.

- [ ] **RM07** Acquire a task's goal item outside its reminder location. Progress still counts; the @ destination is not a restriction on where progress happens.

- [ ] **RM08** Open the bank with `Sort supplies @bank #qa`. The bank task reminds; unrelated vendor/AH/trainer tasks do not.

- [ ] **RM09** Open a vendor with `Buy vials @vendor #qa`. The vendor reminder appears.

- [ ] **RM10** Open the auction house with `List auctions @ah #qa`. The AH reminder appears.

- [ ] **RM11** Open a trainer with `Learn new skills @trainer #qa`. The trainer reminder appears.

- [ ] **RM12** Turn General reminders off and repeat location/NPC triggers. Reminder popups/sounds stop; turn them back on and test again after a fresh entry/cooldown.

- [ ] **RM13** With smart reminders enabled, open the AH while an item goal is short. The message reports the correct missing quantity.

- [ ] **RM14** Open the bank while goal items are stored there. The smart reminder identifies the banked quantity.

- [ ] **RM15** Disable smart reminders while leaving ordinary reminders enabled. Explicit @ tasks still remind, but automatic missing-item/bank-item messages stop.

# Mailbox proximity and completion

The current design learns **your position when you open a mailbox**. It checks proximity about every **3 seconds**, enters the nearby state within **35 yards**, and leaves it beyond **50 yards**. Distances are approximate horizontal distances around the learned spot. A first-time, unlearned mailbox cannot give advance proximity reminders. The same task has a five-minute cooldown for repeated proximity alerts.

- [ ] **MB01** At a mailbox not yet learned, open it once. Check the log for a learned-mailbox entry when position data is available.

- [ ] **MB02** Create `Send items @mail #qa` for proximity testing. Opening the mailbox must leave this task unfinished.

- [ ] **MB03** Close the mailbox, move more than 50 yards away, wait at least three seconds, then approach within 35 yards. Within the next few seconds, receive Near a mailbox before opening it.

- [ ] **MB04** Stay nearby. The task remains highlighted/pulsing in the tracker when that setting is enabled, without repeated popup spam.

- [ ] **MB05** Move beyond 50 yards and wait for a scan. The nearby pulse stops; an otherwise untracked To Do task can disappear from the tracker.

- [ ] **MB06** Reapproach within five minutes. No duplicate proximity popup is expected. After five minutes, leave beyond 50 yards and approach again to test a new reminder.

- [ ] **MB07** Repeat after a UI reload and on B. Learned mailbox locations persist across characters, while reminders still apply only to eligible tasks.

- [ ] **MB08** Learn a second mailbox, preferably across a zone/city-map boundary. Both spots work independently without false reminders far away.

- [ ] **MB09** Add `Check mail @mail` while away, then open a mailbox. It moves to Done once and uses completion feedback.

- [ ] **MB10** Separately test `Check mailbox @mail`, `Check my mail @mail`, and `Check my mailbox @mail`. These supported titles also complete on opening.

- [ ] **MB11** Test mixed capitalization of a supported check-mail title. It still completes.

- [ ] **MB12** Open the mailbox with `Send materials @mail` and `Collect auction proceeds @mail`. They stay manual; merely opening does not prove those errands are finished.

- [ ] **MB13** Add plain `Check mail` without an @ token. Mail is inferred; opening a mailbox completes it when automatic completion is enabled and there are no unfinished goals/subtasks.

- [ ] **MB14** Finish or archive an @mail task, leave, and reapproach. It no longer reminds or pulses.

- [ ] **MB15** Turn reminders off while near a learned mailbox, then walk beyond 50 yards. Nearby pulse state clears on the next scan even though popups are disabled.

- [ ] **MB16** Add a new @mail task while already near a learned mailbox with reminders enabled. It reminds on the next scan without requiring a new entry, and does not repeat while you stay nearby.

- [ ] **MB17** Try `Check mail! @mail` and capitalization/punctuation variations of the supported English phrases. They complete when automatic completion is enabled. Renamed/localized phrases remain manual unless they match a supported title.

- [ ] **MB18** Add a check-mail task with unfinished subtasks or an unrelated live goal, then open the mailbox. The extra work must not complete prematurely. Also disable Automatic completion and verify a plain check-mail task stays open.

- [ ] **MB19** Test at an indoor/stacked-floor mailbox and where map positioning is unavailable. Record accuracy and diagnostics; missing position data must not cause errors or reminders at unrelated locations.

# Tracker visibility movement and layout

- [ ] **TR01** With Show all open tasks off and outside matching reminder locations, an untracked manual To Do task is absent.

- [ ] **TR02** Check Show in the on-screen tracker on that task. It appears; uncheck it and it disappears while still in To Do.

- [ ] **TR03** Move an unpinned task to In Progress. It appears automatically; unchecking Show in tracker does not hide an In Progress task.

- [ ] **TR04** Enable Include all open tasks. Manual To Do tasks appear; disable it and the default rules return.

- [ ] **TR05** Test the same all-open toggle from the tracker header menu. Its behavior agrees with General settings.

- [ ] **TR06** Finish and archive tasks. Neither Done nor archived cards remain in the tracker.

- [ ] **TR07** Switch characters. The tracker excludes other characters' tasks even while their board is selected.

- [ ] **TR08** Enter a matching reminder location with a To Do task. It appears near the top and pulses; leaving stops the pulse.

- [ ] **TR09** Disable Tracker location pulse. Nearby tasks no longer gain a pulse/forced nearby entry; ordinary pin/In Progress rules still work.

- [ ] **TR10** Hide the whole tracker, then progress a goal and enter a reminder location. It stays hidden.

- [ ] **TR11** Drag the unlocked tracker, lock it, and attempt to drag again. Lock prevents movement; unlock restores it.

- [ ] **TR12** Collapse/expand using the header. Tasks return correctly; the header menu can reopen the board and hide the tracker.

- [ ] **TR13** Create enough eligible tasks to require scrolling. Every task is reachable and the header's position/count is accurate.

- [ ] **TR14** Use long titles and a mix of manual/item goals. Rows remain separated, text stays legible, and progress bars do not overlap other rows.

- [ ] **TR15** Left-click and right-click tracker entries. The correct editor/card menu opens.

- [ ] **TR16** Enable Hide tracker in combat. Combat hides it and leaving combat restores the correct state; a manually hidden tracker stays hidden.

- [ ] **TR17** Reload after moving, locking, hiding, or collapsing the tracker. Each saved preference persists.

# Map pins

- [ ] **MP01** Use Pin my location on a card while outdoors. A location is saved and displayed.

- [ ] **MP02** Use Show on map. The waypoint points to the saved location, not your new current position.

- [ ] **MP03** Move elsewhere and reopen the card. Its pin does not silently move with you.

- [ ] **MP04** Clear the pin. The card no longer retains its saved pin.

- [ ] **MP05** Pin a manual task with no reminder destination and revisit the location. A map pin alone does not act as an arrival reminder or complete the task.

- [ ] **MP06** Try pinning/showing a waypoint where the client does not supply a usable map position. The addon reports the limitation without an error.

# Themes accents opacity and readability

For each theme, inspect the main board, a card/editor, tracker, Settings, Help, log window, and dropdown. Check both a bright outdoor scene and a dark background.

- [ ] **AP01** Midnight applies live and remains readable.

- [ ] **AP02** Warm leather applies live and remains readable.

- [ ] **AP03** Forest applies live and remains readable.

- [ ] **AP04** Arcane applies live and remains readable.

- [ ] **AP05** High contrast applies live and remains readable.

- [ ] **AP06** Classic stone shows the WoW-style frame/border artwork, with no missing or green textures.

- [ ] **AP07** Classic leather shows its distinct warm appearance and WoW-style artwork.

- [ ] **AP08** Change Sky, Gold, Mint, Rose, and Lilac accents in each theme. Titles, highlights, and selected controls update; status/priority colors keep their meanings.

- [ ] **AP09** Compare default opacity, 35%, and 100%. Board/tracker backgrounds change without fading all text/icons.

- [ ] **AP10** At 35% board opacity, inspect Settings, editor, Help, logs, Board dropdown, card menu, and confirmation prompts. These remain solid and readable.

- [ ] **AP11** Hover, select, focus, and disable controls after switching skins. Text contrast, borders, and active-state feedback remain clear.

- [ ] **AP12** Switch themes while several windows are already open, then open another window. Existing and newly opened windows match.

- [ ] **AP13** Check all theme/accent buttons and the opacity slider at your normal and a smaller UI scale. Nothing is clipped or unreachable.

- [ ] **AP14** Reload with a classic skin, custom accent, and opacity selected. All three persist.

- [ ] **AP15** Use Reset appearance. It returns to Midnight, Sky, and 96% opacity without changing task content.

# Sounds popups progress messages and statistics

- [ ] **FB01** Preview Off, Soft click, Chime, and Quest complete. Off is silent; the other choices can be heard at normal game volume.

- [ ] **FB02** Assign a distinct sound to status changes. Moving between statuses uses it; reordering within one column stays silent.

- [ ] **FB03** Assign a completion sound. Manual completion plays the completion feedback once.

- [ ] **FB04** Automatically complete an item task. It produces one completion sound rather than stacked move and completion sounds.

- [ ] **FB05** Set the subtask sound and complete manual and live subtasks. Feedback is appropriate; rapid events may be combined to avoid noise.

- [ ] **FB06** Set the reminder sound, then trigger a location/NPC/mailbox reminder. It uses the chosen reminder sound.

- [ ] **FB07** Set one event to Off. That event is silent while the others remain enabled.

- [ ] **FB08** Turn the master Play sounds switch off. Event sounds and preview respect it; turning it back on restores the chosen per-event sounds.

- [ ] **FB09** Disable visual popups but keep sounds on. Completion/reminder sounds still work without the popup.

- [ ] **FB10** Enable popups and trigger several events. Toasts stack/fade without obstructing interaction indefinitely.

- [ ] **FB11** Click a completion/reminder popup. It opens the intended card/board; an expired/deleted target does not open an unrelated card.

- [ ] **FB12** Toggle progress messages and gain tracked items. Messages appear only when enabled and use the correct item/count.

- [ ] **FB13** Reload after changing all sound selections and popup/message settings. Preferences persist.

- [ ] **FB14** Complete disposable tasks and inspect total/today/week/streak statistics. Counts change once per genuine completion; reorder/reload do not add completions.

# Daily weekly and offline resets

These need actual server reset sessions. Do not mark them passed by manually moving a card to To Do. Use a small attainable quantity if 17 items is inconvenient.

- [ ] **RC01** Hold 15 Silverleaf, then add `get 17 Silverleaf *daily #qa`. The goal starts at zero extra and requires 17 more above the baseline.

- [ ] **RC02** Acquire some extra stock, then spend/sell some. Net-gain progress decreases; it is not a lifetime loot counter.

- [ ] **RC03** Reload halfway through the daily goal. The saved baseline/progress survives.

- [ ] **RC04** Complete the daily goal, cross server daily reset, and check it again. It returns to To Do without an extra completion toast/sound.

- [ ] **RC05** Collect the next period's required extra stock. It completes once again from the new baseline.

- [ ] **RC06** Repeat with an item subtask inside a recurring card. Its checkbox/baseline resets correctly.

- [ ] **RC07** Switch a recurring item task to current-stock mode in the editor. After reset, already-sufficient stock does not immediately complete it again; drop below target and replenish to test rearming.

- [ ] **RC08** Test a manual daily task. Done resets to To Do at daily reset while the title/notes remain.

- [ ] **RC09** Repeat completion/reset with a weekly manual and item task at the weekly server reset.

- [ ] **RC10** Finish A's recurring task, log into B first after reset, then A. A's task is reset despite being offline.

- [ ] **RC11** Return after missing a reset period. The appropriate task streak breaks instead of continuing indefinitely.

- [ ] **RC12** Archive a recurring task before reset. It stays archived and is not unexpectedly reset/reactivated.

- [ ] **RC13** Return on an offline character after reset. The new inventory baseline begins at login; confirm the displayed extra-count behavior agrees.

- [ ] **RC14** Change global/card bank-counting settings during an unfinished recurring item goal. A new baseline is established without an accidental completion.

- [ ] **RC15** Change repeat mode between Never, Daily, and Weekly. The selected mode persists and the task follows only that schedule.

- [ ] **RC16** Test `Check mail @mail *daily`. Opening completes it, reset makes it actionable again, and a later mailbox visit can complete the new period.

# Sharing with another player

Both testers should use the same release. Use small disposable boards first. Mark this section Not run if a second tester or the required group type is unavailable.

- [ ] **SH01** Share a small board in a party. The recipient sees an offer and no board is silently accepted.

- [ ] **SH02** Decline an offer. Nothing is imported; send a fresh offer and accept it successfully.

- [ ] **SH03** Let an offer expire for over one minute. An expired offer cannot be accepted as a live transfer.

- [ ] **SH04** Disable share offers in General settings. Incoming offers do not create boards; re-enable and retest.

- [ ] **SH05** Repeat successful share/accept in a raid and in a guild.

- [ ] **SH06** Verify the received board remains separate from the recipient's one personal board and is labeled with its source.

- [ ] **SH07** Change each player's inventory independently. Each member's goal progress stays separate and the owner sees member progress.

- [ ] **SH08** On the recipient, try editing, dragging, deleting, archiving, renaming columns, and `/tb done` against the owner's shared cards. Restricted changes are blocked.

- [ ] **SH09** Keep the recipient editor open while the owner updates its card. The view updates safely without writing stale recipient text over it.

- [ ] **SH10** Delete the open shared card on the owner's side. The recipient editor closes or handles its removal safely.

- [ ] **SH11** Set a local tracker preference on a received card, then receive an owner update. The local preference survives.

- [ ] **SH12** Share a larger test board with normal other addons enabled. Transfer completes or reports an understandable failure, with no permanent partial board.

- [ ] **SH13** Stop sharing with `/tb unshare`, including during a queued transfer when feasible. Further pending outbound work stops.

- [ ] **SH14** Reload both clients after a successful share. Shared/local boards and permissions remain intact.

- [ ] **SH15** Try a board too large for addon messages. The addon reports the size limitation and text export remains available.

# Export import and data integrity

Imports add cards to the importing character's personal board. They can create duplicate tasks when you import the same content repeatedly, so use disposable test data.

- [ ] **EX01** Export a board through `/tb export` and through the Board menu. A complete copyable export is produced.

- [ ] **EX02** Import on another character. Cards are added to that character's personal board without creating a second personal board.

- [ ] **EX03** Compare titles, notes, tags, priority, statuses, subtasks, repeat settings, reminder destinations, and map pins against the source.

- [ ] **EX04** Check imported live goals. They are assigned to the importing character and do not reuse another character's cached progress/baseline.

- [ ] **EX05** Include custom columns. They are matched/added where possible; any column-limit fallback keeps the cards rather than losing them.

- [ ] **EX06** Paste invalid text, a truncated export, and a deliberately altered export. Each is rejected clearly without partially changing the board.

- [ ] **EX07** Import the same disposable export twice. Existing cards remain intact and newly imported cards are independent; record duplication clearly.

- [ ] **EX08** Export/import long titles, notes, punctuation, and item-link text. Display stays readable without unintended texture/link injection.

- [ ] **EX09** Reload after import. Imported cards and their status survive; no second import occurs on login.

- [ ] **EX10** Compare a before/after card inventory for migration and import tests. Account for every original card, including Done and archived entries.

# Help commands diagnostics and performance

- [ ] **DG01** Open Help from the board and `/tb help`. All three tabs open and scroll to their final entries.

- [ ] **DG02** Hover Quick Add repeatedly. A large examples list does not keep popping up; Help remains available by deliberate action.

- [ ] **DG03** Try a representative example from each Help section. It produces the documented task type or command behavior.

- [ ] **DG04** Run `/tb list`, then `/tb done 1` and `/tb done <matching title>` on disposable tasks. The intended open task is completed.

- [ ] **DG05** Run `/tb log show`. The log window opens, scrolls, and permits copying; its close button works outside and inside combat.

- [ ] **DG06** Run `/tb log 20` and `/tb diag`. Chat/report output is readable and contains the current version/build and useful diagnostics.

- [ ] **DG07** `/tb debug on` showed INFO/DEBUG chat and detailed command/card entries in the log. After `/tb debug off`, a new card produced only normal confirmation, with no verbose INFO line.

- [ ] **DG08** Cleared the log from its window after inspecting entries. It showed only “Log cleared”; the 19-card Queue and settings/editor remained intact.

- [ ] **DG09** Run `/tb selftest` again after the session. Compare with the initial result and investigate new failures.

- [ ] **DG10** Exercise a disposable board with roughly 100–200 varied tasks, long titles, subtasks, and eight columns. Scrolling, filtering, dragging, and typing remain responsive.

- [ ] **DG11** Loot rapidly while the board/editor/tracker are open. No heavy stutter, duplicate rows, or selection corruption occurs.

- [ ] **DG12** Travel through zones, open/close windows repeatedly, and play normally for at least 20 minutes. No growing popup backlog, stuck highlights, or repeated errors appear.

- [ ] **DG13** Repeat the core smoke tests with your normal addon set. If a problem occurs, compare a minimal-addon setup and record the conflict.

- [ ] **DG14** Check small/large UI scales and a changed resolution. Windows, menus, and tracker remain reachable with no hidden required controls.

# Bug reports

Leave the failed checkbox unchecked and add one row per issue. Attach screenshots for clipping/visual problems and the relevant `/tb diag` / `/tb log show` output for behavior problems.

| Case ID | Severity | Expected result | Actual result | Reproduction steps | Evidence and status |
| --- | --- | --- | --- | --- | --- |
| | | | | | |
| | | | | | |
| | | | | | |

**Severity:** Blocker = cannot load, lost/corrupted data, or unusable core flow. Major = incorrect goals/status, reminders, ownership, or an inaccessible control. Minor = visual/text issue with a usable workaround.

For each issue, record the addon/client versions, character, location, relevant settings, exact input, frequency, and whether reload changes it. For mailbox reports, include whether the spot was learned, whether you crossed beyond 50 yards, whether five minutes elapsed, and the task's exact title/status.

# Release signoff

- [ ] **SG01** All smoke tests pass on the target client.

- [ ] **SG02** Detailed tests are marked Passed, Failed, Not run, or Not applicable with reasons; an unchecked box alone is not treated as a pass.

- [ ] **SG03** Every failed case has a bug report and disposition. No unresolved data-loss, load, or core-workflow blocker remains.

- [ ] **SG04** Character consolidation, persistence, and import tests show no missing original cards.

- [ ] **SG05** Mailbox tests demonstrate both advance reminders at learned locations and correct completion of supported check-mail tasks.

- [ ] **SG06** Both classic skins, all accents, and opaque dialogs/dropdowns have been visually checked in game.

- [ ] **SG07** Daily/weekly and multiplayer coverage is explicitly recorded. Any untested feature is identified before deciding between Beta and Release.

- [ ] **SG08** The final distributed ZIP has the tested version and runtime files. A fresh install from that ZIP passes the smoke tests.

- [ ] **SG09** The CurseForge description and Help accurately state supported client, mailbox learning, character boards, and current limitations.

- [ ] **SG10** Record the release decision and remaining issues below.

**Release decision:** Pending  
**Open issues:**  
**Not run tests and reasons:**  
**Tester signoff:**

## Tests that need your participation

- [ ] **GAME01 — Real item and progression events.** Use a disposable item goal with a shift-clicked item link, then loot, spend or sell enough items to change its live count and finish it. Check the target, readable title, one completion, tracker and saved result after reload. As convenient, exercise money, level, profession, reputation and quest events. Reference: QA07–09 and GL.

- [ ] **GAME02 — Mailbox approach and completion.** Open a mailbox once to teach its position; close it, walk beyond 50 yards, then return within 35 yards and wait three seconds. Confirm the reminder flashes on approach and stops on exit. Check a task added while already nearby, reminder Off, `Check mail @mail` auto-completion on opening, and a mail task with unfinished subtasks. Test an indoor or multilevel mailbox if available. Reference: MB01–19, MAIL1301–02 and SND1301–04.

- [ ] **GAME03 — Combat window controls.** While in combat, close Settings, log, Help, editor and board windows with their X buttons and Escape where supported. Record any blocked-action or Lua error. Reference: UI11–12 and CLOSE03.

- [ ] **GAME04 — Travel, bank, map and audible feedback.** While playing, enter and leave a task zone, approach relevant NPCs, check cached bank counts away from the bank and after reload, and set a real map waypoint. Listen to each selected event sound, repeating nearby reminder interval, Off and master sound switch at your normal game volume. Reference: RM, BK, MP, FB and SND1301–04.

- [ ] **GAME05 — Isolated legacy migration.** If you have an older populated Questboard or pre-1.2 Taskboard save, test it in an isolated client profile. Compare every original card, status, archive, goal, setting and window position before and after the upgrade; reload twice, edit a migrated card and disable the legacy loader. Do not overwrite your active saves. Mark Not applicable if no older save exists. Reference: IN02–06 and BD11–16.

- [ ] **GAME06 — Server resets.** Observe one actual daily and one weekly reset with manual and item goals, including a character that was offline during the boundary. Check rearming, inventory baseline and streak behavior without duplicate completions. Reference: RC01–16.

- [ ] **GAME07 — Two-player sharing.** With a willing second player, send and decline/accept a party offer, then test the raid or guild channel you use. Verify owner updates, recipient read-only restrictions, member progress, reload and a larger transfer. Reference: SH01–15.

- [ ] **GAME08 — Normal-play session and final decision.** Play at least 20 minutes with your usual addons and a populated board; note FPS, memory, input responsiveness, sound comfort, visual readability at your preferred UI scale, and any Lua errors. Capture `/tb diag` and screenshots for failures, then complete release sign-off. Reference: DG10–14 and SG01–10.
