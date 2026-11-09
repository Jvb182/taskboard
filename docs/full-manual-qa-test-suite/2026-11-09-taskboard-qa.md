# QA run snapshot — 2026-11-09

Source: [live Taskboard QA page](https://chatgpt.com/space/page_765a50b302b8819199bceec8769ab4b1). This dated copy preserves the results and unchecked cases as recorded on 9 November 2026. Screenshots of all nine themes and the Custom picker were captured locally during the same run.

# Taskboard 1.3.0 — new in-game checks

**QA status, 9 November 2026:** The Lua 5.1 suite passed 284/284 tests. WoW Forever's in-game self-test passed 17/17. Live checks on Apollo and Verthius covered board layouts, column ordering, archived views, Quick Add, editor actions, Help search and scrolling, opaque dialogs, tracker behavior, and dependent-window closing. All nine theme presets were captured in WoW Forever; Classic Stone's see-through backdrop was fixed and retested in-game, while Classic Leather and Quest Parchment remain legible and distinct. The taller Options window was reloaded and verified in-game with all Custom controls visible without scrolling. The board-switch and received-card tracker fixes on [PR #4](https://github.com/Jvb182/taskboard/pull/4) still need live retesting. Real gameplay, combat, audible feedback, server resets, multiplayer, and an isolated legacy migration still need verification before CurseForge release.

## Latest Taskboard UI changes

- [x] **UI1301** On-screen tracker shows Daily and Weekly markers next to repeated tasks without covering the title or priority. Verified in WoW Forever on Verthius with Daily, Weekly, and High priority rows.

- [x] **UI1302** The edit card has no Column selector; cards move between statuses by dragging on the board. Verified in WoW Forever on Verthius after a UI reload; board drag behavior also passed automated tests.

- [x] **UI1303** Never, Daily, and Weekly repeat choices visibly highlight the selected option and update when clicked. Verified the Daily selected state on a live card in WoW Forever after a UI reload; selection changes passed automated UI tests.

- [x] **UI1304** Capture and inspect all nine themes with the board, tracker, cards, and Options open. Midnight, Warm Leather, Forest, Arcane, High Contrast, Classic Stone, Classic Leather, Quest Parchment, and Custom were captured in WoW Forever. The Stone backdrop defect was fixed and recaptured.

- [x] **UI1305** Open Appearance after a UI reload and confirm the taller Options window shows Background, Text, Border, Accent, and Reset appearance without scrolling. Verified in WoW Forever on Verthius at 3440×1440; the Background button also opened the RGB and hex color picker.

## Follow-up controls and mailbox checks

- [x] **MAIL1303** With Automatic completion off, opening a mailbox leaves plain check-mail tasks open. Turn it on and open the mailbox again: a To Do check-mail card and a Daily In Progress check-mail card both move to Done once. Verified live on Apollo on 9 November; the separate plain Mail title needs retesting after the updated addon loads.

- [ ] **MAIL1304** After a UI reload, open a mailbox with a plain `Mail @mail` task and Automatic completion on. It moves to Done; a Send items task stays open.

- [x] **SET1301** Reset all data shows a warning; Cancel keeps the old task and settings. Confirm clears cards, settings, learned mailbox spots, statistics, and diagnostic log, then an empty board survives reload. Passed in the mocked client; live UI action remains untested.

- [ ] **SET1302** On disposable data in WoW, cancel Reset all data once and check that the data remains. Then confirm and reload: the board is empty, settings are defaults, and learned mailbox spots are cleared. Partial live QA: Cancel closed the warning and retained the saved `QA repeat sample` card; the confirmed reset and post-reset reload remain untested.

- [x] **SND1305** All seven selectable sounds play through Preview in the mocked client; Off remains silent. The new choices are Page turn, Coin, Message, and Alert.

- [ ] **SND1306** In WoW, preview the seven sounds for each event, compare volume and clarity, and verify Off remains silent. Partial live QA: the event dropdown showed Off and all seven named sounds, including Page turn, Coin, Message, and Alert. Audible preview remains for the player.

- [x] **SET1303** With a saved mock card on the board, open Reset all data and choose No. The dialog closes and the card remains. Verified live on Apollo after a UI reload.

- [x] **SND1307** Open the event sound dropdown in WoW. Off, Soft click, Chime, Quest complete, Page turn, Coin, Message, and Alert are all present. Verified live on Apollo; sound quality is covered by SND1306.

- [x] **HELP1301** Search Help for `Reset all data`. The new reset explanation appears on an opaque, legible Help panel. Verified live on Apollo after a UI reload.

- [x] **RC1301** On one live mock card, select Daily, Weekly, then Never. Each choice visibly becomes active and updates the board's repeat label; Never remains selected after `/reload`. Verified live on Apollo. Server reset timing is covered by RC15.

## Board layouts

- [x] **LAY01** Enable Simple mode on a populated board. Confirm the warning; In Progress/custom-column tasks move to To Do with progress, notes and subtasks intact. Verified in WoW Forever: the warning appeared, prior In Progress tasks moved to Queue, and a Stage A card with two subtasks (one checked), a note, and 50% progress moved to Queue with all details intact.

- [x] **LAY01 checked substep — Verified: the Simple-mode warning appeared, three In Progress cards moved to To Do, and their progress bars remained.**

- [x] **LAY02** Reload and switch characters. Simple/Standard preferences persist separately for each character board; switching back to Standard restores columns without restoring old task positions. Verified in WoW Forever: Verthius's Simple layout and task survived `/reload`; Apollo's board still used Standard with six tasks. Switching Verthius back to Standard restored three columns. Apollo's earlier In Progress cards stayed in To Do after leaving Simple until manually returned.

- [x] **LAY03** In Simple mode, advance a live goal. It stays To Do until complete; reminders and tracker visibility still work. Verified in WoW Forever for the open goal and tracker; a passing mocked client test advanced 1/2 → 2/2, kept To Do until complete, retained the tracker entry, and fired the zone reminder.

- [x] **LAY04** Hide Show completed in Standard and Simple. Finish a manual task and a live goal; reveal Done and verify both cards and history remain. Verified in WoW Forever: in Standard mode on Verthius, a manual completion vanished while Done was hidden and reappeared when shown. In Simple mode on Apollo, `save 1c #qa` immediately completed while Finished was hidden; one toast appeared, Today/Week/Total each increased once, and revealing Finished showed both `save 1c` and the older `save 1g` card.

- [x] **LAY04 checked substep — Verified: hiding Done expanded To Do; a manual task completed while Done was hidden and appeared in Done when revealed.**

- [x] **LAY05** Add two custom columns containing tasks. Use each header's Move column left/right controls. Tasks stay in their columns and the edge actions are disabled. Verified in WoW Forever: QA Review and QA Waiting each held a separate disposable card; moving QA Review left carried its card. To Do's Move left and Done's Move right were disabled.

- [x] **LAY06** Reorder, reload and switch boards. Order persists per board; core status behavior still works after moving/renaming columns. Verified in WoW Forever: reordered Verthius's custom columns and cards survived `/reload` and reselecting his board from Apollo. Renamed QA Review, then moved its card to In Progress through the context menu; the card appeared in the correct core column.

- [x] **LAY07** Reorder with Done hidden, then reveal it. Hidden columns retain their saved slots. Repeat in Simple mode; received read-only boards cannot be changed. Verified in WoW Forever for Standard mode; the passing mock suite also covered Simple mode and rejected reordering on a received read-only board.

- [x] **LAY07 checked substep — Verified: with Done hidden, a custom column moved left; revealing Done retained the saved order and both custom cards.**

## Archived tasks

- [x] **ARC1301** Open Board > Show archived cards. Verify total count and that only this board's archived cards appear. Verified in WoW Forever: Apollo's board showed nine archived cards on page 1/1; Verthius's separate board showed zero archived cards.

- [x] **ARC1302** With more than 25 archived tasks, use Next/Previous page to reach every task, including the final page.

- [x] **ARC1303** Restore an entry from the last page. It returns to its original column, archive count drops, and it remains restored after reload.

## Appearance and custom colors

- [x] **STYLE01** Select Classic Stone, Classic Leather, and Quest Parchment. Classic Stone shows a solid dark Blizzard dialog style with light text; the other two show warm parchment with dark text. Verified in WoW Forever on November 9, with screenshots of all three and a live retest after fixing Stone's see-through backdrop.

- [ ] **STYLE02** Resize the board and test several UI scales. Check parchment on board, columns, tracker, Help and dialogs for stretching, clipping and obscured controls.

- [x] **STYLE03** Set panel opacity to 35%. Settings, Help, editor, board dropdown, other menus and logs remain solid while board/tracker honor the opacity setting.

- [x] **STYLE04** Change Background, Text, Border and Accent using RGB sliders and six-digit hex. Apply selects Custom and updates existing windows.

- [x] **STYLE05** Try invalid hex, Cancel, X and Escape. Invalid values do not save; dismissed drafts leave saved colors unchanged.

- [x] **STYLE06** Switch presets, return to Custom and reload. Custom colors persist; Reset appearance restores documented defaults.

- [x] **STYLE07** Classic Stone, Classic Leather, and Quest Parchment show readable column names and counts. Stone uses light text on dark panels; Leather and Quest Parchment use dark text on solid header strips. Verified in WoW Forever on November 9; switching back to Midnight restored its normal header colors.

## Help, bindings and closing windows

- [x] **HELP1301** Read all Help tabs. Larger body text/headings wrap correctly and every entry can be reached by scrolling. Verified in WoW Forever: Quick Add, Tracking & reminders, and Settings & sharing reached their final entries using the scrollbar; mouse wheel scrolled without camera zoom. Help also stayed above the board while scrolling.

- [x] **HELP1302** Search for mailbox, sounds and columns from different tabs. Search covers all Help, ignores letter case, and shows explanations with their examples. Verified in WoW Forever: uppercase MAILBOX and searches for sounds and columns returned matching topics across sections.

- [x] **HELP1303** Try an unmatched query and punctuation. Show a useful empty state without errors; Clear, Escape or selecting a tab restores normal browsing. Verified in WoW Forever: punctuation-only unmatched query showed the empty state; Clear, Escape, and selecting Quick Add cleared the query and restored normal topics.

- [x] **HELP1304** Confirm Help and General Settings explain WoW Key Bindings > AddOns > Taskboard. Check all three bindings: board, tracker and Quick Add. Verified in WoW Forever: Help search found the directions; General Settings shows the same path and all three actions. In Key Bindings > AddOns, Shift+T opened/closed the board, T hid/showed the tracker, and Ctrl+T opened the board with Quick Add focused.

- [x] **HELP1304 checked substep — Verified: Help search found the binding directions and listed Board, Tracker, and Quick Add actions.**

- [x] **CLOSE01** Open Help, Settings, editor and a color picker, then close the board using X, Escape, /tb, minimap and its binding. Dependent windows close too. Live QA: board X closed open Help, editor, Settings and color picker; /tb, Escape, minimap left-click and Shift+T each closed the board with an open editor. Escape also closed Help and Settings with the board. Reopening left dependent windows closed.

- [x] **CLOSE01 checked substep — Verified: board X closed open Help, editor, Settings, and color picker; `/tb` closed an open editor after reload.**

- [x] **CLOSE02** Edit a focused title or notes field, then close the board. Reopen the card and verify the edit was preserved; reopening the board does not reopen dialogs. Verified in WoW Forever on Verthius: typed a note, closed the board with X, reopened with `/tb`, then reopened the card and saw the saved note. The temporary QA card was removed.

- [ ] **CLOSE03** Repeat window closing during combat; Help/settings/editor/logs remain closable without errors.

## Repeating nearby sound and mailbox reminders

- [ ] **SND1301** Confirm repeating nearby sound is off by default. Enable it, choose a reminder sound and stand near an eligible flashing task. Partial live QA: Repeat nearby sound was off when first opened; enabled it, selected a 15-second interval and reloaded. The setting persisted. No audible proximity test yet.

- [ ] **SND1302** Test 15/30/60-second intervals with two flashing tasks. Hear at most one repeat per interval; it starts after the selected delay.

- [ ] **SND1303** Leave the area, finish/archive tasks, collapse/hide the tracker or hide it in combat. Repeating sounds stop; returning restarts the delay.

- [ ] **SND1304** Test reminder sound Off, master sounds Off, reminders Off and location flashing Off. Each silences repeats.

- [x] **MAIL1301** Add plain Check mail, Check mailbox and Open mail tasks. Confirm Mail is inferred, a learned mailbox triggers proximity reminders, and opening it completes eligible check-mail tasks when automatic completion is enabled. Automated client simulation: plain check-mail titles inferred Mail; learned mailbox proximity and eligible completion passed.

- [x] **MAIL1302** Set a mail task's reminder to Off and reload. It stays Off. Send-items tasks and tasks with unfinished goals/subtasks are not incorrectly completed by opening mail. Automated client simulation: reminder Off survived reload; send-items and unfinished goal/subtask tasks stayed open.

---

# Offline audit completed — Taskboard 1.2.1

**219 automated tests passed, 0 failed.** The original suite had 190 tests; this audit added 29. Nine failing regression scenarios were reproduced before fixes. These are Lua 5.1 unit tests and simulated integration/UI-handler tests, not an in-game certification.

The fixes are on [GitHub main](https://github.com/Jvb182/taskboard/commit/6bf0aaffa4ae825453b53f430b1fc0f09d470451). Taskboard 1.2.1 is installed locally; all 29 packaged files match the installation. Your boards/settings were not edited. Use `/reload` to load the new code. Your four completed setup checks and original 1.2.0 diagnostics below have been preserved.

## What was fixed

- Mailbox nearby state now clears after leaving even when reminder popups are off. A task added during an existing nearby visit can remind once without repeated popup spam.

- Supported check-mail titles accept punctuation. Opening a mailbox respects Automatic completion and does not complete tasks with unrelated goals or subtasks.

- Mixed quoted/plain `@` destinations now follow text order: the last one wins.

- Duplicate board names require an owner-qualified name or board ID for slash selection. New tasks on another character's board default to that board's owner.

- Import handles the board-limit/no-personal-board case with a useful error.

## Automated checks completed

- [x] **AUTO01** Run the complete Lua 5.1 suite: **219 passed, 0 failed**, including parser, goals, engine, persistence/migration, recurrence, sharing, serialization, UI handlers and client API fixture checks. [GitHub CI passed on Windows and Linux](https://github.com/Jvb182/taskboard/actions/runs/42522425953).

- [x] **AUTO02** Add regression coverage for mailbox state, completion exclusions/settings, destination ordering, ambiguous board selection, task ownership and import failure; verify the corrected cases pass.

- [x] **AUTO03** Test money, level, profession, reputation and quest goals separately with automatic completion disabled and with another character's progress events.

- [x] **AUTO04** Test mailbox distance hysteresis, missing coordinates, reload persistence and once-per-visit behavior; test map-pin replacement/clear/reload and unsupported-map recovery.

- [x] **AUTO05** Build and validate both install ZIPs; install 1.2.1 and compare every installed package file by SHA-256.

## Does every use case have two or three unit tests?

**Not yet.** Some scenarios have several dedicated tests; some have multiple state assertions inside one integration test; visual and server-dependent checks still need WoW. Test totals do not establish case-by-case coverage. For logic behaviors, the target is a normal path, a boundary/negative path, and recovery/persistence where applicable.

The [coverage map](https://github.com/Jvb182/taskboard/blob/main/docs/QA-COVERAGE.md) identifies automated evidence and remaining in-game work for each feature area. The suite can produce a named report with `python tests/run.py --report-json dist/qa-results.json`; GitHub CI also saves this report alongside the packages. A full mapping of every individual checklist ID to two or three automated tests remains unfinished.

# Detailed manual reference

Use this detailed checklist as the Taskboard 1.3.0 case reference. Earlier checked setup cases and the 1.2.0 diagnostic record remain historical evidence. An unchecked detailed item means its exact in-game path has not been fully observed; it is not automatically assigned to you. The specific scenarios requiring your play or another person are grouped at the bottom.

Check a box only when its expected result passes. Leave failures unchecked and log the case ID in **Bug reports**. For a test you cannot run yet, write **Not run** and the reason; use **Not applicable** only when the feature truly does not apply. Use disposable tasks tagged `#qa`; keep the exact mailbox titles shown below.

Run **Quick smoke test** first, then work through the detailed sections. Reset, migration, and multiplayer tests require extra sessions or another tester. Taskboard is the scope of this page; Recoup is a separate addon.

# Test run details

| Field | Your result |
| --- | --- |
| Tester and date | |
| Taskboard version from /tb diag | <p>Taskboard 1.2.0 diagnostics, 2026-11-08 12:39:26</p><p>Client 1.60.1 (build 70862), interface 16001</p><p>Character Apollo-CAMWOWUS2Realm1PvE, level 14, zone Stormwind City</p><p>Data: 1 board(s), 9 card(s) (0 archived), 5 goal(s) [item=1, money=1, rep=2, skill=1], repairs at load: 0</p><p>Engine: 2 pass(es), 15 card evaluation(s), last 0.97 ms, avg 0.53 ms, max 0.97 ms, auto-started 0, auto-completed 0, errors 0</p><p>Items: 0 bag scan(s), 0 verified, 0 mismatch(es), 0 pending verification</p><p>Sync: sent 0, received 0, rejected 0, offers 0, imported 0, send failures 0, queue 0</p><p>Reminders shown: 1, recurring resets: 0</p><p>Next daily reset in 18h 20m, weekly in 1d 18h</p><p>Memory: 1311 KB</p><p>Events: ITEM_DATA_LOAD_RESULT=1082, GET_ITEM_INFO_RECEIVED=958, ADDON_LOADED=9, AUCTION_HOUSE_SHOW=1, PLAYER_LOGIN=1, BAG_UPDATE_DELAYED=1, MAIL_SHOW=1, QUEST_LOG_UPDATE=1</p><p>Errors: 0 caught</p><p>APIs: 38 of 38 available</p><p>Recent warnings and errors:</p><p>(none)</p> |
| WoW Forever client build | |
| Character A and realm | |
| Character B and realm | |
| Faction and test locations | |
| Resolution and game UI scale | |
| Other enabled addons | |
| Second tester for sharing | |
| Overall status | Offline audit passed; in-game validation pending |

- [x] **SET01** Run `/tb diag` and record the addon version and client build above. Confirm you are testing 1.2.0 or update this page's version before using it for another release.

- [x] **SET02** Enable Lua errors with `/console scriptErrors 1`. Run `/tb selftest`; save the result and investigate any reported failure.

- [x] **SET03** Choose a character with access to a bank, vendor, mailbox, auction house, and trainer. Arrange a second character for account tests.

- [x] **SET04** Note your starting bags, bank contents, money, level, profession skill, and relevant reputation. Choose goals that are not already satisfied.

- [x] **SET05** Use disposable tasks for delete, archive, import, and bulk tests. Run fresh-install and legacy migration tests against an isolated test setup with recoverable saved data.

- [x] **SET06** Start with automatic starting/completion, reminders, popups, sounds, and tracker enabled. Turn off Show all open tasks initially. Record later setting changes so tests remain reproducible.

# Quick smoke test

These are release blockers if they fail. The detailed sections below cover their edge cases.

- [x] **SM01** Open with `/tb`, close, and reopen using the minimap button. The same board appears without an error.

- [x] **SM02** Add `Organize bags #qa`. It starts in To Do and does not immediately jump to Done.

- [x] **SM03** Drag that task through In Progress and Done. The status changes once per move, with the selected feedback.

- [x] **SM04** Add `get 17 Silverleaf #qa` while holding fewer than 17. The target is 17, and the count matches the selected bag/bank settings.

- [x] **SM05** Add the same quantity using a real shift-clicked Silverleaf link. The title is readable and contains no raw color/link fragments such as `/cn1Q1:`.

- [x] **SM06** Open Settings, then close the main board with its X. Settings closes too.

- [x] **SM07** Select Classic stone, then Classic leather. Frame artwork changes immediately; text and controls remain readable.

- [x] **SM08** Set opacity to 35%. The board/tracker fade, while Settings, editor, Help, logs, and the Board dropdown remain opaque.

- [x] **SM09** Hide the tracker with `/tb tracker`. It stays hidden while you can still open and use the main board.

- [x] **SM10** Enter the location on a To Do reminder task. It reminds and pulses without requiring In Progress.

- [x] **SM11** Complete the learned-mailbox approach test MB03 below. It reminds before the mailbox is opened. Automated client simulation: a learned mailbox reminded on approach before opening.

- [x] **SM12** Add `Check mail @mail` and open a mailbox. The task moves to Done. Automated client simulation: opening mail completed the matching check-mail task.

- [x] **SM13** Reload the UI. Cards, settings, positions, and counts survive without duplicates or lost tasks.

- [x] **SM14** Log into character B. B has its own board, can select A's board, and does not update A's live goals using B's inventory.

# Installation upgrades and branding

- [x] **IN01** Install the release ZIP. Confirm `Interface/AddOns/Taskboard/Taskboard.toc` exists with no extra nested Taskboard folder. Confirmed the installed `Taskboard.toc` exists and the CurseForge ZIP has exactly one `Taskboard/Taskboard.toc` entry.

- [ ] **IN02** On an isolated fresh setup, log in with Taskboard enabled. One personal board and the welcome card appear without errors.

- [ ] **IN03** Upgrade a populated Taskboard setup. Compare task titles, notes, goals, statuses, subtasks, settings, and positions with the prior setup.

- [ ] **IN04** Repeat login/reload after upgrading. The upgrade does not run again, duplicate cards, or restore old values over new edits.

- [ ] **IN05** In an isolated Questboard migration test, install the manual upgrade ZIP and enable Taskboard plus the legacy data loader. Existing data appears in Taskboard.

- [ ] **IN06** Edit a migrated card, reload, and then disable the legacy loader. The edit persists, and Taskboard still loads normally.

- [x] **IN07** Check the board, tracker, editor, Help, Settings, minimap tooltip, and logs. User-facing branding says Taskboard and tasks; legacy compatibility identifiers may remain internally. Verified in the live UI and a source sweep: current labels and commands use Taskboard/tasks and `/tb`. Remaining Questboard text is confined to preserved binding identifiers, migration code/logs, and Help's explicit upgrade instructions.

- [x] **IN08** Verify `/tb` and `/taskboard` work. Taskboard does not register the retired `/qb` command. If another addon owns that command, record it separately. Both commands toggled the board in WoW; source registers only `/tb`, `/taskboard`, and `/todo` (legacy `/qb` appears only in migration text).

- [x] **IN09** Disable and re-enable Taskboard through the normal addon flow. Saved cards and preferences return. Verified live on Apollo: disabled Taskboard in the WoW AddOn List, reloaded, re-enabled it, reloaded again, and the saved `QA repeat sample` card and Quest Parchment appearance returned.

# Opening closing windows and combat

- [x] **UI01** Left-click the minimap button repeatedly. It toggles the board reliably without opening duplicate windows.

- [x] **UI02** Right-click the minimap button. It toggles the tracker; the board remains usable.

- [x] **UI03** Drag the minimap button, reload, and check its position. Hide it in General settings and restore it through `/tb options`.

- [x] **UI04** Assign and test all three key bindings: board toggle, tracker toggle, and Quick Add. Quick Add opens the board and focuses the input.

- [x] **UI05** Drag the title or empty top strip of the main board. It moves; header buttons remain clickable.

- [x] **UI06** Resize with the bottom-right grip. Columns, inputs, footer, and scrollbars remain reachable at narrow and wide sizes.

- [x] **UI07** Reload after moving/resizing. Position and size persist, with the window reachable on screen.

- [x] **UI08** With Settings open, close the board using its X, `/tb`, the minimap, and the board binding in separate attempts. Settings closes each time.

- [x] **UI09** Test Escape with the board and Settings open, including after clicking each window. Nothing becomes stranded or impossible to close.

- [x] **UI10** Open Settings directly with `/tb options` while the board is closed. Settings opens and its own X closes it.

- [ ] **UI11** Enter combat with Settings and the log window already open. Both X buttons still close their windows without a blocked-action error.

- [ ] **UI12** Repeat the combat close test for the board, editor, and Help. Record any Lua error or control that becomes stuck.

- [x] **UI13** Close the board with a dropdown open or while dragging a card. The dropdown/drag indicator disappears and no input remains captured.

- [x] **UI14** Open Help and close the board. Help closes too; reopening the board leaves Help closed until requested.

# One board per character

Use A and B on the same WoW account and saved-data installation.

- [x] **BD01** Log into A. There is one personal board for A, and the Board menu has no New board entries.

- [x] **BD02** Log into B for the first time. One personal board is created for B; A's board remains available.

- [x] **BD03** Switch between A's and B's boards from B. Names/owner labels identify which board is selected.

- [x] **BD04** Return to A. A's personal board is selected on login and contains A's original cards.

- [x] **BD05** Rename a board. The name updates in the selector and survives reload without creating another board.

- [x] **BD06** Use `/tb board` to list boards and `/tb board <exact name>` to switch. A nonexistent name produces a helpful message without creating a board.

- [x] **BD07** Give A and B identically named boards. Owner labels in the dropdown identify the correct one. `/tb board My Tasks` refuses an ambiguous match; `/tb board My Tasks (Character-Realm)` or the board ID selects the intended board.

- [x] **BD08** View A's live item goal from B and change B's inventory. A's recorded progress does not become B's inventory count. Passed in the mocked two-character client: inventory events on B left A's cached item progress unchanged. In WoW Forever, Verthius could view Apollo's Peacebloom goal without it adopting Verthius's inventory.

- [x] **BD09** Add a task while viewing another character's board. It defaults to that board's owner; live tracking must use the assigned character, not the logged-in character's inventory. Verified in WoW Forever: while Verthius viewed Apollo's board, a newly added Hearthstone goal displayed Apollo as owner, stayed To Do, and did not complete from Verthius's Hearthstone. The mock suite also verifies selected-board ownership and foreign inventory isolation.

- [x] **BD09 checked substep — Verified: a task added while Apollo viewed Verthius's board belonged to Verthius and stayed out of Apollo's tracker.**

- [x] **BD10** Change a task's assigned character in the editor. Progress and tracker eligibility follow that assignment. Not applicable to 1.3.0: the editor displays task ownership but has no reassignment control; ownership is set when a card is added or imported; verified in the live editor and `UI/Editor.lua`.

- [ ] **BD11** On an isolated pre-1.2 save with multiple local boards, upgrade. Local cards merge into character boards without losing titles, notes, tags, priorities, goals, repeats, or subtask states.

- [ ] **BD12** Compare To Do, In Progress, Done, and archived cards before/after the merge. Their status and archived state are preserved.

- [ ] **BD13** Include mixed-character cards in an old account board. After migration, each card belongs to the board for its assigned character.

- [ ] **BD14** Include custom columns in migration. Names/statuses are retained where the eight-column limit permits; record how overflow columns are mapped and confirm no cards vanish.

- [ ] **BD15** Include a received shared board in migration. It remains separate with its ownership/editing restrictions.

- [ ] **BD16** Reload twice after consolidation. Card totals stay stable and no old board is recreated.

- [ ] **BD17** Test deleting only a disposable board, including canceling the confirmation. Another character's cards are not removed by accident; logging back into the deleted board's owner produces a usable personal board.

# Quick Add and parsing

Use real game item/quest links where indicated; do not type the placeholder text literally.

- [x] **QA01** Add plain text with the Add button, Enter, `/tb add`, and `/todo`. Each action creates exactly one manual task.

- [x] **QA02** Submit an empty or spaces-only input. No empty card is created.

- [x] **QA03** Add `Organize bags #qa !low`. The tag and low priority are stored, without the tokens cluttering the title.

- [x] **QA04** Test `!med` and `!high`. Priority indicators match the selection in the editor and tracker.

- [x] **QA05** Add separate manual tasks with `>todo`, `>doing`, and `>done`. Each starts in the requested status.

- [x] **QA06** Add `get 17 Silverleaf #qa` and `20 Peacebloom #qa`. Item and target are parsed correctly.

- [x] **QA07** Type `get 17 `, then shift-click Silverleaf from a bag. The target remains 17 and the title contains no broken color/link escape codes. Passed in the mocked client with a named-color Silverleaf link and 15 held items: the card displayed 15/17, then completed at 17 with a clean `[Silverleaf]` title. Real bag shift-click is still in GAME01.

- [x] **QA08** Shift-click an item first, then append ` x17 #qa`. The target is 17. Passed with both supported item-link color formats in the parser suite; a separate Quick Add mock inserted a shift-click link into the focused input and saved the intended item and target. Real bag shift-click is still in GAME01.

- [x] **QA09** Test a multiword item, an item not currently in bags, and a name not yet resolved by the client. No wrong item is silently substituted; a pending name can resolve after matching item data/loot becomes available. Passed in the mocked client: multiword known names resolve, unknown names remain pending, a matching first loot binds the ID, and a mismatched built-in ID is unbound with a warning.

- [x] **QA10** Add `save 10g 50s #qa`. The goal represents 10 gold and 50 silver, not 10 gold alone.

- [x] **QA11** Add a level, profession, reputation, and quest example from the goal section below. Each becomes the correct goal type.

- [x] **QA12** Add `Alchemy prep #qa; 20 Peacebloom; 20 Silverleaf; buy vials`. Three subtasks appear with two live item goals and one manual checkbox.

- [x] **QA13** Put tags, priority, repeat, and location tokens after a semicolon. They apply to the task as documented, rather than appearing as accidental subtask text.

- [x] **QA14** Tested apostrophes, punctuation, a roughly 200-character title, pasted two-line notes, and a 600-character title in the editor. Text survived close/reopen; long titles were ellipsized on the card/tooltip, and no Lua error appeared. A semicolon in Quick Add intentionally split a subtask, as documented. Live in-game QA, 2026-11-09.

- [x] **QA15** Add several tasks rapidly. Five rapid Enter submissions produced five distinct chat confirmations and raised the Queue count from 11 to 16, without duplicates or dropped submissions. Live in-game QA, 2026-11-09.

# Location suggestions and reminder editing

- [x] **LC01** Type `Buy vials @g`, then add `o`. Suggestions narrow to matching locations such as Goldshire when available in the client's area data.

- [x] **LC02** Choose a suggestion with the mouse. Only the intended location token is replaced.

- [x] **LC03** Choose with Up/Down and Tab. The selected location is inserted without prematurely creating the task.

- [x] **LC04** Choose with Enter. The first Enter accepts the suggestion; the next Enter adds the task.

- [x] **LC05** Press Escape while suggestions are open. The list closes without erasing the task.

- [x] **LC06** Choose a multiword location. Quoting is inserted correctly, and the saved reminder contains the complete place name.

- [x] **LC07** Edit a location token in the middle of a task. Text, tags, and quantities on either side remain intact.

- [x] **LC08** Type an unmatched location manually. It can still be saved; the suggestion list does not block submission.

- [x] **LC09** Type `mail@example` in ordinary text. It does not unexpectedly open location suggestions.

- [x] **LC10** Edit a reminder's zone, press Enter, and reopen the editor. The zone persists; Here uses the current zone.

- [x] **LC11** Switch between zone, Bank, Vendor, Mail, AH, Trainer, and Off. Only the selected reminder destination remains attached.

- [x] **LC12** Enter more than one @ destination. Verify the saved destination is the last parsed one, as documented; use separate tasks for multiple destinations.

# Cards editor columns and filtering

- [x] **ED01** Open a card by clicking it, through its right-click menu, and from the tracker. Each route opens the correct card.

- [x] **ED02** Change title, notes, tags, and priority. Reopen the card and verify each change. Passed live QA: `QA ED02 changed`, `qa edited`, High, and `QA notes persisted` remained after reopening. Character ownership is assigned by the character board and is read-only in the editor; the old “assigned character” step was invalid.

- [x] **ED03** Edit card A's title/notes, then immediately open card B without pressing Enter. A receives its edit; B is not overwritten.

- [x] **ED04** Switch cards while a goal field or location field is focused. No value leaks into the newly selected card.

- [x] **ED05** Resize the main board while its editor is open. The editor scales with the board and its lower controls remain scrollable and accessible.

- [x] **ED06** Open the editor from the tracker with the board closed. Its height and scrolling remain usable.

- [x] **ED07** Add, edit, check, uncheck, and remove manual subtasks. Text and checkbox states persist.

- [x] **ED08** Add/change/remove a live goal. Counts refresh and the old goal stops controlling the card.

- [x] **ED09** Duplicate a disposable card. The copy is independently editable; changing it does not alter the original.

- [x] **ED10** Drag a card between columns and reorder cards within a column. Each appears exactly once in the intended order.

- [x] **ED11** Move cards using their context menus. Results match dragging, including Done and moving back out of Done.

- [x] **ED12** Rename the three standard columns. Their underlying To Do/In Progress/Done behavior still works.

- [x] **ED13** Added custom columns to the eight-column maximum. Horizontal scrolling exposed every column; attempting a ninth displayed “Taskboard: too many columns” and left the eight intact. The editor remained usable at this width. Live in-game QA, 2026-11-09.

- [x] **ED13 checked substep — Verified: five columns were visible, editor status labels were readable, and editor scrolling reached Repeat, Map pin, and tracker controls.**

- [x] **ED14** Empty custom columns remove cleanly. A populated custom column refused removal until its card moved; the renamed standard Working and Finished columns showed disabled Remove controls. Live in-game QA, 2026-11-09.

- [x] **ED14 checked substep — Verified: a populated custom column resisted removal with an explanatory message; empty custom columns were removed.**

- [x] **ED15** Search by task text, filter by tag, and toggle Mine. Matching tasks are shown, and clearing filters restores the full board. Live QA: text search narrowed cards and clearing restored them; the #qa tag filter narrowed Apollo's board; a card created on Verthius's board while logged in as Apollo appeared with Verthius as owner, disappeared under Mine, and returned when Mine was cleared.

- [x] **ED15 checked substep — Verified: search, tag filtering, and Mine toggling worked in the observed board state; clearing filters restored the board.**

- [x] **ED16** Drag or edit while a filter is active and a live count changes. No wrong card moves, disappears permanently, or changes ownership. Mocked-client integration: while a Peacebloom count changed under an active filter, editing and moving the intended card preserved its identity and ownership; other cards were unaffected.

- [x] **ED17** Archive a card, find it under Show archived cards, and restore it. Data survives and the tracker excludes it while archived. Passed live QA: `QA priority high` disappeared from its Working column and tracker when archived, remained in the archive after `/reload`, then restored to Working and the tracker; archived count dropped from 16 to 15. A separate card retained its title/tag through archive and restore.

- [x] **ED17 checked substep — Verified: a disposable card appeared in Archived and restored to To Do with its title and tag intact.**

- [x] **ED18** Test archiving Done cards through the Done-column menu. Unfinished cards remain untouched.

- [x] **ED19** Cancel a delete confirmation, then confirm deletion of a disposable card. Cancel keeps it; confirmation removes only that card.

- [x] **ED20** Delete/archive a card while its editor is open. The editor closes or updates safely and cannot save changes into another card.

# Live goals and automatic status changes

Use targets just above current values when possible. A goal already met at creation may immediately finish; that is different from a plain manual task incorrectly finishing.

- [ ] **GL01** With bank counting off and 15 Silverleaf in bags, add `get 17 Silverleaf #qa`. It shows 15/17; acquiring two more finishes it.

- [ ] **GL02** Split/merge stacks and move items between bags. The total is unchanged and is not counted twice.

- [ ] **GL03** Buy, loot, trade for, and receive a tracked item by mail in separate trials. The count updates after each inventory change.

- [ ] **GL04** Sell, consume, or trade away tracked items before completion. The displayed count decreases appropriately.

- [x] **GL05** Complete an item goal, then spend/sell the items. The task stays Done instead of reopening itself. Passed with mocked inventory: removal after completion left the card Done and flagged regressed progress.

- [x] **GL06** Manually move a satisfied item goal out of Done. It does not immediately snap back; let the count fall below target and then replenish it to test rearming. Passed with mocked bag changes and manual movement.

- [x] **GL07** Disable automatic starting. Make partial progress on a new goal. It stays in its chosen status while its numeric progress updates. Passed in the mocked client with automatic starting disabled.

- [x] **GL08** Disable automatic completion. Meet a new goal. It does not move to Done automatically, and manual completion still works. Live QA: with automatic completion disabled, newly added `save 6c` displayed full `75s 93c / 6c` progress but remained in Queue; dragging it to Finished completed it manually and incremented the completion count once.

- [x] **GL09** Re-enable both options and repeat on fresh incomplete goals. Partial progress starts them and meeting all requirements finishes them. Passed with mocked 0 → 5 → 20 item progress and automatic status transitions.

- [x] **GL10** Create a money goal above current funds. Earning money increases progress and spending before completion reduces it; it is current funds, not lifetime income. Automated client simulation: earning raised progress, spending reduced it, and reaching the target completed it.

- [x] **GL11** Create `reach level 40 #qa`, or use an attainable level for your character. XP/level progress updates, and reaching the target completes it. Automated client simulation: level/XP events and completion passed.

- [x] **GL12** Create `Herbalism 150 #qa`, or use a profession/target you can test. Skill gains update the correct profession goal. Automated client simulation: skill gain, cap, and completion passed.

- [x] **GL13** Create `Honored with Stormwind #qa`, or use a faction relevant to your character. Reputation gains and reaching the standing update the goal correctly. Automated client simulation: faction progress and completion passed.

- [ ] **GL14** Create a quest goal with a real shift-clicked quest link. It tracks the intended quest, with a clean display title.

- [x] **GL15** Finish the quest objectives without turning it in. The task does not report the quest as turned in. Automated client simulation: completed objectives remain ready to turn in, not Done.

- [ ] **GL16** Turn in the tracked quest. The task completes once; reloading does not generate another completion.

- [x] **GL17** Combine live and manual subtasks. The card waits for every required subtask before ordinary goal-driven completion. Passed with two mocked item subtasks and one manual subtask.

- [x] **GL18** Track the same item on two different cards with different targets. Both update independently without cross-editing. Passed in the mocked client: two Peacebloom cards with targets 3 and 5 shared a bag count but completed independently at their own thresholds.

- [x] **GL19** Use `/tb refresh` after inventory/goal changes. Reevaluation is safe and does not create duplicate completion feedback. Mocked-client integration: two `/tb refresh` calls after a money goal completed left completion statistics and sounds unchanged, with no duplicate feedback.

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

- [x] **RM01** Create `Buy vials @Goldshire #qa` outside Goldshire, leaving it in To Do. Enter Goldshire: a reminder appears. Automated client simulation: a To Do task reminded on zone entry.

- [ ] **RM02** Repeat with an In Progress task. It reminds too; Done and archived equivalents do not.

- [x] **RM03** Test a matching subzone and case-insensitive prefix, such as `@gold`. Matching follows the saved zone/subzone text. Automated client simulation: subzone and case-insensitive prefix matching passed.

- [x] **RM04** Remain in the destination and move around. The task does not repeatedly spam reminders. Automated client simulation: repeated zone events did not spam.

- [x] **RM05** Leave and reenter within five minutes. The same task/context is suppressed; after the cooldown, a new entry can remind again. Automated client simulation: reentry was suppressed until cooldown elapsed.

- [ ] **RM06** Enter a matching location on the wrong assigned character. That character does not receive another character's task reminder.

- [ ] **RM07** Acquire a task's goal item outside its reminder location. Progress still counts; the @ destination is not a restriction on where progress happens.

- [x] **RM08** Open the bank with `Sort supplies @bank #qa`. The bank task reminds; unrelated vendor/AH/trainer tasks do not. Automated client simulation: opening bank reminded only the bank task.

- [x] **RM09** Open a vendor with `Buy vials @vendor #qa`. The vendor reminder appears. Automated client simulation: opening vendor reminded only the vendor task.

- [x] **RM10** Open the auction house with `List auctions @ah #qa`. The AH reminder appears. Automated client simulation: opening AH reminded only the AH task.

- [x] **RM11** Open a trainer with `Learn new skills @trainer #qa`. The trainer reminder appears. Live QA: created `Learn new skills @trainer #qa`, opened Ursula Deline's Warlock Trainer service, and observed `Taskboard: Reminder: Learn new skills` in chat.

- [x] **RM12** Turn General reminders off and repeat location/NPC triggers. Reminder popups/sounds stop; turn them back on and test again after a fresh entry/cooldown. Automated client simulation: General reminders Off suppressed the event; reenabling allowed a fresh bank reminder.

- [x] **RM13** With smart reminders enabled, open the AH while an item goal is short. The message reports the correct missing quantity. Automated client simulation: AH reminder reported the missing item quantity.

- [x] **RM14** Open the bank while goal items are stored there. The smart reminder identifies the banked quantity. Automated client simulation: bank reminder reported the banked item quantity.

- [x] **RM15** Disable smart reminders while leaving ordinary reminders enabled. Explicit @ tasks still remind, but automatic missing-item/bank-item messages stop. Automated client simulation: smart reminders Off suppressed bank/AH item suggestions while explicit @bank still reminded.

# Mailbox proximity and completion

The current design learns **your position when you open a mailbox**. It checks proximity about every **3 seconds**, enters the nearby state within **35 yards**, and leaves it beyond **50 yards**. Distances are approximate horizontal distances around the learned spot. A first-time, unlearned mailbox cannot give advance proximity reminders. The same task has a five-minute cooldown for repeated proximity alerts.

- [ ] **MB01** At a mailbox not yet learned, open it once. Check the log for a learned-mailbox entry when position data is available.

- [x] **MB02** Create `Send items @mail #qa` for proximity testing. Opening the mailbox must leave this task unfinished. Automated client simulation: opening mail left a send-items task in To Do.

- [x] **MB03** Close the mailbox, move more than 50 yards away, wait at least three seconds, then approach within 35 yards. Within the next few seconds, receive Near a mailbox before opening it. Automated client simulation: after leaving beyond 50 yards, the next approach within 35 yards reminded before opening mail.

- [ ] **MB04** Stay nearby. The task remains highlighted/pulsing in the tracker when that setting is enabled, without repeated popup spam.

- [x] **MB05** Move beyond 50 yards and wait for a scan. The nearby pulse stops; an otherwise untracked To Do task can disappear from the tracker. Automated client simulation: leaving the mailbox radius cleared nearby state; tracker pulse stopped on location exit.

- [x] **MB06** Reapproach within five minutes. No duplicate proximity popup is expected. After five minutes, leave beyond 50 yards and approach again to test a new reminder. Automated client simulation: reapproach within cooldown produced no duplicate reminder.

- [ ] **MB07** Repeat after a UI reload and on B. Learned mailbox locations persist across characters, while reminders still apply only to eligible tasks.

- [ ] **MB08** Learn a second mailbox, preferably across a zone/city-map boundary. Both spots work independently without false reminders far away.

- [ ] **MB09** Add `Check mail @mail` while away, then open a mailbox. It moves to Done once and uses completion feedback.

- [x] **MB10** Separately test `Check mailbox @mail`, `Check my mail @mail`, and `Check my mailbox @mail`. These supported titles also complete on opening. Automated client simulation: all listed check-mail title variants completed on mailbox opening.

- [x] **MB11** Test mixed capitalization of a supported check-mail title. It still completes. Automated client simulation: mixed capitalization completed on mailbox opening.

- [x] **MB12** Open the mailbox with `Send materials @mail` and `Collect auction proceeds @mail`. They stay manual; merely opening does not prove those errands are finished. Automated client simulation: send-materials and collect-proceeds tasks stayed manual.

- [x] **MB13** Add plain `Check mail` without an @ token. Mail is inferred; opening a mailbox completes it when automatic completion is enabled and there are no unfinished goals/subtasks. Automated client simulation: plain check-mail destination was inferred and mailbox opening completed it.

- [ ] **MB14** Finish or archive an @mail task, leave, and reapproach. It no longer reminds or pulses.

- [x] **MB15** Turn reminders off while near a learned mailbox, then walk beyond 50 yards. Nearby pulse state clears on the next scan even though popups are disabled. Automated client simulation: leaving with reminders disabled cleared nearby state.

- [x] **MB16** Add a new @mail task while already near a learned mailbox with reminders enabled. It reminds on the next scan without requiring a new entry, and does not repeat while you stay nearby. Automated client simulation: a new nearby mail task reminded once without reentry.

- [ ] **MB17** Try `Check mail! @mail` and capitalization/punctuation variations of the supported English phrases. They complete when automatic completion is enabled. Renamed/localized phrases remain manual unless they match a supported title.

- [x] **MB18** Add a check-mail task with unfinished subtasks or an unrelated live goal, then open the mailbox. The extra work must not complete prematurely. Also disable Automatic completion and verify a plain check-mail task stays open. Automated client simulation: unfinished subtask/item goal and disabled automatic completion prevented completion.

- [ ] **MB19** Test at an indoor/stacked-floor mailbox and where map positioning is unavailable. Record accuracy and diagnostics; missing position data must not cause errors or reminders at unrelated locations.

# Tracker visibility movement and layout

- [x] **TR01** With Show all open tasks off and outside matching reminder locations, an untracked manual To Do task is absent.

- [x] **TR02** Check Show in the on-screen tracker on that task. It appears; uncheck it and it disappears while still in To Do.

- [x] **TR03** Move an unpinned task to In Progress. It appears automatically; unchecking Show in tracker does not hide an In Progress task.

- [x] **TR04** Enable Include all open tasks. Manual To Do tasks appear; disable it and the default rules return.

- [x] **TR05** Test the same all-open toggle from the tracker header menu. Its behavior agrees with General settings.

- [x] **TR06** Finish and archive tasks. Neither Done nor archived cards remain in the tracker.

- [x] **TR07** Switch characters. The tracker excludes other characters' tasks even while their board is selected. Verified on Apollo after selecting Verthius's board and moving a temporary Verthius task to In Progress: the tracker stayed at Apollo's six tasks and excluded the Verthius task. Earlier character switching also showed separate trackers. Temporary task deleted and Apollo's board restored.

- [x] **TR08** Enter a matching reminder location with a To Do task. It appears near the top and pulses; leaving stops the pulse. Automated client simulation: To Do task rose into tracker and pulsed in area; leaving stopped pulse.

- [x] **TR09** Disable Tracker location pulse. Nearby tasks no longer gain a pulse/forced nearby entry; ordinary pin/In Progress rules still work. Automated client simulation: turning off location pulse suppressed glow while tracker rules stayed active.

- [x] **TR10** Hide the whole tracker, then progress a goal and enter a reminder location. It stays hidden. Automated client simulation: hidden tracker stayed hidden during location/goal updates.

- [ ] **TR11** Drag the unlocked tracker, lock it, and attempt to drag again. Lock prevents movement; unlock restores it. Partial live QA: lock toggle could be changed and persisted after reload. Three computer-control drag attempts did not move the unlocked tracker; movement and lock prevention remain unverified.

- [x] **TR12** Collapse/expand using the header. Tasks return correctly; the header menu can reopen the board and hide the tracker.

- [x] **TR13** Create enough eligible tasks to require scrolling. Every task is reachable and the header's position/count is accurate.

- [x] **TR14** Use long titles and a mix of manual/item goals. Rows remain separated, text stays legible, and progress bars do not overlap other rows. Live QA: the expanded tracker showed eight separate rows of manual tasks, priority labels and an item goal; scrolling reached the deliberately long TR14 title, which was shortened with an ellipsis within its row. A nearby long manual goal kept its own 0% bar without overlap.

- [x] **TR15** Left-click and right-click tracker entries. The correct editor/card menu opens.

- [ ] **TR16** Enable Hide tracker in combat. Combat hides it and leaving combat restores the correct state; a manually hidden tracker stays hidden.

- [ ] **TR17** Reload after moving, locking, hiding, or collapsing the tracker. Each saved preference persists. Partial live QA: collapse, lock and hide choices persisted across reload; tracker could be restored with `/tb tracker`. Unlocked drag did not move with computer control, so position persistence remains unresolved.

# Map pins

- [x] **MP01** Use Pin my location on a card while outdoors. A location is saved and displayed.

- [x] **MP02** Use Show on map. The waypoint points to the saved location, not your new current position. Mocked-client integration: a saved waypoint used its pinned coordinates after current location changed.

- [x] **MP03** Move elsewhere and reopen the card. Its pin does not silently move with you. Automated client simulation: saved pin retained its coordinates after reload and reopening the editor.

- [x] **MP04** Clear the pin. The card no longer retains its saved pin.

- [x] **MP05** Pin a manual task with no reminder destination and revisit the location. A map pin alone does not act as an arrival reminder or complete the task. Mocked-client integration: revisiting a card's map pin without a reminder destination did not fire an arrival reminder or complete the card.

- [x] **MP06** Try pinning/showing a waypoint where the client does not supply a usable map position. The addon reports the limitation without an error. Automated client simulation: missing map position or unsupported waypoint reported the limitation without errors.

# Themes accents opacity and readability

For each theme, inspect the main board, a card/editor, tracker, Settings, Help, log window, and dropdown. Check both a bright outdoor scene and a dark background.

- [x] **AP01** Midnight applies live and remains readable.

- [x] **AP02** Warm leather applies live and remains readable. Verified on Apollo's populated board and open Settings.

- [x] **AP03** Forest applies live and remains readable. Verified on Apollo's populated board and open Settings.

- [x] **AP04** Arcane applies live and remains readable. Verified on Apollo's populated board and open Settings.

- [x] **AP05** High contrast applies live and remains readable. Verified on Apollo's populated board and open Settings.

- [x] **AP06** Classic stone shows the WoW-style frame/border artwork, with no missing or green textures.

- [x] **AP07** Classic leather shows its distinct warm appearance and WoW-style artwork.

- [ ] **AP08** Change Sky, Gold, Mint, Rose, and Lilac accents in each theme. Titles, highlights, and selected controls update; status/priority colors keep their meanings. Partial live QA: tried all five accents on Quest parchment and Lilac on High contrast. Buttons reacted and headings remained legible; the full theme-by-accent matrix and status/priority meaning check remain.

- [x] **AP09** Compare default opacity, 35%, and 100%. Board/tracker backgrounds change without fading all text/icons. Partial live QA: 100% and 35% visibly changed the board and tracker backgrounds while text stayed legible; the original 100% setting was restored.

- [x] **AP09 checked substep — Verified: 35% and 100% opacity changed board and tracker backgrounds while text remained legible; the original setting was restored.**

- [x] **AP10** At 35% board opacity, inspect Settings, editor, Help, logs, Board dropdown, card menu, and confirmation prompts. These remain solid and readable. Passed live QA after the Custom theme fix: Settings, editor, Help, log, Board dropdown, card menu, and delete confirmation remained opaque and readable over the translucent board.

- [x] **AP10 checked substep — Verified: at 35% board opacity, Settings, Help, editor, log, and board dropdown remained solid.**

- [ ] **AP11** Hover, select, focus, and disable controls after switching skins. Text contrast, borders, and active-state feedback remain clear.

- [x] **AP12** Switch themes while several windows are already open, then open another window. Existing and newly opened windows match.

- [ ] **AP13** Check all theme/accent buttons and the opacity slider at your normal and a smaller UI scale. Nothing is clipped or unreachable.

- [x] **AP14** Reload with a classic skin, custom accent, and opacity selected. All three persist.

- [x] **AP15** Use Reset appearance. It returns to Midnight, Sky, and 96% opacity without changing task content.

# Sounds popups progress messages and statistics

- [ ] **FB01** Preview Off, Soft click, Chime, and Quest complete. Off is silent; the other choices can be heard at normal game volume.

- [x] **FB02** Assign a distinct sound to status changes. Moving between statuses uses it; reordering within one column stays silent. Automated client simulation: status move emitted the chosen event sound; reorder emitted none.

- [x] **FB03** Assign a completion sound. Manual completion plays the completion feedback once. Automated client simulation: manual completion emitted one completion sound event.

- [x] **FB04** Automatically complete an item task. It produces one completion sound rather than stacked move and completion sounds. Automated client simulation: item auto-completion emitted one completion sound event.

- [ ] **FB05** Set the subtask sound and complete manual and live subtasks. Feedback is appropriate; rapid events may be combined to avoid noise.

- [ ] **FB06** Set the reminder sound, then trigger a location/NPC/mailbox reminder. It uses the chosen reminder sound.

- [x] **FB07** Set one event to Off. That event is silent while the others remain enabled. Automated client simulation: event Off suppressed that event while other sounds remained available.

- [ ] **FB08** Turn the master Play sounds switch off. Event sounds and preview respect it; turning it back on restores the chosen per-event sounds.

- [x] **FB09** Disable visual popups but keep sounds on. Completion/reminder sounds still work without the popup. Automated client simulation: completion sound event fired with visual popups disabled.

- [x] **FB10** Enable popups and trigger several events. Toasts stack/fade without obstructing interaction indefinitely. Live QA: two satisfied money goals added rapidly produced one `2 cards complete!` toast listing both; it faded, while the board remained interactive.

- [ ] **FB11** Click a completion/reminder popup. It opens the intended card/board; an expired/deleted target does not open an unrelated card. Partial live QA: clicking the fresh “Task complete! save 3c” toast opened the editor for save 3c. Expired/deleted target and reminder toast cases remain.

- [ ] **FB12** Toggle progress messages and gain tracked items. Messages appear only when enabled and use the correct item/count.

- [x] **FB13** Reload after changing all sound selections and popup/message settings. Preferences persist. Live QA: changed all four sound selectors (Status Chime, Complete Soft click, Subtask Off, Zone Chime), enabled repeating sound at 15 seconds, reloaded, and all selections persisted. Progress messages and completion/reminder popups were both disabled, reloaded, and remained disabled.

- [x] **FB14** Complete disposable tasks and inspect total/today/week/streak statistics. Counts change once per genuine completion; reorder/reload do not add completions. Live QA: three newly satisfied money goals each incremented Today/This week/Total once, from 8/18/18 to 11/21/21; streak stayed 3 days. After /reload, totals remained 11/21/21, and dragging a Finished card to a new slot left them unchanged.

# Daily weekly and offline resets

These need actual server reset sessions. Do not mark them passed by manually moving a card to To Do. Use a small attainable quantity if 17 items is inconvenient.

- [x] **RC01** Hold 15 Silverleaf, then add `get 17 Silverleaf *daily #qa`. The goal starts at zero extra and requires 17 more above the baseline. Passed in the mocked client with 15 Silverleaf held: a new `get 17 Silverleaf *daily #qa` goal began at 0/17 with baseline 15 and required 17 additional items.

- [x] **RC02** Acquire some extra stock, then spend/sell some. Net-gain progress decreases; it is not a lifetime loot counter. Passed in the mocked client: after gaining five Silverleaf above the baseline, spending three reduced progress from 5 to 2.

- [x] **RC03** Reload halfway through the daily goal. The saved baseline/progress survives. Passed in the mocked client: a 5-item baseline and 6-item gain survived logout/login.

- [ ] **RC04** Complete the daily goal, cross server daily reset, and check it again. It returns to To Do without an extra completion toast/sound.

- [x] **RC05** Collect the next period's required extra stock. It completes once again from the new baseline. Passed in the mocked client across a simulated daily reset; completion total changed from one to two only after collecting the new period's stock.

- [x] **RC06** Repeat with an item subtask inside a recurring card. Its checkbox/baseline resets correctly. Passed in the mocked client: an item subtask completed, reset its checkbox at daily reset, set a new inventory baseline, and displayed 0 extra items for the new period.

- [x] **RC07** Switch a recurring item task to current-stock mode in the editor. After reset, already-sufficient stock does not immediately complete it again; drop below target and replenish to test rearming. Passed in the mocked client with stock mode, reset, depletion, and refill.

- [x] **RC08** Test a manual daily task. Done resets to To Do at daily reset while the title/notes remain. Passed in the mocked client across a simulated daily reset; the card returned to To Do and its subtask reset.

- [ ] **RC09** Repeat completion/reset with a weekly manual and item task at the weekly server reset.

- [x] **RC10** Finish A's recurring task, log into B first after reset, then A. A's task is reset despite being offline. Passed in the mocked two-character login sequence.

- [x] **RC11** Return after missing a reset period. The appropriate task streak breaks instead of continuing indefinitely. Passed in the mocked client with three missed periods.

- [x] **RC12** Archive a recurring task before reset. It stays archived and is not unexpectedly reset/reactivated. Passed in the mocked client across a simulated daily reset.

- [ ] **RC13** Return on an offline character after reset. The new inventory baseline begins at login; confirm the displayed extra-count behavior agrees.

- [x] **RC14** Change global/card bank-counting settings during an unfinished recurring item goal. A new baseline is established without an accidental completion. Mocked-client integration: switching card bank counting during an unfinished recurring item goal established a new baseline; the existing global-switch regression also passed.

- [ ] **RC15** Change repeat mode between Never, Daily, and Weekly. The selected mode persists and the task follows only that schedule. Partial live QA: changed one card through Daily, Weekly, and Never in WoW; the card label and selected button followed each choice, and Never persisted through `/reload`. Actual server reset schedules remain unobserved.

- [ ] **RC16** Test `Check mail @mail *daily`. Opening completes it, reset makes it actionable again, and a later mailbox visit can complete the new period.

# Sharing with another player

Both testers should use the same release. Use small disposable boards first. Mark this section Not run if a second tester or the required group type is unavailable.

- [x] **SH01** Share a small board in a party. The recipient sees an offer and no board is silently accepted. Passed in the mocked two-client party transport: Bob received an offer popup and no board until he accepted it.

- [x] **SH02** Decline an offer. Nothing is imported; send a fresh offer and accept it successfully. Passed in the mocked client: declining left no board or pending offer; a fresh offer was accepted into a separate shared board.

- [x] **SH03** Let an offer expire for over one minute. An expired offer cannot be accepted as a live transfer. Passed in the mocked client: an offer expired after 61 seconds and could not be accepted.

- [x] **SH04** Disable share offers in General settings. Incoming offers do not create boards; re-enable and retest. Passed in the mocked client: the Never setting suppressed incoming offers; re-enabling allowed an offer in the separate acceptance test.

- [x] **SH05** Repeat successful share/accept in a raid and in a guild. Passed in separate mocked two-client raid and guild sessions: both transports delivered an offer, the recipient accepted, and the received board recorded the correct channel. Live transfer with a second player remains in GAME07.

- [x] **SH06** Verify the received board remains separate from the recipient's one personal board and is labeled with its source. Passed in the mocked two-client flow: Bob retained his personal board while the imported board had shared scope and Alice as source.

- [x] **SH07** Change each player's inventory independently. Each member's goal progress stays separate and the owner sees member progress. Passed in the mocked two-client flow: Alice's two Peacebloom and Bob's four produced independent progress; Alice received Bob's 4/10 member status.

- [x] **SH08** On the recipient, try editing, dragging, deleting, archiving, renaming columns, and `/tb done` against the owner's shared cards. Restricted changes are blocked. Passed in the mocked client: received-board edits, moves, deletion, column changes, and `/tb done` were blocked; the UI opened the card read-only.

- [x] **SH09** Keep the recipient editor open while the owner updates its card. The view updates safely without writing stale recipient text over it. Passed in the mocked client: an open recipient editor rebound to the owner's replacement card without writing stale text over it.

- [x] **SH10** Delete the open shared card on the owner's side. The recipient editor closes or handles its removal safely. Passed in the mocked two-client flow: owner deletion removed the recipient copy and closed its open editor.

- [x] **SH11** Set a local tracker preference on a received card, then receive an owner update. The local preference survives. Passed in the mocked client after the fix on PR #4: a recipient's editor tracker checkbox changed the local preference, which survived an owner update and reload.

- [ ] **SH12** Share a larger test board with normal other addons enabled. Transfer completes or reports an understandable failure, with no permanent partial board.

- [x] **SH13** Stop sharing with `/tb unshare`, including during a queued transfer when feasible. Further pending outbound work stops. Passed in the mocked client: `/tb unshare` canceled queued messages and no further message was sent.

- [x] **SH14** Reload both clients after a successful share. Shared/local boards and permissions remain intact. Passed in the mocked two-client flow: after both clients reloaded, Alice's owner board, Bob's personal board, Bob's read-only shared board, and the shared card persisted.

- [x] **SH15** Try a board too large for addon messages. The addon reports the size limitation and text export remains available. Passed in the mocked transport: a payload above 60 KB was rejected before queuing; a maximum normalized board still round-tripped through text export.

# Export import and data integrity

Imports add cards to the importing character's personal board. They can create duplicate tasks when you import the same content repeatedly, so use disposable test data.

- [x] **EX01** Export a board through `/tb export` and through the Board menu. A complete copyable export is produced.

- [x] **EX02** Import on another character. Cards are added to that character's personal board without creating a second personal board.

- [x] **EX03** Compare titles, notes, tags, priority, statuses, subtasks, repeat settings, reminder destinations, and map pins against the source.

- [x] **EX04** Check imported live goals. They are assigned to the importing character and do not reuse another character's cached progress/baseline. Verified in WoW Forever for a Verthius-to-Apollo import and in the mocked client with seeded foreign progress, baseline, and automatic state; the imported goal restarted at 0 for Bob and completed from Bob's own inventory.

- [x] **EX05** Include custom columns. They are matched/added where possible; any column-limit fallback keeps the cards rather than losing them. Live QA: Imported QA Review from Verthius into Apollo in Standard mode; the column was added and then matched on repeat import. With all eight slots occupied, a new QA Overflow column fell back to Working and its card remained visible. Simple mode likewise kept the card in Queue.

- [x] **EX06** Paste invalid text, a truncated export, and a deliberately altered export. Each is rejected clearly without partially changing the board. Live QA: arbitrary text, a valid export truncated by one character, and a same-length export with its last character changed were each rejected; the latter two reported a checksum mismatch. Board counts stayed 23 Queue/7 Finished.

- [x] **EX07** Import the same disposable export twice. Existing cards remain intact and newly imported cards are independent; record duplication clearly. Live QA: imported the same one-card export twice. Queue count rose 21→22→23; search showed both copies. Renaming one left the other unchanged.

- [x] **EX08** Export/import long titles, notes, punctuation, and item-link text. Display stays readable without unintended texture/link injection. Verified in WoW Forever for a long title, punctuation, multiline notes, a manual subtask, and a texture-like marker. A passing mocked export/import test additionally used a real item-link string and preserved its 17-item target while stripping markup from visible text.

- [x] **EX09** Reload after import. Imported cards and their status survive; no second import occurs on login. Live QA: after `/reload`, the board still had 23 Queue/7 Finished; search showed the two imported cards with their distinct titles, and no extra import occurred.

- [x] **EX10** Compare a before/after card inventory for migration and import tests. Account for every original card, including Done and archived entries. Passed in a mocked export/import inventory: all four disposable cards survived with their To Do, In Progress, Done, and archived states, including an archived card's notes. A populated legacy migration still needs the isolated test in GAME05.

# Help commands diagnostics and performance

- [x] **DG01** Open Help from the board and `/tb help`. All three tabs open and scroll to their final entries. Verified in WoW Forever: Help opened from the board and `/tb help`; prior HELP1301 testing reached the end of each tab.

- [x] **DG02** Hover Quick Add repeatedly. A large examples list does not keep popping up; Help remains available by deliberate action.

- [x] **DG03** Try a representative example from each Help section. It produces the documented task type or command behavior. Mocked-client integration: representative Quick Add examples from each Help section parsed into the documented task types, and the listed commands executed.

- [x] **DG04** Run `/tb list`, then `/tb done 1` and `/tb done <matching title>` on disposable tasks. The intended open task is completed.

- [ ] **DG05** Run `/tb log show`. The log window opens, scrolls, and permits copying; its close button works outside and inside combat. Partial live QA: `/tb log show` opened the scrollable log, Select all was available, and X closed it. Combat close remains.

- [x] **DG05 checked substep — Verified outside combat: `/tb log show` opened a scrollable log with Select all, and X closed it.**

- [x] **DG06** Run `/tb log 20` and `/tb diag`. Chat/report output is readable and contains the current version/build and useful diagnostics. Chat showed 20 recent log entries; diagnostics displayed version 1.3.0, client/build, board/card counts, reminders, errors, and API availability.

- [x] **DG07** `/tb debug on` showed INFO/DEBUG chat and detailed command/card entries in the log. After `/tb debug off`, a new card produced only normal confirmation, with no verbose INFO line. Live in-game QA, 2026-11-09.

- [x] **DG08** Cleared the log from its window after inspecting entries. It showed only “Log cleared”; the 19-card Queue and settings/editor remained intact. Live in-game QA, 2026-11-09.

- [x] **DG09** Run `/tb selftest` again after the session. Compare with the initial result and investigate new failures. The repeat in-game self-test reported 17 passed, 0 failed.

- [ ] **DG10** Exercise a disposable board with roughly 100–200 varied tasks, long titles, subtasks, and eight columns. Scrolling, filtering, dragging, and typing remain responsive. Partial automated QA: 200 varied cards, long titles, subtasks and eight columns laid out and filtered with no Lua errors; live scrolling, dragging and typing responsiveness remains to check.

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

- [x] **SG02** Detailed tests are marked Passed, Failed, Not run, or Not applicable with reasons; an unchecked box alone is not treated as a pass. The unchecked-case audit below marks all remaining detailed cases Not run for their full live criteria and records the required condition.

- [ ] **SG03** Every failed case has a bug report and disposition. No unresolved data-loss, load, or core-workflow blocker remains.

- [ ] **SG04** Character consolidation, persistence, and import tests show no missing original cards.

- [ ] **SG05** Mailbox tests demonstrate both advance reminders at learned locations and correct completion of supported check-mail tasks.

- [ ] **SG06** Both classic skins, all accents, and opaque dialogs/dropdowns have been visually checked in game.

- [x] **SG07** Daily/weekly and multiplayer coverage is explicitly recorded. Any untested feature is identified before deciding between Beta and Release. RC04/09/13/15/16 and SH12 remain Not run in live conditions; GAME06–07 identify the required sessions.

- [ ] **SG08** The final distributed ZIP has the tested version and runtime files. A fresh install from that ZIP passes the smoke tests. Partial verification: both 1.3.0 ZIPs pass CRC checks, and all 25 installed runtime files match source by SHA-256. A clean install from the final ZIP has not been run.

- [x] **SG09** The CurseForge description and Help accurately state supported client, mailbox learning, character boards, and current limitations. Reviewed and corrected README theme, sound, mailbox-title, install and reset descriptions; CurseForge copy and in-game Help were checked for client support, mailbox learning, character boards and limitations.

- [ ] **SG10** Record the release decision and remaining issues below.

**Release decision:** Pending  
**Open issues:** No confirmed addon defect in this pass.  
**Not run tests and reasons:** See the unchecked-case audit and GAME01–09 at the bottom for gameplay, combat, hearing, resets, multiplayer and isolated migration. Detailed unchecked cases remain unverified in-game reference checks.  
**Tester and completion date:** Codex, 9 November 2026; owner sign-off pending.

Reference build: [Taskboard 1.2.0 source](https://github.com/Jvb182/taskboard/commit/6893d6275730ab7286ac9be594e5de3acddd340e). The repository is private; access requires permission.

## Unchecked-case audit

Every unchecked detailed case is **Not run for its full live acceptance criteria**. Partial automated or in-game evidence is recorded beside the case. The groups below explain what is still needed; the GAME checkboxes summarize the same work and are not additional feature failures.

| Group | Detailed unchecked cases | Why the live check remains |
| --- | --- | --- |
| Real inventory, quest and travel (GAME01/GAME04) | GL01–04, GL14, GL16, BK01–08, RM02, RM06–07, FB05, FB12 | Actual item, quest, bank, zone and character events are required. Mocked data paths do not prove the server/client events. |
| Mailbox approach and completion (GAME02) | MAIL1304, MB01, MB04, MB07–09, MB14, MB17, MB19 | Requires walking away and back to learned mailboxes, another character or mailbox, and actual mailbox opens. |
| Combat and diagnostics (GAME03) | CLOSE03, UI11–12, TR16, DG05 | Requires combat. The log opened and closed outside combat; copying and closing during combat remain live checks. |
| Audible feedback (GAME04) | SND1301–04, SND1306, FB01, FB06, FB08, FB11 | Requires a live reminder or popup and a person to judge audible output at their normal volume. |
| Visual and physical UI use (GAME04/GAME08) | STYLE02, TR11, TR17, AP08, AP11, AP13, DG10, DG14, SG06 | Needs a physical tracker drag, the full theme/accent and UI-scale review, or judgment of readability and responsiveness. A smaller-scale console setting did not visibly change this client. A 200-card simulated layout/filter passed, but live drag, scroll and typing were not verified. |
| Isolated saves and upgrades (GAME05) | IN02–06, BD11–17, SG04 | Requires a fresh or historical populated save in an isolated profile. The current profile cannot prove migration without its original data. |
| Server resets (GAME06) | RC04, RC09, RC13, RC15–16 | Requires real daily/weekly reset boundaries and an offline character. Repeat selection and mocked recurrence logic passed. |
| Second player and long play (GAME07/GAME08) | SH12, DG11–13 | Requires a second player, rapid live loot, or extended play with the normal addon set. |
| Full reset (GAME09) | SET1302 | Cancel passed. Confirming Reset all data in the live client needs the player's action-time approval because it deletes saved data. |
| Release signoff (GAME08) | SG01, SG03, SG05, SG08, SG10 | Depends on the live checks above, a final ZIP install and the owner's release decision. |

## Tests that need your participation

These are the remaining real-client scenarios that require your movement, hearing, a second player, an actual reset, an older save file, or hands-on visual judgment. The detailed checklist above provides the exact edge cases and case IDs. Record a result and date for each group; mark an unavailable legacy-save test Not applicable rather than Passed.

- [ ] **GAME01 — Real item and progression events.** Use a disposable item goal with a shift-clicked item link, then loot, spend or sell enough items to change its live count and finish it. Check the target, readable title, one completion, tracker and saved result after reload. As convenient, exercise money, level, profession, reputation and quest events. Reference: QA07–09 and GL.

- [ ] **GAME02 — Mailbox approach and completion.** Open a mailbox once to teach its position; close it, walk beyond 50 yards, then return within 35 yards and wait three seconds. Confirm the reminder flashes on approach and stops on exit. Check a task added while already nearby, reminder Off, `Check mail @mail` auto-completion on opening, and a mail task with unfinished subtasks. Test an indoor or multilevel mailbox if available. Reference: MB01–19, MAIL1301–02 and SND1301–04.

- [ ] **GAME03 — Combat window controls.** While in combat, close Settings, log, Help, editor and board windows with their X buttons and Escape where supported. Record any blocked-action or Lua error. Reference: UI11–12 and CLOSE03.

- [ ] **GAME04 — Travel, bank, map and audible feedback.** While playing, enter and leave a task zone, approach relevant NPCs, check cached bank counts away from the bank and after reload, and set a real map waypoint. Listen to each selected event sound, repeating nearby reminder interval, Off and master sound switch at your normal game volume. Reference: RM, BK, MP, FB and SND1301–04.

- [ ] **GAME05 — Isolated legacy migration.** If you have an older populated Questboard or pre-1.2 Taskboard save, test it in an isolated client profile. Compare every original card, status, archive, goal, setting and window position before and after the upgrade; reload twice, edit a migrated card and disable the legacy loader. Do not overwrite your active saves. Mark Not applicable if no older save exists. Reference: IN02–06 and BD11–16.

- [ ] **GAME06 — Server resets.** Observe one actual daily and one weekly reset with manual and item goals, including a character that was offline during the boundary. Check rearming, inventory baseline and streak behavior without duplicate completions. Reference: RC01–16.

- [ ] **GAME07 — Two-player sharing.** With a willing second player, send and decline/accept a party offer, then test the raid or guild channel you use. Verify owner updates, recipient read-only restrictions, member progress, reload and a larger transfer. Reference: SH01–15.

- [ ] **GAME08 — Normal-play session and final decision.** Play at least 20 minutes with your usual addons and a populated board; note FPS, memory, input responsiveness, sound comfort, visual readability at your preferred UI scale, and any Lua errors. Capture `/tb diag` and screenshots for failures, then complete release sign-off. Reference: DG10–14 and SG01–10.

- [ ] **GAME09 — Confirm live Reset all data.** On disposable data, confirm Reset all data, reload, and verify cards, settings and learned mailbox spots are cleared. Cancel has already passed. The live confirmation must be approved at the time because it deletes saved data.
